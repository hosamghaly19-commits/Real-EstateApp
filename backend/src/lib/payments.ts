import { randomUUID } from 'node:crypto';

/**
 * واجهة بوابة الدفع. دلوقتي فيه نسخة تجريبية (Mock) بتنجح دايماً.
 * TODO (Phase 3): تتبدل ببوابة حقيقية — والاسترداد هيبقى PENDING وبيتأكد بـ webhook
 * بدل ما يتنفّذ جوه الـ transaction.
 */
export interface PaymentGateway {
  charge(input: {
    amount: number;
    currency: string;
    buyerId: string;
    idempotencyKey: string;
  }): Promise<{ provider: string; providerRef: string }>;

  refund(input: {
    amount: number;
    originalProviderRef: string | null;
    idempotencyKey: string;
  }): Promise<{ provider: string; providerRef: string }>;
}

export const mockGateway: PaymentGateway = {
  async charge() {
    return { provider: 'mock', providerRef: `mock_ch_${randomUUID()}` };
  },
  async refund() {
    return { provider: 'mock', providerRef: `mock_rf_${randomUUID()}` };
  },
};

export const gateway: PaymentGateway = mockGateway;
