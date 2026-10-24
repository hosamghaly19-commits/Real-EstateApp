import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:real_estate_app/data/api/api_client.dart';

http.Response _json(Object body, [int status = 200]) => http.Response(
      jsonEncode(body),
      status,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );

ApiClient _client(MockClient mock) => ApiClient(
      client: mock,
      baseUrl: 'http://api.test',
      phoneProvider: () => '01000000008',
    );

void main() {
  test('GET: المسار والبارامترات (عربي) وهيدر الدخول التجريبي', () async {
    late http.Request captured;
    final c = _client(MockClient((req) async {
      captured = req;
      return _json({'data': []});
    }));

    await c.get('/api/properties', query: {'listingType': 'SALE', 'q': 'شقة'});

    expect(captured.method, 'GET');
    expect(captured.url.path, '/api/properties');
    expect(captured.url.queryParameters['listingType'], 'SALE');
    expect(captured.url.queryParameters['q'], 'شقة');
    expect(captured.headers['x-demo-phone'], '01000000008');
  });

  test('POST: بيبعت JSON', () async {
    late http.Request captured;
    final c = _client(MockClient((req) async {
      captured = req;
      return _json({'data': {'id': '1'}}, 201);
    }));

    final res = await c.post('/api/properties', body: {'title': 'عنوان', 'price': 5});

    expect(captured.method, 'POST');
    expect(captured.headers['content-type'], contains('application/json'));
    expect(jsonDecode(captured.body), {'title': 'عنوان', 'price': 5});
    expect((res['data'] as Map<String, dynamic>)['id'], '1');
  });

  test('رد خطأ من الـ API ⇒ ApiException برسالة السيرفر', () async {
    final c = _client(MockClient((req) async => _json({
          'error': {'code': 'ALREADY_REQUESTED', 'message': 'عندك طلب شغّال'},
        }, 409)));

    await expectLater(
      c.get('/x'),
      throwsA(isA<ApiException>()
          .having((e) => e.status, 'status', 409)
          .having((e) => e.code, 'code', 'ALREADY_REQUESTED')
          .having((e) => e.message, 'message', 'عندك طلب شغّال')
          .having((e) => e.isNetwork, 'isNetwork', false)),
    );
  });

  test('رد حقيقي لخطأ التحقق (fixture)', () async {
    final body = File('test/fixtures/error_validation.json').readAsStringSync();
    final c = _client(MockClient((req) async => http.Response(
          body,
          400,
          headers: {'content-type': 'application/json; charset=utf-8'},
        )));

    await expectLater(
      c.post('/api/properties', body: {'title': 'x'}),
      throwsA(isA<ApiException>()
          .having((e) => e.status, 'status', 400)
          .having((e) => e.code, 'code', 'VALIDATION_ERROR')
          .having((e) => e.message, 'message', 'بيانات غير صالحة')
          .having((e) => e.details, 'details', isNotEmpty)),
    );
  });

  test('مشكلة اتصال ⇒ ApiException.isNetwork', () async {
    final c = _client(MockClient((req) async => throw http.ClientException('boom')));

    await expectLater(
      c.get('/x'),
      throwsA(isA<ApiException>()
          .having((e) => e.isNetwork, 'isNetwork', true)
          .having((e) => e.code, 'code', 'NETWORK')),
    );
  });

  test('رد مش JSON: خطأ 502 يفضل محتفظ بالـ status، ونجاح 200 ⇒ BAD_RESPONSE', () async {
    final bad = _client(MockClient((req) async => http.Response('<html>Bad Gateway</html>', 502)));
    await expectLater(
      bad.get('/x'),
      throwsA(isA<ApiException>()
          .having((e) => e.status, 'status', 502)
          .having((e) => e.code, 'code', 'HTTP_502')),
    );

    final weird = _client(MockClient((req) async => http.Response('not json', 200)));
    await expectLater(
      weird.get('/x'),
      throwsA(isA<ApiException>().having((e) => e.code, 'code', 'BAD_RESPONSE')),
    );
  });
}
