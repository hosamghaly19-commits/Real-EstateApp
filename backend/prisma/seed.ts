/**
 * Seed: بيانات أولية + نفس البيانات التجريبية اللي في تطبيق الـ Flutter.
 * آمن للتشغيل أكتر من مرة (upsert / بيتخطى لو فيه بيانات).
 *
 * ⚠️ الأرقام والأسماء هنا تجريبية للتطوير فقط — مش للـ production.
 */
import {
  PrismaClient,
  AccountType,
  UserRole,
  VerificationStatus,
  PropertyType,
  ListingType,
  FinishingLevel,
  PaymentMethod,
  PropertyStatus,
} from '@prisma/client';
import { PrismaPg } from '@prisma/adapter-pg';
import 'dotenv/config';

const prisma = new PrismaClient({
  adapter: new PrismaPg({ connectionString: process.env.DATABASE_URL! }),
});

const img = (id: string) => `https://images.unsplash.com/${id}?w=800&q=70`;
const EXTRA_IMAGES = [
  img('photo-1560448204-e02f11c3d0e2'),
  img('photo-1484154218962-a197022b5858'),
];

// ---------------- إعدادات النظام ----------------
const SETTINGS: { key: string; value: string | number | boolean }[] = [
  { key: 'inspection_fee', value: 100 }, // ج.م
  { key: 'inspection_response_hours', value: 24 },
  // السياسة اللي ماتحسمتش: لو المشتري رفض الموعد البديل، هل الرسوم بتترد؟
  { key: 'refund_on_buyer_declines_alternative', value: true },
  { key: 'currency', value: 'EGP' },
];

// ---------------- الأحياء ----------------
const DISTRICTS = [
  'حي النخيل',
  'الحي الراقي',
  'وسط البلد',
  'حي الجامعة',
  'الكورنيش',
];

// ---------------- المستخدمون ----------------
interface SeedUser {
  key: string;
  phone: string;
  name: string;
  accountType: AccountType;
  businessName?: string;
  verified?: boolean;
  role?: UserRole;
}

const USERS: SeedUser[] = [
  { key: 'office1', phone: '01000000001', name: 'أحمد (مكتب الأمان)', accountType: AccountType.OFFICE, businessName: 'مكتب الأمان العقاري', verified: true },
  { key: 'office2', phone: '01000000002', name: 'مدير مكتب بيت المدينة', accountType: AccountType.OFFICE, businessName: 'مكتب بيت المدينة', verified: true },
  { key: 'dev1', phone: '01000000003', name: 'مسؤول مطور الأفق', accountType: AccountType.DEVELOPER, businessName: 'مطور الأفق', verified: true },
  { key: 'dev2', phone: '01000000004', name: 'مسؤول شركة العمران', accountType: AccountType.DEVELOPER, businessName: 'شركة العمران', verified: true },
  { key: 'ind1', phone: '01000000005', name: 'أحمد س.', accountType: AccountType.INDIVIDUAL },
  { key: 'ind2', phone: '01000000006', name: 'محمود ع.', accountType: AccountType.INDIVIDUAL },
  { key: 'ind3', phone: '01000000007', name: 'سارة م.', accountType: AccountType.INDIVIDUAL },
  { key: 'buyer', phone: '01000000008', name: 'مشتري تجريبي', accountType: AccountType.INDIVIDUAL },
  { key: 'admin', phone: '01000000009', name: 'مدير النظام', accountType: AccountType.OFFICE, role: UserRole.ADMIN },
];

// ---------------- المشاريع ----------------
const PROJECTS = [
  { key: 'oasis', owner: 'dev1', name: 'مشروع الواحة', unitsCount: 240, deliveryYear: 2028, isReadyNow: false },
  { key: 'port', owner: 'dev2', name: 'أبراج الميناء', unitsCount: 120, deliveryYear: 2027, isReadyNow: false },
  { key: 'nakheel', owner: 'dev1', name: 'نخيل ريزيدنس', unitsCount: 85, deliveryYear: null as number | null, isReadyNow: true },
];

// ---------------- العقارات ----------------
const { CASH, INSTALLMENT } = PaymentMethod;

interface SeedProperty {
  owner: string;
  project?: string;
  title: string;
  district: string;
  type: PropertyType;
  listingType: ListingType;
  price: number;
  area: number;
  beds: number;
  baths: number;
  finishing: FinishingLevel | null; // null للأراضي
  pay: PaymentMethod[];
  image: string;
  featured?: boolean;
  verified?: boolean;
}

