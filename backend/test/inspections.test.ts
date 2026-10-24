/**
 * اختبارات سياسة المعاينة: الدفع، القبول/الرفض/الموعد البديل، الاسترداد، انتهاء المهلة، التسابق.
 * بتشتغل على قاعدة متعمل عليها `npm run db:seed`، وبتمسح اللي بتضيفه في الآخر.
 */
import { test, after } from 'node:test';
import assert from 'node:assert/strict';
import request from 'supertest';
import { app } from '../src/app';
import { prisma } from '../src/db';
import { addDays, todayCairo } from '../src/lib/slots';
import { expireOverdue } from '../src/services/inspections';

const h = (phone: string) => ({ 'x-demo-phone': phone });
const OFFICE1 = h('01000000001'); // مكتب الأمان — بيملك "شقة فاخرة…"
const OFFICE2 = h('01000000002'); // مكتب بيت المدينة — بيملك "دوبلكس…"
const DEV1 = h('01000000003'); // مطور الأفق — بيملك "فيلا مستقلة…"
const BUYERS = {
  main: h('01000000008'),
  a: h('01000000005'),
  b: h('01000000006'),
  c: h('01000000007'),
};
const BUYER_PHONES = ['01000000008', '01000000005', '01000000006', '01000000007'];

const startedAt = new Date();
const visit = () => addDays(todayCairo(), 3);
const propId = async (title: string) =>
  (await prisma.property.findFirstOrThrow({ where: { title }, select: { id: true } })).id;

const FLAT = 'شقة فاخرة بتشطيب سوبر لوكس'; // office1
const VILLA = 'فيلا مستقلة بحديقة خاصة'; // dev1
const DUPLEX = 'دوبلكس بإطلالة مفتوحة'; // office2

const book = (who: Record<string, string>, propertyId: string, extra: object = {}, headers: Record<string, string> = {}) =>
  request(app)
    .post('/api/inspections')
    .set(who)
    .set(headers)
    .send({ propertyId, visitDate: visit(), slot: 'MORNING', ...extra });

const act = (who: Record<string, string>, id: string, action: string, body?: object) =>
  request(app).post(`/api/inspections/${id}/${action}`).set(who).send(body ?? {});

const refunds = (id: string) =>
  prisma.payment.findMany({ where: { inspectionRequestId: id, type: 'REFUND' } });

let settingsBackup: { key: string; value: unknown }[] = [];
after(async () => {
  const mine = await prisma.inspectionRequest.findMany({
    where: { buyer: { phone: { in: BUYER_PHONES } }, createdAt: { gte: startedAt } },
    select: { id: true },
  });
  const ids = mine.map((m) => m.id);
  await prisma.payment.deleteMany({ where: { inspectionRequestId: { in: ids }, type: 'REFUND' } });
  await prisma.payment.deleteMany({ where: { inspectionRequestId: { in: ids } } });
  await prisma.inspectionRequest.deleteMany({ where: { id: { in: ids } } });
  await prisma.notification.deleteMany({ where: { createdAt: { gte: startedAt } } });
  for (const s of settingsBackup) {
    await prisma.setting.update({ where: { key: s.key }, data: { value: s.value as never } });
  }
  await prisma.$disconnect();
});

// ---------------------------------------------------------------

test('التحقق والصلاحيات قبل الدفع', async () => {
  const flat = await propId(FLAT);
  assert.equal((await request(app).post('/api/inspections').send({})).status, 401);

  // مالك العقار مايطلبش معاينة لعقاره
  assert.equal((await book(OFFICE1, flat)).status, 403);
  // عقار مش موجود
  assert.equal((await book(BUYERS.main, '00000000-0000-4000-8000-000000000000')).status, 404);
  // في الماضي / بعيد قوي / تاريخ غلط / فترة غلط
  assert.equal((await book(BUYERS.main, flat, { visitDate: addDays(todayCairo(), -1) })).status, 400);
  assert.equal((await book(BUYERS.main, flat, { visitDate: addDays(todayCairo(), 30) })).status, 400);
  assert.equal((await book(BUYERS.main, flat, { visitDate: '2026-02-31' })).status, 400);
  assert.equal((await book(BUYERS.main, flat, { slot: 'MIDNIGHT' })).status, 400);

  // ولا حاجة اتدفعت ولا اتسجلت
  const n = await prisma.inspectionRequest.count({
    where: { buyer: { phone: '01000000008' }, createdAt: { gte: startedAt } },
  });
  assert.equal(n, 0);
});

