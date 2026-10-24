import { randomUUID } from 'node:crypto';
import {
  InspectionSlot,
  InspectionStatus,
  NotificationType,
  Prisma,
  PropertyStatus,
  RefundReason,
} from '@prisma/client';
import { prisma } from '../db';
import { AppError, forbidden, notFound } from '../lib/errors';
import { gateway } from '../lib/payments';
import { PolicySettings, getPolicySettings } from '../lib/settings';
import { SLOTS, cairoLocalToUtc, validateVisit } from '../lib/slots';

type Tx = Prisma.TransactionClient;

/** الحالات اللي الطلب فيها "شغّال" (مينفعش طلب تاني من نفس المشتري على نفس العقار). */
export const LIVE_STATUSES: InspectionStatus[] = ['PENDING', 'CONFIRMED', 'RESCHEDULED'];

export const STATUS_LABEL: Record<InspectionStatus, string> = {
  PENDING: 'قيد الانتظار',
  CONFIRMED: 'تم التأكيد',
  RESCHEDULED: 'موعد بديل مقترح',
  REJECTED: 'مرفوض',
  EXPIRED: 'انتهت المهلة',
  CANCELLED: 'أُلغي',
};

// ---------------------------------------------------------------
//  أدوات مشتركة
// ---------------------------------------------------------------

export async function notify(
  tx: Tx,
  userId: string,
  type: NotificationType,
  title: string,
  body: string,
  data?: Prisma.InputJsonValue,
) {
  await tx.notification.create({ data: { userId, type, title, body, data } });
}

/** استرداد كامل لرسوم المعاينة (مرة واحدة بس — الفهرس الجزئي في الـ DB بيضمن ده). */
async function issueRefund(tx: Tx, req: { id: string; buyerId: string }, reason: RefundReason) {
  const original = await tx.payment.findFirst({
    where: { inspectionRequestId: req.id, type: 'INSPECTION_FEE', status: 'SUCCEEDED' },
  });
  if (!original) return null;

  const key = `refund:${original.id}`;
  const r = await gateway.refund({
    amount: original.amount.toNumber(),
    originalProviderRef: original.providerRef,
    idempotencyKey: key,
  });
  return tx.payment.create({
    data: {
      userId: req.buyerId,
      inspectionRequestId: req.id,
      type: 'REFUND',
      amount: original.amount,
      status: 'SUCCEEDED',
      provider: r.provider,
      providerRef: r.providerRef,
      idempotencyKey: key,
      refundOfId: original.id,
      refundReason: reason,
      // refundDestination: لسه ماتحددتش (محفظة ولا وسيلة الدفع الأصلية)
      completedAt: new Date(),
    },
  });
}

// ---------------------------------------------------------------
//  إنشاء طلب معاينة (دفع الرسوم + الطلب في خطوة واحدة)
// ---------------------------------------------------------------

