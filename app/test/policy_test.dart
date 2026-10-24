import 'package:flutter_test/flutter_test.dart';
import 'package:real_estate_app/data/app_config.dart';
import 'package:real_estate_app/data/inspection_store.dart';
import 'package:real_estate_app/data/mock_data.dart';
import 'package:real_estate_app/models/inspection_request.dart';
import 'package:real_estate_app/models/property.dart';
import 'package:real_estate_app/models/property_filters.dart';

InspectionRequest _req({
  InspectionStatus status = InspectionStatus.pending,
  Duration age = Duration.zero,
}) {
  return InspectionRequest(
    id: 'T-${DateTime.now().microsecondsSinceEpoch}',
    property: mockProperties[0],
    isMine: true,
    status: status,
    dayLabel: 'بكرة',
    slot: inspectionSlots[0],
    fee: inspectionFee,
    createdAt: DateTime.now().subtract(age),
  );
}

void main() {
  final store = InspectionStore.instance;

  group('سياسة الاسترداد', () {
    test('رفض المعلن => استرداد كامل', () {
      final r = _req();
      store.reject(r);
      expect(r.status, InspectionStatus.rejected);
      expect(r.refunded, isTrue);
    });

    test('إلغاء المشتري بعد التأكيد => بلا استرداد', () {
      final r = _req(status: InspectionStatus.confirmed);
      store.buyerCancelConfirmed(r);
      expect(r.status, InspectionStatus.cancelled);
      expect(r.refunded, isFalse);
    });

    test('رفض المشتري للموعد البديل يتبع إعداد السياسة', () {
      final r = _req(status: InspectionStatus.rescheduled);
      store.buyerDeclineAlternative(r);
      expect(r.status, InspectionStatus.cancelled);
      expect(r.refunded, refundWhenBuyerDeclinesAlternative);
    });

    test('اقتراح موعد بديل ثم قبوله', () {
      final r = _req();
      store.propose(r, 'السبت', inspectionSlots[2]);
      expect(r.status, InspectionStatus.rescheduled);
      expect(r.dayLabel, 'السبت');
      expect(r.slot, inspectionSlots[2]);
      store.buyerAcceptAlternative(r);
      expect(r.status, InspectionStatus.confirmed);
      expect(r.refunded, isFalse);
    });

    test('عدّت المهلة من غير رد => انتهت + استرداد كامل', () {
      final r = _req(age: const Duration(hours: inspectionResponseHours + 1));
      store.addForTest(r);
      store.expireOverdue();
      expect(r.status, InspectionStatus.expired);
      expect(r.refunded, isTrue);
    });

    test('داخل المهلة يفضل قيد الانتظار', () {
      final r = _req(age: const Duration(hours: 2));
      store.addForTest(r);
      store.expireOverdue();
      expect(r.status, InspectionStatus.pending);
      expect(r.refunded, isFalse);
    });

    test('الطلب المؤكد القديم ما بيتلغيش بانتهاء المهلة', () {
      final r = _req(
        status: InspectionStatus.confirmed,
        age: const Duration(hours: inspectionResponseHours + 10),
      );
      store.addForTest(r);
      store.expireOverdue();
      expect(r.status, InspectionStatus.confirmed);
    });

    test('الوقت المتبقي للرد', () {
      final fresh = _req();
      expect(fresh.remaining.isNegative, isFalse);
      expect(fresh.remainingLabel, contains('ساعة'));

      final nearly = _req(age: const Duration(hours: 23, minutes: 30));
      expect(nearly.remainingLabel, contains('دقيقة'));
    });
  });

  group('فلاتر الرئيسية', () {
    // حي النخيل، سوبر لوكس، 2,850,000، كاش/تقسيط
    final p = mockProperties[0];

    test('بدون فلاتر', () {
      expect(const PropertyFilters().matches(p), isTrue);
    });

    test('الحي', () {
      expect(const PropertyFilters(districts: {'حي النخيل'}).matches(p), isTrue);
      expect(const PropertyFilters(districts: {'الكورنيش'}).matches(p), isFalse);
    });

    test('أقصى سعر', () {
      expect(const PropertyFilters(maxPrice: 3000000).matches(p), isTrue);
      expect(const PropertyFilters(maxPrice: 1000000).matches(p), isFalse);
    });

    test('التشطيب وطريقة الدفع', () {
      expect(const PropertyFilters(finishing: 'سوبر لوكس').matches(p), isTrue);
      expect(const PropertyFilters(finishing: 'على الطوب').matches(p), isFalse);
      expect(const PropertyFilters(payment: 'تقسيط').matches(p), isTrue);
      // الأرض (p6) كاش بس
      expect(const PropertyFilters(payment: 'تقسيط').matches(mockProperties[5]),
          isFalse);
    });

    test('عدّاد الفلاتر الفعّالة', () {
      expect(const PropertyFilters().activeCount, 0);
      expect(
        const PropertyFilters(
          districts: {'حي النخيل'},
          maxPrice: 1,
          finishing: 'سوبر لوكس',
          payment: 'كاش',
        ).activeCount,
        4,
      );
      expect(const PropertyFilters(maxPrice: 1).withoutPrice().activeCount, 0);
    });
  });

  group('تنسيق الأسعار', () {
    test('formatNumber', () {
      expect(formatNumber(100), '100');
      expect(formatNumber(1000), '1,000');
      expect(formatNumber(2850000), '2,850,000');
    });

    test('priceLabel للبيع والإيجار', () {
      expect(mockProperties[0].priceLabel, '2,850,000 ج.م');
      expect(mockProperties[2].priceLabel, '12,000 ج.م / شهرياً');
    });
  });
}
