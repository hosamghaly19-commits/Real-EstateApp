# Backend — تطبيق العقارات المحلي

Express 5 + TypeScript + Prisma على **Neon PostgreSQL**، والنشر على **Render**.

```
src/
  app.ts, server.ts, config.ts, db.ts
  middleware/   auth.ts (دخول تجريبي)، error.ts
  routes/       properties.ts، inspections.ts، meta.ts (الأحياء/الإعدادات/حسابي)
  services/     inspections.ts (State machine + الاسترداد)
  jobs/         expiry.ts (إقفال الطلبات المنتهية)
  lib/          errors.ts، serializers.ts، slots.ts (توقيت القاهرة)، settings.ts، payments.ts (Mock)
prisma/
  schema.prisma          ← 13 جدول، 16 enum
  sql/constraints.sql    ← قيود وفهارس Prisma مش بيعبّر عنها
  seed.ts                ← إعدادات + أحياء + مستخدمين + نفس بيانات التطبيق
test/                    ← اختبارات تكامل (25): api.test.ts + inspections.test.ts
docs/ERD.md              ← مخطط العلاقات
render.yaml
```

## التشغيل

1. **Neon:** اعمل Project (يفضّل Branch للتطوير) وانسخ من *Connect*:
   `DATABASE_URL` (الـ **Pooled**، فيه `-pooler`) و`DIRECT_URL` (**Direct**).
2. `cp .env.example .env` وحط القيم، ثم `npm install`
3. **الـ migration الأول** (على مرحلتين عشان القيود تدخل جواه):
   ```bash
   npx prisma migrate dev --name init --create-only
   cat prisma/sql/constraints.sql >> prisma/migrations/*_init/migration.sql
   npx prisma migrate dev
   ```
   (على Windows افتح `migration.sql` والصق محتوى `constraints.sql` في آخره.)
4. `npm run db:seed` ثم `npm run dev` ← `http://localhost:3000`

> `migrate dev` بيحتاج shadow database — اشتغل على Branch للتطوير في Neon أو Postgres محلي.

## الـ API

كل الردود JSON: `{ data: ... }` أو `{ error: { code, message, details? } }` (الرسائل بالعربي).

| Method | المسار | دخول | الوصف |
|---|---|---|---|
| GET | `/health` | — | فحص الحالة (Render) |
| GET | `/api/districts` | — | الأحياء |
| GET | `/api/config` | — | رسوم المعاينة، مهلة الرد، سياسة الاسترداد (من جدول `Setting`) |
| GET | `/api/properties` | — | بحث + فلترة + ترتيب + صفحات |
| GET | `/api/properties/:id` | اختياري | التفاصيل (+ بيزوّد المشاهدات). غير النشط بيظهر لصاحبه بس |
| POST | `/api/properties` | ✅ | إضافة عقار (شاشة Add Property) |
| PATCH | `/api/properties/:id/status` | ✅ صاحب الإعلان | `ACTIVE` / `PAUSED` / `CLOSED` |
| GET | `/api/me` | ✅ | حسابي |
| GET | `/api/me/properties` | ✅ | إعلاناتي (كل الحالات) |
| POST | `/api/inspections` | ✅ مشتري | طلب معاينة + دفع الرسوم. هيدر `Idempotency-Key` اختياري لمنع الدفع المزدوج |
| GET | `/api/inspections?role=buyer\|owner` | ✅ | طلباتي، أو الواردة على عقاراتي (+ `status`, `page`, `limit`) |
| GET | `/api/inspections/:id` | ✅ طرف في الطلب | التفاصيل + سجل الأحداث + `availableActions` |
| POST | `/api/inspections/:id/accept` | ✅ معلن | قبول |
| POST | `/api/inspections/:id/reject` | ✅ معلن | رفض ⇒ استرداد كامل |
| POST | `/api/inspections/:id/propose` | ✅ معلن | موعد بديل `{visitDate, slot}` |
| POST | `/api/inspections/:id/respond` | ✅ مشتري | `{accept: true\|false}` على الموعد البديل |
| POST | `/api/inspections/:id/cancel` | ✅ مشتري | إلغاء بعد التأكيد ⇒ بلا استرداد |

**فلاتر القائمة** (`GET /api/properties`): `listingType` (`SALE`/`RENT`)، `type` (`APARTMENT`/`VILLA`/`SHOP`/`OFFICE`/`LAND`)،
`districtIds` (مثلاً `1,3`)، `minPrice`، `maxPrice`، `finishing`، `payment` (`CASH`/`INSTALLMENT`)، `featured`، `q` (بحث في العنوان واسم الحي)،
`sort` (`latest`/`price_asc`/`price_desc`)، `page`، `limit` (حد أقصى 50).