test('طلب معاينة ناجح: دفع + طلب + سجل + إشعار للمعلن', async () => {
  const flat = await propId(FLAT);
  const r = await book(BUYERS.main, flat);
  assert.equal(r.status, 201);
  const d = r.body.data;

  assert.equal(d.status, 'PENDING');
  assert.match(d.code, /^IR-\d+$/);
  assert.equal(d.fee, 100);
  assert.equal(d.refunded, false);
  assert.deepEqual(d.availableActions, ['cancel']); // المشتري يقدر يلغي (باسترداد) وهو منتظر
  assert.equal(d.owner.name, 'مكتب الأمان العقاري');
  assert.equal(d.buyer.phone.includes('••••'), true); // التليفون مخفي قبل التأكيد

  // مهلة الرد ≈ 24 ساعة
  const hours = (new Date(d.responseDeadline).getTime() - Date.now()) / 3_600_000;
  assert.equal(hours > 23.9 && hours <= 24, true);

  const pays = await prisma.payment.findMany({ where: { inspectionRequestId: d.id } });
  assert.equal(pays.length, 1);
  assert.equal(pays[0].type, 'INSPECTION_FEE');
  assert.equal(pays[0].status, 'SUCCEEDED');
  assert.equal(pays[0].amount.toNumber(), 100);

  const notif = await prisma.notification.findMany({
    where: { user: { phone: '01000000001' }, type: 'INSPECTION_REQUESTED', createdAt: { gte: startedAt } },
  });
  assert.equal(notif.length >= 1, true);

  // المعلن بيشوفه وعنده 3 عمليات
  const detail = await request(app).get(`/api/inspections/${d.id}`).set(OFFICE1);
  assert.equal(detail.status, 200);
  assert.deepEqual(detail.body.data.availableActions, ['accept', 'reject', 'propose']);
  assert.equal(detail.body.data.events.length, 1);

  // غريب ⇒ 404 (مانكشفش وجوده)
  assert.equal((await request(app).get(`/api/inspections/${d.id}`).set(DEV1)).status, 404);
});

test('منع الدفع المزدوج: Idempotency-Key + طلب شغّال واحد + سباق', async () => {
  const villa = await propId(VILLA);

  const first = await book(BUYERS.a, villa, {}, { 'Idempotency-Key': 'k-123' });
  assert.equal(first.status, 201);
  // نفس المفتاح ⇒ نفس الطلب (200) ومفيش دفع تاني
  const replay = await book(BUYERS.a, villa, {}, { 'Idempotency-Key': 'k-123' });
  assert.equal(replay.status, 200);
  assert.equal(replay.body.data.id, first.body.data.id);
  // مفتاح جديد لكن فيه طلب شغّال ⇒ 409
  assert.equal((await book(BUYERS.a, villa, {}, { 'Idempotency-Key': 'k-456' })).status, 409);
  const fees = await prisma.payment.count({
    where: { userId: first.body.data.buyer.id, type: 'INSPECTION_FEE', inspectionRequest: { propertyId: villa } },
  });
  assert.equal(fees, 1);

  // سباق: طلبين في نفس اللحظة من نفس المشتري ⇒ واحد بس ينجح
  const duplex = await propId(DUPLEX);
  const [x, y] = await Promise.all([book(BUYERS.b, duplex), book(BUYERS.b, duplex)]);
  assert.deepEqual([x.status, y.status].sort(), [201, 409]);
  const live = await prisma.inspectionRequest.count({
    where: { buyer: { phone: '01000000006' }, propertyId: duplex, createdAt: { gte: startedAt } },
  });
  assert.equal(live, 1);
  const paid = await prisma.payment.count({
    where: { user: { phone: '01000000006' }, type: 'INSPECTION_FEE', createdAt: { gte: startedAt } },
  });
  assert.equal(paid, 1); // اللي خسر السباق ماتسجّلش له دفع
});

