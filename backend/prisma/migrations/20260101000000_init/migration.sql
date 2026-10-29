-- CreateSchema
CREATE SCHEMA IF NOT EXISTS "public";

-- CreateEnum
CREATE TYPE "AccountType" AS ENUM ('INDIVIDUAL', 'OFFICE', 'DEVELOPER');

-- CreateEnum
CREATE TYPE "UserRole" AS ENUM ('USER', 'ADMIN');

-- CreateEnum
CREATE TYPE "VerificationStatus" AS ENUM ('NONE', 'PENDING', 'VERIFIED', 'REJECTED');

-- CreateEnum
CREATE TYPE "PropertyType" AS ENUM ('APARTMENT', 'VILLA', 'SHOP', 'OFFICE', 'LAND');

-- CreateEnum
CREATE TYPE "ListingType" AS ENUM ('SALE', 'RENT');

-- CreateEnum
CREATE TYPE "FinishingLevel" AS ENUM ('CORE_SHELL', 'SEMI_FINISHED', 'SUPER_LUX', 'ULTRA_SUPER_LUX');

-- CreateEnum
CREATE TYPE "PaymentMethod" AS ENUM ('CASH', 'INSTALLMENT');

-- CreateEnum
CREATE TYPE "PropertyStatus" AS ENUM ('DRAFT', 'ACTIVE', 'PAUSED', 'CLOSED');

-- CreateEnum
CREATE TYPE "InspectionStatus" AS ENUM ('PENDING', 'CONFIRMED', 'RESCHEDULED', 'REJECTED', 'EXPIRED', 'CANCELLED');

-- CreateEnum
CREATE TYPE "InspectionSlot" AS ENUM ('MORNING', 'NOON', 'EVENING');

-- CreateEnum
CREATE TYPE "PaymentType" AS ENUM ('INSPECTION_FEE', 'REFUND');

-- CreateEnum
CREATE TYPE "PaymentStatus" AS ENUM ('PENDING', 'SUCCEEDED', 'FAILED');

-- CreateEnum
CREATE TYPE "RefundReason" AS ENUM ('OWNER_REJECTED', 'OWNER_NO_RESPONSE', 'OWNER_CANCELLED_AFTER_CONFIRM', 'BUYER_CANCELLED_BEFORE_RESPONSE', 'BUYER_DECLINED_ALTERNATIVE', 'BUYER_ALTERNATIVE_EXPIRED');

-- CreateEnum
CREATE TYPE "RefundDestination" AS ENUM ('WALLET', 'ORIGINAL_METHOD');

-- CreateEnum
CREATE TYPE "DealStatus" AS ENUM ('PENDING', 'COMPLETED', 'CANCELLED');

-- CreateEnum
CREATE TYPE "NotificationType" AS ENUM ('INSPECTION_REQUESTED', 'INSPECTION_CONFIRMED', 'INSPECTION_RESCHEDULED', 'INSPECTION_REJECTED', 'INSPECTION_EXPIRED', 'INSPECTION_CANCELLED', 'REFUND_ISSUED', 'SYSTEM');

-- CreateTable
CREATE TABLE "User" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "phone" TEXT NOT NULL,
    "email" TEXT,
    "passwordHash" TEXT,
    "name" TEXT NOT NULL,
    "accountType" "AccountType" NOT NULL DEFAULT 'INDIVIDUAL',
    "role" "UserRole" NOT NULL DEFAULT 'USER',
    "verificationStatus" "VerificationStatus" NOT NULL DEFAULT 'NONE',
    "verifiedAt" TIMESTAMP(3),
    "isActive" BOOLEAN NOT NULL DEFAULT true,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "User_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "BusinessProfile" (
    "userId" UUID NOT NULL,
    "displayName" TEXT NOT NULL,
    "logoUrl" TEXT,
    "bio" TEXT,
    "licenseNumber" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "BusinessProfile_pkey" PRIMARY KEY ("userId")
);

-- CreateTable
CREATE TABLE "District" (
    "id" SERIAL NOT NULL,
    "name" TEXT NOT NULL,
    "sortOrder" INTEGER NOT NULL DEFAULT 0,
    "isActive" BOOLEAN NOT NULL DEFAULT true,

    CONSTRAINT "District_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "Project" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "ownerId" UUID NOT NULL,
    "districtId" INTEGER,
    "name" TEXT NOT NULL,
    "description" TEXT,
    "coverUrl" TEXT,
    "unitsCount" INTEGER NOT NULL DEFAULT 0,
    "deliveryYear" INTEGER,
    "isReadyNow" BOOLEAN NOT NULL DEFAULT false,
    "isActive" BOOLEAN NOT NULL DEFAULT true,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "Project_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "Property" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "ownerId" UUID NOT NULL,
    "projectId" UUID,
    "districtId" INTEGER NOT NULL,
    "title" TEXT NOT NULL,
    "description" TEXT,
    "type" "PropertyType" NOT NULL,
    "listingType" "ListingType" NOT NULL,
    "price" DECIMAL(14,2) NOT NULL,
    "area" INTEGER NOT NULL,
    "beds" INTEGER NOT NULL DEFAULT 0,
    "baths" INTEGER NOT NULL DEFAULT 0,
    "finishing" "FinishingLevel",
    "paymentMethods" "PaymentMethod"[],
    "features" TEXT[],
    "status" "PropertyStatus" NOT NULL DEFAULT 'DRAFT',
    "isFeatured" BOOLEAN NOT NULL DEFAULT false,
    "isVerified" BOOLEAN NOT NULL DEFAULT false,
    "viewsCount" INTEGER NOT NULL DEFAULT 0,
    "publishedAt" TIMESTAMP(3),
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "Property_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "PropertyImage" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "propertyId" UUID NOT NULL,
    "url" TEXT NOT NULL,
    "position" INTEGER NOT NULL DEFAULT 0,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "PropertyImage_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "Favorite" (
    "userId" UUID NOT NULL,
    "propertyId" UUID NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "Favorite_pkey" PRIMARY KEY ("userId","propertyId")
);

