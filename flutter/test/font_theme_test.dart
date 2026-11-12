import 'package:chengxin_youyou/ui/theme/app_theme.dart';
import 'package:chengxin_youyou/ui/theme/font_licenses.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('安卓主题使用内置 HarmonyOS Sans SC，iOS 保持系统字体', () {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    final android = AppTheme.build(Brightness.light);
    expect(
      android.textTheme.bodyMedium?.fontFamily,
      AppTheme.androidFontFamily,
    );
    expect(
      android.textTheme.titleLarge?.fontFamily,
      AppTheme.androidFontFamily,
    );
    // 大标题用 Light，正文/标签用 Regular。
    expect(
      android.textTheme.headlineSmall?.fontFamily,
      AppTheme.androidDisplayFontFamily,
    );
    expect(
      android.textTheme.bodyMedium?.fontFamily,
      AppTheme.androidFontFamily,
    );

    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    final ios = AppTheme.build(Brightness.light);
    expect(
      ios.textTheme.bodyMedium?.fontFamily,
      isNot(AppTheme.androidFontFamily),
    );
  });

  testWidgets('内置字体的许可出现在开源许可页', (tester) async {
    registerBundledFontLicenses();
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => showLicensePage(context: context),
              child: const Text('open licenses'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open licenses'));
    await tester.pumpAndSettle();
    expect(find.textContaining('HarmonyOS Sans'), findsWidgets);
  });
}
