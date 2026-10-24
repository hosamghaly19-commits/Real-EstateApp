import { Router } from 'express';
import { z } from 'zod';
import { InspectionSlot, InspectionStatus, Prisma } from '@prisma/client';
import { prisma } from '../db';
import { requireAuth } from '../middleware/auth';
import { notFound } from '../lib/errors';
import { SLOTS } from '../lib/slots';
import {
  acceptInspection,
  cancelInspection,
  createInspection,
  expireOverdue,
  proposeInspection,
  rejectInspection,
  respondToProposal,
} from '../services/inspections';

export const inspectionsRouter = Router();
inspectionsRouter.use(requireAuth);

// ---------------------------------------------------------------
//  Serializer
// ---------------------------------------------------------------

const baseInclude = {
  property: {
    select: {
      id: true,
      title: true,
      type: true,
      listingType: true,
      district: { select: { name: true } },
      images: { orderBy: { position: 'asc' }, take: 1, select: { url: true } },
    },
  },
  buyer: { select: { id: true, name: true, phone: true } },
  owner: {
    select: { id: true, name: true, phone: true, business: { select: { displayName: true } } },
  },
  payments: {
    where: { type: 'REFUND', status: 'SUCCEEDED' },
    select: { amount: true, refundReason: true, completedAt: true },
  },
} satisfies Prisma.InspectionRequestInclude;

const detailInclude = {
  ...baseInclude,
  events: {
    orderBy: { createdAt: 'asc' },
    select: { fromStatus: true, toStatus: true, note: true, createdAt: true, actorId: true },
  },
} satisfies Prisma.InspectionRequestInclude;

type Row = Prisma.InspectionRequestGetPayload<{ include: typeof detailInclude }>;
type ListRow = Prisma.InspectionRequestGetPayload<{ include: typeof baseInclude }>;
type Role = 'buyer' | 'owner' | 'admin';

const maskPhone = (p: string) => (p.length >= 7 ? `${p.slice(0, 3)}••••${p.slice(-4)}` : '••••');
const dateOnly = (d: Date) => d.toISOString().slice(0, 10);

/** العمليات المتاحة للمشاهد حسب حالة الطلب (بتخلّي التطبيق ما يكرّرش اللوجيك). */
function actionsFor(status: InspectionStatus, role: Role): string[] {
  if (role === 'owner') {
    if (status === 'PENDING') return ['accept', 'reject', 'propose'];
    if (status === 'CONFIRMED' || status === 'RESCHEDULED') return ['propose', 'cancel'];
  }
  if (role === 'buyer') {
    if (status === 'PENDING' || status === 'CONFIRMED') return ['cancel'];
    if (status === 'RESCHEDULED') return ['respond'];
  }
  return [];
}

function serialize(r: ListRow | Row, role: Role) {
  // رقم التليفون بيتكشف للطرف التاني بعد التأكيد بس
  const reveal = r.status === 'CONFIRMED' || role === 'admin';
  const refund = r.payments[0];
  return {
    id: r.id,
    code: `IR-${r.number}`,
    status: r.status,
    visitDate: dateOnly(r.visitDate),
    slot: r.slot,
    slotLabel: SLOTS[r.slot].label,
    requestedVisitDate: dateOnly(r.requestedVisitDate),
    requestedSlot: r.requestedSlot,
    fee: r.feeAmount.toNumber(),
    responseDeadline: r.responseDeadline,
    respondedAt: r.respondedAt,
    confirmedAt: r.confirmedAt,
    closedAt: r.closedAt,
    createdAt: r.createdAt,
    refunded: !!refund,
    refund: refund
      ? { amount: refund.amount.toNumber(), reason: refund.refundReason, at: refund.completedAt }
      : null,
    availableActions: actionsFor(r.status, role),
    property: {
      id: r.property.id,
      title: r.property.title,
      type: r.property.type,
      listingType: r.property.listingType,
      district: r.property.district.name,
      coverUrl: r.property.images[0]?.url ?? null,
    },
    buyer: { id: r.buyer.id, name: r.buyer.name, phone: reveal ? r.buyer.phone : maskPhone(r.buyer.phone) },
    owner: {
      id: r.owner.id,
      name: r.owner.business?.displayName ?? r.owner.name,
      phone: reveal ? r.owner.phone : maskPhone(r.owner.phone),
    },
    ...('events' in r && {
      events: r.events.map((e) => ({
        from: e.fromStatus,
        to: e.toStatus,
        note: e.note,
        at: e.createdAt,
        bySystem: e.actorId === null,
      })),
    }),
  };
}

