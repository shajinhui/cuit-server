import 'package:chengxin_youyou/app/app.dart';
import 'package:chengxin_youyou/features/tools/presentation/tools_page.dart';
import 'package:chengxin_youyou/ui/components/glass_navigation_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes/campus_preview_repository.dart';
import 'fakes/test_dependencies.dart';

void main() {
  for (final scale in [1.0, 2.0, 3.0]) {
    testWidgets('安卓工具首页 320 宽、$scale 倍字体：入口名称完整，末行可见', (tester) async {
      _androidScreen(tester, scale: scale, bottom: 48);
      final dependencies = (await tester.runAsync(testDependencies))!;
      await dependencies.settings.setLightweightGlass(true);
      dependencies.session.enterDemo();
      await tester.pumpWidget(ChengxinApp(dependencies: dependencies));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('nav-1')));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      final scroll = find.descendant(
        of: find.byType(ToolsPage),
        matching: find.byType(CustomScrollView),
      );
      final scrollable = find
          .descendant(of: scroll, matching: find.byType(Scrollable))
          .first;
      for (final entry in {
        'classrooms': '查空教室',
        'autorun': '校园跑与俱乐部',
        'library': '图书馆',
      }.entries) {
        final card = find.byKey(ValueKey('tool-card-${entry.key}'));
        await tester.scrollUntilVisible(card, 100, scrollable: scrollable);
        await tester.pumpAndSettle();
        final label = find.descendant(
          of: card,
          matching: find.text(entry.value),
        );
        expect(
          tester.renderObject<RenderParagraph>(label).didExceedMaxLines,
          isFalse,
          reason: '${entry.value}不能被省略',
        );
        expect(tester.takeException(), isNull);
      }
      await tester.drag(scroll, const Offset(0, -2000));
      await tester.pumpAndSettle();
      final last = find.byKey(const ValueKey('tool-card-library'));
      expect(
        tester.getBottomLeft(last).dy,
        lessThan(tester.getTopLeft(find.byType(GlassNavigationBar)).dy),
      );
      await tester.pumpWidget(const SizedBox.shrink());
      dependencies.dispose();
    }, variant: TargetPlatformVariant.only(TargetPlatform.android));
  }

  testWidgets('安卓各首页在大字体与底部安全区下可以切换和滚动', (tester) async {
    _androidScreen(tester, scale: 2, bottom: 48);
    final dependencies = (await tester.runAsync(
      () => testDependencies(campusRepository: CampusPreviewRepository()),
    ))!;
    await dependencies.settings.setLightweightGlass(true);
    dependencies.session.enterDemo();
    await tester.pumpWidget(ChengxinApp(dependencies: dependencies));
    await tester.pumpAndSettle();
    for (final tab in [2, 3, 0]) {
      await tester.tap(find.byKey(ValueKey('nav-$tab')));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: '首页 $tab');
    }
    await tester.pumpWidget(const SizedBox.shrink());
    dependencies.dispose();
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));
}

void _androidScreen(
  WidgetTester tester, {
  required double scale,
  required double bottom,
}) {
  tester.view.physicalSize = const Size(320, 568);
  tester.view.devicePixelRatio = 1;
  tester.view.padding = FakeViewPadding(top: 24, bottom: bottom);
  tester.platformDispatcher.textScaleFactorTestValue = scale;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPadding);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
}