export async function createInspection(
  buyerId: string,
  input: { propertyId: string; visitDate: string; slot: InspectionSlot; idempotencyKey?: string },
): Promise<{ id: string; replayed: boolean }> {
  const settings = await getPolicySettings();
  validateVisit(input.visitDate, input.slot);

  const property = await prisma.property.findUnique({
    where: { id: input.propertyId },
    select: { id: true, ownerId: true, status: true, title: true },
  });
  if (!property || property.status !== PropertyStatus.ACTIVE) throw notFound('العقار مش موجود');
  if (property.ownerId === buyerId) throw forbidden('مينفعش تطلب معاينة لعقارك');

  // نفس الـ Idempotency-Key ⇒ نرجّع نفس الطلب من غير ما ندفع تاني
  const feeKey = `fee:${buyerId}:${input.idempotencyKey ?? randomUUID()}`;
  const replay = await prisma.payment.findUnique({
    where: { idempotencyKey: feeKey },
    select: { inspectionRequestId: true },
  });
  if (replay?.inspectionRequestId) return { id: replay.inspectionRequestId, replayed: true };

  const live = await prisma.inspectionRequest.findFirst({
    where: { buyerId, propertyId: property.id, status: { in: LIVE_STATUSES } },
    select: { id: true },
  });
  if (live) {
    throw new AppError(409, 'ALREADY_REQUESTED', 'عندك طلب معاينة شغّال على العقار ده');
  }

  const now = new Date();
  const visitStart = cairoLocalToUtc(input.visitDate, SLOTS[input.slot].startHour);
  // مهلة الرد = 24 ساعة (من الإعدادات) أو لحد بداية الموعد — أيهما أقرب
  const deadline = new Date(
    Math.min(now.getTime() + settings.responseHours * 3_600_000, visitStart.getTime()),
  );
  const visitDate = new Date(`${input.visitDate}T00:00:00Z`);

  // 1) الدفع. (TODO Phase 3: بوابة حقيقية + تأكيد بـ webhook)
  const charge = await gateway.charge({
    amount: settings.fee,
    currency: 'EGP',
    buyerId,
    idempotencyKey: feeKey,
  });

  // 2) تسجيل الطلب. لو فشل بعد الدفع ⇒ نرد الفلوس (compensation)
  try {
    const created = await prisma.$transaction(async (tx) => {
      const req = await tx.inspectionRequest.create({
        data: {
          propertyId: property.id,
          buyerId,
          ownerId: property.ownerId,
          status: 'PENDING',
          visitDate,
          slot: input.slot,
          requestedVisitDate: visitDate,
          requestedSlot: input.slot,
          feeAmount: settings.fee,
          responseDeadline: deadline,
        },
      });
      await tx.payment.create({
        data: {
          userId: buyerId,
          inspectionRequestId: req.id,
          type: 'INSPECTION_FEE',
          amount: settings.fee,
          status: 'SUCCEEDED',
          provider: charge.provider,
          providerRef: charge.providerRef,
          idempotencyKey: feeKey,
          completedAt: now,
        },
      });
      await tx.inspectionEvent.create({
        data: {
          inspectionRequestId: req.id,
          actorId: buyerId,
          fromStatus: null,
          toStatus: 'PENDING',
          note: 'طلب معاينة + دفع الرسوم',
        },
      });
      await notify(
        tx,
        property.ownerId,
        'INSPECTION_REQUESTED',
        'طلب معاينة جديد',
        `فيه طلب معاينة على "${property.title}". رُد خلال ${settings.responseHours} ساعة.`,
        { inspectionRequestId: req.id },
      );
      return req;
    });
    return { id: created.id, replayed: false };
  } catch (e) {
    await gateway
      .refund({
        amount: settings.fee,
        originalProviderRef: charge.providerRef,
        idempotencyKey: `compensate:${feeKey}`,
      })
      .catch((err) => console.error('⚠️ فشل رد الرسوم بعد فشل تسجيل الطلب', feeKey, err));
    if (e instanceof Prisma.PrismaClientKnownRequestError && e.code === 'P2002') {
      throw new AppError(409, 'ALREADY_REQUESTED', 'عندك طلب معاينة شغّال على العقار ده');
    }
    throw e;
  }
}

// ---------------------------------------------------------------
//  انتقالات الحالة (State machine)
// ---------------------------------------------------------------
//
//  PENDING     ─ المعلن يقبل ────────────▶ CONFIRMED
//              ─ المعلن يرفض ────────────▶ REJECTED    (+ استرداد كامل)
//              ─ المعلن يقترح موعد ──────▶ RESCHEDULED
//              ─ المشتري يلغي ───────────▶ CANCELLED   (+ استرداد كامل)
//              ─ المعلن ماردّش في المهلة ▶ EXPIRED     (+ استرداد كامل)
//  CONFIRMED   ─ المعلن يقترح موعد ──────▶ RESCHEDULED
//              ─ المعلن يلغي ────────────▶ CANCELLED   (+ استرداد كامل)
//              ─ المشتري يلغي ───────────▶ CANCELLED   (بلا استرداد)
//  RESCHEDULED ─ المشتري يوافق ──────────▶ CONFIRMED
//              ─ المشتري يرفض ───────────▶ CANCELLED   (استرداد حسب الإعداد)
//              ─ المشتري ماردّش ─────────▶ EXPIRED     (استرداد حسب الإعداد)
//              ─ المعلن يقترح موعد تاني ─▶ RESCHEDULED
//              ─ المعلن يلغي ────────────▶ CANCELLED   (+ استرداد كامل)
//
//  REJECTED / EXPIRED / CANCELLED = نهائية