async function loadFor(id: string, userId: string, isAdmin: boolean) {
  const r = await prisma.inspectionRequest.findUnique({ where: { id }, include: detailInclude });
  const role: Role | null = !r
    ? null
    : r.buyerId === userId
      ? 'buyer'
      : r.ownerId === userId
        ? 'owner'
        : isAdmin
          ? 'admin'
          : null;
  if (!r || !role) throw notFound('الطلب مش موجود'); // مانكشفش وجوده لغير أطرافه
  return serialize(r, role);
}

// ---------------------------------------------------------------
//  Validation
// ---------------------------------------------------------------

const idParam = z.object({ id: z.string().uuid('الـ id مش صحيح') });

const dateStr = z
  .string()
  .regex(/^\d{4}-\d{2}-\d{2}$/, 'التاريخ بصيغة YYYY-MM-DD')
  .refine((s) => {
    const d = new Date(`${s}T00:00:00Z`);
    return !Number.isNaN(d.getTime()) && d.toISOString().slice(0, 10) === s;
  }, 'تاريخ غير صحيح');

const visitBody = z.object({ visitDate: dateStr, slot: z.nativeEnum(InspectionSlot) });
const createBody = visitBody.extend({ propertyId: z.string().uuid('العقار مش صحيح') });

const listQuery = z.object({
  role: z.enum(['buyer', 'owner']),
  status: z.nativeEnum(InspectionStatus).optional(),
  page: z.coerce.number().int().min(1).default(1),
  limit: z.coerce.number().int().min(1).max(50).default(20),
});

// ---------------------------------------------------------------
//  Routes
// ---------------------------------------------------------------

/** طلب معاينة (بيدفع الرسوم). هيدر Idempotency-Key اختياري لمنع الدفع المزدوج. */
inspectionsRouter.post('/', async (req, res) => {
  const body = createBody.parse(req.body);
  const key = req.header('idempotency-key')?.slice(0, 100);
  const { id, replayed } = await createInspection(req.user!.id, { ...body, idempotencyKey: key });
  res.status(replayed ? 200 : 201).json({ data: await loadFor(id, req.user!.id, false) });
});

/** قائمة طلباتي: role=buyer (اللي طلبتها) أو role=owner (الواردة على عقاراتي). */
inspectionsRouter.get('/', async (req, res) => {
  const q = listQuery.parse(req.query);
  await expireOverdue(); // قفل أي طلب انتهت مهلته قبل ما نعرض القائمة

  const where: Prisma.InspectionRequestWhereInput = {
    ...(q.role === 'buyer' ? { buyerId: req.user!.id } : { ownerId: req.user!.id }),
    ...(q.status && { status: q.status }),
  };
  const [total, rows] = await Promise.all([
    prisma.inspectionRequest.count({ where }),
    prisma.inspectionRequest.findMany({
      where,
      include: baseInclude,
      orderBy: [{ createdAt: 'desc' }, { id: 'asc' }],
      skip: (q.page - 1) * q.limit,
      take: q.limit,
    }),
  ]);
  res.json({
    data: rows.map((r) => serialize(r, q.role)),
    page: q.page,
    limit: q.limit,
    total,
    totalPages: Math.ceil(total / q.limit),
  });
});

inspectionsRouter.get('/:id', async (req, res) => {
  const { id } = idParam.parse(req.params);
  await expireOverdue();
  res.json({ data: await loadFor(id, req.user!.id, req.user!.role === 'ADMIN') });
});

// ---- المعلن ----
inspectionsRouter.post('/:id/accept', async (req, res) => {
  const { id } = idParam.parse(req.params);
  await acceptInspection(id, req.user!.id);
  res.json({ data: await loadFor(id, req.user!.id, false) });
});

inspectionsRouter.post('/:id/reject', async (req, res) => {
  const { id } = idParam.parse(req.params);
  await rejectInspection(id, req.user!.id);
  res.json({ data: await loadFor(id, req.user!.id, false) });
});

inspectionsRouter.post('/:id/propose', async (req, res) => {
  const { id } = idParam.parse(req.params);
  await proposeInspection(id, req.user!.id, visitBody.parse(req.body));
  res.json({ data: await loadFor(id, req.user!.id, false) });
});

// ---- المشتري (و/أو المعلن للإلغاء) ----
inspectionsRouter.post('/:id/respond', async (req, res) => {
  const { id } = idParam.parse(req.params);
  const { accept } = z.object({ accept: z.boolean() }).parse(req.body);
  await respondToProposal(id, req.user!.id, accept);
  res.json({ data: await loadFor(id, req.user!.id, false) });
});

inspectionsRouter.post('/:id/cancel', async (req, res) => {
  const { id } = idParam.parse(req.params);
  await cancelInspection(id, req.user!.id);
  res.json({ data: await loadFor(id, req.user!.id, false) });
});
