import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

class _MeasureSize extends SingleChildRenderObjectWidget {
  const _MeasureSize({required this.onSize, super.child});

  final ValueChanged<Size> onSize;

  @override
  _RenderMeasureSize createRenderObject(BuildContext context) =>
      _RenderMeasureSize(onSize);

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderMeasureSize renderObject,
  ) {
    renderObject.onSize = onSize;
  }
}

class _RenderMeasureSize extends RenderProxyBox {
  _RenderMeasureSize(this.onSize);

  ValueChanged<Size> onSize;
  Size? _lastSize;

  @override
  void performLayout() {
    super.performLayout();
    final nextSize = size;
    if (_lastSize == nextSize) return;
    _lastSize = nextSize;
    WidgetsBinding.instance.addPostFrameCallback((_) => onSize(nextSize));
  }
}

/// 向页面暴露底部导航的可见状态和实际高度。
class AutoHideNavigationScope extends InheritedWidget {
  const AutoHideNavigationScope({
    super.key,
    required this.visible,
    required this.bottomBarHeight,
    required this.systemBottomInset,
    required super.child,
  });

  final bool visible;
  final double bottomBarHeight;

  /// 不含应用底部导航的系统安全区，导航收起后供页面铺到底部。
  final double systemBottomInset;

  static AutoHideNavigationScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AutoHideNavigationScope>();

  @override
  bool updateShouldNotify(AutoHideNavigationScope oldWidget) =>
      visible != oldWidget.visible ||
      bottomBarHeight != oldWidget.bottomBarHeight ||
      systemBottomInset != oldWidget.systemBottomInset;
}

/// 主页面滚动时自动收起底部导航，向上回滑后恢复。
///
/// `extendBody` 让页面保持在底部导航后方，这样导航滑出时不会引起内容
/// 重新布局。导航完全隐藏后也会移除点击和读屏焦点。
class AutoHideScaffold extends StatefulWidget {
  const AutoHideScaffold({
    super.key,
    required this.body,
    this.bottomNavigationBar,
    this.resetToken = 0,
  });

  final Widget body;
  final Widget? bottomNavigationBar;

  /// 切换底部 Tab 时更新，确保新页面回到顶部状态并重新显示导航。
  final int resetToken;

  @override
  State<AutoHideScaffold> createState() => _AutoHideScaffoldState();
}

class _AutoHideScaffoldState extends State<AutoHideScaffold> {
  static const _hiddenOffset = Offset(0, 1.15);
  static const _duration = Duration(milliseconds: 220);

  bool _visible = true;
  double _bottomBarHeight = 0;

  @override
  void didUpdateWidget(covariant AutoHideScaffold oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.resetToken != widget.resetToken ||
        (oldWidget.bottomNavigationBar == null &&
            widget.bottomNavigationBar != null)) {
      _visible = true;
    }
  }

  void _setVisible(bool visible) {
    if (_visible == visible) return;
    setState(() => _visible = visible);
  }

  bool _handleScroll(ScrollNotification notification) {
    if (widget.bottomNavigationBar == null) return false;
    if (notification.metrics.axis != Axis.vertical) return false;
    if (notification.metrics.pixels <= 0) {
      _setVisible(true);
      return false;
    }
    if (notification is! ScrollUpdateNotification) return false;
    final delta = notification.scrollDelta ?? 0;
    if (delta > 4) {
      _setVisible(false);
    } else if (delta < -4) {
      _setVisible(true);
    }
    return false;
  }

  void _measureBottomBar(Size size) {
    if (!mounted) return;
    final height = size.height;
    if ((height - _bottomBarHeight).abs() < .5) return;
    setState(() => _bottomBarHeight = height);
  }

  @override
  Widget build(BuildContext context) {
    final bar = widget.bottomNavigationBar;
    final systemBottomInset = MediaQuery.paddingOf(context).bottom;
    final animationDuration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : _duration;
    return Scaffold(
      extendBody: true,
      body: AutoHideNavigationScope(
        visible: _visible,
        bottomBarHeight: _bottomBarHeight,
        systemBottomInset: systemBottomInset,
        child: NotificationListener<ScrollNotification>(
          onNotification: _handleScroll,
          child: widget.body,
        ),
      ),
      bottomNavigationBar: bar == null
          ? null
          : ExcludeSemantics(
              excluding: !_visible,
              child: IgnorePointer(
                key: const ValueKey('auto-hide-navigation-pointer'),
                ignoring: !_visible,
                // 只用位移动画：安卓导航是实时采样的液态玻璃，外面再套一层
                // Opacity 会让每帧多一次 saveLayer，并在滚动时重新采样背景，
                // 正是滚动掉帧的主要来源。整条导航会完整滑出屏幕，不需要淡出。
                child: AnimatedSlide(
                  key: const ValueKey('auto-hide-navigation'),
                  offset: _visible ? Offset.zero : _hiddenOffset,
                  duration: animationDuration,
                  curve: Curves.easeOutCubic,
                  child: _MeasureSize(onSize: _measureBottomBar, child: bar),
                ),
              ),
            ),
    );
  }
}
