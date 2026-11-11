import 'package:flutter/material.dart';

import '../../../ui/components/page_layout.dart';

/// 亮色调色板基线。保留这些常量是为了让校园主题的历史调用点可读，
/// 实际渲染请通过 [campusPalette] 取当前亮度的色值。
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

/// 校园模块的语义色板。
///
/// 白底石墨黑是浅色下的原貌；深色下保留同样的语义关系：画布最暗、
/// 卡片浮一档、主色反转为浅墨色，按钮文字随之变深。
@immutable
class CampusPalette extends ThemeExtension<CampusPalette> {
  const CampusPalette({
    required this.pageBackground,
    required this.canvas,
    required this.surface,
    required this.controlSurface,
    required this.line,
    required this.cardLine,
    required this.cardBorder,
    required this.ink,
    required this.muted,
    required this.onInk,
    required this.shadow,
    required this.containerLow,
    required this.containerHighest,
    required this.outline,
  });

  /// 页面根背景（导航栏、帖子页等）。
  final Color pageBackground;

  /// 内容画布，比页面背景略深，用来衬托卡片。
  final Color canvas;

  /// 卡片、输入框等前景面。
  final Color surface;

  /// 次级面：分段控件轨道、标签底、禁用态。
  final Color controlSurface;

  /// 分隔线。
  final Color line;

  /// 卡片内部细线。
  final Color cardLine;

  /// 卡片描边。
  final Color cardBorder;

  /// 主文字、主按钮底色、选中态。
  final Color ink;

  /// 次要文字。
  final Color muted;

  /// 压在 [ink] 上的前景色（深色模式下是深字浅底）。
  final Color onInk;

  /// 卡片投影色（已含透明度）。
  final Color shadow;

  final Color containerLow;
  final Color containerHighest;
  final Color outline;

  static const light = CampusPalette(
    pageBackground: campusPageBackground,
    canvas: campusCanvas,
    surface: campusSurface,
    controlSurface: campusControlSurface,
    line: campusLine,
    cardLine: campusCardLine,
    cardBorder: campusCardBorder,
    ink: campusInk,
    muted: campusMuted,
    onInk: campusOnInk,
    shadow: Color(0x0C1A1A1A),
    containerLow: Color(0xFFFAFAFA),
    containerHighest: Color(0xFFEDEDED),
    outline: Color(0xFFBDBDBD),
  );

  static const dark = CampusPalette(
    pageBackground: Color(0xFF0D0D0F),
    canvas: Color(0xFF0D0D0F),
    surface: Color(0xFF1F1F22),
    controlSurface: Color(0xFF2C2C2E),
    line: Color(0xFF333336),
    cardLine: Color(0xFF2A2A2C),
    cardBorder: Color(0xFF2F2F32),
    ink: Color(0xFFF2F2F2),
    muted: Color(0xFF9A9AA0),
    onInk: Color(0xFF141416),
    shadow: Color(0x66000000),
    containerLow: Color(0xFF171719),
    containerHighest: Color(0xFF333336),
    outline: Color(0xFF4A4A4E),
  );

  static CampusPalette of(BuildContext context) =>
      Theme.of(context).extension<CampusPalette>() ??
      (Theme.of(context).brightness == Brightness.dark ? dark : light);

  @override
  CampusPalette copyWith({
    Color? pageBackground,
    Color? canvas,
    Color? surface,
    Color? controlSurface,
    Color? line,
    Color? cardLine,
    Color? cardBorder,
    Color? ink,
    Color? muted,
    Color? onInk,
    Color? shadow,
    Color? containerLow,
    Color? containerHighest,
    Color? outline,
  }) => CampusPalette(
    pageBackground: pageBackground ?? this.pageBackground,
    canvas: canvas ?? this.canvas,
    surface: surface ?? this.surface,
    controlSurface: controlSurface ?? this.controlSurface,
    line: line ?? this.line,
    cardLine: cardLine ?? this.cardLine,
    cardBorder: cardBorder ?? this.cardBorder,
    ink: ink ?? this.ink,
    muted: muted ?? this.muted,
    onInk: onInk ?? this.onInk,
    shadow: shadow ?? this.shadow,
    containerLow: containerLow ?? this.containerLow,
    containerHighest: containerHighest ?? this.containerHighest,
    outline: outline ?? this.outline,
  );

