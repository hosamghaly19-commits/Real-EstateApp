import 'package:flutter/foundation.dart';
import '../models/inspection_request.dart';
import '../models/property.dart';
import 'app_config.dart';
import 'mock_data.dart';

DateTime _ago(int hours) => DateTime.now().subtract(Duration(hours: hours));

/// مخزن مؤقت في الذاكرة لطلبات المعاينة + سياسة الاسترداد.
///
/// سياسة الاسترداد (معتمدة):
///  1) المعلن رفض الطلب، أو عدّت المهلة من غير رد  => استرداد كامل تلقائي.
///  2) بعد تأكيد الموعد => الرسوم بتتخصم من السعر عند الإتمام،
///     وغير قابلة للاسترداد لو المشتري ألغى.
///
/// TODO (Phase 2/3): يتبدل بـ Repository + بوابة الدفع (الاسترداد الفعلي).
class InspectionStore extends ChangeNotifier {
  InspectionStore._();
  static final InspectionStore instance = InspectionStore._();

  final List<InspectionRequest> _items = [
    // ---- طلباتي كمشتري ----
    InspectionRequest(
      id: 'IR-20418',
      property: mockProperties[0],
      isMine: true,
      status: InspectionStatus.pending,
      dayLabel: 'بكرة',
      slot: inspectionSlots[0],
      fee: inspectionFee,
      createdAt: _ago(3),
    ),
    InspectionRequest(
      id: 'IR-20395',
      property: mockProperties[1],
      isMine: true,
      status: InspectionStatus.confirmed,
      dayLabel: 'الخميس',
      slot: inspectionSlots[1],
      fee: inspectionFee,
      createdAt: _ago(20),
    ),
    InspectionRequest(
      id: 'IR-20287',
      property: mockProperties[8],
      isMine: true,
      status: InspectionStatus.rescheduled,
      dayLabel: 'السبت',
      slot: inspectionSlots[0],
      fee: inspectionFee,
      createdAt: _ago(10),
    ),
    InspectionRequest(
      id: 'IR-20311',
      property: mockProperties[6],
      isMine: true,
      status: InspectionStatus.rejected,
      dayLabel: 'اليوم',
      slot: inspectionSlots[2],
      fee: inspectionFee,
      createdAt: _ago(12),
      refunded: true,
    ),
    InspectionRequest(
      id: 'IR-20240',
      property: mockProperties[3],
      isMine: true,
      status: InspectionStatus.expired,
      dayLabel: 'أمس',
      slot: inspectionSlots[1],
      fee: inspectionFee,
      createdAt: _ago(40),
      refunded: true,
    ),
    // ---- طلبات واردة (منظور مكتب/مطور) ----
    InspectionRequest(
      id: 'IR-30121',
      property: mockProperties[0],
      isMine: false,
      status: InspectionStatus.pending,
      dayLabel: 'بكرة',
      slot: inspectionSlots[1],
      fee: inspectionFee,
      createdAt: _ago(2),
      buyerName: 'محمد إبراهيم',
      buyerPhone: '010••••4521',
    ),
    InspectionRequest(
      id: 'IR-30119',
      property: mockProperties[1],
      isMine: false,
      status: InspectionStatus.pending,
      dayLabel: 'اليوم',
      slot: inspectionSlots[2],
      fee: inspectionFee,
      createdAt: _ago(20),
      buyerName: 'منى خالد',
      buyerPhone: '011••••8830',
    ),
    InspectionRequest(
      id: 'IR-30102',
      property: mockProperties[8],
      isMine: false,
      status: InspectionStatus.confirmed,
      dayLabel: 'الخميس',
      slot: inspectionSlots[0],
      fee: inspectionFee,
      createdAt: _ago(30),
      buyerName: 'كريم عادل',
      buyerPhone: '012••••1175',
    ),
    InspectionRequest(
      id: 'IR-30090',
      property: mockProperties[2],
      isMine: false,
      status: InspectionStatus.rescheduled,
      dayLabel: 'السبت',
      slot: inspectionSlots[1],
      fee: inspectionFee,
      createdAt: _ago(8),
      buyerName: 'هدى سمير',
      buyerPhone: '015••••3302',
    ),
  ];

  List<InspectionRequest> get items => List.unmodifiable(_items);

  @visibleForTesting
  void addForTest(InspectionRequest r) => _items.add(r);

  void _set(
    InspectionRequest r,
    InspectionStatus status, {
    String? day,
    String? slot,
    bool? refunded,
  }) {
    r.status = status;
    if (day != null) r.dayLabel = day;
    if (slot != null) r.slot = slot;
    if (refunded != null) r.refunded = refunded;
    notifyListeners();
  }

  /// بيتنادى عليها بعد نجاح الدفع من الـ Pop-up.
  void addMine({
    required Property property,
    required String dayLabel,
    required String slot,
    required String id,
  }) {
    _items.insert(
      0,
      InspectionRequest(
        id: id,
        property: property,
        isMine: true,
        status: InspectionStatus.pending,
        dayLabel: dayLabel,
        slot: slot,
        fee: inspectionFee,
        createdAt: DateTime.now(),
      ),
    );
    notifyListeners();
  }

  // ---- إجراءات المعلن ----
  void accept(InspectionRequest r) => _set(r, InspectionStatus.confirmed);

  void propose(InspectionRequest r, String day, String slot) =>
      _set(r, InspectionStatus.rescheduled, day: day, slot: slot);

  /// رفض المعلن => استرداد كامل.
  void reject(InspectionRequest r) =>
      _set(r, InspectionStatus.rejected, refunded: true);

  // ---- إجراءات المشتري ----
  void buyerAcceptAlternative(InspectionRequest r) =>
      _set(r, InspectionStatus.confirmed);

  void buyerDeclineAlternative(InspectionRequest r) => _set(
      r, InspectionStatus.cancelled,
      refunded: refundWhenBuyerDeclinesAlternative);

  /// إلغاء بعد تأكيد الموعد => الرسوم غير قابلة للاسترداد.
  void buyerCancelConfirmed(InspectionRequest r) =>
      _set(r, InspectionStatus.cancelled, refunded: false);

  /// الطلبات اللي المعلن ماردّش عليها في المهلة => إلغاء + استرداد كامل.
  void expireOverdue() {
    var changed = false;
    for (final r in _items) {
      if (r.status == InspectionStatus.pending && r.remaining.isNegative) {
        r.status = InspectionStatus.expired;
        r.refunded = true;
        changed = true;
      }
    }
    if (changed) notifyListeners();
  }
}
