/**
 * اختبارات تكامل — بتشتغل على قاعدة بيانات متعمل عليها `npm run db:seed`.
 *   DATABASE_URL=postgresql://... npm test
 * بتضيف عقار وبتمسحه في الآخر.
 */
import { test, after } from 'node:test';
import assert from 'node:assert/strict';
import request from 'supertest';
import { app } from '../src/app';
import { prisma } from '../src/db';

const OFFICE = { 'x-demo-phone': '01000000001' }; // مكتب الأمان
const OTHER = { 'x-demo-phone': '01000000005' }; // فرد (مش صاحب العقار الجديد)

const validBody = (districtId: number) => ({
  title: 'شقة اختبار للبيع',
  description: 'وصف تجريبي',
  type: 'APARTMENT',
  listingType: 'SALE',
  districtId,
  price: 2_000_000,
  area: 110,
  beds: 2,
  baths: 1,
  finishing: 'SUPER_LUX',
  paymentMethods: ['CASH'],
  features: ['أسانسير'],
  images: ['https://images.unsplash.com/photo-1560448204-e02f11c3d0e2?w=800'],
});

const createdIds: string[] = [];
after(async () => {
  if (createdIds.length) await prisma.property.deleteMany({ where: { id: { in: createdIds } } });
  await prisma.$disconnect();
});

test('health', async () => {
  const r = await request(app).get('/health');
  assert.equal(r.status, 200);
  assert.equal(r.body.status, 'ok');
});

test('districts + config (من جدول Setting)', async () => {
  const d = await request(app).get('/api/districts');
  assert.equal(d.status, 200);
  assert.equal(d.body.data.length, 5);

  const c = await request(app).get('/api/config');
  assert.equal(c.body.data.inspectionFee, 100);
  assert.equal(c.body.data.inspectionResponseHours, 24);
});

test('القائمة: كل العقارات النشطة + ترقيم صفحات', async () => {
  const r = await request(app).get('/api/properties?limit=4');
  assert.equal(r.status, 200);
  assert.equal(r.body.total >= 9, true);
  assert.equal(r.body.data.length, 4);
  assert.equal(typeof r.body.data[0].price, 'number');
  assert.ok(r.body.data[0].coverUrl);
  assert.equal(r.body.data[0].images.length, 1); // الغلاف بس في القائمة
});

test('فلاتر: إيجار / تقسيط / مميز / حي / سعر / بحث عربي', async () => {
  const rent = await request(app).get('/api/properties?listingType=RENT');
  assert.equal(rent.body.data.every((p: any) => p.listingType === 'RENT'), true);
  assert.equal(rent.body.data.length, 3);

  const inst = await request(app).get('/api/properties?listingType=SALE&payment=INSTALLMENT');
  assert.equal(inst.body.data.length, 4);

  const feat = await request(app).get('/api/properties?featured=true');
  assert.equal(feat.body.data.length, 5);

  const districts = (await request(app).get('/api/districts')).body.data;
  const uni = districts.find((d: any) => d.name === 'حي الجامعة').id;
  const byDistrict = await request(app).get(`/api/properties?districtIds=${uni}`);
  assert.equal(byDistrict.body.data.length, 3);

  const cheap = await request(app).get('/api/properties?listingType=SALE&maxPrice=3000000');
  assert.equal(cheap.body.data.every((p: any) => p.price <= 3_000_000), true);
  assert.equal(cheap.body.data.length, 2);

  const q = await request(app).get('/api/properties?q=' + encodeURIComponent('فيلا'));
  assert.equal(q.body.data.length, 1);
  const qd = await request(app).get('/api/properties?q=' + encodeURIComponent('الكورنيش'));
  assert.equal(qd.body.data.length, 1); // بيدوّر في اسم الحي كمان

  const sorted = await request(app).get('/api/properties?listingType=SALE&sort=price_asc');
  const prices = sorted.body.data.map((p: any) => p.price);
  assert.deepEqual(prices, [...prices].sort((a, b) => a - b));
});

test('فلتر غلط ⇒ 400 برسالة عربي', async () => {
  const r = await request(app).get('/api/properties?listingType=BUY&limit=999');
  assert.equal(r.status, 400);
  assert.equal(r.body.error.code, 'VALIDATION_ERROR');
  assert.equal(r.body.error.message, 'بيانات غير صالحة');
});

