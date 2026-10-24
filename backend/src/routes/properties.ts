import { Router } from 'express';
import { z } from 'zod';
import {
  FinishingLevel,
  ListingType,
  PaymentMethod,
  Prisma,
  PropertyStatus,
  PropertyType,
} from '@prisma/client';
import { prisma } from '../db';
import { requireAuth } from '../middleware/auth';
import { badRequest, forbidden, notFound } from '../lib/errors';
import {
  detailInclude,
  listInclude,
  serializeProperty,
} from '../lib/serializers';

export const propertiesRouter = Router();

// ---------------------------------------------------------------
//  GET /api/properties — بحث + فلترة (نفس فلاتر شاشة الرئيسية)
// ---------------------------------------------------------------

const csvInts = z
  .string()
  .transform((s) => s.split(',').filter(Boolean).map(Number))
  .pipe(z.array(z.number().int().positive()).max(20));

const listQuery = z.object({
  listingType: z.nativeEnum(ListingType).optional(),
  type: z.nativeEnum(PropertyType).optional(),
  districtIds: csvInts.optional(),
  minPrice: z.coerce.number().nonnegative().optional(),
  maxPrice: z.coerce.number().positive().optional(),
  finishing: z.nativeEnum(FinishingLevel).optional(),
  payment: z.nativeEnum(PaymentMethod).optional(),
  featured: z.enum(['true', 'false']).transform((v) => v === 'true').optional(),
  q: z.string().trim().min(1).max(80).optional(),
  sort: z.enum(['latest', 'price_asc', 'price_desc']).default('latest'),
  page: z.coerce.number().int().min(1).default(1),
  limit: z.coerce.number().int().min(1).max(50).default(20),
});

const orderByMap: Record<string, Prisma.PropertyOrderByWithRelationInput[]> = {
  latest: [{ publishedAt: 'desc' }, { id: 'asc' }],
  price_asc: [{ price: 'asc' }, { id: 'asc' }],
  price_desc: [{ price: 'desc' }, { id: 'asc' }],
};

propertiesRouter.get('/', async (req, res) => {
  const q = listQuery.parse(req.query);

  const where: Prisma.PropertyWhereInput = {
    status: PropertyStatus.ACTIVE,
    ...(q.listingType && { listingType: q.listingType }),
    ...(q.type && { type: q.type }),
    ...(q.districtIds?.length && { districtId: { in: q.districtIds } }),
    ...((q.minPrice !== undefined || q.maxPrice !== undefined) && {
      price: { gte: q.minPrice, lte: q.maxPrice },
    }),
    ...(q.finishing && { finishing: q.finishing }),
    ...(q.payment && { paymentMethods: { has: q.payment } }),
    ...(q.featured !== undefined && { isFeatured: q.featured }),
    ...(q.q && {
      OR: [
        { title: { contains: q.q, mode: 'insensitive' } },
        { district: { name: { contains: q.q, mode: 'insensitive' } } },
      ],
    }),
  };

  // قراءتين مستقلتين — مش محتاجين transaction (وبتتفادى تحذير pg عن الاستعلامات المتزامنة)
  const [total, rows] = await Promise.all([
    prisma.property.count({ where }),
    prisma.property.findMany({
      where,
      include: listInclude,
      orderBy: orderByMap[q.sort],
      skip: (q.page - 1) * q.limit,
      take: q.limit,
    }),
  ]);

  res.json({
    data: rows.map(serializeProperty),
    page: q.page,
    limit: q.limit,
    total,
    totalPages: Math.ceil(total / q.limit),
  });
});

// ---------------------------------------------------------------
//  GET /api/properties/:id — التفاصيل
// ---------------------------------------------------------------

const idParam = z.object({ id: z.string().uuid('الـ id مش صحيح') });

propertiesRouter.get('/:id', async (req, res) => {
  const { id } = idParam.parse(req.params);
  const p = await prisma.property.findUnique({ where: { id }, include: detailInclude });

  const isOwner = !!p && req.user?.id === p.ownerId;
  // الإعلانات غير النشطة بتظهر لصاحبها بس
  if (!p || (p.status !== PropertyStatus.ACTIVE && !isOwner)) throw notFound('العقار مش موجود');

  if (!isOwner) {
    // عدّاد مشاهدات بسيط. TODO: يتحول لحدث منفصل (PropertyView) لو احتجنا منع التكرار.
    prisma.property
      .update({ where: { id }, data: { viewsCount: { increment: 1 } } })
      .catch((e) => console.error('views increment failed', e));
  }
  res.json({ data: serializeProperty(p) });
});

// ---------------------------------------------------------------
//  POST /api/properties — إضافة عقار (شاشة Add Property)
// ---------------------------------------------------------------

