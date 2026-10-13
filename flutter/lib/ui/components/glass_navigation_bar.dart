import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:liquid_glass_easy/liquid_glass_easy.dart';
import '../../core/platform/app_platform.dart';

import 'glass_surface.dart';

class GlassNavigationBar extends StatefulWidget {
  const GlassNavigationBar({
    super.key,
    required this.selectedIndex,
    required this.onSelected,
    required this.lightweight,
  }) : assert(selectedIndex >= 0 && selectedIndex < labels.length);
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final bool lightweight;
  static const labels = ['课表', '工具', '校园', '我的'];
  static const icons = [
    'assets/icons/navigation/nav-schedule.png',
    'assets/icons/navigation/nav-tools.png',
    'assets/icons/navigation/nav-ratings.png',
    'assets/icons/navigation/nav-profile-tab.png',
  ];
  // 图标沿用 Vue 项目的原资源；放大比例与原导航栏的透明留白校准一致。
  static const iconScales = [1.25, 1.5, 1.35, 1.17];

  @override
  State<GlassNavigationBar> createState() => _GlassNavigationBarState();
}

class _GlassNavigationBarState extends State<GlassNavigationBar> {
  Future<void>? _glassLoading;

  Future<void> _prepareGlass(BuildContext context) async {
    // 先解码原图标，再启用玻璃与选中动效，避免首屏图标延迟出现。
    await Future.wait<void>([
      LiquidGlassShaders.ensureLoaded(),
      for (final path in GlassNavigationBar.icons)
        precacheImage(AssetImage(path), context),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final highContrast = MediaQuery.highContrastOf(context);
    final textScaler = MediaQuery.textScalerOf(context);
    // 收紧图标和文字上下的留白；大字体仍按内容增高，避免裁切。
    final baseHeight = textScaler.scale(16) > 22 ? 72.0 : 60.0;
    final height = math.max(
      baseHeight,
      25 + 3 + textScaler.scale(11) * 1.4 + 12,
    );
    final canRefract =
        !isHarmonyOS &&
        !widget.lightweight &&
        !highContrast &&
        ui.ImageFilter.isShaderFilterSupported;

    Widget simpleBar({bool forceLightweight = false}) => Align(
      alignment: Alignment.bottomCenter,
      child: _SimpleGlassNavigationBar(
        selectedIndex: widget.selectedIndex,
        onSelected: widget.onSelected,
        lightweight: widget.lightweight || forceLightweight,
        height: height,
      ),
    );

    // 留出选中胶囊抬起的空间，与导航本体的上下留白分开计算。
    return SizedBox(
      height: height + 12,
      child: !canRefract || reduceMotion
          ? simpleBar()
          : FutureBuilder<void>(
              // 首次进入前加载一次；加载中或失败时仍可正常切换页面。
              future: _glassLoading ??= _prepareGlass(context),
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done ||
                    snapshot.hasError) {
                  return simpleBar(forceLightweight: true);
                }
                return _LiquidNavigationBar(
                  selectedIndex: widget.selectedIndex,
                  onSelected: widget.onSelected,
                  height: height,
                );
              },
            ),
    );
  }
}

