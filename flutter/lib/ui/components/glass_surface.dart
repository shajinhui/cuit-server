import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:liquid_glass_easy/liquid_glass_easy.dart';
import '../../core/platform/app_platform.dart';

/// 玻璃库限定在 UI 组件中，业务页面不感知渲染器或插件版本。
class GlassSurface extends StatelessWidget {
  const GlassSurface({
    super.key,
    required this.child,
    this.lightweight = false,
  });
  final Widget child;
  final bool lightweight;

  /// 液态玻璃（shader 折射）路径的填充色。
  ///
  /// 折射本身已经能交代「这里有一块玻璃」，再叠一层厚白就只剩白块：
  /// 40% 白压在白卡片上是纯白，导航栏看上去像贴了一条背景。真实液态
  /// 玻璃只做很轻的提亮，这里收到 12%（深色压到 54%，否则黑上黑看不出
  /// 边界）。
  static Color _lensFill(bool dark) =>
      dark ? const Color(0x8A12151B) : const Color(0x1FFFFFFF);

  /// 降级路径（磨砂、鸿蒙、轻量模式）的填充色。
  ///
  /// 这条路径没有折射，全靠模糊撑住轮廓，填充太淡会糊成一片背景色，
  /// 所以比折射路径厚一些。
  static Color _fallbackFill(bool dark) =>
      dark ? const Color(0x9E1A1E26) : const Color(0x4DFFFFFF);

  /// 导航栏与普通玻璃表面共用材质；仅在 UI 层引用第三方类型。
  static LiquidGlassStyle liquidStyle(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return LiquidGlassStyle(
      shape: const LiquidGlassShape.roundedRectangle(
        cornerRadius: 34,
        borderWidth: 1,
        lightIntensity: .7,
      ),
      appearance: LiquidGlassAppearance(
        color: _lensFill(dark),
        // 模糊太强会把背后的内容抹成一片纯色（同样显得像背景块）。
        blur: const LiquidGlassBlur(sigmaX: 5, sigmaY: 5),
        saturation: 1.1,
      ),
      refraction: const LiquidGlassRefraction(
        distortion: .08,
        distortionWidth: 18,
        chromaticAberration: .002,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final highContrast = MediaQuery.highContrastOf(context);

    Widget surface;
    // 不支持实时折射时只模糊当前小区域，不截取整页来模拟折射。
    if (!isHarmonyOS &&
        !lightweight &&
        !highContrast &&
        ui.ImageFilter.isShaderFilterSupported) {
      surface = LiquidGlassLens(style: liquidStyle(context), child: child);
    } else {
      surface = ClipRRect(
        borderRadius: BorderRadius.circular(34),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(
            sigmaX: highContrast ? 0 : 8,
            sigmaY: highContrast ? 0 : 8,
          ),
          child: ColoredBox(
            color: highContrast
                ? (dark ? const Color(0xFF232832) : Colors.white)
                : _fallbackFill(dark),
            child: child,
          ),
        ),
      );
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(34),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: dark ? .34 : .12),
            blurRadius: 26,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Stack(
        children: [
          surface,
          Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                // 带圆角的边框只能四边同色，所以「上亮下暗」的厚度改用
                // 一层顶部受光渐变来画：玻璃上沿亮一线，往下快速消失。
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(34),
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.white.withValues(alpha: dark ? .10 : .34),
                      Colors.white.withValues(alpha: 0),
                      Colors.white.withValues(alpha: 0),
                      Colors.white.withValues(alpha: dark ? .02 : .05),
                    ],
                    stops: const [0, .35, .82, 1],
                  ),
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(34),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: dark ? .20 : .66),
                    width: 1,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