  @override
  CampusPalette lerp(ThemeExtension<CampusPalette>? other, double t) {
    if (other is! CampusPalette) return this;
    return CampusPalette(
      pageBackground: Color.lerp(pageBackground, other.pageBackground, t)!,
      canvas: Color.lerp(canvas, other.canvas, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      controlSurface: Color.lerp(controlSurface, other.controlSurface, t)!,
      line: Color.lerp(line, other.line, t)!,
      cardLine: Color.lerp(cardLine, other.cardLine, t)!,
      cardBorder: Color.lerp(cardBorder, other.cardBorder, t)!,
      ink: Color.lerp(ink, other.ink, t)!,
      muted: Color.lerp(muted, other.muted, t)!,
      onInk: Color.lerp(onInk, other.onInk, t)!,
      shadow: Color.lerp(shadow, other.shadow, t)!,
      containerLow: Color.lerp(containerLow, other.containerLow, t)!,
      containerHighest: Color.lerp(
        containerHighest,
        other.containerHighest,
        t,
      )!,
      outline: Color.lerp(outline, other.outline, t)!,
    );
  }
}

CampusPalette campusPalette(BuildContext context) => CampusPalette.of(context);

/// 校园页里的取色入口：`context.campusColors.ink`。
extension CampusPaletteContext on BuildContext {
  CampusPalette get campusColors => CampusPalette.of(this);
}

/// 列表卡片统一的白面、极轻描边和柔和投影，让卡片从画布上浮起来。
BoxDecoration campusCardDecoration(
  BuildContext context, {
  double radius = 18,
  bool elevated = true,
  Color? color,
}) {
  final campus = campusPalette(context);
  return BoxDecoration(
    color: color ?? campus.surface,
    borderRadius: BorderRadius.circular(radius),
    border: Border.all(color: campus.cardBorder, width: .5),
    boxShadow: elevated
        ? [
            BoxShadow(
              color: campus.shadow,
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ]
        : null,
  );
}

/// 缓存上一份父主题对应的校园主题。
///
/// `ColorScheme.fromSeed` 要做一整套色彩空间换算，校园页每次 setState
/// （筛选、加载、滚动）都会请求主题；按父主题引用缓存后，只有真正切换
/// 主题时才重新生成。
ThemeData? _cachedCampusTheme;
ThemeData? _cachedCampusThemeParent;

/// 校园评分、二手和校园统一的白底石墨黑主题（深色下自动反转）。
///
/// 浅色时白色占大面积，黑色只用于文字、主按钮、选中态；深色时反过来，
/// 画布压到近黑、卡片抬一档、主按钮变成浅墨色。
ThemeData campusTheme(BuildContext context) {
  final parent = Theme.of(context);
  final cached = _cachedCampusTheme;
  if (cached != null && identical(parent, _cachedCampusThemeParent)) {
    return cached;
  }
  final theme = _buildCampusTheme(context, parent.brightness);
  _cachedCampusTheme = theme;
  _cachedCampusThemeParent = parent;
  return theme;
}

ThemeData _buildCampusTheme(BuildContext context, Brightness brightness) {
  final dark = brightness == Brightness.dark;
  final campus = dark ? CampusPalette.dark : CampusPalette.light;
  final scheme =
      ColorScheme.fromSeed(
        seedColor: campus.ink,
        brightness: brightness,
      ).copyWith(
        primary: campus.ink,
        onPrimary: campus.onInk,
        primaryContainer: campus.controlSurface,
        onPrimaryContainer: campus.ink,
        secondary: campus.muted,
        onSecondary: campus.onInk,
        secondaryContainer: campus.controlSurface,
        onSecondaryContainer: campus.ink,
        tertiary: campus.muted,
        onTertiary: campus.onInk,
        tertiaryContainer: campus.controlSurface,
        onTertiaryContainer: campus.ink,
        surface: campus.surface,
        onSurface: campus.ink,
        onSurfaceVariant: campus.muted,
        surfaceContainerLow: campus.containerLow,
        surfaceContainer: campus.surface,
        surfaceContainerHigh: campus.controlSurface,
        surfaceContainerHighest: campus.containerHighest,
        outline: campus.outline,
        outlineVariant: campus.line,
        error: dark ? const Color(0xFFFF6B5E) : const Color(0xFF8F3D32),
        onError: dark ? const Color(0xFF20100E) : Colors.white,
      );
  final base = pageTheme(
    context,
    backgroundColor: campus.pageBackground,
    accent: campus.ink,
    brightness: brightness,
    colorScheme: scheme,
    surface: campus.surface,
    onSurface: campus.ink,
    onAccent: campus.onInk,
    inputFillColor: campus.controlSurface,
    controlTrackColor: campus.controlSurface,
    controlSelectedColor: campus.ink,
    controlSelectedForegroundColor: campus.onInk,
  );
  // pageTheme 已经把 PagePalette 注册进 extensions，这里只追加校园色板。
  return base.copyWith(
    extensions: [
      ...base.extensions.values.where((item) => item is! CampusPalette),
      campus,
    ],
  );
}

/// 在校园业务页面根节点应用统一的白底石墨黑主题，并让子页面在正确的
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
