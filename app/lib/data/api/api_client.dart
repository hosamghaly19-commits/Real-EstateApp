import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../core/env.dart';
import '../account_store.dart';

class ApiException implements Exception {
  final int status; // 0 = مشكلة اتصال
  final String code;
  final String message;
  final List<dynamic>? details;

  const ApiException(this.status, this.code, this.message, [this.details]);

  bool get isNetwork => status == 0;

  @override
  String toString() => message;
}

/// عميل HTTP بسيط للـ API. الردود دايماً JSON: { data: ... } أو { error: { code, message } }.
class ApiClient {
  ApiClient({
    http.Client? client,
    String? baseUrl,
    String Function()? phoneProvider,
  })  : _client = client ?? http.Client(),
        _base = baseUrl ?? apiBaseUrl,
        _phone = phoneProvider ?? _defaultPhone;

  static String _defaultPhone() => AccountStore.instance.current.loginPhone;

  static final ApiClient shared = ApiClient();

  final http.Client _client;
  final String _base;
  final String Function() _phone;

  /// ⚠️ دخول تجريبي: الهيدر ده بيخلّي السيرفر يعتبرك المستخدم صاحب الرقم.
  /// TODO: يتبدل بـ Authorization: Bearer <token> لما نبني الـ Auth الحقيقي.
  Map<String, String> get _headers => {
        'content-type': 'application/json',
        'accept': 'application/json',
        'x-demo-phone': _phone(),
      };

  Uri _uri(String path, [Map<String, String>? query]) {
    final uri = Uri.parse('$_base$path');
    return (query == null || query.isEmpty)
        ? uri
        : uri.replace(queryParameters: query);
  }

  Future<Map<String, dynamic>> get(String path, {Map<String, String>? query}) =>
      _send(() => _client.get(_uri(path, query), headers: _headers));

  Future<Map<String, dynamic>> post(String path, {Object? body}) => _send(() =>
      _client.post(_uri(path),
          headers: _headers, body: body == null ? null : jsonEncode(body)));

  Future<Map<String, dynamic>> patch(String path, {Object? body}) => _send(() =>
      _client.patch(_uri(path),
          headers: _headers, body: body == null ? null : jsonEncode(body)));

  Future<Map<String, dynamic>> _send(Future<http.Response> Function() call) async {
    try {
      final res = await call().timeout(const Duration(seconds: 15));

      // الرد ممكن يكون مش JSON (مثلاً صفحة 502 من الـ proxy)
      dynamic body;
      try {
        body = res.bodyBytes.isEmpty
            ? <String, dynamic>{}
            : jsonDecode(utf8.decode(res.bodyBytes));
      } on FormatException {
        body = null;
      }

      if (res.statusCode >= 200 && res.statusCode < 300) {
        if (body is Map<String, dynamic>) return body;
        throw const ApiException(0, 'BAD_RESPONSE', 'رد غير متوقع من السيرفر');
      }

      final Map<String, dynamic> err =
          (body is Map && body['error'] is Map<String, dynamic>)
              ? body['error'] as Map<String, dynamic>
              : <String, dynamic>{};
      throw ApiException(
        res.statusCode,
        (err['code'] as String?) ?? 'HTTP_${res.statusCode}',
        (err['message'] as String?) ??
            (res.statusCode >= 500
                ? 'السيرفر مش متاح دلوقتي (${res.statusCode}). جرّب بعد شوية'
                : 'حصل خطأ (${res.statusCode})'),
        err['details'] as List<dynamic>?,
      );
    } on ApiException {
      rethrow;
    } on TimeoutException {
      throw const ApiException(0, 'TIMEOUT', 'السيرفر اتأخر في الرد، جرّب تاني');
    } on http.ClientException {
      throw const ApiException(
          0, 'NETWORK', 'مش قادر أتصل بالسيرفر. اتأكد من الإنترنت وجرّب تاني');
    }
  }
}