مثال: `GET /api/properties?listingType=SALE&type=APARTMENT&payment=INSTALLMENT&sort=price_asc`

### الدخول التجريبي ⚠️
لحد ما نبني الـ Auth الحقيقي، ابعت هيدر `x-demo-phone: 01000000001` (مكتب الأمان). أرقام الـ seed: `01000000001`…`09`.
شغّال تلقائياً خارج production، وفي production **مقفول** ما لم تفعّل `DEMO_AUTH=true` (ما تعملهاش).

## دورة حياة المعاينة

```
PENDING     ─ المعلن يقبل ────────────▶ CONFIRMED
            ─ المعلن يرفض ────────────▶ REJECTED    (+ استرداد كامل)
            ─ المعلن يقترح موعد ──────▶ RESCHEDULED
            ─ المشتري يلغي ───────────▶ CANCELLED   (+ استرداد كامل)
            ─ المعلن ماردّش في المهلة ▶ EXPIRED     (+ استرداد كامل)
CONFIRMED   ─ المعلن يقترح موعد ──────▶ RESCHEDULED
            ─ المعلن يلغي ────────────▶ CANCELLED   (+ استرداد كامل)
            ─ المشتري يلغي ───────────▶ CANCELLED   (بلا استرداد)
RESCHEDULED ─ المشتري يوافق ──────────▶ CONFIRMED
            ─ المشتري يرفض ───────────▶ CANCELLED   (استرداد كامل*)
            ─ المشتري ماردّش في المهلة▶ EXPIRED     (استرداد كامل*)
            ─ المعلن يقترح موعد تاني ─▶ RESCHEDULED
            ─ المعلن يلغي ────────────▶ CANCELLED   (+ استرداد كامل)
REJECTED / EXPIRED / CANCELLED = نهائية
* بيتحكم فيه Setting.refund_on_buyer_declines_alternative (الافتراضي: true)
```

- **الدفع والطلب في خطوة واحدة:** الرسوم بتتحصّل، وبعدها الطلب + الدفعة + سجل الحدث + إشعار المعلن بيتسجلوا في transaction واحد. لو التسجيل فشل بعد الدفع، الرسوم بتتردّ تلقائياً (compensation).
- **مهلة الرد:** `Setting.inspection_response_hours` (24 ساعة) **أو لحد بداية الموعد**، أيهما أقرب. بتتثبّت في `responseDeadline` وقت الطلب، وبتتجدد لما المعلن يقترح موعد بديل (المهلة بقت على المشتري). أي عملية بعد انتهاء المهلة بترجع 409 وبتقفل الطلب فوراً.
- **الإقفال التلقائي:** job كل دقيقة جوه السيرفر (`src/jobs/expiry.ts`) + إقفال "كسول" عند قراءة قايمة الطلبات أو محاولة أي عملية. كلاهما آمن للتكرار (مفيش استرداد مزدوج).
- **التسابق:** كل انتقال بيتنفّذ بـ `UPDATE … WHERE status IN (…)`، فلو المعلن ضغط قبول ورفض في نفس اللحظة واحد بس بينجح (والتاني 409).
- **الخصوصية:** رقم تليفون الطرف التاني بيظهر مقنّع (`010••••4521`) لحد ما الطلب يتأكد.
- **المواعيد بتوقيت القاهرة** (مع التوقيت الصيفي): الفترات `MORNING 10–12` / `NOON 1–3` / `EVENING 5–8`، وأقصى حجز 7 أيام قدّام.
- **`availableActions`** في كل رد بتقول للتطبيق إيه المسموح للمستخدم الحالي (بدل ما التطبيق يكرر اللوجيك).
- **بوابة الدفع تجريبية (Mock)** في `src/lib/payments.ts` — بتنجح دايماً. في Phase 3 بتتبدل ببوابة حقيقية، والاسترداد بيبقى PENDING ويتأكد بـ webhook.

### سياسة الاسترداد — القرارات النهائية

