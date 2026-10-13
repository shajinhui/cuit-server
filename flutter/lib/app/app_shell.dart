import 'package:chengxin_youyou/core/config/app_settings.dart';
import 'package:chengxin_youyou/ui/components/glass_navigation_bar.dart';
import 'package:chengxin_youyou/ui/platform/native_tab_bar.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

class AppShell extends StatelessWidget {
  const AppShell({
    super.key,
    required this.navigationShell,
    required this.onScheduleActivated,
    this.hideBottomBar = false,
  });
  final StatefulNavigationShell navigationShell;
  final VoidCallback onScheduleActivated;
  final bool hideBottomBar;
  @override
  Widget build(BuildContext context) {
    final settings = context.watch<AppSettings>();
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    void onSelected(int index) {
      if (index == 0) onScheduleActivated();
      navigationShell.goBranch(index);
    }

    final Widget bottomBar;
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      bottomBar = NativeTabBar(
        selectedIndex: navigationShell.currentIndex,
        safeAreaBottom: bottomInset,
        onSelected: onSelected,
      );
    } else {
      bottomBar = SafeArea(
        top: false,
        minimum: const EdgeInsets.fromLTRB(24, 0, 24, 12),
        child: Center(
          heightFactor: 1,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 390),
            child: GlassNavigationBar(
              selectedIndex: navigationShell.currentIndex,
              lightweight: settings.lightweightGlass,
              onSelected: onSelected,
            ),
          ),
        ),
      );
    }

    return Scaffold(
      extendBody: true,
      body: navigationShell,
      // 功能详情页使用返回栏；校园跑有自己的三个导航入口。
      bottomNavigationBar: hideBottomBar ? null : bottomBar,
    );
  }
}
