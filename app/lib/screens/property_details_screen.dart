import '../data/repositories/property_repository.dart';
import 'package:flutter/material.dart';
import '../data/app_config.dart';
import '../models/property.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';
import '../widgets/inspection_sheet.dart';
import '../widgets/property_image.dart';

const _extra = 'https://images.unsplash.com/';

class PropertyDetailsScreen extends StatefulWidget {
  final Property property;
  const PropertyDetailsScreen({super.key, required this.property});

  @override
  State<PropertyDetailsScreen> createState() => _PropertyDetailsScreenState();
}

class _PropertyDetailsScreenState extends State<PropertyDetailsScreen> {
  int _page = 0;
  bool _fav = false;
  bool _requested = false;

  late Property _p;

  @override
  void initState() {
    super.initState();
    _p = widget.property;
    _refresh();
  }

  /// بنجيب التفاصيل الكاملة (كل الصور، الوصف، المميزات) ونعرضها فوق اللي معانا.
  Future<void> _refresh() async {
    try {
      final full = await propertyRepo.detail(widget.property.id);
      if (mounted) setState(() => _p = full);
    } catch (_) {
      // نفضل نعرض البيانات اللي معانا (مثلاً طلبات تجريبية بعقارات مش موجودة في السيرفر).
    }
  }

  List<String> get _gallery => _p.images.isNotEmpty
      ? _p.images
      : [
    _p.imageUrl,
    '${_extra}photo-1560448204-e02f11c3d0e2?w=800&q=70',
    '${_extra}photo-1484154218962-a197022b5858?w=800&q=70',
  ];

