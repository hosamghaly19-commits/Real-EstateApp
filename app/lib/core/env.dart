/// عنوان الـ API. لو فاضي ⇒ التطبيق بيشتغل ببيانات تجريبية في الذاكرة (الوضع الافتراضي).
///
/// تشغيل مع الـ API:
///   flutter run --dart-define=API_BASE_URL=http://localhost:3000
///   (محاكي أندرويد: http://10.0.2.2:3000)
const String apiBaseUrl = String.fromEnvironment('API_BASE_URL');

bool get useApi => apiBaseUrl.isNotEmpty;
