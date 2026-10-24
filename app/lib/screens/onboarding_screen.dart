import 'package:flutter/material.dart';
import '../data/app_config.dart';
import '../data/app_prefs.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import 'home_screen.dart';

class _PageData {
  final IconData icon;
  final List<IconData> orbit;
  final String title;
  final String body;
  const _PageData(this.icon, this.orbit, this.title, this.body);
}

class OnboardingScreen extends StatefulWidget {
  final VoidCallback onToggleTheme;
  const OnboardingScreen({super.key, required this.onToggleTheme});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _controller = PageController();
  int _index = 0;

  List<_PageData> get _pages => [
        const _PageData(
          Icons.search_rounded,
          [Icons.location_on_rounded, Icons.tune_rounded, Icons.apartment_rounded],
          'اكتشف عقارات مدينتك',
          'فلترة دقيقة حسب الحي ونوع العقار والسعر والتشطيب وطريقة الدفع، '
              'عشان توصل للي يناسبك أسرع.',
        ),
        _PageData(
          Icons.verified_user_rounded,
          const [Icons.event_available_rounded, Icons.payments_rounded, Icons.undo_rounded],
          'معاينة بقرار جاد',
          'رسوم معاينة $inspectionFee ج.م تثبت جدية طلبك، وبتتخصم بالكامل من السعر '
              'عند الإتمام. ولو المعلن رفض أو ماردّش، بتترد لك كاملة.',
        ),
        const _PageData(
          Icons.dashboard_customize_rounded,
          [Icons.person_rounded, Icons.business_rounded, Icons.domain_rounded],
          'للأفراد والمكاتب والمطورين',
          'أضف إعلانك بسهولة، وتابع طلبات المعاينة وأداء عقاراتك '
              'من لوحة تحكم واحدة.',
        ),
      ];

  bool get _last => _index == _pages.length - 1;

  Future<void> _finish() async {
    await AppPrefs.setOnboardingDone();
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => HomeScreen(onToggleTheme: widget.onToggleTheme),
      ),
    );
  }

  void _next() {
    if (_last) {
      _finish();
    } else {
      _controller.nextPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOutCubic,
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pages = _pages;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 200),
                  opacity: _last ? 0 : 1,
                  child: TextButton(
                    onPressed: _last ? null : _finish,
                    child: Text('تخطي',
                        style: TextStyle(color: AppTheme.muted(context))),
                  ),
                ),
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: pages.length,
                onPageChanged: (i) => setState(() => _index = i),
                itemBuilder: (_, i) => _Page(data: pages[i]),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(pages.length, (i) {
                final active = i == _index;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: active ? 26 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: active
                        ? AppColors.amber
                        : Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withOpacity(.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                );
              }),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
              child: ElevatedButton(
                onPressed: _next,
                child: Text(_last ? 'ابدأ الآن' : 'التالي'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Page extends StatelessWidget {
  final _PageData data;
  const _Page({required this.data});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _Illustration(icon: data.icon, orbit: data.orbit),
          const SizedBox(height: 32),
          Text(data.title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 25, fontWeight: FontWeight.w900, height: 1.4)),
          const SizedBox(height: 12),
          Text(data.body,
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: AppTheme.muted(context), fontSize: 14.5, height: 1.8)),
        ],
      ),
    );
  }
}

/// رسمة بسيطة بالأيقونات (من غير أصول صور).
class _Illustration extends StatelessWidget {
  final IconData icon;
  final List<IconData> orbit;
  const _Illustration({required this.icon, required this.orbit});

  static const _spots = [
    Alignment(-.85, -.55),
    Alignment(.9, -.1),
    Alignment(-.55, .85),
  ];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 290,
      height: 270,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 250,
            height: 250,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.amber.withOpacity(.07),
            ),
          ),
          Container(
            width: 180,
            height: 180,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.amber.withOpacity(.12),
            ),
          ),
          Container(
            width: 112,
            height: 112,
            decoration: BoxDecoration(
              color: AppColors.amber,
              borderRadius: BorderRadius.circular(34),
              boxShadow: [
                BoxShadow(
                  color: AppColors.amber.withOpacity(.3),
                  blurRadius: 30,
                ),
              ],
            ),
            child: Icon(icon, size: 58, color: AppColors.black),
          ),
          for (var i = 0; i < orbit.length; i++)
            Align(
              alignment: _spots[i],
              child: Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: AppTheme.outline(context)),
                ),
                child: Icon(orbit[i],
                    size: 26, color: AppTheme.accentText(context)),
              ),
            ),
        ],
      ),
    );
  }
}