test('التفاصيل: الصور والمالك + عدّاد المشاهدات + 404/400', async () => {
  const list = await request(app).get('/api/properties?q=' + encodeURIComponent('فيلا'));
  const id = list.body.data[0].id;
  const before = list.body.data[0].viewsCount;

  const r = await request(app).get(`/api/properties/${id}`);
  assert.equal(r.status, 200);
  assert.equal(r.body.data.images.length, 3);
  assert.equal(r.body.data.owner.name, 'مطور الأفق'); // اسم النشاط مش اسم الشخص
  assert.equal(r.body.data.owner.verified, true);

  await new Promise((res) => setTimeout(res, 150));
  const again = await request(app).get(`/api/properties/${id}`);
  assert.equal(again.body.data.viewsCount > before, true);

  assert.equal((await request(app).get('/api/properties/00000000-0000-4000-8000-000000000000')).status, 404);
  assert.equal((await request(app).get('/api/properties/not-a-uuid')).status, 400);
});

test('الإضافة: بدون دخول ⇒ 401، بيانات غلط ⇒ 400', async () => {
  const districts = (await request(app).get('/api/districts')).body.data;
  const did = districts[0].id;

  assert.equal((await request(app).post('/api/properties').send(validBody(did))).status, 401);
  assert.equal(
    (await request(app).post('/api/properties').set('x-demo-phone', '0999').send(validBody(did))).status,
    401,
  );

  // أرض بتشطيب
  const land = await request(app).post('/api/properties').set(OFFICE)
    .send({ ...validBody(did), type: 'LAND', beds: 0, baths: 0 });
  assert.equal(land.status, 400);
  // شقة من غير غرف
  const noBeds = await request(app).post('/api/properties').set(OFFICE)
    .send({ ...validBody(did), beds: 0 });
  assert.equal(noBeds.status, 400);
  // حي مش موجود
  const badDistrict = await request(app).post('/api/properties').set(OFFICE).send(validBody(99999));
  assert.equal(badDistrict.status, 400);
  // صورة http
  const http = await request(app).post('/api/properties').set(OFFICE)
    .send({ ...validBody(did), images: ['http://x.com/a.jpg'] });
  assert.equal(http.status, 400);
});

test('دورة حياة الإعلان: إضافة ← ظهور ← إيقاف ← صلاحيات ← تفعيل', async () => {
  const districts = (await request(app).get('/api/districts')).body.data;
  const created = await request(app).post('/api/properties').set(OFFICE).send(validBody(districts[0].id));
  assert.equal(created.status, 201);
  const id = created.body.data.id as string;
  createdIds.push(id);
  assert.equal(created.body.data.status, 'ACTIVE');
  assert.equal(created.body.data.owner.name, 'مكتب الأمان العقاري');
  assert.ok(created.body.data.publishedAt);

  // بيظهر أول القائمة (الأحدث)
  const latest = await request(app).get('/api/properties?limit=1');
  assert.equal(latest.body.data[0].id, id);

  // مش صاحبه ⇒ 403 / من غير دخول ⇒ 401
  assert.equal((await request(app).patch(`/api/properties/${id}/status`).set(OTHER).send({ status: 'PAUSED' })).status, 403);
  assert.equal((await request(app).patch(`/api/properties/${id}/status`).send({ status: 'PAUSED' })).status, 401);

  // صاحبه يوقفه ⇒ يختفي من العام ويفضل ظاهر لصاحبه
  const paused = await request(app).patch(`/api/properties/${id}/status`).set(OFFICE).send({ status: 'PAUSED' });
  assert.equal(paused.status, 200);
  assert.equal((await request(app).get(`/api/properties/${id}`)).status, 404);
  assert.equal((await request(app).get(`/api/properties/${id}`).set(OFFICE)).status, 200);
  const mine = await request(app).get('/api/me/properties').set(OFFICE);
  assert.equal(mine.body.data.some((p: any) => p.id === id), true);

  // تفعيل تاني
  const active = await request(app).patch(`/api/properties/${id}/status`).set(OFFICE).send({ status: 'ACTIVE' });
  assert.equal(active.body.data.status, 'ACTIVE');
  assert.equal((await request(app).get(`/api/properties/${id}`)).status, 200);

  // إغلاق ثم محاولة تعديل ⇒ 400
  await request(app).patch(`/api/properties/${id}/status`).set(OFFICE).send({ status: 'CLOSED' });
  assert.equal((await request(app).patch(`/api/properties/${id}/status`).set(OFFICE).send({ status: 'ACTIVE' })).status, 400);
});

test('/api/me', async () => {
  const r = await request(app).get('/api/me').set(OFFICE);
  assert.equal(r.status, 200);
  assert.equal(r.body.data.accountType, 'OFFICE');
  assert.equal(r.body.data.business.displayName, 'مكتب الأمان العقاري');
  assert.equal((await request(app).get('/api/me')).status, 401);
});

test('مسار مش موجود ⇒ 404 JSON', async () => {
  const r = await request(app).get('/api/nope');
  assert.equal(r.status, 404);
  assert.equal(r.body.error.code, 'NOT_FOUND');
});
