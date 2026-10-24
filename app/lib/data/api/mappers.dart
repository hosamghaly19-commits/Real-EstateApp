import '../../models/property.dart';

// قيم الـ API (إنجليزي) ↔ نصوص الواجهة (عربي)

const Map<String, String> kTypeToApi = {
  'شقة': 'APARTMENT',
  'فيلا': 'VILLA',
  'محل': 'SHOP',
  'مكتب': 'OFFICE',
  'أرض': 'LAND',
};

const Map<String, String> kListingToApi = {'بيع': 'SALE', 'إيجار': 'RENT'};

const Map<String, String> kFinishingToApi = {
  'على الطوب': 'CORE_SHELL',
  'نص تشطيب': 'SEMI_FINISHED',
  'سوبر لوكس': 'SUPER_LUX',
  'ألترا سوبر لوكس': 'ULTRA_SUPER_LUX',
};

const Map<String, String> kPaymentToApi = {'كاش': 'CASH', 'تقسيط': 'INSTALLMENT'};

const Map<String, String> kAccountTypeAr = {
  'INDIVIDUAL': 'فرد',
  'OFFICE': 'مكتب',
  'DEVELOPER': 'مطور',
};

/// الأراضي مالهاش تشطيب في الـ API (null) — الواجهة بتعرض "غير مشطب".
const String kLandFinishingLabel = 'غير مشطب';

Map<String, String> _invert(Map<String, String> m) =>
    {for (final e in m.entries) e.value: e.key};

final Map<String, String> _typeFromApi = _invert(kTypeToApi);
final Map<String, String> _listingFromApi = _invert(kListingToApi);
final Map<String, String> _finishingFromApi = _invert(kFinishingToApi);
final Map<String, String> _paymentFromApi = _invert(kPaymentToApi);

/// رد الـ API ⇒ موديل الواجهة. شغّال لعنصر القائمة وللتفاصيل.
Property propertyFromJson(Map<String, dynamic> j) {
  final images = [for (final e in (j['images'] as List<dynamic>? ?? const [])) e as String];
  final owner = (j['owner'] as Map<String, dynamic>?) ?? <String, dynamic>{};
  final district = (j['district'] as Map<String, dynamic>?) ?? <String, dynamic>{};
  final finishing = j['finishing'] as String?;

  return Property(
    id: j['id'] as String,
    title: j['title'] as String,
    district: (district['name'] as String?) ?? '',
    type: _typeFromApi[j['type']] ?? (j['type'] as String),
    listingType: _listingFromApi[j['listingType']] ?? (j['listingType'] as String),
    price: (j['price'] as num).round(),
    area: (j['area'] as num).toInt(),
    beds: (j['beds'] as num?)?.toInt() ?? 0,
    baths: (j['baths'] as num?)?.toInt() ?? 0,
    finishing: finishing == null
        ? kLandFinishingLabel
        : (_finishingFromApi[finishing] ?? finishing),
    paymentMethods: [
      for (final m in (j['paymentMethods'] as List<dynamic>? ?? const []))
        _paymentFromApi[m] ?? (m as String),
    ],
    imageUrl: (j['coverUrl'] as String?) ?? (images.isNotEmpty ? images.first : ''),
    images: images,
    features: [for (final f in (j['features'] as List<dynamic>? ?? const [])) f as String],
    description: (j['description'] as String?) ?? '',
    isFeatured: j['isFeatured'] == true,
    isVerified: j['isVerified'] == true,
    viewsCount: (j['viewsCount'] as num?)?.toInt() ?? 0,
    ownerName: (owner['name'] as String?) ?? '',
    ownerType: kAccountTypeAr[owner['accountType']] ?? 'فرد',
  );
}

/// مسودة الإعلان (من شاشة الإضافة) ⇒ جسم POST /api/properties.
Map<String, dynamic> propertyToCreateJson(Property p, int districtId) {
  final finishingApi = kFinishingToApi[p.finishing]; // null للأراضي
  return {
    'title': p.title,
    if (p.description.isNotEmpty) 'description': p.description,
    'type': kTypeToApi[p.type],
    'listingType': kListingToApi[p.listingType],
    'districtId': districtId,
    'price': p.price,
    'area': p.area,
    'beds': p.beds,
    'baths': p.baths,
    if (finishingApi != null) 'finishing': finishingApi,
    'paymentMethods': [for (final m in p.paymentMethods) kPaymentToApi[m]],
    'features': p.features,
    'images': p.images.isNotEmpty ? p.images : [p.imageUrl],
  };
}
