import '../data/repositories/property_repository.dart';
import '../data/district_store.dart';
import '../data/api/api_client.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../data/app_config.dart';
import '../data/mock_data.dart';
import '../models/property.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../widgets/property_card.dart';
import '../widgets/property_image.dart';

const _stepTitles = [
  'الأساسيات',
  'المواصفات',
  'السعر والدفع',
  'الصور والوصف',
  'المراجعة',
];

const _owners = [
  ('فرد', Icons.person_rounded, 'مالك مباشر'),
  ('مكتب', Icons.business_rounded, 'وسيط عقاري'),
  ('مطور', Icons.domain_rounded, 'شركة تطوير'),
];

const _types = [
  ('شقة', Icons.apartment_rounded),
  ('فيلا', Icons.villa_rounded),
  ('محل', Icons.storefront_rounded),
  ('مكتب', Icons.business_center_rounded),
  ('أرض', Icons.landscape_rounded),
];

const _featureOptions = [
  'أسانسير',
  'جراج',
  'أمن 24 ساعة',
  'قريب من الخدمات',
  'عداد مستقل',
  'حديقة',
  'تكييف مركزي',
  'جاهز للسكن',
];

const _landFeatureOptions = [
  'على شارعين',
  'مرافق متوفرة',
  'عقد مسجّل',
  'قريبة من الخدمات',
  'واجهة رئيسية',
];

// TODO: يتبدل برفع صور حقيقي (image_picker + تخزين) مع الـ Backend.
const _u = 'https://images.unsplash.com/';
const _samplePhotos = [
  '${_u}photo-1560448204-e02f11c3d0e2?w=800&q=70',
  '${_u}photo-1484154218962-a197022b5858?w=800&q=70',
  '${_u}photo-1502672260266-1c1ef2d93688?w=800&q=70',
  '${_u}photo-1493809842364-78817add7ffb?w=800&q=70',
  '${_u}photo-1522708323590-d24dbb6b0267?w=800&q=70',
  '${_u}photo-1545324418-cc1a3fa10c00?w=800&q=70',
  '${_u}photo-1564013799919-ab600027ffc6?w=800&q=70',
  '${_u}photo-1512917774080-9991f1c4c750?w=800&q=70',
];
const _maxPhotos = 8;

class AddPropertyScreen extends StatefulWidget {
  const AddPropertyScreen({super.key});

  @override
  State<AddPropertyScreen> createState() => _AddPropertyScreenState();
}

class _AddPropertyScreenState extends State<AddPropertyScreen> {
  int _step = 0;
  Property? _created;

  // 1) الأساسيات
  String? _ownerType;
  String _listing = 'بيع';
  String? _type;
  String? _district;

  // 2) المواصفات
  final _areaCtrl = TextEditingController();
  int _beds = 2;
  int _baths = 1;
  String? _finishing;
  final Set<String> _features = {};

  // 3) السعر
  final _priceCtrl = TextEditingController();
  final Set<String> _payments = {'كاش'};

  // 4) الصور والوصف
  final List<String> _photos = [];
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();

