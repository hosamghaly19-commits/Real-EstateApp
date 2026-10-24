import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:real_estate_app/data/api/api_client.dart';
import 'package:real_estate_app/data/district_store.dart';
import 'package:real_estate_app/data/repositories/property_repository.dart';
import 'package:real_estate_app/models/property.dart';
import 'package:real_estate_app/models/property_filters.dart';

String _fixtureText(String name) => File('test/fixtures/$name').readAsStringSync();

http.Response _ok(String body, [int status = 200]) => http.Response(
      body,
      status,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );

ApiPropertyRepository _repo(MockClient mock) => ApiPropertyRepository(ApiClient(
      client: mock,
      baseUrl: 'http://api.test',
      phoneProvider: () => '01000000001',
    ));

void main() {
  setUp(() {
    DistrictStore.instance.setForTest({'حي النخيل': 1, 'الحي الراقي': 2, 'وسط البلد': 3});
  });

  group('ApiPropertyRepository', () {
    test('search: الفلاتر بتتحوّل لبارامترات الـ API', () async {
      late http.Request captured;
      final repo = _repo(MockClient((req) async {
        captured = req;
        return _ok(_fixtureText('properties_list.json'));
      }));

      final list = await repo.search(const PropertyQuery(
        listing: 'بيع',
        type: 'شقة',
        query: 'نخيل',
        filters: PropertyFilters(
          districts: {'حي النخيل', 'وسط البلد'},
          maxPrice: 3000000,
          finishing: 'سوبر لوكس',
          payment: 'تقسيط',
        ),
      ));

      final q = captured.url.queryParameters;
      expect(captured.url.path, '/api/properties');
      expect(q['listingType'], 'SALE');
      expect(q['type'], 'APARTMENT');
      expect(q['q'], 'نخيل');
      expect(q['districtIds']!.split(',').toSet(), {'1', '3'});
      expect(q['maxPrice'], '3000000');
      expect(q['finishing'], 'SUPER_LUX');
      expect(q['payment'], 'INSTALLMENT');
      expect(q['limit'], '50');
      expect(list, isNotEmpty);
      expect(list.first.type, isNotEmpty);
    });

    test('search بدون فلاتر: مفيش بارامترات زيادة', () async {
      late http.Request captured;
      final repo = _repo(MockClient((req) async {
        captured = req;
        return _ok(_fixtureText('properties_list.json'));
      }));

      await repo.search(const PropertyQuery(listing: 'إيجار'));

      expect(captured.url.queryParameters.keys.toSet(), {'listingType', 'limit'});
      expect(captured.url.queryParameters['listingType'], 'RENT');
    });

    test('detail', () async {
      late http.Request captured;
      final repo = _repo(MockClient((req) async {
        captured = req;
        return _ok(_fixtureText('property_detail_villa.json'));
      }));

      final p = await repo.detail('abc');

      expect(captured.url.path, '/api/properties/abc');
      expect(p.images.length, 3);
      expect(p.title, 'فيلا مستقلة بحديقة خاصة');
    });

    test('create: الحي بيتحوّل لـ id، والمسودة بتتحوّل لجسم الـ API', () async {
      late http.Request captured;
      final repo = _repo(MockClient((req) async {
        captured = req;
        return _ok(_fixtureText('property_detail_villa.json'), 201);
      }));

      const draft = Property(
        id: 'local',
        title: 'فيلا اختبار',
        district: 'الحي الراقي',
        type: 'فيلا',
        listingType: 'بيع',
        price: 9000000,
        area: 400,
        beds: 5,
        baths: 4,
        finishing: 'ألترا سوبر لوكس',
        paymentMethods: ['كاش'],
        imageUrl: 'https://x.test/a.jpg',
        images: ['https://x.test/a.jpg'],
        ownerName: 'حسابي',
        ownerType: 'مطور',
      );

      final created = await repo.create(draft);

      final body = jsonDecode(captured.body) as Map<String, dynamic>;
      expect(captured.method, 'POST');
      expect(captured.url.path, '/api/properties');
      expect(body['districtId'], 2);
      expect(body['type'], 'VILLA');
      expect(body['finishing'], 'ULTRA_SUPER_LUX');
      expect(created.id, isNot('local')); // الـ id من السيرفر
    });

    test('create بحي مجهول ⇒ NO_DISTRICT من غير ما يبعت طلب', () async {
      var called = false;
      final repo = _repo(MockClient((req) async {
        called = true;
        return _ok('{}');
      }));

      const draft = Property(
        id: 'local',
        title: 'x',
        district: 'حي مجهول',
        type: 'شقة',
        listingType: 'بيع',
        price: 1,
        area: 1,
        beds: 1,
        baths: 1,
        finishing: 'سوبر لوكس',
        paymentMethods: ['كاش'],
        imageUrl: 'https://x.test/a.jpg',
        ownerName: 'حسابي',
        ownerType: 'فرد',
      );

      await expectLater(
        repo.create(draft),
        throwsA(isA<ApiException>().having((e) => e.code, 'code', 'NO_DISTRICT')),
      );
      expect(called, isFalse);
    });

    test('create: رفض السيرفر بيوصل برسالته', () async {
      final repo = _repo(MockClient((req) async => _ok(_fixtureText('error_validation.json'), 400)));
      const draft = Property(
        id: 'local',
        title: 'x',
        district: 'حي النخيل',
        type: 'شقة',
        listingType: 'بيع',
        price: 1,
        area: 1,
        beds: 1,
        baths: 1,
        finishing: 'سوبر لوكس',
        paymentMethods: ['كاش'],
        imageUrl: 'https://x.test/a.jpg',
        ownerName: 'حسابي',
        ownerType: 'فرد',
      );

      await expectLater(
        repo.create(draft),
        throwsA(isA<ApiException>().having((e) => e.message, 'message', 'بيانات غير صالحة')),
      );
    });

    test('mine', () async {
      late http.Request captured;
      final repo = _repo(MockClient((req) async {
        captured = req;
        return _ok(_fixtureText('properties_list.json'));
      }));

      final list = await repo.mine();

      expect(captured.url.path, '/api/me/properties');
      expect(captured.headers['x-demo-phone'], '01000000001');
      expect(list, isNotEmpty);
    });
  });

  group('MockPropertyRepository (الوضع التجريبي)', () {
    test('search: إيجار فقط', () async {
      final list = await MockPropertyRepository().search(const PropertyQuery(listing: 'إيجار'));
      expect(list.length, 3);
      expect(list.every((p) => p.isRent), isTrue);
    });

    test('search: نوع + فلتر + بحث', () async {
      final repo = MockPropertyRepository();
      final villas = await repo.search(const PropertyQuery(listing: 'بيع', type: 'فيلا'));
      expect(villas.length, 1);

      final cheap = await repo.search(const PropertyQuery(
        listing: 'بيع',
        filters: PropertyFilters(maxPrice: 3000000),
      ));
      expect(cheap.every((p) => p.price <= 3000000), isTrue);

      final byText = await repo.search(const PropertyQuery(listing: 'إيجار', query: 'الكورنيش'));
      expect(byText.length, 1);
    });

    test('mine: عقارات الحساب الحالي (مكتب الأمان)', () async {
      final mine = await MockPropertyRepository().mine();
      expect(mine.length, 2);
    });

    test('create بيضيف العقار ويظهر في البحث', () async {
      final repo = MockPropertyRepository();
      const draft = Property(
        id: 'new-1',
        title: 'عقار جديد',
        district: 'حي النخيل',
        type: 'شقة',
        listingType: 'بيع',
        price: 1500000,
        area: 90,
        beds: 2,
        baths: 1,
        finishing: 'سوبر لوكس',
        paymentMethods: ['كاش'],
        imageUrl: 'https://x.test/a.jpg',
        ownerName: 'حسابي',
        ownerType: 'فرد',
      );

      final created = await repo.create(draft);
      expect(created.id, 'new-1');

      final found = await repo.search(const PropertyQuery(listing: 'بيع', query: 'عقار جديد'));
      expect(found.map((p) => p.id), contains('new-1'));
    });
  });
}