interface Loaded {
  id: string;
  status: InspectionStatus;
  buyerId: string;
  ownerId: string;
  propertyTitle: string;
  /** الرسوم اللي اتدفعت فعلاً (مش من الإعدادات الحالية) */
  fee: string;
}

type Notif = { userId: string; type: NotificationType; title: string; body: string };

interface TransitionArgs {
  id: string;
  actorId: string;
  by: 'owner' | 'buyer';
  from: InspectionStatus[];
  to: InspectionStatus;
  data?: Prisma.InspectionRequestUpdateManyMutationInput;
  refund?: (s: PolicySettings) => RefundReason | null;
  note: string;
  notifications: (r: Loaded, refunded: boolean) => Notif[];
}

const refundNote = (fee: string) => `تم رد رسوم المعاينة (${fee} ج.م) بالكامل إلى حسابك/محفظتك.`;
const refundNotif = (userId: string, fee: string): Notif => ({
  userId,
  type: 'REFUND_ISSUED',
  title: 'تم رد رسوم المعاينة',
  body: refundNote(fee),
});

async function transition(a: TransitionArgs): Promise<void> {
  const row = await prisma.inspectionRequest.findUnique({
    where: { id: a.id },
    select: {
      id: true,
      status: true,
      buyerId: true,
      ownerId: true,
      feeAmount: true,
      responseDeadline: true,
      property: { select: { title: true } },
    },
  });
  if (!row) throw notFound('الطلب مش موجود');

  const isOwner = row.ownerId === a.actorId;
  const isBuyer = row.buyerId === a.actorId;
  if (!isOwner && !isBuyer) throw notFound('الطلب مش موجود'); // مانكشفش وجوده لغير أطرافه
  if ((a.by === 'owner' && !isOwner) || (a.by === 'buyer' && !isBuyer)) {
    throw forbidden('العملية دي مش متاحة لك');
  }

  // لو مهلة الرد خلصت والـ job لسه ماقفلهاش، نقفلها دلوقتي ونرفض العملية
  if (
    (row.status === 'PENDING' || row.status === 'RESCHEDULED') &&
    row.responseDeadline.getTime() < Date.now()
  ) {
    await expireOverdue();
    throw new AppError(409, 'INVALID_STATE', 'انتهت مهلة الرد على الطلب ده');
  }

  if (!a.from.includes(row.status)) {
    throw new AppError(
      409,
      'INVALID_STATE',
      `مينفعش تنفّذ العملية دي والطلب "${STATUS_LABEL[row.status]}"`,
    );
  }

  const loaded: Loaded = {
    id: row.id,
    status: row.status,
    buyerId: row.buyerId,
    ownerId: row.ownerId,
    propertyTitle: row.property.title,
    fee: row.feeAmount.toString(),
  };
  const settings = await getPolicySettings();
  const refundReason = a.refund?.(settings) ?? null;

  await prisma.$transaction(async (tx) => {
    // التحديث مشروط بالحالة القديمة ⇒ لو اتنين ضغطوا مع بعض واحد بس بينجح
    const upd = await tx.inspectionRequest.updateMany({
      where: { id: a.id, status: { in: a.from } },
      data: { status: a.to, ...a.data },
    });
    if (upd.count === 0) {
      throw new AppError(409, 'INVALID_STATE', 'حالة الطلب اتغيّرت، حدّث الصفحة وجرّب تاني');
    }
    const refunded = refundReason ? !!(await issueRefund(tx, loaded, refundReason)) : false;
    await tx.inspectionEvent.create({
      data: {
        inspectionRequestId: a.id,
        actorId: a.actorId,
        fromStatus: row.status,
        toStatus: a.to,
        note: a.note,
      },
    });
    for (const n of a.notifications(loaded, refunded)) {
      await notify(tx, n.userId, n.type, n.title, n.body, { inspectionRequestId: a.id });
    }
  });
}

