import 'package:shared_preferences/shared_preferences.dart';

/// إعدادات بسيطة محفوظة على الجهاز.
class AppPrefs {
  AppPrefs._();

  static const _kOnboardingDone = 'onboarding_done';

  static Future<bool> isOnboardingDone() async {
    try {
      final p = await SharedPreferences.getInstance();
      return p.getBool(_kOnboardingDone) ?? false;
    } catch (_) {
      return false; // لو التخزين فشل، نعرض الـ Onboarding بدل ما نوقف التطبيق.
    }
  }

  static Future<void> setOnboardingDone() async {
    try {
      final p = await SharedPreferences.getInstance();
      await p.setBool(_kOnboardingDone, true);
    } catch (_) {}
  }
}
