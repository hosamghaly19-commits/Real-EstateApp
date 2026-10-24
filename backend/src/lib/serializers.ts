import { Prisma } from '@prisma/client';

export const listInclude = {
  district: { select: { id: true, name: true } },
  images: { orderBy: { position: 'asc' }, take: 1, select: { url: true } },
  owner: {
    select: {
      id: true,
      name: true,
      accountType: true,
      verificationStatus: true,
      business: { select: { displayName: true } },
    },
  },
  project: { select: { id: true, name: true } },
} satisfies Prisma.PropertyInclude;

export const detailInclude = {
  ...listInclude,
  images: { orderBy: { position: 'asc' }, select: { url: true } },
} satisfies Prisma.PropertyInclude;

export type PropertyRow = Prisma.PropertyGetPayload<{ include: typeof detailInclude }>;

/** الشكل اللي بيرجع للتطبيق (الأسعار أرقام، الـ enums زي ما هي). */
export function serializeProperty(p: PropertyRow) {
  const images = p.images.map((i) => i.url);
  return {
    id: p.id,
    title: p.title,
    description: p.description,
    type: p.type,
    listingType: p.listingType,
    price: p.price.toNumber(),
    area: p.area,
    beds: p.beds,
    baths: p.baths,
    finishing: p.finishing,
    paymentMethods: p.paymentMethods,
    features: p.features,
    status: p.status,
    isFeatured: p.isFeatured,
    isVerified: p.isVerified,
    viewsCount: p.viewsCount,
    publishedAt: p.publishedAt,
    district: p.district,
    project: p.project,
    coverUrl: images[0] ?? null,
    images,
    owner: {
      id: p.owner.id,
      name: p.owner.business?.displayName ?? p.owner.name,
      accountType: p.owner.accountType,
      verified: p.owner.verificationStatus === 'VERIFIED',
    },
  };
}
