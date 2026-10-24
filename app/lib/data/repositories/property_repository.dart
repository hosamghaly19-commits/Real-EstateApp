import '../../core/env.dart';
import '../../models/property.dart';
import '../../models/property_filters.dart';
import '../api/api_client.dart';
import '../api/mappers.dart';
import '../account_store.dart';
import '../district_store.dart';
import '../property_store.dart';

class PropertyQuery {
  final String listing; // بيع / إيجار
  final String? type; // شقة / فيلا / … (null = الكل)
  final String query;
  final PropertyFilters filters;

  const PropertyQuery({
    required this.listing,
    this.type,
    this.query = '',
    this.filters = const PropertyFilters(),
  });
}

abstract class PropertyRepository {
  Future<List<Property>> search(PropertyQuery q);
  Future<Property> detail(String id);
  Future<Property> create(Property draft);
  Future<List<Property>> mine();
}

/// بيانات تجريبية في الذاكرة (الوضع الافتراضي).
class MockPropertyRepository implements PropertyRepository {
  @override
  Future<List<Property>> search(PropertyQuery q) async {
    return PropertyStore.instance.items.where((p) {
      if (p.listingType != q.listing) return false;
      if (q.type != null && p.type != q.type) return false;
      if (q.query.isNotEmpty &&
          !p.title.contains(q.query) &&
          !p.district.contains(q.query) &&
          !p.type.contains(q.query)) {
        return false;
      }
      return q.filters.matches(p);
    }).toList();
  }

  @override
  Future<Property> detail(String id) async =>
      PropertyStore.instance.items.firstWhere((p) => p.id == id);

  @override
  Future<Property> create(Property draft) async {
    PropertyStore.instance.add(draft);
    return draft;
  }

  @override
  Future<List<Property>> mine() async =>
      PropertyStore.instance.items.where(AccountStore.instance.current.owns).toList();
}

/// الـ API الحقيقي.
class ApiPropertyRepository implements PropertyRepository {
  ApiPropertyRepository([ApiClient? client]) : _api = client ?? ApiClient.shared;

  final ApiClient _api;

  @override
  Future<List<Property>> search(PropertyQuery q) async {
    await DistrictStore.instance.load();
    final ids = <int>[
      for (final name in q.filters.districts)
        if (DistrictStore.instance.idOf(name) != null) DistrictStore.instance.idOf(name)!,
    ];
    final params = <String, String>{
      'listingType': kListingToApi[q.listing] ?? 'SALE',
      'limit': '50',
      if (q.type != null) 'type': kTypeToApi[q.type] ?? '',
      if (q.query.isNotEmpty) 'q': q.query,
      if (ids.isNotEmpty) 'districtIds': ids.join(','),
      if (q.filters.maxPrice != null) 'maxPrice': q.filters.maxPrice!.round().toString(),
      if (q.filters.finishing != null) 'finishing': kFinishingToApi[q.filters.finishing] ?? '',
      if (q.filters.payment != null) 'payment': kPaymentToApi[q.filters.payment] ?? '',
    };
    params.removeWhere((_, v) => v.isEmpty);
    final res = await _api.get('/api/properties', query: params);
    return _list(res);
  }

  @override
  Future<Property> detail(String id) async {
    final res = await _api.get('/api/properties/$id');
    return propertyFromJson(res['data'] as Map<String, dynamic>);
  }

  @override
  Future<Property> create(Property draft) async {
    await DistrictStore.instance.load();
    final districtId = DistrictStore.instance.idOf(draft.district);
    if (districtId == null) {
      throw const ApiException(0, 'NO_DISTRICT', 'مش قادر أحدد الحي. اتأكد من الاتصال وجرّب تاني');
    }
    final res = await _api.post('/api/properties', body: propertyToCreateJson(draft, districtId));
    return propertyFromJson(res['data'] as Map<String, dynamic>);
  }

  @override
  Future<List<Property>> mine() async => _list(await _api.get('/api/me/properties'));

  List<Property> _list(Map<String, dynamic> res) => [
        for (final j in (res['data'] as List<dynamic>)) propertyFromJson(j as Map<String, dynamic>),
      ];
}

final PropertyRepository propertyRepo =
    useApi ? ApiPropertyRepository() : MockPropertyRepository();
