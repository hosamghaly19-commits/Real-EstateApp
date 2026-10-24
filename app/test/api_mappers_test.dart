import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:real_estate_app/data/api/mappers.dart';
import 'package:real_estate_app/models/property.dart';

/// الـ fixtures دي ردود حقيقية اتسحبت من الـ API.
Map<String, dynamic> _fixture(String name) =>
    jsonDecode(File('test/fixtures/$name').readAsStringSync()) as Map<String, dynamic>;

void main() {
  group('رد الـ API ⇒ Property', () {
    test('عناصر القائمة', () {
      final rows = (_fixture('properties_list.json')['data'] as List<dynamic>)
          .cast<Map<String, dynamic>>();
      final props = rows.map(propertyFromJson).toList();

      expect(props, isNotEmpty);
      // الفيكستشر مرتّب بالسعر تنازلياً
      expect(props.first.price >= props.last.price, isTrue);
      for (final p in props) {
        expect(p.id, isNotEmpty);
        expect(p.imageUrl, startsWith('https://'));
        expect(['بيع', 'إيجار'], contains(p.listingType));
      }
    });

    test('تفاصيل فيلا: كل الحقول بالعربي', () {
      final p = propertyFromJson(
          _fixture('property_detail_villa.json')['data'] as Map<String, dynamic>);

      expect(p.title, 'فيلا مستقلة بحديقة خاصة');
      expect(p.type, 'فيلا');
      expect(p.listingType, 'بيع');
      expect(p.price, 9500000);
      expect(p.priceLabel, '9,500,000 ج.م');
      expect(p.area, 420);
      expect(p.beds, 5);
      expect(p.baths, 4);
      expect(p.finishing, 'ألترا سوبر لوكس');
      expect(p.paymentMethods, ['كاش', 'تقسيط']);
      expect(p.district, 'الحي الراقي');
      expect(p.ownerName, 'مطور الأفق'); // اسم النشاط
      expect(p.ownerType, 'مطور');
      expect(p.isVerified, isTrue);
      expect(p.isFeatured, isTrue);
      expect(p.images.length, 3);
      expect(p.imageUrl, p.images.first);
    });

    test('الأرض: finishing = null ⇒ "غير مشطب"', () {
      final p = propertyFromJson(
          _fixture('property_detail_land.json')['data'] as Map<String, dynamic>);

      expect(p.type, 'أرض');
      expect(p.finishing, kLandFinishingLabel);
      expect(p.beds, 0);
      expect(p.baths, 0);
      expect(p.ownerType, 'فرد');
    });

    test('كل أنواع الـ enums بتتحوّل لعربي', () {
      for (final e in kTypeToApi.entries) {
        final p = propertyFromJson(_minimal({'type': e.value}));
        expect(p.type, e.key);
      }
      for (final e in kListingToApi.entries) {
        expect(propertyFromJson(_minimal({'listingType': e.value})).listingType, e.key);
      }
      for (final e in kFinishingToApi.entries) {
        expect(propertyFromJson(_minimal({'finishing': e.value})).finishing, e.key);
      }
      for (final e in kAccountTypeAr.entries) {
        final p = propertyFromJson(_minimal({
          'owner': {'name': 'x', 'accountType': e.key},
        }));
        expect(p.ownerType, e.value);
      }
    });

    test('سعر عشري بيتقرّب', () {
      expect(propertyFromJson(_minimal({'price': 1234.6})).price, 1235);
    });
  });

  group('مسودة الإعلان ⇒ جسم الإنشاء', () {
    const draft = Property(
      id: 'u1',
      title: 'شقة اختبار',
      district: 'حي النخيل',
      type: 'شقة',
      listingType: 'بيع',
      price: 2000000,
      area: 110,
      beds: 2,
      baths: 1,
      finishing: 'سوبر لوكس',
      paymentMethods: ['كاش', 'تقسيط'],
      imageUrl: 'https://x.test/a.jpg',
      images: ['https://x.test/a.jpg', 'https://x.test/b.jpg'],
      features: ['أسانسير'],
      description: 'وصف',
      ownerName: 'حسابي',
      ownerType: 'مكتب',
    );

    test('شقة', () {
      final j = propertyToCreateJson(draft, 3);
      expect(j['title'], 'شقة اختبار');
      expect(j['type'], 'APARTMENT');
      expect(j['listingType'], 'SALE');
      expect(j['districtId'], 3);
      expect(j['price'], 2000000);
      expect(j['finishing'], 'SUPER_LUX');
      expect(j['paymentMethods'], ['CASH', 'INSTALLMENT']);
      expect(j['features'], ['أسانسير']);
      expect(j['images'], hasLength(2));
      expect(j['description'], 'وصف');
      expect(j.containsKey('id'), isFalse); // الـ id بيتولّد في السيرفر
    });

    test('أرض: من غير finishing ومن غير وصف فاضي', () {
      const land = Property(
        id: 'u2',
        title: 'أرض',
        district: 'حي الجامعة',
        type: 'أرض',
        listingType: 'بيع',
        price: 1000000,
        area: 300,
        beds: 0,
        baths: 0,
        finishing: kLandFinishingLabel,
        paymentMethods: ['كاش'],
        imageUrl: 'https://x.test/a.jpg',
        ownerName: 'حسابي',
        ownerType: 'فرد',
      );
      final j = propertyToCreateJson(land, 4);
      expect(j.containsKey('finishing'), isFalse);
      expect(j.containsKey('description'), isFalse);
      expect(j['images'], ['https://x.test/a.jpg']); // لو images فاضية بنستخدم الغلاف
      expect(j['type'], 'LAND');
    });
  });
}

/// أقل JSON صالح لإنشاء Property، مع إمكانية تغيير حقول.
Map<String, dynamic> _minimal(Map<String, dynamic> over) => {
      'id': 'id-1',
      'title': 't',
      'type': 'APARTMENT',
      'listingType': 'SALE',
      'price': 100,
      'area': 50,
      'finishing': 'SUPER_LUX',
      'paymentMethods': ['CASH'],
      'district': {'id': 1, 'name': 'حي'},
      'owner': {'name': 'x', 'accountType': 'INDIVIDUAL'},
      ...over,
    };