// ---------------- المعلن ----------------

export async function acceptInspection(id: string, ownerId: string) {
  const now = new Date();
  await transition({
    id,
    actorId: ownerId,
    by: 'owner',
    from: ['PENDING'],
    to: 'CONFIRMED',
    data: { confirmedAt: now, respondedAt: now },
    note: 'المعلن قبل الطلب',
    notifications: (r) => [
      {
        userId: r.buyerId,
        type: 'INSPECTION_CONFIRMED',
        title: 'تم تأكيد المعاينة',
        body: `المعلن أكّد معاينة "${r.propertyTitle}".`,
      },
    ],
  });
}

export async function rejectInspection(id: string, ownerId: string) {
  const now = new Date();
  await transition({
    id,
    actorId: ownerId,
    by: 'owner',
    from: ['PENDING'],
    to: 'REJECTED',
    data: { respondedAt: now, closedAt: now },
    refund: () => 'OWNER_REJECTED',
    note: 'المعلن رفض الطلب — استرداد كامل',
    notifications: (r, refunded) => [
      {
        userId: r.buyerId,
        type: 'INSPECTION_REJECTED',
        title: 'المعلن رفض طلب المعاينة',
        body: `المعلن رفض معاينة "${r.propertyTitle}". ${refundNote(r.fee)}`,
      },
      ...(refunded ? [refundNotif(r.buyerId, r.fee)] : []),
    ],
  });
}

export async function proposeInspection(
  id: string,
  ownerId: string,
  input: { visitDate: string; slot: InspectionSlot },
) {
  validateVisit(input.visitDate, input.slot);
  const settings = await getPolicySettings();
  // للمشتري نفس المهلة: مهلة الرد أو بداية الموعد البديل — أيهما أقرب
  const visitStart = cairoLocalToUtc(input.visitDate, SLOTS[input.slot].startHour);
  const deadline = new Date(
    Math.min(Date.now() + settings.responseHours * 3_600_000, visitStart.getTime()),
  );

  await transition({
    id,
    actorId: ownerId,
    by: 'owner',
    from: ['PENDING', 'CONFIRMED', 'RESCHEDULED'],
    to: 'RESCHEDULED',
    data: {
      visitDate: new Date(`${input.visitDate}T00:00:00Z`),
      slot: input.slot,
      respondedAt: new Date(),
      confirmedAt: null,
      responseDeadline: deadline,
    },
    note: `المعلن اقترح موعد بديل: ${input.visitDate} — ${SLOTS[input.slot].label}`,
    notifications: (r) => [
      {
        userId: r.buyerId,
        type: 'INSPECTION_RESCHEDULED',
        title: 'المعلن اقترح موعد بديل',
        body: `موعد جديد لمعاينة "${r.propertyTitle}": ${input.visitDate} — ${SLOTS[input.slot].label}. وافق عليه أو ارفضه خلال ${settings.responseHours} ساعة.`,
      },
    ],
  });
}

/** المعلن يلغي بعد ما أكّد (أو وهو منتظر رد المشتري) ⇒ استرداد كامل: المعاينة ماتمّتش بسببه. */
async function ownerCancel(id: string, ownerId: string) {
  await transition({
    id,
    actorId: ownerId,
    by: 'owner',
    from: ['CONFIRMED', 'RESCHEDULED'],
    to: 'CANCELLED',
    data: { closedAt: new Date() },
    refund: () => 'OWNER_CANCELLED_AFTER_CONFIRM',
    note: 'المعلن ألغى المعاينة — استرداد كامل',
    notifications: (r, refunded) => [
      {
        userId: r.buyerId,
        type: 'INSPECTION_CANCELLED',
        title: 'المعلن ألغى المعاينة',
        body: `المعلن ألغى معاينة "${r.propertyTitle}". ${refundNote(r.fee)}`,
      },
      ...(refunded ? [refundNotif(r.buyerId, r.fee)] : []),
    ],
  });
}

