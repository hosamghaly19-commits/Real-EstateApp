import '../data/repositories/property_repository.dart';
import '../data/district_store.dart';
import '../data/api/api_client.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import '../data/mock_data.dart';
import '../data/property_store.dart';
import '../models/property.dart';
import '../models/property_filters.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';
import '../widgets/filter_sheet.dart';
import '../widgets/promo_banners.dart';
import '../widgets/property_card.dart';
import 'account_dashboard_screen.dart';
import 'add_property_screen.dart';
import 'inspection_requests_screen.dart';
import 'property_details_screen.dart';

class _Category {
  final String label;
  final String? type; // null = الكل
  final IconData icon;
  const _Category(this.label, this.type, this.icon);
}

const _categories = [
  _Category('الكل', null, Icons.grid_view_rounded),
  _Category('شقق', 'شقة', Icons.apartment_rounded),
  _Category('فلل', 'فيلا', Icons.villa_rounded),
  _Category('محلات', 'محل', Icons.storefront_rounded),
  _Category('مكاتب', 'مكتب', Icons.business_center_rounded),
  _Category('أراضي', 'أرض', Icons.landscape_rounded),
];

class HomeScreen extends StatefulWidget {
  final VoidCallback onToggleTheme;
  const HomeScreen({super.key, required this.onToggleTheme});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String _listing = 'بيع';
  _Category _category = _categories.first;
  String _query = '';
  PropertyFilters _filters = const PropertyFilters();
  final Set<String> _favorites = {};
  final _searchCtrl = TextEditingController();

