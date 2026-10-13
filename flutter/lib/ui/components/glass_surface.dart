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
        color: dark ? const Color(0x8F232832) : const Color(0x66FFFFFF),
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
            sigmaX: highContrast ? 0 : 10,
            sigmaY: highContrast ? 0 : 10,
          ),
          child: ColoredBox(
            color: highContrast
                ? (dark ? const Color(0xFF232832) : Colors.white)
                : (dark ? const Color(0xB8232832) : const Color(0x99FFFFFF)),
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
            color: Colors.black.withValues(alpha: dark ? .22 : .09),
            blurRadius: 28,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        children: [
          surface,
          Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(34),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: dark ? .16 : .8),
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
