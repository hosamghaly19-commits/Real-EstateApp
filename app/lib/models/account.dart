import 'property.dart';

class Account {
  final String name;
  final String type; // مكتب / مطور
  final String phone;

  /// رقم الدخول التجريبي اللي بيتبعت للـ API (هيدر x-demo-phone). بيتشال مع الـ Auth الحقيقي.
  final String loginPhone;

  final bool verified;
  final String since;

  const Account({
    required this.name,
    required this.type,
    required this.phone,
    required this.loginPhone,
    required this.verified,
    required this.since,
  });

  bool get isDeveloper => type == 'مطور';

  /// العقارات اللي تخص الحساب (الإعلانات الجديدة بتتسجل باسم "حسابي").
  bool owns(Property p) => p.ownerName == name || p.ownerName == 'حسابي';
}
