import '../data/repositories/property_repository.dart';
import '../data/api/api_client.dart';
import '../core/env.dart';
import 'package:flutter/material.dart';
import '../data/account_store.dart';
import '../data/inspection_store.dart';
import '../data/mock_data.dart';
import '../data/property_store.dart';
import '../models/account.dart';
import '../models/inspection_request.dart';
import '../models/property.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';
import '../widgets/property_image.dart';
import 'add_property_screen.dart';
import 'inspection_requests_screen.dart';
import 'property_details_screen.dart';

/// مشاهدات تجريبية ثابتة لكل إعلان.
/// TODO (Phase 2): أرقام حقيقية من الـ API.
int mockViews(Property p) =>
    40 + (p.id.codeUnits.fold<int>(0, (a, b) => a + b) * 7) % 460;

/// المشاهدات: حقيقية من الـ API، وتجريبية في الوضع التجريبي.
int viewsOf(Property p) => useApi ? p.viewsCount : mockViews(p);

class AccountDashboardScreen extends StatefulWidget {
  const AccountDashboardScreen({super.key});

  @override
  State<AccountDashboardScreen> createState() =>
      _AccountDashboardScreenState();
}

class _AccountDashboardScreenState extends State<AccountDashboardScreen> {
  final _accounts = AccountStore.instance;
  final _inspections = InspectionStore.instance;
  final _properties = PropertyStore.instance;

  List<Property> _mine = const [];
  bool _loadingMine = true;
  String? _mineError;
  int _mineSeq = 0;