test('قبول المعلن ثم إلغاء المشتري ⇒ بلا استرداد', async () => {
  const flat = await propId(FLAT);
  const id = (await book(BUYERS.c, flat)).body.data.id as string;

  assert.equal((await act(BUYERS.c, id, 'accept')).status, 403); // المشتري مايقبلش
  assert.equal((await act(DEV1, id, 'accept')).status, 404); // غريب

  const acc = await act(OFFICE1, id, 'accept');
  assert.equal(acc.status, 200);
  assert.equal(acc.body.data.status, 'CONFIRMED');
  assert.deepEqual(acc.body.data.availableActions, ['propose', 'cancel']);
  // بعد التأكيد التليفون بيتكشف للطرفين
  assert.equal(acc.body.data.buyer.phone, '01000000007');
  assert.equal(acc.body.data.owner.phone, '01000000001');

  // مينفعش المعلن يرفض بعد القبول
  assert.equal((await act(OFFICE1, id, 'reject')).status, 409);

  const cancel = await act(BUYERS.c, id, 'cancel');
  assert.equal(cancel.status, 200);
  assert.equal(cancel.body.data.status, 'CANCELLED');
  assert.equal(cancel.body.data.refunded, false);
  assert.equal((await refunds(id)).length, 0); // الرسوم غير قابلة للاسترداد

  // بعد الإلغاء المشتري يقدر يطلب تاني (الفهرس الجزئي بيسمح)
  assert.equal((await book(BUYERS.c, flat)).status, 201);
});

test('رفض المعلن ⇒ استرداد كامل مرة واحدة بس', async () => {
  const villa = await propId(VILLA);
  const id = (await book(BUYERS.main, villa)).body.data.id as string;

  const rej = await act(DEV1, id, 'reject');
  assert.equal(rej.status, 200);
  assert.equal(rej.body.data.status, 'REJECTED');
  assert.equal(rej.body.data.refunded, true);
  assert.equal(rej.body.data.refund.amount, 100);
  assert.equal(rej.body.data.refund.reason, 'OWNER_REJECTED');
  assert.ok(rej.body.data.closedAt);

  // رفض تاني ⇒ 409 ومفيش استرداد تاني
  assert.equal((await act(DEV1, id, 'reject')).status, 409);
  const rf = await refunds(id);
  assert.equal(rf.length, 1);
  assert.equal(rf[0].amount.toNumber(), 100);
  assert.equal(rf[0].status, 'SUCCEEDED');

  // إشعار استرداد للمشتري
  const n = await prisma.notification.count({
    where: { user: { phone: '01000000008' }, type: 'REFUND_ISSUED', createdAt: { gte: startedAt } },
  });
  assert.equal(n >= 1, true);

  // سجل الأحداث: طلب ← رفض
  const d = await request(app).get(`/api/inspections/${id}`).set(BUYERS.main);
  assert.deepEqual(d.body.data.events.map((e: any) => e.to), ['PENDING', 'REJECTED']);
});

test('موعد بديل: المعلن يقترح ⇒ المشتري يوافق / يرفض (والاسترداد حسب الإعداد)', async () => {
  const duplex = await propId(DUPLEX);
  const newDate = addDays(todayCairo(), 4);

  // --- يوافق ---
  const id1 = (await book(BUYERS.a, duplex)).body.data.id as string;
  assert.equal((await act(OFFICE2, id1, 'propose', { visitDate: '2020-01-01', slot: 'NOON' })).status, 400);
  const prop = await act(OFFICE2, id1, 'propose', { visitDate: newDate, slot: 'EVENING' });
  assert.equal(prop.status, 200);
  assert.equal(prop.body.data.status, 'RESCHEDULED');
  assert.equal(prop.body.data.visitDate, newDate);
  assert.equal(prop.body.data.slot, 'EVENING');
  assert.equal(prop.body.data.requestedSlot, 'MORNING'); // الأصلي محفوظ
  assert.equal((await act(OFFICE2, id1, 'respond', { accept: true })).status, 403); // المعلن مايرد بدل المشتري
  const ok = await act(BUYERS.a, id1, 'respond', { accept: true });
  assert.equal(ok.body.data.status, 'CONFIRMED');
  assert.equal(ok.body.data.refunded, false);

  // --- يرفض + الإعداد = استرداد ---
  const id2 = (await book(BUYERS.main, duplex)).body.data.id as string;
  await act(OFFICE2, id2, 'propose', { visitDate: newDate, slot: 'NOON' });
  const no = await act(BUYERS.main, id2, 'respond', { accept: false });
  assert.equal(no.body.data.status, 'CANCELLED');
  assert.equal(no.body.data.refunded, true);
  assert.equal(no.body.data.refund.reason, 'BUYER_DECLINED_ALTERNATIVE');

  // --- يرفض + الإعداد = من غير استرداد ---
  settingsBackup = await prisma.setting.findMany({ where: { key: 'refund_on_buyer_declines_alternative' } });
  await prisma.setting.update({ where: { key: 'refund_on_buyer_declines_alternative' }, data: { value: false } });
  const id3 = (await book(BUYERS.c, duplex)).body.data.id as string;
  await act(OFFICE2, id3, 'propose', { visitDate: newDate, slot: 'NOON' });
  const no2 = await act(BUYERS.c, id3, 'respond', { accept: false });
  assert.equal(no2.body.data.status, 'CANCELLED');
  assert.equal(no2.body.data.refunded, false);
  assert.equal((await refunds(id3)).length, 0);
  await prisma.setting.update({ where: { key: 'refund_on_buyer_declines_alternative' }, data: { value: true } });
});

