import { Router } from 'express';
import { prisma } from '../db';
import { requireAuth } from '../middleware/auth';
import { listInclude, serializeProperty } from '../lib/serializers';

export const metaRouter = Router();

/** الأحياء (للفلترة وللإضافة) */
metaRouter.get('/districts', async (_req, res) => {
  const rows = await prisma.district.findMany({
    where: { isActive: true },
    orderBy: [{ sortOrder: 'asc' }, { id: 'asc' }],
    select: { id: true, name: true },
  });
  res.json({ data: rows });
});

/** إعدادات عامة التطبيق محتاجها (رسوم المعاينة، مهلة الرد…) — من جدول Setting */
metaRouter.get('/config', async (_req, res) => {
  const rows = await prisma.setting.findMany();
  const s = new Map(rows.map((r) => [r.key, r.value]));
  res.json({
    data: {
      inspectionFee: Number(s.get('inspection_fee') ?? 100),
      inspectionResponseHours: Number(s.get('inspection_response_hours') ?? 24),
      refundOnBuyerDeclinesAlternative: Boolean(
        s.get('refund_on_buyer_declines_alternative') ?? true,
      ),
      currency: String(s.get('currency') ?? 'EGP'),
    },
  });
});

/** حسابي */
metaRouter.get('/me', requireAuth, async (req, res) => {
  const u = await prisma.user.findUniqueOrThrow({
    where: { id: req.user!.id },
    select: {
      id: true,
      name: true,
      phone: true,
      accountType: true,
      verificationStatus: true,
      business: { select: { displayName: true, logoUrl: true, bio: true } },
      createdAt: true,
    },
  });
  res.json({ data: u });
});

/** إعلاناتي (كل الحالات) */
metaRouter.get('/me/properties', requireAuth, async (req, res) => {
  const rows = await prisma.property.findMany({
    where: { ownerId: req.user!.id },
    include: listInclude,
    orderBy: { createdAt: 'desc' },
  });
  res.json({ data: rows.map((r) => serializeProperty(r)) });
});

