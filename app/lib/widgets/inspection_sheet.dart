import 'package:flutter/material.dart';
import '../data/app_config.dart';
import '../data/inspection_store.dart';
import '../models/property.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import 'property_image.dart';

enum _Step { form, paying, done }

/// Pop-up تأكيد طلب المعاينة المدفوعة.
class InspectionSheet extends StatefulWidget {
  final Property property;
  final VoidCallback onSuccess;

  const InspectionSheet({
    super.key,
    required this.property,
    required this.onSuccess,
  });

  @override
  State<InspectionSheet> createState() => _InspectionSheetState();
}

class _InspectionSheetState extends State<InspectionSheet> {
  static const _dayNames = ['اليوم', 'بكرة', 'بعد بكرة'];

  _Step _step = _Step.form;
  int _day = 0;
  int _slot = 0;
  bool _agreed = false;
  late final List<DateTime> _days;
  late final String _ref;

  String get _fee => formatNumber(inspectionFee);

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _days = List.generate(3, (i) => now.add(Duration(days: i)));
    _ref = 'INS-${now.millisecondsSinceEpoch % 90000 + 10000}';
  }

  Future<void> _pay() async {
    setState(() => _step = _Step.paying);
    // TODO (Phase 3): استبدلها باستدعاء بوابة الدفع الحقيقية.
    await Future.delayed(const Duration(milliseconds: 1500));
    if (!mounted) return;
    final d = _days[_day];
    InspectionStore.instance.addMine(
      property: widget.property,
      dayLabel: '${_dayNames[_day]} (${d.day}/${d.month})',
      slot: inspectionSlots[_slot],
      id: _ref,
    );
    setState(() => _step = _Step.done);
    widget.onSuccess();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints:
          BoxConstraints(maxHeight: MediaQuery.of(context).size.height * .92),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.fromLTRB(
          20, 12, 20, 16 + MediaQuery.of(context).viewPadding.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 42,
            height: 4,
            decoration: BoxDecoration(
              color: AppTheme.muted(context).withOpacity(.4),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(height: 16),
          Flexible(
            child: SingleChildScrollView(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                child: _step == _Step.done ? _done(context) : _form(context),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------- Form ----------------

  Widget _form(BuildContext context) {
    final p = widget.property;
    final paying = _step == _Step.paying;
    final deal = p.isRent ? 'التعاقد' : 'الشراء';
    final base = p.isRent ? 'قيمة التعاقد' : 'إجمالي سعر العقار';

    return IgnorePointer(
      ignoring: paying,
      child: Column(
        key: const ValueKey('form'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.amber,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.event_available_rounded,
                    color: AppColors.black),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('تأكيد طلب المعاينة',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.w900)),
                    Text('رسوم المعاينة عربون يثبت جدية طلبك',
                        style: TextStyle(
                            color: AppTheme.muted(context), fontSize: 12.5)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // العقار
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.outline(context)),
            ),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child:
                      PropertyImage(url: p.imageUrl, width: 56, height: 56),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(p.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 14)),
                      Text('${p.district} • ${p.type}',
                          style: TextStyle(
                              color: AppTheme.muted(context), fontSize: 12)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // الرسوم
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: AppColors.amber.withOpacity(.12),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.amber.withOpacity(.5)),
            ),
            child: Row(
              children: [
                const Expanded(
                  child: Text('رسوم المعاينة',
                      style: TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 15)),
                ),
                Text('$_fee ج.م',
                    style: TextStyle(
                        color: AppTheme.accentText(context),
                        fontWeight: FontWeight.w900,
                        fontSize: 20)),
              ],
            ),
          ),

          const SizedBox(height: 18),
          const Text('الرسوم بتتعامل إزاي؟',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
          const SizedBox(height: 10),
          _InfoRow(
            icon: Icons.check_circle_rounded,
            color: AppColors.success,
            title: 'خصم كامل عند الإتمام',
            text:
                'رسوم المعاينة ($_fee ج.م) تُخصم بالكامل من $base عند إتمام عملية $deal.',
          ),
          const SizedBox(height: 10),
          _InfoRow(
            icon: Icons.undo_rounded,
            color: AppColors.success,
            title: 'استرداد كامل',
            text:
                'لو المعلن رفض الطلب أو ماردّش خلال $inspectionResponseHours ساعة، '
                'بنرد لك $_fee ج.م بالكامل تلقائياً لحسابك/محفظتك.',
          ),
          const SizedBox(height: 10),
          _InfoRow(
            icon: Icons.info_rounded,
            color: AppTheme.muted(context),
            title: 'بعد تأكيد الموعد',
            text:
                'لو ألغيت المعاينة أو الصفقة ماتمّتش، الرسوم مقابل تنظيم وتأكيد المعاينة وغير قابلة للاسترداد.',
          ),

          const SizedBox(height: 18),
          const Text('الموعد المفضّل',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (var i = 0; i < _days.length; i++)
                _Choice(
                  label: '${_dayNames[i]} (${_days[i].day}/${_days[i].month})',
                  selected: _day == i,
                  onTap: () => setState(() => _day = i),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (var i = 0; i < inspectionSlots.length; i++)
                _Choice(
                  label: inspectionSlots[i],
                  selected: _slot == i,
                  onTap: () => setState(() => _slot = i),
                ),
            ],
          ),

          const SizedBox(height: 14),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => setState(() => _agreed = !_agreed),
            child: Row(
              children: [
                Checkbox(
                  value: _agreed,
                  activeColor: AppColors.amber,
                  checkColor: AppColors.black,
                  onChanged: (v) => setState(() => _agreed = v ?? false),
                ),
                const Expanded(
                  child: Text('فهمت وأوافق على شروط رسوم المعاينة',
                      style: TextStyle(fontSize: 13.5)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          ElevatedButton(
            onPressed: _agreed && !paying ? _pay : null,
            child: paying
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                        strokeWidth: 2.5, color: AppColors.black),
                  )
                : Text('تأكيد الدفع وطلب المعاينة - $_fee ج.م'),
          ),
          const SizedBox(height: 6),
          Center(
            child: TextButton(
              onPressed: paying ? null : () => Navigator.pop(context),
              child: Text('إلغاء',
                  style: TextStyle(color: AppTheme.muted(context))),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------- Success ----------------

  Widget _done(BuildContext context) {
    return Column(
      key: const ValueKey('done'),
      children: [
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.success.withOpacity(.15),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.check_rounded,
              size: 44, color: AppColors.success),
        ),
        const SizedBox(height: 16),
        const Text('تم استلام طلب المعاينة',
            style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900)),
        const SizedBox(height: 6),
        Text('هيتواصل معاك صاحب العقار لتأكيد الموعد قريباً.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppTheme.muted(context))),
        const SizedBox(height: 18),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.outline(context)),
          ),
          child: Column(
            children: [
              _kv(context, 'رقم الطلب', _ref),
              const SizedBox(height: 8),
              _kv(context, 'الموعد', '${_dayNames[_day]} • ${inspectionSlots[_slot]}'),
              const SizedBox(height: 8),
              _kv(context, 'الرسوم المدفوعة', '$_fee ج.م'),
            ],
          ),
        ),
        const SizedBox(height: 18),
        ElevatedButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('تمام'),
        ),
      ],
    );
  }

  Widget _kv(BuildContext context, String k, String v) => Row(
        children: [
          Text(k,
              style: TextStyle(color: AppTheme.muted(context), fontSize: 13)),
          const Spacer(),
          Text(v,
              style:
                  const TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5)),
        ],
      );
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String text;

  const _InfoRow({
    required this.icon,
    required this.color,
    required this.title,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: color, size: 22),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: const TextStyle(
                      fontWeight: FontWeight.w800, fontSize: 13.5)),
              const SizedBox(height: 2),
              Text(text,
                  style: TextStyle(
                      color: AppTheme.muted(context),
                      fontSize: 12.5,
                      height: 1.5)),
            ],
          ),
        ),
      ],
    );
  }
}

class _Choice extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _Choice({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: selected ? AppColors.amber : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: selected ? AppColors.amber : AppTheme.outline(context)),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: selected ? AppColors.black : null)),
      ),
    );
  }
}
