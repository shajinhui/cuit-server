import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class AppTheme {
  static const accent = Color(0xFF2574F5);
  static const background = Color(0xFFF4F6FA);

  /// 仅安卓使用内置的 HarmonyOS Sans SC；iOS 传 null，继续用系统的苹方 / SF Pro。
  ///
  /// 这个家族没有 350 的中间字面：Light 偏细、Regular 偏粗。所以按字号分工：
  /// 大标题用 Light，正文/标签用 Regular，既不发飘也不发重。
  static const String androidFontFamily = 'HarmonyOS Sans SC Text';
  static const String androidDisplayFontFamily = 'HarmonyOS Sans SC Light';

  static String? get _platformFontFamily {
    if (kIsWeb) return null;
    return defaultTargetPlatform == TargetPlatform.android
        ? androidFontFamily
        : null;
  }

  static String? get _platformDisplayFontFamily {
    if (kIsWeb) return null;
    return defaultTargetPlatform == TargetPlatform.android
        ? androidDisplayFontFamily
        : null;
  }

  static ThemeData build(Brightness brightness) {
    final dark = brightness == Brightness.dark;
    final scheme = ColorScheme.fromSeed(
      seedColor: accent,
      brightness: brightness,
      primary: dark ? const Color(0xFF8DB6FF) : accent,
      surface: dark ? const Color(0xFF191C23) : Colors.white,
    );
    final theme = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      brightness: brightness,
      scaffoldBackgroundColor: dark ? const Color(0xFF101217) : background,
      fontFamily: _platformFontFamily,
      fontFamilyFallback: const [
        'PingFang SC',
        'Noto Sans CJK SC',
        'sans-serif',
      ],
      textTheme: const TextTheme(
        headlineLarge: TextStyle(
          fontSize: 32,
          fontWeight: FontWeight.w700,
          letterSpacing: -1,
        ),
        headlineMedium: TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.w700,
          letterSpacing: -.7,
        ),
        titleLarge: TextStyle(fontSize: 21, fontWeight: FontWeight.w700),
        titleMedium: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        bodyLarge: TextStyle(fontSize: 16, height: 1.5),
        bodyMedium: TextStyle(fontSize: 14, height: 1.5),
        bodySmall: TextStyle(fontSize: 12, height: 1.4),
      ).apply(bodyColor: scheme.onSurface, displayColor: scheme.onSurface),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(48, 54),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(17),
          ),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: dark ? const Color(0xFF252932) : const Color(0xFFF5F7FA),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 17,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: scheme.primary, width: 1.5),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: scheme.surface,
        showDragHandle: true,
        modalBarrierColor: Colors.black.withValues(alpha: .25),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant.withValues(alpha: .45),
        thickness: .7,
      ),
    );
    final displayFont = _platformDisplayFontFamily;
    if (displayFont == null) return theme;
    final text = theme.textTheme;
    return theme.copyWith(
      textTheme: text.copyWith(
        displayLarge: text.displayLarge?.copyWith(fontFamily: displayFont),
        displayMedium: text.displayMedium?.copyWith(fontFamily: displayFont),
        displaySmall: text.displaySmall?.copyWith(fontFamily: displayFont),
        headlineLarge: text.headlineLarge?.copyWith(fontFamily: displayFont),
        headlineMedium: text.headlineMedium?.copyWith(fontFamily: displayFont),
        headlineSmall: text.headlineSmall?.copyWith(fontFamily: displayFont),
      ),
    );
  }
}