  // 5) المراجعة
  bool _agreed = false;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    DistrictStore.instance.addListener(_onDistricts);
    DistrictStore.instance.load();
  }

  void _onDistricts() {
    if (mounted) setState(() {});
  }

  bool get _isLand => _type == 'أرض';
  bool get _hasBeds => _type == 'شقة' || _type == 'فيلا';
  bool get _isRent => _listing == 'إيجار';
  int get _area => int.tryParse(_areaCtrl.text) ?? 0;
  int get _price => int.tryParse(_priceCtrl.text) ?? 0;
  String get _autoTitle =>
      '${_type ?? 'عقار'} ${_isRent ? 'للإيجار' : 'للبيع'} في ${_district ?? ''}'
          .trim();

  @override
  void dispose() {
    DistrictStore.instance.removeListener(_onDistricts);
    _areaCtrl.dispose();
    _priceCtrl.dispose();
    _titleCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  bool _valid(int step) {
    switch (step) {
      case 0:
        return _ownerType != null && _type != null && _district != null;
      case 1:
        return _area > 0 && (_isLand || _finishing != null);
      case 2:
        return _price > 0 && _payments.isNotEmpty;
      case 3:
        return _photos.isNotEmpty;
      case 4:
        return _agreed;
    }
    return false;
  }

  void _next() {
    if (!_valid(_step)) return;
    FocusScope.of(context).unfocus();
    if (_step < _stepTitles.length - 1) {
      setState(() => _step++);
    } else {
      _submit();
    }
  }

  void _back() {
    FocusScope.of(context).unfocus();
    setState(() => _step--);
  }

  Property _buildProperty() => Property(
        id: 'u${DateTime.now().millisecondsSinceEpoch}',
        title: _titleCtrl.text.trim().isEmpty
            ? _autoTitle
            : _titleCtrl.text.trim(),
        district: _district!,
        type: _type!,
        listingType: _listing,
        price: _price,
        area: _area,
        beds: _hasBeds ? _beds : 0,
        baths: _isLand ? 0 : _baths,
        finishing: _isLand ? 'غير مشطب' : _finishing!,
        paymentMethods: _payments.toList(),
        imageUrl: _photos.first,
        images: List.of(_photos),
        ownerName: 'حسابي',
        ownerType: _ownerType!,
        features: _features.toList(),
        description: _descCtrl.text.trim(),
      );

  Future<void> _submit() async {
    if (_submitting) return;
    final draft = _buildProperty();
    setState(() => _submitting = true);
    try {
      final created = await propertyRepo.create(draft);
      if (!mounted) return;
      setState(() => _created = created);
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _reset() {
    setState(() {
      _step = 0;
      _created = null;
      _ownerType = null;
      _listing = 'بيع';
      _type = null;
      _district = null;
      _areaCtrl.clear();
      _beds = 2;
      _baths = 1;
      _finishing = null;
      _features.clear();
      _priceCtrl.clear();
      _payments
        ..clear()
        ..add('كاش');
      _photos.clear();
      _titleCtrl.clear();
      _descCtrl.clear();
      _agreed = false;
    });
  }

  // ======================= Build =======================

  @override
  Widget build(BuildContext context) {
    if (_created != null) return _success(context);

    final last = _step == _stepTitles.length - 1;
    return Scaffold(
      appBar: AppBar(title: const Text('إضافة عقار')),
      body: Column(
        children: [
          _progress(context),
          Expanded(
            child: SingleChildScrollView(
              keyboardDismissBehavior:
                  ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                child: KeyedSubtree(
                  key: ValueKey(_step),
                  child: _stepBody(context),
                ),
              ),
            ),
          ),
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
                if (_step > 0) ...[
                  SizedBox(
                    width: 110,
                    child: OutlinedButton(
                      onPressed: _back,
                      child: const Text('السابق'),
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  child: ElevatedButton(
                    onPressed: _valid(_step) && !_submitting ? _next : null,
                    child: _submitting
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                                strokeWidth: 2.5, color: AppColors.black),
                          )
                        : Text(last ? 'نشر الإعلان' : 'التالي'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _progress(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 6, 20, 14),
      child: Column(
        children: [
          Row(
            children: [
              Text('الخطوة ${_step + 1} من ${_stepTitles.length}',
                  style: TextStyle(
                      color: AppTheme.muted(context), fontSize: 12.5)),
              const Spacer(),
              Text(_stepTitles[_step],
                  style: TextStyle(
                      color: AppTheme.accentText(context),
                      fontWeight: FontWeight.w800)),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: (_step + 1) / _stepTitles.length,
              minHeight: 6,
              color: AppColors.amber,
              backgroundColor: AppTheme.outline(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _stepBody(BuildContext context) {
    switch (_step) {
      case 0:
        return _stepBasics(context);
      case 1:
        return _stepSpecs(context);
      case 2:
        return _stepPrice(context);
      case 3:
        return _stepMedia(context);
      default:
        return _stepReview(context);
    }
  }

  // ======================= Steps =======================

  Widget _label(String t, {bool required = false}) => Padding(
        padding: const EdgeInsets.only(top: 18, bottom: 10),
        child: Row(
          children: [
            Text(t,
                style:
                    const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
            if (required)
              const Text(' *',
                  style: TextStyle(
                      color: AppColors.amber, fontWeight: FontWeight.w900)),
          ],
        ),
      );

  Widget _stepBasics(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label('مين المعلن؟', required: true),
        Row(
          children: [
            for (var i = 0; i < _owners.length; i++) ...[
              if (i > 0) const SizedBox(width: 10),
              Expanded(child: _ownerCard(context, _owners[i])),
            ],
          ],
        ),
        _label('نوع العرض', required: true),
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: AppTheme.outline(context)),
          ),
          child: Row(
            children: [
              _seg(context, 'للبيع', 'بيع'),
              _seg(context, 'للإيجار', 'إيجار'),
            ],
          ),
        ),
        _label('نوع العقار', required: true),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final t in _types)
              _SelChip(
                label: t.$1,
                icon: t.$2,
                selected: _type == t.$1,
                onTap: () => setState(() {
                  _type = t.$1;
                  _features.clear();
                }),
              ),
          ],
        ),
        _label('الحي', required: true),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final d in DistrictStore.instance.names)
              _SelChip(
                label: d,
                selected: _district == d,
                onTap: () => setState(() => _district = d),
              ),
          ],
        ),
      ],
    );
  }

  Widget _ownerCard(BuildContext context, (String, IconData, String) o) {
    final selected = _ownerType == o.$1;
    return GestureDetector(
      onTap: () => setState(() => _ownerType = o.$1),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.amber.withOpacity(.14)
              : Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? AppColors.amber : AppTheme.outline(context),
            width: selected ? 1.6 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(o.$2,
                size: 26,
                color: selected
                    ? AppTheme.accentText(context)
                    : AppTheme.muted(context)),
            const SizedBox(height: 6),
            Text(o.$1,
                style: const TextStyle(
                    fontWeight: FontWeight.w800, fontSize: 14)),
            Text(o.$3,
                textAlign: TextAlign.center,
                style:
                    TextStyle(color: AppTheme.muted(context), fontSize: 11)),
          ],
        ),
      ),
    );
  }

  Widget _seg(BuildContext context, String label, String value) {
    final selected = _listing == value;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _listing = value),
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

  Widget _stepSpecs(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label('المساحة', required: true),
        TextField(
          controller: _areaCtrl,
          keyboardType: TextInputType.number,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(6),
          ],
          onChanged: (_) => setState(() {}),
          decoration:
              const InputDecoration(hintText: 'مثال: 120', suffixText: 'م²'),
        ),
        if (_hasBeds) ...[
          const SizedBox(height: 14),
          _Counter(
            label: 'عدد الغرف',
            value: _beds,
            min: 1,
            max: 10,
            onChanged: (v) => setState(() => _beds = v),
          ),
        ],
        if (!_isLand) ...[
          const SizedBox(height: 10),
          _Counter(
            label: 'عدد الحمامات',
            value: _baths,
            min: 1,
            max: 8,
            onChanged: (v) => setState(() => _baths = v),
          ),
          _label('التشطيب', required: true),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final f in finishingOptions)
                _SelChip(
                  label: f,
                  selected: _finishing == f,
                  onTap: () => setState(() => _finishing = f),
                ),
            ],
          ),
        ],
        _label('المميزات (اختياري)'),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final f in (_isLand ? _landFeatureOptions : _featureOptions))
              _SelChip(
                label: f,
                selected: _features.contains(f),
                onTap: () => setState(() => _features.contains(f)
                    ? _features.remove(f)
                    : _features.add(f)),
              ),
          ],
        ),
      ],
    );
  }

  Widget _stepPrice(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label(_isRent ? 'الإيجار الشهري' : 'السعر المطلوب', required: true),
        TextField(
          controller: _priceCtrl,
          keyboardType: TextInputType.number,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(10),
          ],
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            hintText: _isRent ? 'مثال: 6000' : 'مثال: 2500000',
            suffixText: _isRent ? 'ج.م / شهرياً' : 'ج.م',
          ),
        ),
        if (_price > 0)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text('${formatNumber(_price)} ج.م',
                style: TextStyle(
                    color: AppTheme.accentText(context),
                    fontWeight: FontWeight.w800)),
          ),
        _label('طرق الدفع المقبولة', required: true),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final m in paymentOptions)
              _SelChip(
                label: m,
                selected: _payments.contains(m),
                onTap: () => setState(() => _payments.contains(m)
                    ? _payments.remove(m)
                    : _payments.add(m)),
              ),
          ],
        ),
        const SizedBox(height: 22),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.amber.withOpacity(.1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.amber.withOpacity(.45)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.verified_user_rounded,
                  color: AppTheme.accentText(context), size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'المشترين بيدفعوا ${formatNumber(inspectionFee)} ج.م رسوم معاينة '
                  'قبل ما يطلبوا المعاينة، وده بيقلل الطلبات غير الجادة. '
                  'لو رفضت طلب أو ماردّيتش خلال $inspectionResponseHours ساعة، '
                  'الرسوم بتترد للمشتري بالكامل.',
                  style: const TextStyle(fontSize: 12.5, height: 1.6),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _stepMedia(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label('الصور (${_photos.length}/$_maxPhotos)', required: true),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (var i = 0; i < _photos.length; i++)
              _photoTile(context, i),
            if (_photos.length < _maxPhotos) _addPhotoTile(context),
          ],
        ),
        const SizedBox(height: 8),
        Text('(تجريبي: بنضيف صور عينة لحد ما نربط رفع الصور الحقيقي)',
            style: TextStyle(color: AppTheme.muted(context), fontSize: 11.5)),
        _label('عنوان الإعلان'),
        TextField(
          controller: _titleCtrl,
          maxLength: 80,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            hintText: _autoTitle,
            counterText: '',
          ),
        ),
        const SizedBox(height: 4),
        Text('لو سبته فاضي هنكتبه تلقائياً.',
            style: TextStyle(color: AppTheme.muted(context), fontSize: 11.5)),
        _label('الوصف'),
        TextField(
          controller: _descCtrl,
          maxLines: 5,
          maxLength: 600,
          decoration: const InputDecoration(
            hintText: 'اكتب تفاصيل تهم المشتري: الدور، الإطلالة، قرب الخدمات...',
          ),
        ),
      ],
    );
  }

  Widget _photoTile(BuildContext context, int i) {
    return SizedBox(
      width: 96,
      height: 96,
      child: Stack(
        fit: StackFit.expand,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: PropertyImage(url: _photos[i]),
          ),
          if (i == 0)
            PositionedDirectional(
              bottom: 6,
              start: 6,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.amber,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text('الغلاف',
                    style: TextStyle(
                        color: AppColors.black,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800)),
              ),
            ),
          PositionedDirectional(
            top: 4,
            end: 4,
            child: GestureDetector(
              onTap: () => setState(() => _photos.removeAt(i)),
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(.65),
                  shape: BoxShape.circle,
                ),
                child:
                    const Icon(Icons.close_rounded, size: 14, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _addPhotoTile(BuildContext context) {
    return GestureDetector(
      onTap: () => setState(
          () => _photos.add(_samplePhotos[_photos.length % _samplePhotos.length])),
      child: Container(
        width: 96,
        height: 96,
        decoration: BoxDecoration(
          color: AppColors.amber.withOpacity(.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.amber.withOpacity(.6)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add_a_photo_rounded,
                color: AppTheme.accentText(context)),
            const SizedBox(height: 4),
            Text('إضافة صورة',
                style: TextStyle(
                    color: AppTheme.accentText(context),
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }

  Widget _stepReview(BuildContext context) {
    final p = _buildProperty();
    Widget kv(String k, String v) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 5),
          child: Row(
            children: [
              Text(k,
                  style:
                      TextStyle(color: AppTheme.muted(context), fontSize: 13)),
              const Spacer(),
              Flexible(
                child: Text(v,
                    textAlign: TextAlign.end,
                    style: const TextStyle(
                        fontWeight: FontWeight.w800, fontSize: 13.5)),
              ),
            ],
          ),
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label('شكل الإعلان عند المشترين'),
        IgnorePointer(
          child: PropertyListTile(
            property: p,
            isFavorite: false,
            onFavorite: () {},
            onTap: () {},
          ),
        ),
        _label('ملخص البيانات'),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.outline(context)),
          ),
          child: Column(
            children: [
              kv('المعلن', p.ownerType),
              kv('نوع العرض', p.isRent ? 'إيجار' : 'بيع'),
              kv('الحي', p.district),
              kv('المساحة', '${p.area} م²'),
              kv(p.isRent ? 'الإيجار' : 'السعر', p.priceLabel),
              kv('الدفع', p.paymentMethods.join(' / ')),
              kv('الصور', '${p.images.length}'),
            ],
          ),
        ),
        const SizedBox(height: 14),
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => setState(() => _agreed = !_agreed),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Checkbox(
                value: _agreed,
                activeColor: AppColors.amber,
                checkColor: AppColors.black,
                onChanged: (v) => setState(() => _agreed = v ?? false),
              ),
              const Expanded(
                child: Padding(
                  padding: EdgeInsets.only(top: 10),
                  child: Text(
                    'أقر بصحة بيانات الإعلان، وأوافق إن المعاينات والتعاقد '
                    'تتم من خلال التطبيق.',
                    style: TextStyle(fontSize: 13, height: 1.5),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ======================= Success =======================

  Widget _success(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: AppColors.success.withOpacity(.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check_rounded,
                    size: 52, color: AppColors.success),
              ),
              const SizedBox(height: 20),
              const Text('تم إضافة إعلانك',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
              const SizedBox(height: 8),
              Text('هيظهر في أول قائمة العروض في الرئيسية.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppTheme.muted(context))),
              const SizedBox(height: 28),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(_created),
                child: const Text('عرض في الرئيسية'),
              ),
              const SizedBox(height: 10),
              OutlinedButton(
                onPressed: _reset,
                child: const Text('إضافة عقار آخر'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ======================= Small widgets =======================

class _SelChip extends StatelessWidget {
  final String label;
  final IconData? icon;
  final bool selected;
  final VoidCallback onTap;

  const _SelChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? AppColors.amber : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: selected ? AppColors.amber : AppTheme.outline(context)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon,
                  size: 18,
                  color: selected
                      ? AppColors.black
                      : AppTheme.accentText(context)),
              const SizedBox(width: 6),
            ],
            Text(label,
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: selected ? AppColors.black : null)),
          ],
        ),
      ),
    );
  }
}

class _Counter extends StatelessWidget {
  final String label;
  final int value;
  final int min;
  final int max;
  final ValueChanged<int> onChanged;

  const _Counter({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    Widget btn(IconData icon, bool enabled, VoidCallback onTap) =>
        GestureDetector(
          onTap: enabled ? onTap : null,
          child: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: enabled
                  ? AppColors.amber
                  : AppTheme.muted(context).withOpacity(.15),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(icon,
                size: 20,
                color: enabled ? AppColors.black : AppTheme.muted(context)),
          ),
        );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.outline(context)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(label,
                style: const TextStyle(
                    fontWeight: FontWeight.w700, fontSize: 14)),
          ),
          btn(Icons.remove_rounded, value > min, () => onChanged(value - 1)),
          SizedBox(
            width: 44,
            child: Text('$value',
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontWeight: FontWeight.w900, fontSize: 17)),
          ),
          btn(Icons.add_rounded, value < max, () => onChanged(value + 1)),
        ],
      ),
    );
  }
}