-- CreateTable
CREATE TABLE "InspectionRequest" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "number" SERIAL NOT NULL,
    "propertyId" UUID NOT NULL,
    "buyerId" UUID NOT NULL,
    "ownerId" UUID NOT NULL,
    "status" "InspectionStatus" NOT NULL DEFAULT 'PENDING',
    "visitDate" DATE NOT NULL,
    "slot" "InspectionSlot" NOT NULL,
    "requestedVisitDate" DATE NOT NULL,
    "requestedSlot" "InspectionSlot" NOT NULL,
    "feeAmount" DECIMAL(10,2) NOT NULL,
    "responseDeadline" TIMESTAMP(3) NOT NULL,
    "respondedAt" TIMESTAMP(3),
    "confirmedAt" TIMESTAMP(3),
    "closedAt" TIMESTAMP(3),
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "InspectionRequest_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "InspectionEvent" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "inspectionRequestId" UUID NOT NULL,
    "actorId" UUID,
    "fromStatus" "InspectionStatus",
    "toStatus" "InspectionStatus" NOT NULL,
    "note" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "InspectionEvent_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "Payment" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "userId" UUID NOT NULL,
    "inspectionRequestId" UUID,
    "type" "PaymentType" NOT NULL,
    "amount" DECIMAL(10,2) NOT NULL,
    "currency" TEXT NOT NULL DEFAULT 'EGP',
    "status" "PaymentStatus" NOT NULL DEFAULT 'PENDING',
    "provider" TEXT,
    "providerRef" TEXT,
    "idempotencyKey" TEXT NOT NULL,
    "refundOfId" UUID,
    "refundReason" "RefundReason",
    "refundDestination" "RefundDestination",
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "completedAt" TIMESTAMP(3),

    CONSTRAINT "Payment_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "Deal" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "propertyId" UUID NOT NULL,
    "buyerId" UUID NOT NULL,
    "sellerId" UUID NOT NULL,
    "inspectionRequestId" UUID,
    "agreedPrice" DECIMAL(14,2) NOT NULL,
    "inspectionCredit" DECIMAL(10,2) NOT NULL DEFAULT 0,
    "commissionAmount" DECIMAL(14,2),
    "status" "DealStatus" NOT NULL DEFAULT 'PENDING',
    "closedAt" TIMESTAMP(3),
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "Deal_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "Notification" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "userId" UUID NOT NULL,
    "type" "NotificationType" NOT NULL,
    "title" TEXT NOT NULL,
    "body" TEXT NOT NULL,
    "data" JSONB,
    "readAt" TIMESTAMP(3),
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "Notification_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "Setting" (
    "key" TEXT NOT NULL,
    "value" JSONB NOT NULL,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "Setting_pkey" PRIMARY KEY ("key")
);

-- CreateIndex
CREATE UNIQUE INDEX "User_phone_key" ON "User"("phone");

-- CreateIndex
CREATE UNIQUE INDEX "User_email_key" ON "User"("email");

-- CreateIndex
CREATE UNIQUE INDEX "District_name_key" ON "District"("name");

-- CreateIndex
CREATE INDEX "Project_ownerId_idx" ON "Project"("ownerId");

-- CreateIndex
CREATE INDEX "Property_status_listingType_type_districtId_idx" ON "Property"("status", "listingType", "type", "districtId");

-- CreateIndex
CREATE INDEX "Property_districtId_price_idx" ON "Property"("districtId", "price");

-- CreateIndex
CREATE INDEX "Property_ownerId_status_idx" ON "Property"("ownerId", "status");

-- CreateIndex
CREATE INDEX "Property_projectId_idx" ON "Property"("projectId");

-- CreateIndex
CREATE INDEX "Property_status_publishedAt_idx" ON "Property"("status", "publishedAt" DESC);

-- CreateIndex
CREATE INDEX "PropertyImage_propertyId_position_idx" ON "PropertyImage"("propertyId", "position");

-- CreateIndex
CREATE INDEX "Favorite_propertyId_idx" ON "Favorite"("propertyId");

-- CreateIndex
CREATE UNIQUE INDEX "InspectionRequest_number_key" ON "InspectionRequest"("number");

