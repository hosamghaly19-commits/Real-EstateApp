import 'package:flutter/foundation.dart';
import '../models/account.dart';

/// الحساب الحالي (تجريبي). TODO (Phase 2): يتبدل بالـ Auth الحقيقي.
class AccountStore extends ChangeNotifier {
  AccountStore._();
  static final AccountStore instance = AccountStore._();

  static const accounts = [
    Account(
      name: 'مكتب الأمان العقاري',
      type: 'مكتب',
      phone: '010••••7788',
      loginPhone: '01000000001',
      verified: true,
      since: '2025',
    ),
    Account(
      name: 'مطور الأفق',
      type: 'مطور',
      phone: '011••••2040',
      loginPhone: '01000000003',
      verified: true,
      since: '2024',
    ),
  ];

  int _index = 0;
  int get index => _index;
  Account get current => accounts[_index];

  void select(int i) {
    if (i == _index) return;
    _index = i;
    notifyListeners();
  }
}