test('انتهاء المهلة ⇒ EXPIRED + استرداد تلقائي (والتكرار مايردّش مرتين)', async () => {
  const flat = await propId(FLAT);
  const id = (await book(BUYERS.b, flat)).body.data.id as string;

  // نخلّي المهلة في الماضي
  await prisma.inspectionRequest.update({
    where: { id },
    data: { responseDeadline: new Date(Date.now() - 60_000) },
  });

  // أي قراءة للقائمة بتقفل الطلبات المنتهية (lazy expiry)
  const list = await request(app).get('/api/inspections?role=buyer').set(BUYERS.b);
  const it = list.body.data.find((x: any) => x.id === id);
  assert.equal(it.status, 'EXPIRED');
  assert.equal(it.refunded, true);
  assert.equal(it.refund.reason, 'OWNER_NO_RESPONSE');

  // تشغيل الـ job تاني ⇒ مفيش حاجة تتقفل ومفيش استرداد تاني
  assert.equal(await expireOverdue(), 0);
  assert.equal((await refunds(id)).length, 1);

  // المعلن مايقدرش يقبل طلب منتهي
  assert.equal((await act(OFFICE1, id, 'accept')).status, 409);

  // سجل الأحداث بيوضح إن النظام هو اللي قفله
  const d = await request(app).get(`/api/inspections/${id}`).set(BUYERS.b);
  const last = d.body.data.events.at(-1);
  assert.equal(last.to, 'EXPIRED');
  assert.equal(last.bySystem, true);
});

test('المهلة بتقصر لو الموعد أقرب من 24 ساعة', async () => {
  // موعد النهارده/بكرة بيطلّع مهلة أقصر أو مساوية 24 ساعة، ومش بعد بداية الموعد أبداً
  const duplex = await propId(DUPLEX);
  const tomorrow = addDays(todayCairo(), 1);
  const r = await book(BUYERS.main, duplex, { visitDate: tomorrow, slot: 'MORNING' });
  assert.equal(r.status, 201);
  const hours = (new Date(r.body.data.responseDeadline).getTime() - Date.now()) / 3_600_000;
  assert.equal(hours <= 24, true);
});

test('التسابق: قبول ورفض في نفس اللحظة ⇒ واحد بس ينجح', async () => {
  const villa = await propId(VILLA);
  const id = (await book(BUYERS.c, villa)).body.data.id as string;

  const [a, b] = await Promise.all([act(DEV1, id, 'accept'), act(DEV1, id, 'reject')]);
  assert.deepEqual([a.status, b.status].sort(), [200, 409]);

  const final = (await request(app).get(`/api/inspections/${id}`).set(BUYERS.c)).body.data;
  const rf = await refunds(id);
  if (final.status === 'REJECTED') assert.equal(rf.length, 1);
  else {
    assert.equal(final.status, 'CONFIRMED');
    assert.equal(rf.length, 0); // اتقبل ⇒ مفيش استرداد، حتى لو الرفض حاول
  }
});

