import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

class AppTheme {
  AppTheme._();

  static ThemeData dark() => _build(
        brightness: Brightness.dark,
        bg: AppColors.black,
        surface: AppColors.charcoal,
        onSurface: Colors.white,
      );

  static ThemeData light() => _build(
        brightness: Brightness.light,
        bg: AppColors.lightBg,
        surface: Colors.white,
        onSurface: const Color(0xFF1B1B1B),
      );

  // ---- Helpers مستخدمة في الـ Widgets ----
  static bool isDark(BuildContext c) =>
      Theme.of(c).brightness == Brightness.dark;

  static Color muted(BuildContext c) =>
      Theme.of(c).colorScheme.onSurface.withOpacity(.62);

  static Color outline(BuildContext c) => isDark(c)
      ? Colors.white.withOpacity(.08)
      : Colors.black.withOpacity(.08);

  /// لون الأصفر للنصوص: أغمق شوية في الوضع الفاتح عشان التباين.
  static Color accentText(BuildContext c) =>
      isDark(c) ? AppColors.amber : const Color(0xFF9A6B00);

  static ThemeData _build({
    required Brightness brightness,
    required Color bg,
    required Color surface,
    required Color onSurface,
  }) {
    final isDark = brightness == Brightness.dark;
    final borderColor =
        isDark ? Colors.white.withOpacity(.08) : Colors.black.withOpacity(.08);

    final scheme = ColorScheme(
      brightness: brightness,
      primary: AppColors.amber,
      onPrimary: AppColors.black,
      secondary: AppColors.amberDeep,
      onSecondary: AppColors.black,
      error: const Color(0xFFE53935),
      onError: Colors.white,
      surface: surface,
      onSurface: onSurface,
    );

    final base = ThemeData(
      brightness: brightness,
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: bg,
    );

    final textTheme = GoogleFonts.cairoTextTheme(base.textTheme)
        .apply(bodyColor: onSurface, displayColor: onSurface);

    return base.copyWith(
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: bg,
        elevation: 0,
        scrolledUnderElevation: 0,
        foregroundColor: onSurface,
        titleTextStyle:
            textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.amber,
          foregroundColor: AppColors.black,
          minimumSize: const Size.fromHeight(54),
          elevation: 0,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle:
              GoogleFonts.cairo(fontWeight: FontWeight.w800, fontSize: 16),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: onSurface,
          minimumSize: const Size.fromHeight(54),
          side: BorderSide(color: onSurface.withOpacity(.2)),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle:
              GoogleFonts.cairo(fontWeight: FontWeight.w700, fontSize: 15),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        hintStyle: GoogleFonts.cairo(color: onSurface.withOpacity(.45)),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: borderColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: borderColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.amber, width: 1.5),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: surface,
        indicatorColor: AppColors.amber.withOpacity(.2),
        surfaceTintColor: Colors.transparent,
        height: 68,
      ),
      sliderTheme: base.sliderTheme.copyWith(
        activeTrackColor: AppColors.amber,
        thumbColor: AppColors.amber,
        inactiveTrackColor: onSurface.withOpacity(.15),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.charcoalLight,
        contentTextStyle: GoogleFonts.cairo(color: Colors.white),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}
