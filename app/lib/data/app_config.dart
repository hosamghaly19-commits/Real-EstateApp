/// رسوم المعاينة (ج.م). غيّرها من هنا فقط وهتتحدث في كل التطبيق.
const int inspectionFee = 100;

/// فترات المعاينة المتاحة (مشتركة بين الـ Pop-up وشاشة الطلبات).
const inspectionSlots = ['صباحاً 10–12', 'ظهراً 1–3', 'مساءً 5–8'];

/// أيام المعاينة القادمة بصيغة: "بكرة (19/10)".
List<String> upcomingDayLabels() {
  const names = ['اليوم', 'بكرة', 'بعد بكرة'];
  final now = DateTime.now();
  return List.generate(3, (i) {
    final d = now.add(Duration(days: i));
    return '${names[i]} (${d.day}/${d.month})';
  });
}

/// مهلة رد المعلن على طلب المعاينة (بالساعات). لو عدّت من غير رد:
/// الطلب بيتلغي والرسوم بتتردّ للمشتري بالكامل تلقائياً.
/// TODO: 24 ساعة قيمة افتراضية مني — محتاجة تأكيدك.
const int inspectionResponseHours = 24;

/// لو المشتري رفض الموعد البديل اللي اقترحه المعلن، هل الرسوم بتتردّ؟
/// TODO: السياسة دي ماتحسمتش — افترضت "نعم". غيّرها لـ false لو مش عايزها.
const bool refundWhenBuyerDeclinesAlternative = true;
