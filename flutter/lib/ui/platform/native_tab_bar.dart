import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// 在 iOS 上使用系统 UITabBar，其余平台继续使用 Flutter 导航栏。
class NativeTabBar extends StatefulWidget {
  const NativeTabBar({
    super.key,
    required this.selectedIndex,
    required this.safeAreaBottom,
    required this.onSelected,
  });

  final int selectedIndex;
  final double safeAreaBottom;
  final ValueChanged<int> onSelected;

  @override
  State<NativeTabBar> createState() => _NativeTabBarState();
}

class _NativeTabBarState extends State<NativeTabBar> {
  static const _viewType = 'chengxin_youyou/native_tab_bar';
  MethodChannel? _channel;

  void _onPlatformViewCreated(int viewId) {
    final channel = MethodChannel('$_viewType/$viewId');
    _channel = channel;
    channel.setMethodCallHandler(_handleNativeCall);
    unawaited(_setSelectedIndex());
  }

  Future<void> _handleNativeCall(MethodCall call) async {
    if (call.method != 'onSelect' || call.arguments is! int) return;
    widget.onSelected(call.arguments as int);
  }

  Future<void> _setSelectedIndex() async {
    final channel = _channel;
    if (channel == null) return;

    try {
      await channel.invokeMethod<void>(
        'setSelectedIndex',
        widget.selectedIndex,
      );
    } on PlatformException {
      // 原生视图刚创建时可能还未准备好；下次路由更新时会再次同步。
    }
  }

  @override
  void didUpdateWidget(covariant NativeTabBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedIndex != widget.selectedIndex ||
        oldWidget.safeAreaBottom != widget.safeAreaBottom) {
      unawaited(_setSelectedIndex());
    }
  }

  @override
  void dispose() {
    _channel?.setMethodCallHandler(null);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      // 把底部安全区也交给 UIKit，由 UITabBar 自己放置图标和背景。
      height: 50 + widget.safeAreaBottom,
      child: UiKitView(
        viewType: _viewType,
        onPlatformViewCreated: _onPlatformViewCreated,
      ),
    );
  }
}