  void _toast(String msg) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _requestInspection() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => InspectionSheet(
        property: _p,
        onSuccess: () {
          if (mounted) setState(() => _requested = true);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = _p;
    final isLand = p.type == 'أرض';
    final fee = formatNumber(inspectionFee);

    final specs = <(IconData, String, String)>[
      (Icons.category_rounded, 'النوع', p.type),
      (Icons.square_foot_rounded, 'المساحة', '${p.area} م²'),
      if (p.beds > 0) (Icons.bed_rounded, 'الغرف', '${p.beds}'),
      if (p.baths > 0) (Icons.bathtub_outlined, 'الحمامات', '${p.baths}'),
      if (!isLand) (Icons.format_paint_rounded, 'التشطيب', p.finishing),
    ];

    final defaultFeatures = isLand
        ? ['على شارعين', 'مرافق متوفرة', 'عقد مسجّل']
        : ['أسانسير', 'جراج', 'أمن 24 ساعة', 'قريب من الخدمات', 'عداد مستقل'];
    final features =
        p.features.isNotEmpty ? p.features : defaultFeatures;

    final generatedDescription =
        '${p.type} ${p.isRent ? 'للإيجار' : 'للبيع'} في ${p.district}، '
        'مساحتها ${p.area} م²${isLand ? '' : ' بتشطيب ${p.finishing}'}. '
        'موقع مميز قريب من الخدمات والمواصلات، والعقار جاهز للمعاينة. '
        'التعاقد والتوثيق بيتم من خلال التطبيق لضمان حقوق جميع الأطراف.';
    final description =
        p.description.isNotEmpty ? p.description : generatedDescription;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 320,
            pinned: true,
            automaticallyImplyLeading: false,
            leadingWidth: 64,
            leading: Padding(
              padding: const EdgeInsetsDirectional.only(start: 16, top: 6, bottom: 6),
              child: _CircleBtn(
                icon: Icons.arrow_back_ios_new_rounded,
                onTap: () => Navigator.of(context).pop(),
              ),
            ),
            actions: [
              _CircleBtn(
                icon: _fav
                    ? Icons.favorite_rounded
                    : Icons.favorite_border_rounded,
                color: _fav ? AppColors.amber : Colors.white,
                onTap: () => setState(() => _fav = !_fav),
              ),
              const SizedBox(width: 8),
              _CircleBtn(
                icon: Icons.share_rounded,
                onTap: () => _toast('المشاركة قريباً'),
              ),
              const SizedBox(width: 16),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  PageView.builder(
                    itemCount: _gallery.length,
                    onPageChanged: (i) => setState(() => _page = i),
                    itemBuilder: (_, i) => PropertyImage(url: _gallery[i]),
                  ),
                  IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.center,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.black.withOpacity(.55),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Align(
                    alignment: Alignment.bottomCenter,
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: List.generate(_gallery.length, (i) {
                          final active = i == _page;
                          return AnimatedContainer(
                            duration: const Duration(milliseconds: 220),
                            margin: const EdgeInsets.symmetric(horizontal: 3),
                            width: active ? 22 : 7,
                            height: 7,
                            decoration: BoxDecoration(
                              color: active
                                  ? AppColors.amber
                                  : Colors.white.withOpacity(.6),
                              borderRadius: BorderRadius.circular(8),
                            ),
                          );
                        }),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      _Tag(p.listingType,
                          bg: AppColors.amber, fg: AppColors.black),
                      const SizedBox(width: 8),
                      if (p.isVerified)
                        _Tag('عقار موثّق',
                            icon: Icons.verified_rounded,
                            bg: AppColors.success.withOpacity(.15),
                            fg: AppColors.success),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(p.title,
                      style: const TextStyle(
                          fontSize: 21,
                          fontWeight: FontWeight.w900,
                          height: 1.4)),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.location_on_outlined,
                          size: 17, color: AppTheme.muted(context)),
                      const SizedBox(width: 4),
                      Text(p.district,
                          style: TextStyle(color: AppTheme.muted(context))),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(p.priceLabel,
                      style: TextStyle(
                          color: AppTheme.accentText(context),
                          fontSize: 26,
                          fontWeight: FontWeight.w900)),

                  // تنبيه المعاينة المدفوعة
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.amber.withOpacity(.1),
                      borderRadius: BorderRadius.circular(16),
                      border:
                          Border.all(color: AppColors.amber.withOpacity(.45)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.verified_user_rounded,
                            color: AppTheme.accentText(context), size: 22),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'المعاينة برسوم $fee ج.م لإثبات الجدية، وبتتخصم بالكامل لو أتممت الصفقة. '
                            'ولو المعلن رفض أو ماردّش، بتترد لك كاملة.',
                            style: const TextStyle(
                                fontSize: 13, height: 1.5),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),
                  GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                    childAspectRatio: 2.3,
                    children: [
                      for (final s in specs) _SpecTile(s.$1, s.$2, s.$3),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SliverToBoxAdapter(child: SectionHeader(title: 'الوصف')),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(description,
                  style: TextStyle(
                      color: AppTheme.muted(context), height: 1.8)),
            ),
          ),
          const SliverToBoxAdapter(child: SectionHeader(title: 'المميزات')),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final f in features)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppTheme.outline(context)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.check_rounded,
                              size: 16, color: AppTheme.accentText(context)),
                          const SizedBox(width: 6),
                          Text(f, style: const TextStyle(fontSize: 13)),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SliverToBoxAdapter(
              child: SectionHeader(title: 'طرق الدفع المتاحة')),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Wrap(
                spacing: 8,
                children: [
                  for (final m in p.paymentMethods)
                    Chip(
                      label: Text(m,
                          style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              color: AppColors.black)),
                      backgroundColor: AppColors.amber,
                      side: BorderSide.none,
                    ),
                ],
              ),
            ),
          ),
          const SliverToBoxAdapter(child: SectionHeader(title: 'المعلن')),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: _OwnerCard(
                p: p,
                onTap: () => _toast('بروفايل المعلن في خطوة قادمة'),
              ),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 120)),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          border: Border(top: BorderSide(color: AppTheme.outline(context))),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
            child: Row(
              children: [
                Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(p.isRent ? 'الإيجار' : 'السعر',
                        style: TextStyle(
                            color: AppTheme.muted(context), fontSize: 11.5)),
                    Text(formatNumber(p.price),
                        style: TextStyle(
                            color: AppTheme.accentText(context),
                            fontSize: 17,
                            fontWeight: FontWeight.w900)),
                  ],
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _requested
                      ? OutlinedButton.icon(
                          onPressed: null,
                          icon: const Icon(Icons.check_circle_rounded,
                              color: AppColors.success),
                          label: const Text('تم إرسال طلب المعاينة'),
                        )
                      : ElevatedButton.icon(
                          onPressed: _requestInspection,
                          icon: const Icon(Icons.event_available_rounded),
                          label: Text('طلب معاينة - $fee ج.م'),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CircleBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final Color color;

  const _CircleBtn({
    required this.icon,
    required this.onTap,
    this.color = Colors.white,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(.55),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 19, color: color),
        ),
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  final String text;
  final IconData? icon;
  final Color bg;
  final Color fg;

  const _Tag(this.text, {this.icon, required this.bg, required this.fg});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration:
          BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: fg),
            const SizedBox(width: 4),
          ],
          Text(text,
              style: TextStyle(
                  color: fg, fontSize: 12, fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}

class _SpecTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _SpecTile(this.icon, this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.outline(context)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.amber.withOpacity(.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child:
                Icon(icon, size: 20, color: AppTheme.accentText(context)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: TextStyle(
                        color: AppTheme.muted(context), fontSize: 11.5)),
                Text(value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontWeight: FontWeight.w800, fontSize: 13.5)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _OwnerCard extends StatelessWidget {
  final Property p;
  final VoidCallback onTap;
  const _OwnerCard({required this.p, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppTheme.outline(context)),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: AppColors.amber,
                child: Text(p.ownerName.characters.first,
                    style: const TextStyle(
                        color: AppColors.black,
                        fontWeight: FontWeight.w900,
                        fontSize: 18)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(p.ownerName,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w800)),
                        ),
                        if (p.isVerified) ...[
                          const SizedBox(width: 4),
                          const Icon(Icons.verified_rounded,
                              size: 16, color: AppColors.amber),
                        ],
                      ],
                    ),
                    Text(p.ownerType,
                        style: TextStyle(
                            color: AppTheme.muted(context), fontSize: 12.5)),
                  ],
                ),
              ),
              Icon(Icons.chevron_left_rounded,
                  color: AppTheme.muted(context)),
            ],
          ),
        ),
      ),
    );
  }
}
