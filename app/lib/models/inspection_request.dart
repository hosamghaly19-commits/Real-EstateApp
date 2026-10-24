import 'package:flutter/material.dart';
import '../data/app_config.dart';
import '../theme/app_colors.dart';
import 'property.dart';

enum InspectionStatus {
  pending,
  confirmed,
  rescheduled,
  rejected,
  expired,
  cancelled,
}

extension InspectionStatusX on InspectionStatus {
  String get label => switch (this) {
        InspectionStatus.pending => 'قيد الانتظار',
        InspectionStatus.confirmed => 'تم التأكيد',
        InspectionStatus.rescheduled => 'موعد بديل مقترح',
        InspectionStatus.rejected => 'مرفوض',
        InspectionStatus.expired => 'انتهت المهلة',
        InspectionStatus.cancelled => 'أُلغيت',
      };

  Color get color => switch (this) {
        InspectionStatus.pending => AppColors.amber,
        InspectionStatus.confirmed => AppColors.success,
        InspectionStatus.rescheduled => const Color(0xFF42A5F5),
        InspectionStatus.rejected => const Color(0xFFE57373),
        InspectionStatus.expired => const Color(0xFF9E9E9E),
        InspectionStatus.cancelled => const Color(0xFF9E9E9E),
      };

  IconData get icon => switch (this) {
        InspectionStatus.pending => Icons.hourglass_top_rounded,
        InspectionStatus.confirmed => Icons.check_circle_rounded,
        InspectionStatus.rescheduled => Icons.update_rounded,
        InspectionStatus.rejected => Icons.cancel_rounded,
        InspectionStatus.expired => Icons.timer_off_rounded,
        InspectionStatus.cancelled => Icons.event_busy_rounded,
      };
}

class InspectionRequest {
  final String id;
  final Property property;

  /// true = طلبي كمشتري، false = طلب وارد على عقار معلن عندي (مكتب/مطور).
  final bool isMine;
  final String buyerName;
  final String buyerPhone;
  final int fee;
  final DateTime createdAt;

  InspectionStatus status;
  String dayLabel;
  String slot;

  /// هل رسوم المعاينة اتردّت للمشتري؟
  bool refunded;

  InspectionRequest({
    required this.id,
    required this.property,
    required this.isMine,
    required this.status,
    required this.dayLabel,
    required this.slot,
    required this.fee,
    required this.createdAt,
    this.refunded = false,
    this.buyerName = 'أنا',
    this.buyerPhone = '',
  });

  /// الوقت المتبقي لرد المعلن قبل ما الطلب يتلغي ويتردّ الرسوم.
  Duration get remaining => createdAt
      .add(const Duration(hours: inspectionResponseHours))
      .difference(DateTime.now());

  String get remainingLabel {
    final d = remaining;
    if (d.isNegative) return 'لحظات';
    if (d.inHours >= 1) return '${d.inHours} ساعة';
    return '${d.inMinutes < 1 ? 1 : d.inMinutes} دقيقة';
  }
}