test('القوائم: buyer / owner / فلتر الحالة / ترقيم', async () => {
  const mine = await request(app).get('/api/inspections?role=buyer&limit=50').set(BUYERS.main);
  assert.equal(mine.status, 200);
  assert.equal(mine.body.data.every((x: any) => x.buyer.id === mine.body.data[0].buyer.id), true);

  const incoming = await request(app).get('/api/inspections?role=owner&limit=50').set(DEV1);
  assert.equal(incoming.body.data.every((x: any) => x.owner.name === 'مطور الأفق'), true);

  const onlyRejected = await request(app).get('/api/inspections?role=buyer&status=REJECTED').set(BUYERS.main);
  assert.equal(onlyRejected.body.data.every((x: any) => x.status === 'REJECTED'), true);
  assert.equal(onlyRejected.body.data.length >= 1, true);

  assert.equal((await request(app).get('/api/inspections')).status, 401);
  assert.equal((await request(app).get('/api/inspections?role=admin').set(BUYERS.main)).status, 400);
});

// ================= القرارات الأربعة في السياسة =================

const forceExpired = (id: string) =>
  prisma.inspectionRequest.update({ where: { id }, data: { responseDeadline: new Date(Date.now() - 60_000) } });
const myList = async (who: Record<string, string>) =>
  (await request(app).get('/api/inspections?role=buyer&limit=50').set(who)).body.data as any[];

test('(1) المشتري يلغي قبل رد المعلن ⇒ استرداد كامل', async () => {
  const flat = await propId(FLAT);
  const id = (await book(BUYERS.a, flat)).body.data.id as string;

  const c = await act(BUYERS.a, id, 'cancel');
  assert.equal(c.status, 200);
  assert.equal(c.body.data.status, 'CANCELLED');
  assert.equal(c.body.data.refunded, true);
  assert.equal(c.body.data.refund.reason, 'BUYER_CANCELLED_BEFORE_RESPONSE');
  assert.equal(c.body.data.refund.amount, 100);
  assert.deepEqual(c.body.data.availableActions, []);

  // مرة تانية ⇒ 409 ومفيش استرداد تاني، والمعلن مايقدرش يقبل طلب ملغي
  assert.equal((await act(BUYERS.a, id, 'cancel')).status, 409);
  assert.equal((await act(OFFICE1, id, 'accept')).status, 409);
  assert.equal((await refunds(id)).length, 1);

  // المعلن اتبلّغ، والمشتري جاله إشعار استرداد
  const owner = await prisma.notification.count({
    where: { user: { phone: '01000000001' }, type: 'INSPECTION_CANCELLED', createdAt: { gte: startedAt } },
  });
  assert.equal(owner >= 1, true);
});

test('(3) المعلن يلغي بعد ما أكّد ⇒ استرداد كامل للمشتري', async () => {
  const villa = await propId(VILLA);
  const id = (await book(BUYERS.b, villa)).body.data.id as string;

  // وهو PENDING المعلن بيرفض (مش بيلغي)
  assert.equal((await act(DEV1, id, 'cancel')).status, 409);
  assert.equal((await act(BUYERS.main, id, 'cancel')).status, 404); // غريب

  await act(DEV1, id, 'accept');
  const detail = await request(app).get(`/api/inspections/${id}`).set(DEV1);
  assert.deepEqual(detail.body.data.availableActions, ['propose', 'cancel']);

  const c = await act(DEV1, id, 'cancel');
  assert.equal(c.status, 200);
  assert.equal(c.body.data.status, 'CANCELLED');
  assert.equal(c.body.data.refunded, true);
  assert.equal(c.body.data.refund.reason, 'OWNER_CANCELLED_AFTER_CONFIRM');
  assert.equal((await refunds(id)).length, 1);

  // وبرضه يلغي لو كان بيقترح موعد بديل (RESCHEDULED)
  const id2 = (await book(BUYERS.main, villa)).body.data.id as string;
  await act(DEV1, id2, 'propose', { visitDate: addDays(todayCairo(), 4), slot: 'NOON' });
  const c2 = await act(DEV1, id2, 'cancel');
  assert.equal(c2.body.data.status, 'CANCELLED');
  assert.equal(c2.body.data.refund.reason, 'OWNER_CANCELLED_AFTER_CONFIRM');
});