  @override
  void initState() {
    super.initState();
    _accounts.addListener(_loadMine); // تبديل الحساب ⇒ إعلانات حساب تاني
    _properties.addListener(_loadMine); // الوضع التجريبي: إضافة عقار
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _inspections.expireOverdue();
    });
    _loadMine();
  }

  @override
  void dispose() {
    _accounts.removeListener(_loadMine);
    _properties.removeListener(_loadMine);
    super.dispose();
  }

  Future<void> _loadMine() async {
    final seq = ++_mineSeq;
    try {
      final r = await propertyRepo.mine();
      if (!mounted || seq != _mineSeq) return;
      setState(() {
        _mine = r;
        _loadingMine = false;
        _mineError = null;
      });
    } on ApiException catch (e) {
      if (!mounted || seq != _mineSeq) return;
      setState(() {
        _mineError = e.message;
        _loadingMine = false;
      });
    } catch (_) {
      if (!mounted || seq != _mineSeq) return;
      setState(() {
        _mineError = 'حصل خطأ غير متوقع';
        _loadingMine = false;
      });
    }
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(msg)));
  }

  void _openRequests() => Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => const InspectionRequestsScreen(startAsOffice: true),
      ));

  void _openProperty(Property p) => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => PropertyDetailsScreen(property: p)),
      );

  Future<void> _addProperty() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const AddPropertyScreen()),
    );
    if (mounted) _loadMine();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('حسابي')),
      body: ListenableBuilder(
        listenable: Listenable.merge([_accounts, _inspections, _properties]),
        builder: (context, _) {
          final acc = _accounts.current;
          final mine = _mine;
          final incoming = _inspections.items
              .where((r) => !r.isMine && acc.owns(r.property))
              .toList();
          final pending = incoming
              .where((r) => r.status == InspectionStatus.pending)
              .toList();
          final confirmed = incoming
              .where((r) => r.status == InspectionStatus.confirmed)
              .length;
          final views = mine.fold<int>(0, (a, p) => a + viewsOf(p));

          return ListView(
            padding: const EdgeInsets.only(bottom: 32),
            children: [
              _header(context, acc),
              _accountSwitch(context),
              _kpis(context, mine.length, pending.length, confirmed, views),
              SectionHeader(
                title: 'طلبات تنتظر ردك',
                action: 'عرض الكل',
                onAction: _openRequests,
              ),
              _pendingSection(context, pending),
              SectionHeader(
                title: 'إعلاناتي (${mine.length})',
                action: 'إضافة عقار',
                onAction: _addProperty,
              ),
              _mineSection(context, mine, incoming),
              if (acc.isDeveloper) ..._projects(context, acc),
              const SectionHeader(title: 'الحساب'),
              _menu(context, acc),
            ],
          );
        },
      ),
    );
  }

  // ---------------- Header ----------------

  Widget _header(BuildContext context, Account acc) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 6, 20, 0),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          gradient: const LinearGradient(
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
            colors: [AppColors.charcoalLight, AppColors.black],
          ),
          border: Border.all(color: AppColors.amber.withOpacity(.3)),
        ),
        child: Row(
          children: [
            Container(
              width: 62,
              height: 62,
              decoration: BoxDecoration(
                color: AppColors.amber,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(
                  acc.isDeveloper
                      ? Icons.domain_rounded
                      : Icons.business_rounded,
                  size: 32,
                  color: AppColors.black),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(acc.name,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.w900)),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      _pill(acc.type, AppColors.amber,
                          AppColors.amber.withOpacity(.16)),
                      if (acc.verified)
                        _pill('موثّق', AppColors.success,
                            AppColors.success.withOpacity(.18),
                            icon: Icons.verified_rounded),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text('${acc.phone} • عضو منذ ${acc.since}',
                      style: TextStyle(
                          color: Colors.white.withOpacity(.6), fontSize: 12)),
                ],
              ),
            ),
            IconButton(
              onPressed: () => _toast('تعديل البيانات قريباً'),
              icon: const Icon(Icons.edit_rounded, color: Colors.white70),
            ),
          ],
        ),
      ),
    );
  }

  Widget _pill(String text, Color fg, Color bg, {IconData? icon}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration:
          BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: fg),
            const SizedBox(width: 3),
          ],
          Text(text,
              style: TextStyle(
                  color: fg, fontSize: 11.5, fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }

  /// تبديل تجريبي بين حساب مكتب وحساب مطور.
  /// TODO: يتشال لما نبني الـ Auth (نوع الحساب بيتحدد عند التسجيل).
  Widget _accountSwitch(BuildContext context) {
    Widget seg(String label, int i) {
      final selected = _accounts.index == i;
      return Expanded(
        child: GestureDetector(
          onTap: () => _accounts.select(i),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(vertical: 9),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: selected ? AppColors.amber : Colors.transparent,
              borderRadius: BorderRadius.circular(11),
            ),
            child: Text(label,
                style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                    color:
                        selected ? AppColors.black : AppTheme.muted(context))),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppTheme.outline(context)),
        ),
        child: Row(children: [seg('عرض كمكتب', 0), seg('عرض كمطور', 1)]),
      ),
    );
  }

  // ---------------- KPIs ----------------

  Widget _kpis(BuildContext context, int listings, int pending, int confirmed,
      int views) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                  child: _Kpi('إعلانات نشطة', '$listings',
                      Icons.home_work_rounded)),
              const SizedBox(width: 10),
              Expanded(
                  child: _Kpi('بانتظار ردك', '$pending',
                      Icons.notifications_active_rounded,
                      highlight: pending > 0)),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                  child: _Kpi('معاينات مؤكدة', '$confirmed',
                      Icons.event_available_rounded)),
              const SizedBox(width: 10),
              Expanded(
                  child: _Kpi('المشاهدات', formatNumber(views),
                      Icons.visibility_rounded)),
            ],
          ),
        ],
      ),
    );
  }

  // ---------------- Pending requests ----------------

  Widget _pendingSection(BuildContext context, List<InspectionRequest> list) {
    if (list.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.outline(context)),
          ),
          child: Row(
            children: [
              const Icon(Icons.done_all_rounded,
                  color: AppColors.success, size: 22),
              const SizedBox(width: 10),
              Text('مفيش طلبات معلّقة دلوقتي',
                  style: TextStyle(color: AppTheme.muted(context))),
            ],
          ),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          for (final r in list.take(3)) _pendingRow(context, r),
        ],
      ),
    );
  }

  Widget _pendingRow(BuildContext context, InspectionRequest r) {
    final p = r.property;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.amber.withOpacity(.4)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: PropertyImage(url: p.imageUrl, width: 52, height: 52),
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
                            fontWeight: FontWeight.w800, fontSize: 13.5)),
                    Text('${r.buyerName} • ${r.dayLabel} • ${r.slot}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            color: AppTheme.muted(context), fontSize: 12)),
                    Text('باقي ${r.remainingLabel} للرد',
                        style: TextStyle(
                            color: AppTheme.accentText(context),
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                      minimumSize: const Size.fromHeight(40)),
                  onPressed: () {
                    _inspections.accept(r);
                    _toast('تم قبول الطلب وإخطار المشتري');
                  },
                  child: const Text('قبول', style: TextStyle(fontSize: 13.5)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(40)),
                  onPressed: _openRequests,
                  child: const Text('موعد آخر / رفض',
                      style: TextStyle(fontSize: 13.5)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ---------------- Listings ----------------

  /// حالات تحميل/خطأ إعلاناتي، وبعدها القايمة.
  Widget _mineSection(BuildContext context, List<Property> mine,
      List<InspectionRequest> incoming) {
    if (_mineError != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          children: [
            Text(_mineError!,
                textAlign: TextAlign.center,
                style: TextStyle(color: AppTheme.muted(context))),
            const SizedBox(height: 10),
            OutlinedButton(
              style: OutlinedButton.styleFrom(minimumSize: const Size(160, 46)),
              onPressed: _loadMine,
              child: const Text('إعادة المحاولة'),
            ),
          ],
        ),
      );
    }
    if (_loadingMine) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 28),
        child: Center(
          child: SizedBox(
            width: 28,
            height: 28,
            child: CircularProgressIndicator(strokeWidth: 3, color: AppColors.amber),
          ),
        ),
      );
    }
    return _listings(context, mine, incoming);
  }

  Widget _listings(BuildContext context, List<Property> mine,
      List<InspectionRequest> incoming) {
    if (mine.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.outline(context)),
          ),
          child: Column(
            children: [
              Icon(Icons.add_home_work_rounded,
                  size: 40, color: AppColors.amber.withOpacity(.8)),
              const SizedBox(height: 8),
              const Text('لسه ماضفتش إعلانات',
                  style: TextStyle(fontWeight: FontWeight.w800)),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: _addProperty,
                child: const Text('إضافة أول عقار'),
              ),
            ],
          ),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          for (final p in mine)
            _listingRow(
              context,
              p,
              incoming.where((r) => r.property.id == p.id).length,
            ),
        ],
      ),
    );
  }

  Widget _listingRow(BuildContext context, Property p, int requests) {
    Widget stat(IconData i, String t) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(i, size: 14, color: AppTheme.muted(context)),
            const SizedBox(width: 3),
            Text(t,
                style:
                    TextStyle(color: AppTheme.muted(context), fontSize: 12)),
          ],
        );

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.outline(context)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _openProperty(p),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: PropertyImage(url: p.imageUrl, width: 74, height: 74),
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
                              fontWeight: FontWeight.w800, fontSize: 13.5)),
                      Text(p.priceLabel,
                          style: TextStyle(
                              color: AppTheme.accentText(context),
                              fontWeight: FontWeight.w900,
                              fontSize: 14)),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 12,
                        children: [
                          stat(Icons.visibility_outlined,
                              formatNumber(viewsOf(p))),
                          stat(Icons.event_note_rounded, '$requests طلب'),
                        ],
                      ),
                    ],
                  ),
                ),
                _pill('نشط', AppColors.success,
                    AppColors.success.withOpacity(.15)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ---------------- Developer projects ----------------

  List<Widget> _projects(BuildContext context, Account acc) {
    final list = mockDevelopers.where((d) => d.developer == acc.name).toList();
    return [
      const SectionHeader(title: 'مشاريعي'),
      SizedBox(
        height: 140,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          itemCount: list.length,
          itemBuilder: (_, i) => DeveloperCard(dev: list[i]),
        ),
      ),
    ];
  }

  // ---------------- Profile menu ----------------

  Widget _menu(BuildContext context, Account acc) {
    final items = <(IconData, String, String?, bool)>[
      (Icons.verified_user_outlined, 'توثيق الحساب',
          acc.verified ? 'موثّق' : 'غير موثّق', false),
      (Icons.account_balance_wallet_outlined, 'المحفظة والمدفوعات', null, false),
      (Icons.support_agent_rounded, 'الدعم والمساعدة', null, false),
      (Icons.logout_rounded, 'تسجيل الخروج', null, true),
    ];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppTheme.outline(context)),
        ),
        child: Column(
          children: [
            for (var i = 0; i < items.length; i++) ...[
              if (i > 0) Divider(height: 1, color: AppTheme.outline(context)),
              ListTile(
                onTap: () => _toast('قريباً'),
                leading: Icon(items[i].$1,
                    color: items[i].$4
                        ? InspectionStatus.rejected.color
                        : AppTheme.accentText(context)),
                title: Text(items[i].$2,
                    style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: items[i].$4
                            ? InspectionStatus.rejected.color
                            : null)),
                trailing: items[i].$3 != null
                    ? Text(items[i].$3!,
                        style: TextStyle(
                            color: acc.verified
                                ? AppColors.success
                                : AppTheme.muted(context),
                            fontWeight: FontWeight.w800,
                            fontSize: 12.5))
                    : Icon(Icons.chevron_left_rounded,
                        color: AppTheme.muted(context)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Kpi extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final bool highlight;

  const _Kpi(this.label, this.value, this.icon, {this.highlight = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: highlight
            ? AppColors.amber.withOpacity(.12)
            : Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
            color: highlight
                ? AppColors.amber.withOpacity(.55)
                : AppTheme.outline(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 22, color: AppTheme.accentText(context)),
          const SizedBox(height: 8),
          Text(value,
              style:
                  const TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
          Text(label,
              style: TextStyle(color: AppTheme.muted(context), fontSize: 12)),
        ],
      ),
    );
  }
}