class _LiquidNavigationBar extends StatelessWidget {
  const _LiquidNavigationBar({
    required this.selectedIndex,
    required this.onSelected,
    required this.height,
  });
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final double height;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final style = GlassSurface.liquidStyle(context);
    return LayoutBuilder(
      builder: (context, constraints) => Stack(
        children: [
          // 外层 SafeArea 已处理底部间距，避免库再次叠加安全区。
          MediaQuery.removePadding(
            context: context,
            removeBottom: true,
            child: ExcludeSemantics(
              child: LiquidGlassTabBar.withImpeller(
                key: const ValueKey('navigation-liquid'),
                width: constraints.maxWidth,
                height: height,
                margin: EdgeInsets.zero,
                selectedIndex: selectedIndex,
                onChanged: onSelected,
                style: style.copyWith(
                  appearance: style.appearance.copyWith(
                    shadow: const LiquidGlassShadow(blur: 12, opacity: .12),
                  ),
                ),
                itemStyle: LiquidGlassTabItemStyle(
                  selectedColor: scheme.primary,
                  unselectedColor: scheme.onSurfaceVariant,
                  iconSize: 25,
                  labelFontSize: 11,
                  iconLabelGap: 3,
                  selectedFontWeight: FontWeight.w700,
                ),
                pillStyle: LiquidGlassTabPillStyle(
                  mode: LiquidGlassPillMode.impellerOnly,
                  growHeight: 8,
                  travelStiffness: 320,
                  travelDamping: 36,
                  // 去掉额外放大镜层，避免为装饰再叠一层折射。
                  magnifierPill: const LiquidGlassTabMagnifierPillStyle(
                    enabled: false,
                  ),
                  rest: LiquidGlassStyle(
                    appearance: LiquidGlassAppearance(
                      color: scheme.primary.withValues(alpha: .12),
                    ),
                  ),
                ),
                items: [
                  for (
                    var index = 0;
                    index < GlassNavigationBar.labels.length;
                    index++
                  )
                    LiquidGlassTabBarItem(
                      label: GlassNavigationBar.labels[index],
                      iconBuilder: (context, icon) => _NavigationIcon(
                        index: index,
                        size: icon.size,
                        color: icon.color,
                      ),
                      labelBuilder: (context, label) => Text(
                        label.text!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: label.textStyle,
                      ),
                    ),
                ],
              ),
            ),
          ),
          // 库会重复绘制图标；单独提供完整语义，触摸与长按拖动仍交给库。
          Positioned(
            left: 6,
            right: 6,
            bottom: 6,
            height: height - 12,
            child: Row(
              children: [
                for (
                  var index = 0;
                  index < GlassNavigationBar.labels.length;
                  index++
                )
                  Expanded(
                    child: Semantics(
                      key: ValueKey('nav-$index'),
                      container: true,
                      selected: index == selectedIndex,
                      button: true,
                      label: GlassNavigationBar.labels[index],
                      onTap: () => onSelected(index),
                      child: const SizedBox.expand(),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SimpleGlassNavigationBar extends StatelessWidget {
  const _SimpleGlassNavigationBar({
    required this.selectedIndex,
    required this.onSelected,
    required this.lightweight,
    required this.height,
  });
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final bool lightweight;
  final double height;
  static const labels = GlassNavigationBar.labels;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return GlassSurface(
      lightweight: lightweight,
      child: SizedBox(
        height: height,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final width = (constraints.maxWidth - 12) / labels.length;
            return Stack(
              children: [
                // 只移动选中背景，切换时不重建玻璃轮廓。
                AnimatedPositioned(
                  duration: reduceMotion
                      ? Duration.zero
                      : const Duration(milliseconds: 220),
                  curve: Curves.easeOutCubic,
                  left: 6 + width * selectedIndex,
                  top: 6,
                  bottom: 6,
                  width: width,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(29),
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          scheme.primary.withValues(alpha: .16),
                          scheme.primary.withValues(alpha: .06),
                        ],
                      ),
                      border: Border.all(
                        color: scheme.primary.withValues(alpha: .08),
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: Row(
                    children: [
                      for (var index = 0; index < labels.length; index++)
                        Expanded(
                          child: Semantics(
                            selected: index == selectedIndex,
                            button: true,
                            label: labels[index],
                            child: Tooltip(
                              message: labels[index],
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  key: ValueKey('nav-$index'),
                                  borderRadius: BorderRadius.circular(29),
                                  onTap: () => onSelected(index),
                                  child: ExcludeSemantics(
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        _NavigationIcon(
                                          index: index,
                                          size: 25,
                                          color: index == selectedIndex
                                              ? scheme.primary
                                              : scheme.onSurfaceVariant,
                                        ),
                                        const SizedBox(height: 3),
                                        Text(
                                          labels[index],
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: index == selectedIndex
                                                ? FontWeight.w700
                                                : FontWeight.w500,
                                            color: index == selectedIndex
                                                ? scheme.primary
                                                : scheme.onSurfaceVariant,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _NavigationIcon extends StatelessWidget {
  const _NavigationIcon({
    required this.index,
    required this.size,
    required this.color,
  });
  final int index;
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) => RepaintBoundary(
    child: ClipRect(
      child: SizedBox(
        width: size,
        height: size,
        child: Transform.scale(
          scale: GlassNavigationBar.iconScales[index],
          child: Image.asset(
            GlassNavigationBar.icons[index],
            width: size,
            height: size,
            color: color,
            colorBlendMode: BlendMode.srcIn,
            fit: BoxFit.contain,
            excludeFromSemantics: true,
          ),
        ),
      ),
    ),
  );
}