-- CreateIndex
CREATE INDEX "InspectionRequest_buyerId_status_idx" ON "InspectionRequest"("buyerId", "status");

-- CreateIndex
CREATE INDEX "InspectionRequest_ownerId_status_idx" ON "InspectionRequest"("ownerId", "status");

-- CreateIndex
CREATE INDEX "InspectionRequest_propertyId_idx" ON "InspectionRequest"("propertyId");

-- CreateIndex
CREATE INDEX "InspectionRequest_status_responseDeadline_idx" ON "InspectionRequest"("status", "responseDeadline");

-- CreateIndex
CREATE INDEX "InspectionEvent_inspectionRequestId_createdAt_idx" ON "InspectionEvent"("inspectionRequestId", "createdAt");

-- CreateIndex
CREATE UNIQUE INDEX "Payment_idempotencyKey_key" ON "Payment"("idempotencyKey");

-- CreateIndex
CREATE INDEX "Payment_inspectionRequestId_idx" ON "Payment"("inspectionRequestId");

-- CreateIndex
CREATE INDEX "Payment_userId_createdAt_idx" ON "Payment"("userId", "createdAt" DESC);

-- CreateIndex
CREATE UNIQUE INDEX "Payment_provider_providerRef_key" ON "Payment"("provider", "providerRef");

-- CreateIndex
CREATE UNIQUE INDEX "Deal_inspectionRequestId_key" ON "Deal"("inspectionRequestId");

-- CreateIndex
CREATE INDEX "Deal_propertyId_idx" ON "Deal"("propertyId");

-- CreateIndex
CREATE INDEX "Deal_buyerId_idx" ON "Deal"("buyerId");

-- CreateIndex
CREATE INDEX "Deal_sellerId_idx" ON "Deal"("sellerId");

-- CreateIndex
CREATE INDEX "Notification_userId_createdAt_idx" ON "Notification"("userId", "createdAt" DESC);

-- AddForeignKey
ALTER TABLE "BusinessProfile" ADD CONSTRAINT "BusinessProfile_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "Project" ADD CONSTRAINT "Project_ownerId_fkey" FOREIGN KEY ("ownerId") REFERENCES "User"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "Project" ADD CONSTRAINT "Project_districtId_fkey" FOREIGN KEY ("districtId") REFERENCES "District"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "Property" ADD CONSTRAINT "Property_ownerId_fkey" FOREIGN KEY ("ownerId") REFERENCES "User"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "Property" ADD CONSTRAINT "Property_projectId_fkey" FOREIGN KEY ("projectId") REFERENCES "Project"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "Property" ADD CONSTRAINT "Property_districtId_fkey" FOREIGN KEY ("districtId") REFERENCES "District"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "PropertyImage" ADD CONSTRAINT "PropertyImage_propertyId_fkey" FOREIGN KEY ("propertyId") REFERENCES "Property"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "Favorite" ADD CONSTRAINT "Favorite_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "Favorite" ADD CONSTRAINT "Favorite_propertyId_fkey" FOREIGN KEY ("propertyId") REFERENCES "Property"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "InspectionRequest" ADD CONSTRAINT "InspectionRequest_propertyId_fkey" FOREIGN KEY ("propertyId") REFERENCES "Property"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "InspectionRequest" ADD CONSTRAINT "InspectionRequest_buyerId_fkey" FOREIGN KEY ("buyerId") REFERENCES "User"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "InspectionRequest" ADD CONSTRAINT "InspectionRequest_ownerId_fkey" FOREIGN KEY ("ownerId") REFERENCES "User"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "InspectionEvent" ADD CONSTRAINT "InspectionEvent_inspectionRequestId_fkey" FOREIGN KEY ("inspectionRequestId") REFERENCES "InspectionRequest"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "InspectionEvent" ADD CONSTRAINT "InspectionEvent_actorId_fkey" FOREIGN KEY ("actorId") REFERENCES "User"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "Payment" ADD CONSTRAINT "Payment_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "Payment" ADD CONSTRAINT "Payment_inspectionRequestId_fkey" FOREIGN KEY ("inspectionRequestId") REFERENCES "InspectionRequest"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "Payment" ADD CONSTRAINT "Payment_refundOfId_fkey" FOREIGN KEY ("refundOfId") REFERENCES "Payment"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "Deal" ADD CONSTRAINT "Deal_propertyId_fkey" FOREIGN KEY ("propertyId") REFERENCES "Property"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "Deal" ADD CONSTRAINT "Deal_buyerId_fkey" FOREIGN KEY ("buyerId") REFERENCES "User"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "Deal" ADD CONSTRAINT "Deal_sellerId_fkey" FOREIGN KEY ("sellerId") REFERENCES "User"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "Deal" ADD CONSTRAINT "Deal_inspectionRequestId_fkey" FOREIGN KEY ("inspectionRequestId") REFERENCES "InspectionRequest"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "Notification" ADD CONSTRAINT "Notification_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;


-- ===== constraints.sql (partial indexes / CHECK / pg_trgm) =====
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
