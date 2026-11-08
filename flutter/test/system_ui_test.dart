import 'package:chengxin_youyou/ui/theme/app_system_ui.dart';
import 'package:chengxin_youyou/ui/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('浅色主题下系统栏透明、图标为深色', () {
    final style = appSystemUiStyle(Brightness.light);
    // 默认值 0x40000000 / 0xFF000000 就是顶部灰影和底部黑边的来源。
    expect(style.statusBarColor, Colors.transparent);
    expect(style.systemNavigationBarColor, Colors.transparent);
    expect(style.systemNavigationBarDividerColor, Colors.transparent);
    expect(style.statusBarIconBrightness, Brightness.dark);
    expect(style.systemNavigationBarIconBrightness, Brightness.dark);
    expect(style.statusBarBrightness, Brightness.light);
    // 安卓 10+ 给透明系统栏加的对比蒙层会把边缘重新变灰。
    expect(style.systemStatusBarContrastEnforced, isFalse);
    expect(style.systemNavigationBarContrastEnforced, isFalse);
  });

  test('深色主题下系统栏仍然透明、图标换成浅色', () {
    final style = appSystemUiStyle(Brightness.dark);
    expect(style.statusBarColor, Colors.transparent);
    expect(style.systemNavigationBarColor, Colors.transparent);
    expect(style.statusBarIconBrightness, Brightness.light);
    expect(style.systemNavigationBarIconBrightness, Brightness.light);
    expect(style.statusBarBrightness, Brightness.dark);
  });

  testWidgets('应用根节点按当前主题下发系统栏样式', (tester) async {
    for (final brightness in Brightness.values) {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.build(brightness),
          builder: (context, child) =>
              AppSystemUiOverlay(child: child ?? const SizedBox.shrink()),
          home: const Scaffold(body: SizedBox.expand()),
        ),
      );
      await tester.pumpAndSettle();

      final regions = tester
          .widgetList<AnnotatedRegion<SystemUiOverlayStyle>>(
            find.byType(AnnotatedRegion<SystemUiOverlayStyle>),
          )
          .toList();
      expect(regions, isNotEmpty);

      final style = regions
          .map((region) => region.value)
          .firstWhere((value) => value.statusBarColor == Colors.transparent);
      expect(style.systemNavigationBarColor, Colors.transparent);
      expect(style.systemNavigationBarContrastEnforced, isFalse);
      expect(
        style.statusBarIconBrightness,
        brightness == Brightness.dark ? Brightness.light : Brightness.dark,
      );
    }
  });
}
