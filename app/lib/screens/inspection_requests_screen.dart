import 'dart:async';
import 'package:flutter/material.dart';
import '../data/account_store.dart';
import '../data/app_config.dart';
import '../data/inspection_store.dart';
import '../models/inspection_request.dart';
import '../models/property.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../widgets/property_image.dart';
import 'property_details_screen.dart';

class InspectionRequestsScreen extends StatefulWidget {
  final bool startAsOffice;
  const InspectionRequestsScreen({super.key, this.startAsOffice = false});

  @override
  State<InspectionRequestsScreen> createState() =>
      _InspectionRequestsScreenState();
}

class _InspectionRequestsScreenState extends State<InspectionRequestsScreen> {
  final _store = InspectionStore.instance;

  // تبديل تجريبي بين منظور المشتري والمكتب/المطور.
  // TODO: يتحدد تلقائياً حسب نوع الحساب بعد ما نبني الـ Auth.
  bool _asOffice = false;
  InspectionStatus? _filter;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _asOffice = widget.startAsOffice;
    _store.expireOverdue();
    _timer = Timer.periodic(
        const Duration(minutes: 1), (_) => _store.expireOverdue());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(msg)));
  }

  void _openProperty(Property p) => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => PropertyDetailsScreen(property: p)),
      );

  void _contact() =>
      _toast('التواصل (اتصال / رسائل) هيتفعّل مع ربط الـ Backend');

  Future<void> _propose(InspectionRequest r) async {
    final res = await showModalBottomSheet<(String, String)>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ProposeSheet(request: r),
    );
    if (res != null) {
      _store.propose(r, res.$1, res.$2);
      _toast('تم إرسال الموعد المقترح للمشتري');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('طلبات المعاينة')),
      body: ListenableBuilder(
        listenable: Listenable.merge([_store, AccountStore.instance]),
        builder: (context, _) {
          final account = AccountStore.instance.current;
          final all = _store.items
              .where((r) => r.isMine != _asOffice)
              .where((r) => !_asOffice || account.owns(r.property))
              .toList();
          final list = _filter == null
              ? all
              : all.where((r) => r.status == _filter).toList();

          return Column(
            children: [
              _roleToggle(context),
              if (_asOffice) _stats(context, all),
              _filterChips(context),
              Expanded(
                child: list.isEmpty
                    ? _empty(context)
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                        itemCount: list.length,
                        itemBuilder: (_, i) => _card(context, list[i]),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  // ---------------- Header parts ----------------

  Widget _roleToggle(BuildContext context) {
    Widget seg(String label, bool office) {
      final selected = _asOffice == office;
      return Expanded(
        child: GestureDetector(
          onTap: () => setState(() {
            _asOffice = office;
            _filter = null;
          }),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(vertical: 11),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: selected ? AppColors.amber : Colors.transparent,
              borderRadius: BorderRadius.circular(11),
            ),
            child: Text(label,
                style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 13.5,
                    color:
                        selected ? AppColors.black : AppTheme.muted(context))),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: AppTheme.outline(context)),
        ),
        child: Row(children: [
          seg('طلباتي كمشتري', false),
          seg('الطلبات الواردة', true),
        ]),
      ),
    );
  }

  Widget _stats(BuildContext context, List<InspectionRequest> all) {
    final pending =
        all.where((r) => r.status == InspectionStatus.pending).length;
    final confirmed =
        all.where((r) => r.status == InspectionStatus.confirmed).length;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
      child: Row(
        children: [
          _StatTile('الإجمالي', '${all.length}', Icons.inbox_rounded),
          const SizedBox(width: 10),
          _StatTile('جديدة', '$pending', Icons.notifications_active_rounded),
          const SizedBox(width: 10),
          _StatTile('مؤكدة', '$confirmed', Icons.event_available_rounded),
        ],
      ),
    );
  }

  Widget _filterChips(BuildContext context) {
    final options = <InspectionStatus?>[null, ...InspectionStatus.values];
    return Padding(
      padding: const EdgeInsets.only(top: 14, bottom: 8),
      child: SizedBox(
        height: 38,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          itemCount: options.length,
          separatorBuilder: (_, __) => const SizedBox(width: 8),
          itemBuilder: (_, i) {
            final o = options[i];
            final selected = _filter == o;
            return GestureDetector(
              onTap: () => setState(() => _filter = o),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                alignment: Alignment.center,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: selected ? AppColors.amber : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: selected
                          ? AppColors.amber
                          : AppTheme.outline(context)),
                ),
                child: Text(o?.label ?? 'الكل',
                    style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: selected ? AppColors.black : null)),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _empty(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.event_busy_rounded,
                size: 56, color: AppColors.amber.withOpacity(.7)),
            const SizedBox(height: 12),
            const Text('مفيش طلبات هنا',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            Text(
              _asOffice
                  ? 'هتظهر هنا طلبات المعاينة اللي بتوصلك.'
                  : 'اطلب معاينة من صفحة أي عقار وهتتابعها من هنا.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppTheme.muted(context)),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------- Card ----------------

  Widget _card(BuildContext context, InspectionRequest r) {
    final p = r.property;
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.outline(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: PropertyImage(url: p.imageUrl, width: 66, height: 66),
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
                            fontWeight: FontWeight.w800, fontSize: 14.5)),
                    Text('${p.district} • ${p.type}',
                        style: TextStyle(
                            color: AppTheme.muted(context), fontSize: 12)),
                    const SizedBox(height: 6),
                    _StatusBadge(r.status),
                  ],
                ),
              ),
            ],
          ),
          Divider(height: 26, color: AppTheme.outline(context)),
          _line(context, Icons.schedule_rounded, '${r.dayLabel} • ${r.slot}',
              bold: true),
          if (_asOffice)
            _line(context, Icons.person_outline_rounded,
                '${r.buyerName} • ${r.buyerPhone}'),
          if (r.refunded)
            _line(context, Icons.undo_rounded,
                'رسوم المعاينة: ${formatNumber(r.fee)} ج.م (تم ردّها بالكامل)')
          else
            _line(context, Icons.verified_rounded,
                'رسوم المعاينة مدفوعة: ${formatNumber(r.fee)} ج.م'),
          _line(context, Icons.tag_rounded, 'رقم الطلب: ${r.id}', muted: true),
          const SizedBox(height: 12),
          _asOffice ? _officeActions(context, r) : _buyerActions(context, r),
        ],
      ),
    );
  }

  Widget _line(BuildContext context, IconData icon, String text,
      {bool bold = false, bool muted = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Icon(icon,
              size: 17,
              color: muted
                  ? AppTheme.muted(context)
                  : AppTheme.accentText(context)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text,
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: bold ? FontWeight.w800 : FontWeight.w500,
                    color: muted ? AppTheme.muted(context) : null)),
          ),
        ],
      ),
    );
  }

  // ---------------- Actions ----------------

  String _remaining(InspectionRequest r) {
    final d = r.remaining;
    if (d.isNegative) return 'لحظات';
    if (d.inHours >= 1) return '${d.inHours} ساعة';
    return '${d.inMinutes < 1 ? 1 : d.inMinutes} دقيقة';
  }

  /// صندوق أخضر لرسائل الاسترداد (بيطمّن المشتري).
  Widget _refundNote(BuildContext context, String text) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.success.withOpacity(.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.success.withOpacity(.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.undo_rounded, size: 18, color: AppColors.success),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text, style: const TextStyle(fontSize: 12.5, height: 1.5)),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmCancel(InspectionRequest r) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('إلغاء المعاينة؟'),
        content: Text(
            'بعد تأكيد الموعد، رسوم المعاينة (${formatNumber(r.fee)} ج.م) '
            'غير قابلة للاسترداد لو ألغيت.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('رجوع'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('إلغاء المعاينة',
                style: TextStyle(color: InspectionStatus.rejected.color)),
          ),
        ],
      ),
    );
    if (ok == true) {
      _store.buyerCancelConfirmed(r);
      _toast('تم إلغاء المعاينة');
    }
  }

  Widget _buyerActions(BuildContext context, InspectionRequest r) {
    final fee = formatNumber(r.fee);
    switch (r.status) {
      case InspectionStatus.pending:
        return _refundNote(
          context,
          'بانتظار رد المعلن. لو رفض أو ماردّش خلال ${_remaining(r)}، '
          'هيترجعلك رسوم المعاينة ($fee ج.م) كاملة تلقائياً.',
        );
      case InspectionStatus.confirmed:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _note(context, Icons.info_outline_rounded,
                'الموعد مؤكد. لو ألغيت بعد التأكيد، رسوم المعاينة غير قابلة للاسترداد.'),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                    child: _btn('تواصل مع المعلن', _contact,
                        icon: Icons.chat_rounded)),
                const SizedBox(width: 10),
                Expanded(
                    child: _btn('عرض العقار', () => _openProperty(r.property),
                        filled: false)),
              ],
            ),
            Center(
              child: TextButton(
                onPressed: () => _confirmCancel(r),
                child: Text('إلغاء المعاينة',
                    style: TextStyle(
                        color: InspectionStatus.rejected.color, fontSize: 13)),
              ),
            ),
          ],
        );
      case InspectionStatus.rescheduled:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _note(context, Icons.update_rounded,
                'المعلن اقترح الموعد الموضح أعلاه. توافق عليه؟'),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _btn('قبول الموعد', () {
                    _store.buyerAcceptAlternative(r);
                    _toast('تم تأكيد الموعد');
                  }),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _btn('رفض الموعد', () {
                    _store.buyerDeclineAlternative(r);
                    _toast(refundWhenBuyerDeclinesAlternative
                        ? 'تم إلغاء الطلب ورد رسومك بالكامل'
                        : 'تم إلغاء الطلب');
                  }, filled: false),
                ),
              ],
            ),
          ],
        );
      case InspectionStatus.rejected:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _refundNote(
                context,
                'المعلن رفض الطلب. تم رد رسوم المعاينة ($fee ج.م) '
                'بالكامل إلى حسابك/محفظتك.'),
            const SizedBox(height: 10),
            _btn('عرض العقار', () => _openProperty(r.property), filled: false),
          ],
        );
      case InspectionStatus.expired:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _refundNote(
                context,
                'انتهت المهلة دون رد من المعلن. تم رد رسوم المعاينة ($fee ج.م) '
                'بالكامل إلى حسابك/محفظتك.'),
            const SizedBox(height: 10),
            _btn('عرض العقار', () => _openProperty(r.property), filled: false),
          ],
        );
      case InspectionStatus.cancelled:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (r.refunded)
              _refundNote(
                  context,
                  'تم إلغاء الطلب، ورد رسوم المعاينة ($fee ج.م) '
                  'بالكامل إلى حسابك/محفظتك.')
            else
              _note(context, Icons.info_outline_rounded,
                  'تم إلغاء المعاينة بعد التأكيد، والرسوم غير قابلة للاسترداد.'),
            const SizedBox(height: 10),
            _btn('عرض العقار', () => _openProperty(r.property), filled: false),
          ],
        );
    }
  }

  Widget _officeActions(BuildContext context, InspectionRequest r) {
    switch (r.status) {
      case InspectionStatus.pending:
        return Column(
          children: [
            _note(context, Icons.timer_outlined,
                'لازم ترد خلال ${_remaining(r)}، وإلا هيتلغي الطلب وتترد رسوم المشتري تلقائياً.'),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _btn('قبول', () {
                    _store.accept(r);
                    _toast('تم قبول الطلب وإخطار المشتري');
                  }, icon: Icons.check_rounded),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _btn('موعد آخر', () => _propose(r),
                      filled: false, icon: Icons.edit_calendar_rounded),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  width: 44,
                  height: 44,
                  child: OutlinedButton(
                    onPressed: _contact,
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(44, 44),
                      padding: EdgeInsets.zero,
                    ),
                    child: const Icon(Icons.call_rounded, size: 20),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            TextButton(
              onPressed: () {
                _store.reject(r);
                _toast('تم رفض الطلب ورد رسوم المشتري بالكامل');
              },
              child: Text('رفض الطلب',
                  style: TextStyle(
                      color: InspectionStatus.rejected.color, fontSize: 13)),
            ),
          ],
        );
      case InspectionStatus.confirmed:
        return Row(
          children: [
            Expanded(
                child: _btn('تواصل مع المشتري', _contact,
                    icon: Icons.chat_rounded)),
            const SizedBox(width: 10),
            Expanded(
                child: _btn('تغيير الموعد', () => _propose(r), filled: false)),
          ],
        );
      case InspectionStatus.rescheduled:
        return _note(context, Icons.hourglass_top_rounded,
            'بانتظار موافقة المشتري على الموعد المقترح.');
      case InspectionStatus.rejected:
        return _note(context, Icons.info_outline_rounded,
            'تم رفض هذا الطلب ورد رسوم المشتري بالكامل.');
      case InspectionStatus.expired:
        return _note(context, Icons.timer_off_rounded,
            'انتهت مهلة الرد، فتم إلغاء الطلب ورد رسوم المشتري تلقائياً.');
      case InspectionStatus.cancelled:
        return _note(
            context, Icons.event_busy_rounded, 'المشتري ألغى هذا الطلب.');
    }
  }

  Widget _note(BuildContext context, IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.muted(context).withOpacity(.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppTheme.muted(context)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text,
                style: TextStyle(
                    fontSize: 12.5, color: AppTheme.muted(context))),
          ),
        ],
      ),
    );
  }

  Widget _btn(String text, VoidCallback onTap,
      {bool filled = true, IconData? icon}) {
    final label = Text(text, style: const TextStyle(fontSize: 13.5));
    if (filled) {
      final style =
          ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(44));
      return icon == null
          ? ElevatedButton(onPressed: onTap, style: style, child: label)
          : ElevatedButton.icon(
              onPressed: onTap, style: style, icon: Icon(icon, size: 18), label: label);
    }
    final style =
        OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(44));
    return icon == null
        ? OutlinedButton(onPressed: onTap, style: style, child: label)
        : OutlinedButton.icon(
            onPressed: onTap, style: style, icon: Icon(icon, size: 18), label: label);
  }
}