| الحالة | النتيجة | `refundReason` |
|---|---|---|
| المعلن رفض | استرداد كامل | `OWNER_REJECTED` |
| المعلن ماردّش في المهلة | استرداد كامل (تلقائي) | `OWNER_NO_RESPONSE` |
| المشتري ألغى **قبل** رد المعلن | استرداد كامل — لسه ماحصلش أي التزام بوقت | `BUYER_CANCELLED_BEFORE_RESPONSE` |
| المعلن ألغى **بعد** ما أكّد | استرداد كامل — المعاينة ماتمّتش بسببه | `OWNER_CANCELLED_AFTER_CONFIRM` |
| المشتري رفض الموعد البديل | استرداد كامل* | `BUYER_DECLINED_ALTERNATIVE` |
| المشتري ماردّش على الموعد البديل | استرداد كامل* (الصمت = رفض) | `BUYER_ALTERNATIVE_EXPIRED` |
| المشتري ألغى **بعد** التأكيد | **بلا استرداد** — مقابل تنظيم وتأكيد المعاينة | — |
| الصفقة ماتمّتش بعد معاينة حصلت | بلا استرداد؛ وبتتخصم من السعر لو تمّت | — |

\* قابل للتعديل من `Setting.refund_on_buyer_declines_alternative`.

**ملاحظات للمراجعة:**
- إلغاء المشتري المجاني قبل رد المعلن ممكن يتستغل (طلب ثم إلغاء بشكل متكرر لإزعاج المعلن). لو ظهر ده، الحل حد أقصى للطلبات الشغّالة أو حد يومي لكل مشتري.
- المعلن اللي بيلغي بعد التأكيد بشكل متكرر محتاج سجل سمعة/مخالفات (كل حدث متسجّل في `InspectionEvent` فالبيانات موجودة).
- أسباب الاسترداد ثابتة في الـ Schema (enum) والتعديل عليها يحتاج migration.

## الاختبارات
```bash
DATABASE_URL=postgresql://... npm test    # لازم قاعدة متعمل عليها db:seed
npm run typecheck
```

## قرارات تصميم

| الموضوع | القرار |
|---|---|
| Prisma بدون Rust engine | `engineType = "client"` + `@prisma/adapter-pg` — أخف وأسهل على Render، وهو الاتجاه الافتراضي في Prisma 7 |
| الفلوس | `Decimal` في الـ DB، وبترجع للتطبيق كأرقام |
| اسم المعلن | اسم النشاط (`BusinessProfile.displayName`) لو موجود، وإلا اسم الشخص |
| قيود حرجة في الـ DB مش في الكود بس | طلب معاينة نشط واحد لكل مشتري/عقار، استرداد واحد لكل دفعة، إعلان ACTIVE لازم `publishedAt`… |

### سياسة المعاينة ← إزاي اتمثلت في الـ DB
| السياسة | التمثيل |
|---|---|
| رسوم 100 ج.م + مهلة 24 ساعة | `Setting` + `InspectionRequest.feeAmount` / `responseDeadline` (بتتثبّت وقت الطلب) |
| رفض المعلن / عدم الرد ⇒ استرداد كامل | `REJECTED` / `EXPIRED` + `Payment(type=REFUND, refundReason=…)` |
| إلغاء بعد التأكيد ⇒ بلا استرداد | `CANCELLED` من غير سجل REFUND |
| خصم الرسوم من السعر عند الإتمام | `Deal.inspectionCredit` |

## اللي اتجرّب فعلاً واللي لأ

**اتجرّب (على PostgreSQL 16 محلي):**
- `prisma validate`، و`tsc --noEmit`، و`npm run build`.
- 18 اختبار على قيود الـ DB (`constraints.sql`) + بحث `pg_trgm` العربي.
- الـ seed (مرتين، idempotent).
- **25 اختبار تكامل للـ API** عدّوا كلهم (واتكرّر تشغيل ملف المعاينات 4 مرات متتالية بدون فشل): العقارات (فلاتر، إضافة، صلاحيات) + **المعاينات**: الدفع، القبول/الرفض/الموعد البديل، الاسترداد (مرة واحدة بس) لكل الحالات الست، إلغاء بعد التأكيد بلا استرداد، انتهاء مهلة المعلن ومهلة المشتري، منع الدفع المزدوج (Idempotency + سباق)، وتسابق قبول/رفض وتسابق إلغاء/قبول.
- تشغيل السيرفر المبني فعلاً: الـ expiry job قفل طلب منتهي ورد رسومه لوحده بعد إعادة التشغيل.

**ماجرّبتوش:**
- `prisma migrate dev/deploy` الحقيقي (بيئتي مفيهاش وصول لـ binaries.prisma.sh): الـ DDL اللي اختبرت عليه مولَّد بسكريبت تقريبي من الـ Schema، فممكن تبقى فيه فروق صغيرة (أسماء الفهارس مثلاً).
- الاتصال بـ **Neon** نفسه (الـ pooler/SSL) والنشر على **Render** (`render.yaml` للمراجعة).
- أول تشغيل `migrate` ممكن يطلع تحذير `package.json#prisma is deprecated` — بيّن ومش مؤثر في Prisma 6.
