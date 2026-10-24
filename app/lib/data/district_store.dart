import 'package:flutter/foundation.dart';
import '../core/env.dart';
import 'api/api_client.dart';
import 'mock_data.dart';

/// الأحياء. في وضع الـ API بتتحمّل من السيرفر (واللي معاها الـ id)، وإلا بتستخدم القايمة التجريبية.
class DistrictStore extends ChangeNotifier {
  DistrictStore._();
  static final DistrictStore instance = DistrictStore._();

  List<String> _names = List.of(districts);
  final Map<String, int> _ids = {};
  bool _loaded = false;

  List<String> get names => List.unmodifiable(_names);

  /// الـ id في السيرفر (null في الوضع التجريبي أو قبل التحميل).
  int? idOf(String name) => _ids[name];

  @visibleForTesting
  void setForTest(Map<String, int> ids) {
    _names = ids.keys.toList();
    _ids
      ..clear()
      ..addAll(ids);
    _loaded = true;
    notifyListeners();
  }

  Future<void> load() async {
    if (_loaded || !useApi) return;
    try {
      final res = await ApiClient.shared.get('/api/districts');
      final rows = (res['data'] as List<dynamic>).cast<Map<String, dynamic>>();
      _names = [for (final d in rows) d['name'] as String];
      _ids
        ..clear()
        ..addEntries([
          for (final d in rows) MapEntry(d['name'] as String, (d['id'] as num).toInt()),
        ]);
      _loaded = true;
      notifyListeners();
    } on ApiException {
      // بنفضل على القايمة الافتراضية، وبنجرّب تاني في المرة الجاية.
    }
  }
}
