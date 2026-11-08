import 'package:flutter/material.dart';

import '../../../ui/components/page_layout.dart';

const campusPageBackground = Color(0xFFFFFFFF);
const campusCanvas = Color(0xFFF7F7F5);
const campusSurface = Color(0xFFFFFFFF);
const campusControlSurface = Color(0xFFF5F5F5);
const campusLine = Color(0xFFE8E8E8);
const campusCardLine = Color(0xFFEAEAE6);
const campusCardBorder = Color(0xFFF1F1ED);
const campusInk = Color(0xFF1A1A1A);
const campusMuted = Color(0xFF737373);
const campusOnInk = Color(0xFFFFFFFF);

/// 列表卡片统一的白面、极轻描边和柔和投影，让白卡片从画布上浮起来。
BoxDecoration campusCardDecoration({
  double radius = 18,
  bool elevated = true,
  Color color = campusSurface,
}) => BoxDecoration(
  color: color,
  borderRadius: BorderRadius.circular(radius),
  border: Border.all(color: campusCardBorder, width: .5),
  boxShadow: elevated
      ? [
          BoxShadow(
            color: const Color(0xFF1A1A1A).withValues(alpha: .045),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ]
      : null,
);

/// 校园评分、二手和校园统一的白底石墨黑主题。
///
/// 白色占大面积，黑色只用于文字、主按钮、选中态和少量强调。
ThemeData campusTheme(BuildContext context) {
  final scheme =
      ColorScheme.fromSeed(
        seedColor: campusInk,
        brightness: Brightness.light,
      ).copyWith(
        primary: campusInk,
        onPrimary: campusOnInk,
        primaryContainer: campusControlSurface,
        onPrimaryContainer: campusInk,
        secondary: campusMuted,
        onSecondary: campusOnInk,
        secondaryContainer: campusControlSurface,
        onSecondaryContainer: campusInk,
        tertiary: campusMuted,
        onTertiary: campusOnInk,
        tertiaryContainer: campusControlSurface,
        onTertiaryContainer: campusInk,
        surface: campusSurface,
        onSurface: campusInk,
        onSurfaceVariant: campusMuted,
        surfaceContainerLow: const Color(0xFFFAFAFA),
        surfaceContainer: campusSurface,
        surfaceContainerHigh: campusControlSurface,
        surfaceContainerHighest: const Color(0xFFEDEDED),
        outline: const Color(0xFFBDBDBD),
        outlineVariant: campusLine,
        error: const Color(0xFF8F3D32),
        onError: Colors.white,
      );
  return pageTheme(
    context,
    backgroundColor: campusPageBackground,
    accent: campusInk,
    brightness: Brightness.light,
    colorScheme: scheme,
    surface: campusSurface,
    onSurface: campusInk,
    onAccent: campusOnInk,
    inputFillColor: campusControlSurface,
    controlTrackColor: campusControlSurface,
    controlSelectedColor: campusInk,
    controlSelectedForegroundColor: campusOnInk,
  );
}

/// 在校园业务页面根节点应用统一白底石墨黑主题，并让子页面在正确的
/// Theme 上下文中构建。
class CampusThemeBuilder extends StatelessWidget {
  const CampusThemeBuilder({super.key, required this.builder});

  final WidgetBuilder builder;

  @override
  Widget build(BuildContext context) => Theme(
    data: campusTheme(context),
    child: Builder(builder: builder),
  );
}
