import 'package:flutter/material.dart';
import '../data/app_prefs.dart';
import '../theme/app_colors.dart';
import 'home_screen.dart';
import 'onboarding_screen.dart';

class SplashScreen extends StatefulWidget {
  final VoidCallback onToggleTheme;
  const SplashScreen({super.key, required this.onToggleTheme});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  );
  late final Animation<double> _scale = Tween(begin: .7, end: 1.0)
      .animate(CurvedAnimation(parent: _c, curve: Curves.easeOutBack));
  late final Animation<double> _fade =
      CurvedAnimation(parent: _c, curve: const Interval(0, .7));

  @override
  void initState() {
    super.initState();
    _c.forward();
    _go();
  }

  Future<void> _go() async {
    final results = await Future.wait<dynamic>([
      Future.delayed(const Duration(milliseconds: 2300)),
      AppPrefs.isOnboardingDone(),
    ]);
    if (!mounted) return;
    final done = results[1] as bool;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 450),
        pageBuilder: (_, __, ___) => done
            ? HomeScreen(onToggleTheme: widget.onToggleTheme)
            : OnboardingScreen(onToggleTheme: widget.onToggleTheme),
        transitionsBuilder: (_, anim, __, child) =>
            FadeTransition(opacity: anim, child: child),
      ),
    );
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // الـ Splash دايماً داكنة بغض النظر عن وضع التطبيق.
    return Scaffold(
      backgroundColor: AppColors.black,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Center(
                child: FadeTransition(
                  opacity: _fade,
                  child: ScaleTransition(
                    scale: _scale,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Stack(
                          alignment: Alignment.center,
                          children: [
                            Container(
                              width: 210,
                              height: 210,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: RadialGradient(colors: [
                                  AppColors.amber.withOpacity(.22),
                                  Colors.transparent,
                                ]),
                              ),
                            ),
                            Container(
                              width: 104,
                              height: 104,
                              decoration: BoxDecoration(
                                color: AppColors.amber,
                                borderRadius: BorderRadius.circular(32),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.amber.withOpacity(.35),
                                    blurRadius: 36,
                                    spreadRadius: 2,
                                  ),
                                ],
                              ),
                              child: const Icon(Icons.home_work_rounded,
                                  size: 56, color: AppColors.black),
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),
                        const Text('عقارات',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 32,
                                fontWeight: FontWeight.w900)),
                        const SizedBox(height: 6),
                        Text('كل عقارات مدينتك في مكان واحد',
                            style: TextStyle(
                                color: Colors.white.withOpacity(.6),
                                fontSize: 14)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.only(bottom: 36),
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                    strokeWidth: 2.2, color: AppColors.amber),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