test('(2) المشتري ماردّش على الموعد البديل ⇒ EXPIRED + استرداد (والإعداد بيتحكم)', async () => {
  const duplex = await propId(DUPLEX);
  const newDate = addDays(todayCairo(), 4);

  // المعلن لما يقترح موعد، المشتري بياخد مهلة جديدة
  const id = (await book(BUYERS.c, duplex)).body.data.id as string;
  const before = (await request(app).get(`/api/inspections/${id}`).set(BUYERS.c)).body.data.responseDeadline;
  await new Promise((r) => setTimeout(r, 30));
  const prop = await act(OFFICE2, id, 'propose', { visitDate: newDate, slot: 'EVENING' });
  const dl = new Date(prop.body.data.responseDeadline).getTime();
  assert.equal(dl > new Date(before).getTime(), true);
  assert.equal(dl > Date.now() && dl <= Date.now() + 24 * 3_600_000, true);

  // عدّت مهلة المشتري ⇒ بيتقفل لوحده + استرداد
  await forceExpired(id);
  const it = (await myList(BUYERS.c)).find((x) => x.id === id);
  assert.equal(it.status, 'EXPIRED');
  assert.equal(it.refunded, true);
  assert.equal(it.refund.reason, 'BUYER_ALTERNATIVE_EXPIRED');
  assert.equal((await refunds(id)).length, 1);
  // المشتري مايقدرش يوافق بعد ما اتقفل
  assert.equal((await act(BUYERS.c, id, 'respond', { accept: true })).status, 409);

  // لو الإعداد = من غير استرداد ⇒ بيتقفل برضه لكن من غير استرداد
  settingsBackup = await prisma.setting.findMany({ where: { key: 'refund_on_buyer_declines_alternative' } });
  await prisma.setting.update({ where: { key: 'refund_on_buyer_declines_alternative' }, data: { value: false } });
  try {
    const flat = await propId(FLAT);
    const id2 = (await book(BUYERS.a, flat)).body.data.id as string;
    await act(OFFICE1, id2, 'propose', { visitDate: newDate, slot: 'NOON' });
    await forceExpired(id2);
    const it2 = (await myList(BUYERS.a)).find((x) => x.id === id2);
    assert.equal(it2.status, 'EXPIRED');
    assert.equal(it2.refunded, false);
    assert.equal((await refunds(id2)).length, 0);
  } finally {
    await prisma.setting.update({ where: { key: 'refund_on_buyer_declines_alternative' }, data: { value: true } });
  }
});

test('رد المعلن بعد انتهاء المهلة (قبل ما الـ job يقفلها) ⇒ مرفوض والمشتري بياخد استرداده', async () => {
  const flat = await propId(FLAT);
  const id = (await book(BUYERS.b, flat)).body.data.id as string;
  await forceExpired(id);

  assert.equal((await act(OFFICE1, id, 'accept')).status, 409);
  const it = (await request(app).get(`/api/inspections/${id}`).set(BUYERS.b)).body.data;
  assert.equal(it.status, 'EXPIRED');
  assert.equal(it.refund.reason, 'OWNER_NO_RESPONSE');
  assert.equal((await refunds(id)).length, 1);
});

test('تسابق: المشتري يلغي والمعلن يقبل في نفس اللحظة ⇒ الاسترداد صح في الحالتين', async () => {
  const villa = await propId(VILLA);
  // نقفل أي طلب شغّال قديم للمشتري ده على الفيلا
  const old = await prisma.inspectionRequest.findMany({
    where: { buyer: { phone: '01000000006' }, propertyId: villa, status: { in: ['PENDING', 'CONFIRMED', 'RESCHEDULED'] } },
  });
  for (const o of old) await act(BUYERS.b, o.id, 'cancel');

  for (let i = 0; i < 3; i++) {
    const id = (await book(BUYERS.b, villa)).body.data.id as string;
    const [cancel, accept] = await Promise.all([act(BUYERS.b, id, 'cancel'), act(DEV1, id, 'accept')]);
    assert.equal(cancel.status, 200); // المشتري دايماً بينجح يلغي (قبل أو بعد القبول)
    assert.equal([200, 409].includes(accept.status), true);

    const final = (await request(app).get(`/api/inspections/${id}`).set(BUYERS.b)).body.data;
    assert.equal(final.status, 'CANCELLED');
    // قبل القبول ⇒ استرداد. بعد القبول ⇒ إلغاء بعد التأكيد = بلا استرداد. مفيش حالة وسط.
    assert.equal((await refunds(id)).length, accept.status === 200 ? 0 : 1);
  }
});