const PROPERTIES: SeedProperty[] = [
  { owner: 'office1', title: 'شقة فاخرة بتشطيب سوبر لوكس', district: 'حي النخيل', type: 'APARTMENT', listingType: 'SALE', price: 2850000, area: 165, beds: 3, baths: 2, finishing: 'SUPER_LUX', pay: [CASH, INSTALLMENT], image: 'photo-1545324418-cc1a3fa10c00', featured: true, verified: true },
  { owner: 'dev1', project: 'nakheel', title: 'فيلا مستقلة بحديقة خاصة', district: 'الحي الراقي', type: 'VILLA', listingType: 'SALE', price: 9500000, area: 420, beds: 5, baths: 4, finishing: 'ULTRA_SUPER_LUX', pay: [CASH, INSTALLMENT], image: 'photo-1512917774080-9991f1c4c750', featured: true, verified: true },
  { owner: 'office1', title: 'شقة مفروشة بإطلالة على الكورنيش', district: 'الكورنيش', type: 'APARTMENT', listingType: 'RENT', price: 12000, area: 120, beds: 2, baths: 1, finishing: 'ULTRA_SUPER_LUX', pay: [CASH], image: 'photo-1502672260266-1c1ef2d93688', featured: true, verified: true },
  { owner: 'ind1', title: 'محل تجاري بواجهة رئيسية', district: 'وسط البلد', type: 'SHOP', listingType: 'SALE', price: 4200000, area: 60, beds: 0, baths: 1, finishing: 'SEMI_FINISHED', pay: [CASH], image: 'photo-1604014237800-1c9102c219da' },
  { owner: 'office2', title: 'مكتب إداري بمساحة مفتوحة', district: 'وسط البلد', type: 'OFFICE', listingType: 'RENT', price: 18000, area: 95, beds: 0, baths: 1, finishing: 'SUPER_LUX', pay: [CASH], image: 'photo-1497366216548-37526070297c', verified: true },
  { owner: 'ind2', title: 'أرض سكنية على شارعين', district: 'حي الجامعة', type: 'LAND', listingType: 'SALE', price: 3100000, area: 300, beds: 0, baths: 0, finishing: null, pay: [CASH], image: 'photo-1500382017468-9049fed747ef' },
  { owner: 'dev1', project: 'oasis', title: 'شقة في كمبوند بتقسيط ٧ سنوات', district: 'حي الجامعة', type: 'APARTMENT', listingType: 'SALE', price: 1950000, area: 130, beds: 3, baths: 2, finishing: 'SEMI_FINISHED', pay: [INSTALLMENT], image: 'photo-1522708323590-d24dbb6b0267', featured: true, verified: true },
  { owner: 'ind3', title: 'شقة للإيجار قريبة من الجامعة', district: 'حي الجامعة', type: 'APARTMENT', listingType: 'RENT', price: 5500, area: 100, beds: 2, baths: 1, finishing: 'SUPER_LUX', pay: [CASH], image: 'photo-1493809842364-78817add7ffb' },
  { owner: 'office2', title: 'دوبلكس بإطلالة مفتوحة', district: 'حي النخيل', type: 'APARTMENT', listingType: 'SALE', price: 4600000, area: 240, beds: 4, baths: 3, finishing: 'ULTRA_SUPER_LUX', pay: [CASH, INSTALLMENT], image: 'photo-1564013799919-ab600027ffc6', featured: true, verified: true },
];

async function main() {
  // 1) الإعدادات (update: {} عشان ما نكتبش فوق تعديلات الأدمن)
  for (const s of SETTINGS) {
    await prisma.setting.upsert({
      where: { key: s.key },
      update: {},
      create: { key: s.key, value: s.value },
    });
  }

  // 2) الأحياء
  const districtId = new Map<string, number>();
  for (const [i, name] of DISTRICTS.entries()) {
    const d = await prisma.district.upsert({
      where: { name },
      update: {},
      create: { name, sortOrder: i },
    });
    districtId.set(name, d.id);
  }

  // 3) المستخدمون
  const userId = new Map<string, string>();
  for (const u of USERS) {
    const row = await prisma.user.upsert({
      where: { phone: u.phone },
      update: {},
      create: {
        phone: u.phone,
        name: u.name,
        accountType: u.accountType,
        role: u.role ?? UserRole.USER,
        verificationStatus: u.verified
          ? VerificationStatus.VERIFIED
          : VerificationStatus.NONE,
        verifiedAt: u.verified ? new Date() : null,
        business: u.businessName
          ? { create: { displayName: u.businessName } }
          : undefined,
      },
    });
    userId.set(u.key, row.id);
  }

  // 4) المشاريع
  const projectId = new Map<string, string>();
  if ((await prisma.project.count()) === 0) {
    for (const p of PROJECTS) {
      const row = await prisma.project.create({
        data: {
          ownerId: userId.get(p.owner)!,
          name: p.name,
          unitsCount: p.unitsCount,
          deliveryYear: p.deliveryYear,
          isReadyNow: p.isReadyNow,
        },
      });
      projectId.set(p.key, row.id);
    }
  } else {
    for (const p of await prisma.project.findMany()) {
      const key = PROJECTS.find((x) => x.name === p.name)?.key;
      if (key) projectId.set(key, p.id);
    }
  }

  // 5) العقارات (بس لو الجدول فاضي)
  if ((await prisma.property.count()) === 0) {
    for (const p of PROPERTIES) {
      await prisma.property.create({
        data: {
          ownerId: userId.get(p.owner)!,
          projectId: p.project ? projectId.get(p.project) : undefined,
          districtId: districtId.get(p.district)!,
          title: p.title,
          type: p.type,
          listingType: p.listingType,
          price: p.price,
          area: p.area,
          beds: p.beds,
          baths: p.baths,
          finishing: p.finishing,
          paymentMethods: p.pay,
          features: [],
          status: PropertyStatus.ACTIVE,
          isFeatured: p.featured ?? false,
          isVerified: p.verified ?? false,
          publishedAt: new Date(),
          images: {
            create: [img(p.image), ...EXTRA_IMAGES].map((url, position) => ({
              url,
              position,
            })),
          },
        },
      });
    }
  }

  const [users, props, images] = await Promise.all([
    prisma.user.count(),
    prisma.property.count(),
    prisma.propertyImage.count(),
  ]);
  console.log(
    `✅ seed تمام — users: ${users}, districts: ${districtId.size}, properties: ${props}, images: ${images}`,
  );
}

main()
  .catch((e) => {
    console.error(e);
    process.exit(1);
  })
  .finally(() => prisma.$disconnect());