// ---------------- المشتري ----------------

export async function respondToProposal(id: string, buyerId: string, accept: boolean) {
  if (accept) {
    await transition({
      id,
      actorId: buyerId,
      by: 'buyer',
      from: ['RESCHEDULED'],
      to: 'CONFIRMED',
      data: { confirmedAt: new Date() },
      note: 'المشتري وافق على الموعد البديل',
      notifications: (r) => [
        {
          userId: r.ownerId,
          type: 'INSPECTION_CONFIRMED',
          title: 'المشتري وافق على الموعد',
          body: `تم تأكيد معاينة "${r.propertyTitle}".`,
        },
      ],
    });
    return;
  }
  await transition({
    id,
    actorId: buyerId,
    by: 'buyer',
    from: ['RESCHEDULED'],
    to: 'CANCELLED',
    data: { closedAt: new Date() },
    refund: (s) => (s.refundOnBuyerDeclinesAlternative ? 'BUYER_DECLINED_ALTERNATIVE' : null),
    note: 'المشتري رفض الموعد البديل',
    notifications: (r, refunded) => [
      {
        userId: r.ownerId,
        type: 'INSPECTION_CANCELLED',
        title: 'المشتري رفض الموعد البديل',
        body: `اتلغى طلب معاينة "${r.propertyTitle}".`,
      },
      ...(refunded ? [refundNotif(r.buyerId, r.fee)] : []),
    ],
  });
}

/**
 * المشتري يلغي:
 *  - قبل رد المعلن (PENDING) ⇒ استرداد كامل (لسه ماحصلش أي التزام بوقت).
 *  - بعد التأكيد (CONFIRMED)  ⇒ بلا استرداد (مقابل تنظيم وتأكيد المعاينة).
 * بنجرّب الحالتين بالترتيب، وكل واحدة محمية بشرط الحالة في الـ UPDATE، فمفيش
 * استرداد بالغلط لو المعلن قبل في نفس اللحظة.
 */
async function buyerCancel(id: string, buyerId: string) {
  try {
    await transition({
      id,
      actorId: buyerId,
      by: 'buyer',
      from: ['PENDING'],
      to: 'CANCELLED',
      data: { closedAt: new Date() },
      refund: () => 'BUYER_CANCELLED_BEFORE_RESPONSE',
      note: 'المشتري ألغى قبل رد المعلن — استرداد كامل',
      notifications: (r, refunded) => [
        {
          userId: r.ownerId,
          type: 'INSPECTION_CANCELLED',
          title: 'المشتري ألغى الطلب',
          body: `المشتري ألغى طلب معاينة "${r.propertyTitle}" قبل ما ترد.`,
        },
        ...(refunded ? [refundNotif(r.buyerId, r.fee)] : []),
      ],
    });
    return;
  } catch (e) {
    if (!(e instanceof AppError && e.code === 'INVALID_STATE')) throw e;
  }
  await transition({
    id,
    actorId: buyerId,
    by: 'buyer',
    from: ['CONFIRMED'],
    to: 'CANCELLED',
    data: { closedAt: new Date() },
    note: 'المشتري ألغى بعد التأكيد — الرسوم غير قابلة للاسترداد',
    notifications: (r) => [
      {
        userId: r.ownerId,
        type: 'INSPECTION_CANCELLED',
        title: 'المشتري ألغى المعاينة',
        body: `المشتري ألغى معاينة "${r.propertyTitle}".`,
      },
    ],
  });
}

/** إلغاء من أي طرف — الخدمة بتحدد دور المستخدم وتطبّق السياسة المناسبة. */
export async function cancelInspection(id: string, actorId: string) {
  const r = await prisma.inspectionRequest.findUnique({
    where: { id },
    select: { buyerId: true, ownerId: true },
  });
  if (!r) throw notFound('الطلب مش موجود');
  if (r.ownerId === actorId) return ownerCancel(id, actorId);
  if (r.buyerId === actorId) return buyerCancel(id, actorId);
  throw notFound('الطلب مش موجود');
}