class _StatusBadge extends StatelessWidget {
  final InspectionStatus status;
  const _StatusBadge(this.status);

  @override
  Widget build(BuildContext context) {
    final fg = status == InspectionStatus.pending
        ? AppTheme.accentText(context)
        : status.color;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: status.color.withOpacity(.16),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(status.icon, size: 13, color: fg),
          const SizedBox(width: 4),
          Text(status.label,
              style: TextStyle(
                  color: fg, fontSize: 11.5, fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  const _StatTile(this.label, this.value, this.icon);

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.outline(context)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 20, color: AppTheme.accentText(context)),
            const SizedBox(height: 6),
            Text(value,
                style: const TextStyle(
                    fontSize: 20, fontWeight: FontWeight.w900)),
            Text(label,
                style:
                    TextStyle(color: AppTheme.muted(context), fontSize: 11.5)),
          ],
        ),
      ),
    );
  }
}

/// Pop-up اقتراح موعد بديل (للمكتب/المطور).
class _ProposeSheet extends StatefulWidget {
  final InspectionRequest request;
  const _ProposeSheet({required this.request});

  @override
  State<_ProposeSheet> createState() => _ProposeSheetState();
}

class _ProposeSheetState extends State<_ProposeSheet> {
  final _days = upcomingDayLabels();
  int _day = 0;
  int _slot = 0;

  Widget _choice(String label, bool selected, VoidCallback onTap) {
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

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.fromLTRB(
          20, 12, 20, 20 + MediaQuery.of(context).viewPadding.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 42,
              height: 4,
              decoration: BoxDecoration(
                color: AppTheme.muted(context).withOpacity(.4),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text('اقتراح موعد بديل',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
          const SizedBox(height: 4),
          Text('الموعد الحالي: ${widget.request.dayLabel} • ${widget.request.slot}',
              style: TextStyle(color: AppTheme.muted(context), fontSize: 12.5)),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (var i = 0; i < _days.length; i++)
                _choice(_days[i], _day == i, () => setState(() => _day = i)),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (var i = 0; i < inspectionSlots.length; i++)
                _choice(inspectionSlots[i], _slot == i,
                    () => setState(() => _slot = i)),
            ],
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: () =>
                Navigator.pop(context, (_days[_day], inspectionSlots[_slot])),
            child: const Text('إرسال الموعد المقترح'),
          ),
        ],
      ),
    );
  }
}
