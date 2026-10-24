-- ============================================================
--  قيود وفهارس Prisma مش بيعبّر عنها (Partial indexes / CHECK / pg_trgm)
--  بتتضاف داخل migration (شوف README → "تطبيق الـ constraints").
-- ============================================================

-- ---------- InspectionRequest ----------

-- 1) مفيش أكتر من طلب معاينة "شغّال" لنفس المشتري على نفس العقار
--    (يمنع دفع الرسوم مرتين بالغلط)
CREATE UNIQUE INDEX "InspectionRequest_one_live_per_buyer_property"
  ON "InspectionRequest" ("buyerId", "propertyId")
  WHERE "status" IN ('PENDING', 'CONFIRMED', 'RESCHEDULED');

-- 2) المشتري مايطلبش معاينة لعقاره هو
ALTER TABLE "InspectionRequest"
  ADD CONSTRAINT "InspectionRequest_buyer_not_owner"
  CHECK ("buyerId" <> "ownerId");

ALTER TABLE "InspectionRequest"
  ADD CONSTRAINT "InspectionRequest_fee_non_negative"
  CHECK ("feeAmount" >= 0);

-- 3) الحالات النهائية لازم يكون ليها وقت إغلاق
ALTER TABLE "InspectionRequest"
  ADD CONSTRAINT "InspectionRequest_closed_has_time"
  CHECK ("status" NOT IN ('REJECTED', 'EXPIRED', 'CANCELLED') OR "closedAt" IS NOT NULL);

-- ---------- Payment ----------

ALTER TABLE "Payment"
  ADD CONSTRAINT "Payment_amount_positive" CHECK ("amount" > 0);

-- رسوم المعاينة لازم تكون مربوطة بطلب معاينة
ALTER TABLE "Payment"
  ADD CONSTRAINT "Payment_fee_has_inspection"
  CHECK ("type" <> 'INSPECTION_FEE' OR "inspectionRequestId" IS NOT NULL);

-- الاسترداد: لازم يشاور على الدفعة الأصلية وله سبب. وغير الاسترداد ماله علاقة بحقول الاسترداد.
-- (refundDestination اختياري لحد ما نحسم: محفظة ولا وسيلة الدفع الأصلية)
ALTER TABLE "Payment"
  ADD CONSTRAINT "Payment_refund_fields"
  CHECK (
    ("type" = 'REFUND' AND "refundOfId" IS NOT NULL AND "refundReason" IS NOT NULL)
    OR
    ("type" <> 'REFUND' AND "refundOfId" IS NULL AND "refundReason" IS NULL AND "refundDestination" IS NULL)
  );

-- استرداد واحد فقط لكل دفعة (غير الفاشل)
CREATE UNIQUE INDEX "Payment_one_refund_per_payment"
  ON "Payment" ("refundOfId")
  WHERE "type" = 'REFUND' AND "status" <> 'FAILED';

-- ---------- Property / Project ----------

ALTER TABLE "Property"
  ADD CONSTRAINT "Property_price_positive" CHECK ("price" > 0),
  ADD CONSTRAINT "Property_area_positive" CHECK ("area" > 0),
  ADD CONSTRAINT "Property_counts_non_negative" CHECK ("beds" >= 0 AND "baths" >= 0),
  ADD CONSTRAINT "Property_active_has_published_at"
    CHECK ("status" <> 'ACTIVE' OR "publishedAt" IS NOT NULL);

ALTER TABLE "Project"
  ADD CONSTRAINT "Project_units_non_negative" CHECK ("unitsCount" >= 0);

-- ---------- Deal ----------

ALTER TABLE "Deal"
  ADD CONSTRAINT "Deal_price_positive" CHECK ("agreedPrice" > 0),
  ADD CONSTRAINT "Deal_credit_range" CHECK ("inspectionCredit" >= 0 AND "inspectionCredit" <= "agreedPrice"),
  ADD CONSTRAINT "Deal_buyer_not_seller" CHECK ("buyerId" <> "sellerId");

-- ---------- بحث نصي (عنوان الإعلان) ----------
CREATE EXTENSION IF NOT EXISTS pg_trgm;

CREATE INDEX "Property_title_trgm_idx"
  ON "Property" USING gin ("title" gin_trgm_ops);