  List<Property> _results = const [];
  bool _loading = true;
  bool _firstLoadDone = false;
  String? _error;
  int _seq = 0;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    PropertyStore.instance.addListener(_onStore);
    DistrictStore.instance.load();
    _reload();
  }

  @override
  void dispose() {
    PropertyStore.instance.removeListener(_onStore);
    _debounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  /// الوضع التجريبي: أي تغيير في مخزن العقارات بيعيد التحميل.
  void _onStore() {
    if (mounted) _reload();
  }

  /// بيجيب العقارات حسب الفلاتر الحالية (من الـ API أو من البيانات التجريبية).
  Future<void> _reload() async {
    final seq = ++_seq;
    if (_firstLoadDone) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final r = await propertyRepo.search(PropertyQuery(
        listing: _listing,
        type: _category.type,
        query: _query,
        filters: _filters,
      ));
      if (!mounted || seq != _seq) return; // وصل رد أحدث
      setState(() {
        _results = r;
        _loading = false;
        _firstLoadDone = true;
        _error = null;
      });
    } on ApiException catch (e) {
      if (!mounted || seq != _seq) return;
      setState(() {
        _error = e.message;
        _loading = false;
        _firstLoadDone = true;
      });
    } catch (_) {
      if (!mounted || seq != _seq) return;
      setState(() {
        _error = 'حصل خطأ غير متوقع';
        _loading = false;
        _firstLoadDone = true;
      });
    }
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(msg)));
  }

  void _toggleFav(String id) => setState(() {
        _favorites.contains(id) ? _favorites.remove(id) : _favorites.add(id);
      });

  void _openProperty(Property p) => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => PropertyDetailsScreen(property: p)),
      );

  Future<void> _openAddProperty() async {
    final p = await Navigator.of(context).push<Property>(
      MaterialPageRoute(builder: (_) => const AddPropertyScreen()),
    );
    if (p != null && mounted) {
      _searchCtrl.clear();
      setState(() {
        _listing = p.listingType;
        _category = _categories.first;
        _filters = const PropertyFilters();
        _query = '';
      });
      _reload();
      _toast('تم إضافة إعلانك وظهر في أحدث العروض');
    }
  }

  Future<void> _openFilters() async {
    final result = await showModalBottomSheet<PropertyFilters>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => FilterSheet(initial: _filters, listingType: _listing),
    );
    if (result != null) {
      setState(() => _filters = result);
      _reload();
    }
  }

  @override
  Widget build(BuildContext context) {
    final results = _results;
    final featured = results.where((p) => p.isFeatured).toList();

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(child: _header(context)),
            SliverToBoxAdapter(child: _searchBar(context)),
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.only(top: 18),
                child: PromoBanners(),
              ),
            ),
            SliverToBoxAdapter(child: _listingToggle(context)),
            SliverToBoxAdapter(child: _categoryChips(context)),
            if (featured.isNotEmpty) ...[
              SliverToBoxAdapter(
                child: SectionHeader(
                  title: 'عقارات مميزة',
                  action: 'عرض الكل',
                  onAction: () => _toast('قريباً'),
                ),
              ),
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 345,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    itemCount: featured.length,
                    itemBuilder: (_, i) => FeaturedPropertyCard(
                      property: featured[i],
                      isFavorite: _favorites.contains(featured[i].id),
                      onFavorite: () => _toggleFav(featured[i].id),
                      onTap: () => _openProperty(featured[i]),
                    ),
                  ),
                ),
              ),
            ],
            SliverToBoxAdapter(
              child: SectionHeader(
                title: 'مشاريع المطورين',
                action: 'المزيد',
                onAction: () => _toast('قريباً'),
              ),
            ),
            SliverToBoxAdapter(
              child: SizedBox(
                height: 140,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: mockDevelopers.length,
                  itemBuilder: (_, i) => DeveloperCard(dev: mockDevelopers[i]),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: SectionHeader(title: 'أحدث العروض (${results.length})'),
            ),
            if (_loading && results.isNotEmpty)
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(20, 0, 20, 12),
                  child: LinearProgressIndicator(minHeight: 2, color: AppColors.amber),
                ),
              ),
            if (_error != null)
              SliverToBoxAdapter(child: _errorState(context))
            else if (_loading && results.isEmpty)
              const SliverToBoxAdapter(child: _LoadingState())
            else if (results.isEmpty)
              SliverToBoxAdapter(child: _emptyState(context))
            else
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                sliver: SliverList.builder(
                  itemCount: results.length,
                  itemBuilder: (_, i) => PropertyListTile(
                    property: results[i],
                    isFavorite: _favorites.contains(results[i].id),
                    onFavorite: () => _toggleFav(results[i].id),
                    onTap: () => _openProperty(results[i]),
                  ),
                ),
              ),
            const SliverToBoxAdapter(child: SizedBox(height: 24)),
          ],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: 0,
        onDestinationSelected: (i) {
          if (i == 3) {
            Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => const InspectionRequestsScreen()));
          } else if (i == 4) {
            Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => const AccountDashboardScreen()));
          } else if (i == 2) {
            _openAddProperty();
          } else if (i != 0) {
            _toast('الشاشة دي هتتبني في الخطوات الجاية');
          }
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded, color: AppColors.amber),
            label: 'الرئيسية',
          ),
          NavigationDestination(
            icon: Icon(Icons.map_outlined),
            selectedIcon: Icon(Icons.map_rounded, color: AppColors.amber),
            label: 'الخريطة',
          ),
          NavigationDestination(
            icon: Icon(Icons.add_circle_outline_rounded),
            selectedIcon:
                Icon(Icons.add_circle_rounded, color: AppColors.amber),
            label: 'أضف عقار',
          ),
          NavigationDestination(
            icon: Icon(Icons.event_available_outlined),
            selectedIcon:
                Icon(Icons.event_available_rounded, color: AppColors.amber),
            label: 'معايناتي',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline_rounded),
            selectedIcon: Icon(Icons.person_rounded, color: AppColors.amber),
            label: 'حسابي',
          ),
        ],
      ),
    );
  }

  // ---------------- Sections ----------------

  Widget _header(BuildContext context) {
    final dark = AppTheme.isDark(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: AppColors.amber,
              borderRadius: BorderRadius.circular(15),
            ),
            child: const Icon(Icons.home_work_rounded,
                color: AppColors.black, size: 26),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('أهلاً بيك 👋',
                    style: TextStyle(
                        color: AppTheme.muted(context), fontSize: 12.5)),
                const Text('ابحث عن عقارك المثالي',
                    style:
                        TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
              ],
            ),
          ),
          IconButton(
            onPressed: widget.onToggleTheme,
            icon: Icon(dark ? Icons.light_mode_rounded : Icons.dark_mode_rounded),
            tooltip: 'تبديل الوضع',
          ),
          Stack(
            children: [
              IconButton(
                onPressed: () => _toast('لا توجد إشعارات جديدة'),
                icon: const Icon(Icons.notifications_none_rounded),
              ),
              PositionedDirectional(
                top: 11,
                end: 12,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                      color: AppColors.amber, shape: BoxShape.circle),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _searchBar(BuildContext context) {
    final count = _filters.activeCount;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _searchCtrl,
              onChanged: (v) {
                _query = v.trim();
                _debounce?.cancel();
                _debounce = Timer(const Duration(milliseconds: 350), _reload);
              },
              decoration: const InputDecoration(
                hintText: 'ابحث بالحي أو نوع العقار...',
                prefixIcon: Icon(Icons.search_rounded),
              ),
            ),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: _openFilters,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: AppColors.amber,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.tune_rounded,
                      color: AppColors.black),
                ),
                if (count > 0)
                  PositionedDirectional(
                    top: -5,
                    end: -5,
                    child: Container(
                      width: 20,
                      height: 20,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: AppColors.black,
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.amber, width: 1.5),
                      ),
                      child: Text('$count',
                          style: const TextStyle(
                              color: AppColors.amber,
                              fontSize: 10,
                              fontWeight: FontWeight.w800)),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _listingToggle(BuildContext context) {
    Widget seg(String label, String value) {
      final selected = _listing == value;
      return Expanded(
        child: GestureDetector(
          onTap: () {
            setState(() {
              _listing = value;
              _filters = _filters.withoutPrice();
            });
            _reload();
          },
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
                    color: selected ? AppColors.black : AppTheme.muted(context))),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: AppTheme.outline(context)),
        ),
        child: Row(children: [seg('للبيع', 'بيع'), seg('للإيجار', 'إيجار')]),
      ),
    );
  }

  Widget _categoryChips(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: SizedBox(
        height: 44,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          itemCount: _categories.length,
          separatorBuilder: (_, __) => const SizedBox(width: 8),
          itemBuilder: (_, i) {
            final c = _categories[i];
            final selected = c == _category;
            return GestureDetector(
              onTap: () {
                setState(() => _category = c);
                _reload();
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: selected
                      ? AppColors.amber
                      : Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(13),
                  border: Border.all(
                      color: selected
                          ? AppColors.amber
                          : AppTheme.outline(context)),
                ),
                child: Row(
                  children: [
                    Icon(c.icon,
                        size: 18,
                        color: selected
                            ? AppColors.black
                            : AppTheme.accentText(context)),
                    const SizedBox(width: 6),
                    Text(c.label,
                        style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                            color: selected ? AppColors.black : null)),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _errorState(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
      child: Column(
        children: [
          Icon(Icons.wifi_off_rounded, size: 56, color: AppColors.amber.withOpacity(.7)),
          const SizedBox(height: 12),
          Text(_error ?? 'حصل خطأ',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
          const SizedBox(height: 14),
          OutlinedButton(
            style: OutlinedButton.styleFrom(minimumSize: const Size(160, 46)),
            onPressed: _reload,
            child: const Text('إعادة المحاولة'),
          ),
        ],
      ),
    );
  }

  Widget _emptyState(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
      child: Column(
        children: [
          Icon(Icons.search_off_rounded,
              size: 56, color: AppColors.amber.withOpacity(.7)),
          const SizedBox(height: 12),
          const Text('مفيش نتائج مطابقة',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text('جرّب تغيّر الفلاتر أو كلمة البحث',
              style: TextStyle(color: AppTheme.muted(context))),
          const SizedBox(height: 14),
          TextButton(
            onPressed: () {
              setState(() {
                _filters = const PropertyFilters();
                _category = _categories.first;
                _query = '';
                _searchCtrl.clear();
              });
              _reload();
            },
            child: Text('مسح الفلاتر',
                style: TextStyle(color: AppTheme.accentText(context))),
          ),
        ],
      ),
    );
  }
}

class _LoadingState extends StatelessWidget {
  const _LoadingState();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 56),
      child: Center(
        child: SizedBox(
          width: 30,
          height: 30,
          child: CircularProgressIndicator(strokeWidth: 3, color: AppColors.amber),
        ),
      ),
    );
  }
}