const httpsUrl = z
  .string()
  .url()
  .refine((u) => u.startsWith('https://'), 'لازم الرابط يبدأ بـ https://');

const createBody = z
  .object({
    title: z.string().trim().min(3, 'العنوان قصير').max(120),
    description: z.string().trim().max(2000).optional(),
    type: z.nativeEnum(PropertyType),
    listingType: z.nativeEnum(ListingType),
    districtId: z.number().int().positive(),
    projectId: z.string().uuid().optional(),
    price: z.number().positive().max(100_000_000_000),
    area: z.number().int().min(1).max(1_000_000),
    beds: z.number().int().min(0).max(20).default(0),
    baths: z.number().int().min(0).max(20).default(0),
    finishing: z.nativeEnum(FinishingLevel).nullish(),
    paymentMethods: z.array(z.nativeEnum(PaymentMethod)).min(1, 'اختار طريقة دفع'),
    features: z.array(z.string().trim().min(1).max(40)).max(20).default([]),
    images: z.array(httpsUrl).min(1, 'ضيف صورة واحدة على الأقل').max(8),
  })
  .superRefine((b, ctx) => {
    const hasBeds = b.type === 'APARTMENT' || b.type === 'VILLA';
    if (b.type === 'LAND') {
      if (b.finishing) ctx.addIssue({ code: 'custom', path: ['finishing'], message: 'الأرض مالهاش تشطيب' });
      if (b.beds > 0 || b.baths > 0) ctx.addIssue({ code: 'custom', path: ['beds'], message: 'الأرض مالهاش غرف أو حمامات' });
    } else if (!b.finishing) {
      ctx.addIssue({ code: 'custom', path: ['finishing'], message: 'اختار التشطيب' });
    }
    if (hasBeds && b.beds < 1) ctx.addIssue({ code: 'custom', path: ['beds'], message: 'لازم غرفة واحدة على الأقل' });
    if (!hasBeds && b.beds > 0) ctx.addIssue({ code: 'custom', path: ['beds'], message: 'النوع ده مالهوش غرف' });
    if (new Set(b.paymentMethods).size !== b.paymentMethods.length) {
      ctx.addIssue({ code: 'custom', path: ['paymentMethods'], message: 'طرق الدفع مكررة' });
    }
  });

propertiesRouter.post('/', requireAuth, async (req, res) => {
  const b = createBody.parse(req.body);
  const userId = req.user!.id;

  const district = await prisma.district.findUnique({ where: { id: b.districtId } });
  if (!district || !district.isActive) throw badRequest('الحي مش موجود');

  if (b.projectId) {
    const project = await prisma.project.findUnique({ where: { id: b.projectId } });
    if (!project || project.ownerId !== userId) throw badRequest('المشروع مش موجود أو مش بتاعك');
  }

  const created = await prisma.property.create({
    data: {
      ownerId: userId,
      projectId: b.projectId,
      districtId: b.districtId,
      title: b.title,
      description: b.description,
      type: b.type,
      listingType: b.listingType,
      price: b.price,
      area: b.area,
      beds: b.beds,
      baths: b.baths,
      finishing: b.finishing ?? null,
      paymentMethods: b.paymentMethods,
      features: b.features,
      status: PropertyStatus.ACTIVE,
      publishedAt: new Date(), // مطلوب بقيد الـ DB لأي إعلان ACTIVE
      images: { create: b.images.map((url, position) => ({ url, position })) },
    },
    include: detailInclude,
  });

  res.status(201).json({ data: serializeProperty(created) });
});

// ---------------------------------------------------------------
//  PATCH /api/properties/:id/status — إيقاف / تفعيل / إغلاق (لصاحب الإعلان)
// ---------------------------------------------------------------

const statusBody = z.object({
  status: z.enum(['ACTIVE', 'PAUSED', 'CLOSED']),
});

propertiesRouter.patch('/:id/status', requireAuth, async (req, res) => {
  const { id } = idParam.parse(req.params);
  const { status } = statusBody.parse(req.body);

  const p = await prisma.property.findUnique({ where: { id } });
  if (!p) throw notFound('العقار مش موجود');
  if (p.ownerId !== req.user!.id) throw forbidden('الإعلان ده مش بتاعك');
  if (p.status === PropertyStatus.CLOSED) throw badRequest('الإعلان مقفول ومينفعش يتعدّل');

  const updated = await prisma.property.update({
    where: { id },
    data: {
      status,
      publishedAt: status === 'ACTIVE' ? (p.publishedAt ?? new Date()) : undefined,
    },
    include: detailInclude,
  });
  res.json({ data: serializeProperty(updated) });
});