// ---------------------------------------------------------------
//  إقفال الطلبات اللي الطرف اللي عليه الدور ماردّش عليها في المهلة
// ---------------------------------------------------------------
//  PENDING     (المعلن ماردّش)   ⇒ EXPIRED + استرداد كامل
//  RESCHEDULED (المشتري ماردّش)  ⇒ EXPIRED + استرداد حسب الإعداد (صمت المشتري = رفض)

export async function expireOverdue(limit = 100): Promise<number> {
  const due = await prisma.inspectionRequest.findMany({
    where: { status: { in: ['PENDING', 'RESCHEDULED'] }, responseDeadline: { lt: new Date() } },
    select: {
      id: true,
      status: true,
      buyerId: true,
      ownerId: true,
      feeAmount: true,
      property: { select: { title: true } },
    },
    orderBy: { responseDeadline: 'asc' },
    take: limit,
  });
  if (due.length === 0) return 0;
  const settings = await getPolicySettings();

  let expired = 0;
  for (const r of due) {
    try {
      const done = await prisma.$transaction(async (tx) => {
        const now = new Date();
        const upd = await tx.inspectionRequest.updateMany({
          // شرط الحالة نفسها: لو الطرف التاني رد في نفس اللحظة نسيبه
          where: { id: r.id, status: r.status, responseDeadline: { lt: now } },
          data: { status: 'EXPIRED', closedAt: now },
        });
        if (upd.count === 0) return false;

        const fee = r.feeAmount.toString();
        const waitingOnOwner = r.status === 'PENDING';
        const reason: RefundReason | null = waitingOnOwner
          ? 'OWNER_NO_RESPONSE'
          : settings.refundOnBuyerDeclinesAlternative
            ? 'BUYER_ALTERNATIVE_EXPIRED'
            : null;
        const refunded = reason ? !!(await issueRefund(tx, r, reason)) : false;

        await tx.inspectionEvent.create({
          data: {
            inspectionRequestId: r.id,
            actorId: null, // النظام
            fromStatus: r.status,
            toStatus: 'EXPIRED',
            note: waitingOnOwner
              ? 'انتهت مهلة رد المعلن — استرداد كامل تلقائي'
              : refunded
                ? 'انتهت مهلة رد المشتري على الموعد البديل — استرداد تلقائي'
                : 'انتهت مهلة رد المشتري على الموعد البديل',
          },
        });

        const meta = { inspectionRequestId: r.id };
        if (waitingOnOwner) {
          await notify(tx, r.buyerId, 'INSPECTION_EXPIRED', 'انتهت مهلة رد المعلن',
            `المعلن ماردّش على طلب معاينة "${r.property.title}". ${refundNote(fee)}`, meta);
          await notify(tx, r.ownerId, 'INSPECTION_EXPIRED', 'طلب معاينة انتهت مهلته',
            `فاتتك مهلة الرد على طلب معاينة "${r.property.title}" فاتلغى.`, meta);
        } else {
          await notify(tx, r.buyerId, 'INSPECTION_EXPIRED', 'انتهت مهلة الرد على الموعد البديل',
            `اتلغى طلب معاينة "${r.property.title}" لأنك ماردّيتش على الموعد البديل.${refunded ? ' ' + refundNote(fee) : ''}`, meta);
          await notify(tx, r.ownerId, 'INSPECTION_EXPIRED', 'المشتري ماردّش على الموعد البديل',
            `اتلغى طلب معاينة "${r.property.title}" لأن المشتري ماردّش على الموعد البديل.`, meta);
        }
        if (refunded) await notify(tx, r.buyerId, 'REFUND_ISSUED', 'تم رد رسوم المعاينة', refundNote(fee), meta);
        return true;
      });
      if (done) expired++;
    } catch (e) {
      console.error('⚠️ فشل إقفال الطلب المنتهي', r.id, e);
    }
  }
  return expired;
}
