import 'package:flutter/foundation.dart';
import '../models/property.dart';
import 'mock_data.dart';

/// مخزن مؤقت للعقارات في الذاكرة.
/// TODO (Phase 2): يتبدل بـ Repository بيكلّم الـ REST API.
class PropertyStore extends ChangeNotifier {
  PropertyStore._();
  static final PropertyStore instance = PropertyStore._();

  final List<Property> _items = [...mockProperties];

  List<Property> get items => List.unmodifiable(_items);

  void add(Property p) {
    _items.insert(0, p);
    notifyListeners();
  }
}
