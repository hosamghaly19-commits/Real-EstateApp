import { prisma } from '../db';

export interface PolicySettings {
  fee: number;
  responseHours: number;
  refundOnBuyerDeclinesAlternative: boolean;
}

/** سياسة المعاينة من جدول Setting (مع قيم افتراضية لو ناقصة). */
export async function getPolicySettings(): Promise<PolicySettings> {
  const rows = await prisma.setting.findMany({
    where: {
      key: {
        in: ['inspection_fee', 'inspection_response_hours', 'refund_on_buyer_declines_alternative'],
      },
    },
  });
  const m = new Map(rows.map((r) => [r.key, r.value]));
  return {
    fee: Number(m.get('inspection_fee') ?? 100),
    responseHours: Number(m.get('inspection_response_hours') ?? 24),
    refundOnBuyerDeclinesAlternative: Boolean(m.get('refund_on_buyer_declines_alternative') ?? true),
  };
}
