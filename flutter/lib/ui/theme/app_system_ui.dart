import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// 全局系统栏样式。
///
/// 安卓上 Flutter 的默认 overlay style 是「状态栏 25% 黑 + 导航栏纯黑」，
/// 只要页面把背景画到屏幕边缘，就会同时出现顶部一条灰黑遮罩和底部一条黑边。
/// 这里统一改成透明：页面自己的背景色直接铺满，两端的黑边随之消失。
SystemUiOverlayStyle appSystemUiStyle(Brightness brightness) {
  final dark = brightness == Brightness.dark;
  // 系统栏图标永远是「背景色的反色」：浅色页面配深色图标，深色页面配浅色图标。
  final iconBrightness = dark ? Brightness.light : Brightness.dark;
  return SystemUiOverlayStyle(
    // 状态栏
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: iconBrightness,
    // iOS 的 statusBarBrightness 表示状态栏底色，取值与图标亮度相反。
    statusBarBrightness: dark ? Brightness.dark : Brightness.light,
    // 安卓 10+ 会给透明状态栏自动叠一层对比蒙层，那层灰就是「顶部阴影」，
    // 关掉之后才是真正的透明。
    systemStatusBarContrastEnforced: false,
    // 导航栏
    systemNavigationBarColor: Colors.transparent,
    systemNavigationBarDividerColor: Colors.transparent,
    systemNavigationBarIconBrightness: iconBrightness,
    // 同一套对比蒙层在底部会变成灰带，一并关掉。
    systemNavigationBarContrastEnforced: false,
  );
}

/// 启动时把窗口切到「边到边」：内容画到系统栏下面，系统栏本身保持透明。
///
/// 安卓 15 起 targetSdk 35+ 会强制边到边，但 14 及以下仍需显式切换，
/// 否则窗口会自己缩在系统栏里面，透明导航栏反而露出启动背景色。
void configureAppSystemUi() {
  if (defaultTargetPlatform != TargetPlatform.android) return;
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  // 首帧之前先写一次，避免引擎把默认的黑色导航栏先画出来。
  SystemChrome.setSystemUIOverlayStyle(appSystemUiStyle(Brightness.light));
}

/// 把系统栏样式挂到整棵树上。
///
/// 应用里没有 AppBar（唯一的系统栏样式来源也没有），所以根节点上的注解
/// 就是最终生效值；主题切换时 `Theme.of` 变化会重建它，图标亮度跟着变。
class AppSystemUiOverlay extends StatelessWidget {
  const AppSystemUiOverlay({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => AnnotatedRegion<SystemUiOverlayStyle>(
    value: appSystemUiStyle(Theme.of(context).brightness),
    child: child,
  );
}
