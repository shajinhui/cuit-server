import 'package:chengxin_youyou/app/app.dart';
import 'package:chengxin_youyou/features/schedule/presentation/widgets/course_grid.dart';
import 'package:chengxin_youyou/ui/components/glass_navigation_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes/test_dependencies.dart';

void main() {
  for (final size in [
    const Size(320, 568),
    const Size(360, 800),
    const Size(440, 956),
  ]) {
    testWidgets('安卓课表在 ${size.width.toInt()} 宽屏幕：头部只占一行、节次不被导航遮挡', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      tester.view.padding = FakeViewPadding(
        top: 24,
        bottom: size.width == 320 ? 0 : 24,
      );
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPadding);
      if (size.width == 360) {
        // 导航会随系统字体增高，课表应使用实际高度，而不是固定预留值。
        tester.platformDispatcher.textScaleFactorTestValue = 2;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      }

      final dependencies = (await tester.runAsync(testDependencies))!;
      await dependencies.settings.setLightweightGlass(true);
      dependencies.session.enterDemo();
      await tester.pumpWidget(ChengxinApp(dependencies: dependencies));
      await tester.pumpAndSettle();
      final vm = dependencies.schedule!;
      vm.selectWeek(12);
      await tester.pumpAndSettle();

      final date = find.text(vm.dateTitle);
      final dateRect = tester.getRect(date);
      // 极窄屏靠 FittedBox 缩字号，而不是把日期截成省略号。
      expect(
        tester.renderObject<RenderParagraph>(date).didExceedMaxLines,
        isFalse,
      );
      final pill = find
          .ancestor(
            of: find.byKey(const Key('selected-week')),
            matching: find.byType(DecoratedBox),
          )
          .first;
      // 日期完整地压在周次胶囊上方：省高度靠胶囊下移，而不是让胶囊盖住日期。
      expect(tester.getRect(pill).top, greaterThanOrEqualTo(dateRect.bottom));
      expect(
        tester.getRect(find.byKey(const Key('selected-week'))).top,
        greaterThan(dateRect.bottom),
      );
      for (final label in ['添加课程', '重新同步课表', '更多操作']) {
        final button = find.byTooltip(label);
        final rect = tester.getRect(button);
        // 触摸区与视觉玻璃同为 44：Material 默认的 48 触摸扩展会让安卓
        // 比 iOS 多占 12px 宽度，把日期挤到缩放。
        expect(rect.size, const Size(44, 44));
        expect(rect.left, greaterThanOrEqualTo(dateRect.right));
      }

      // 状态栏之下只有「头部 56 + 周条 64」两段；旧版安卓两行头部是 174，
      // 谁再把日期单开一行，就会在这里失败。
      expect(
        tester.getRect(find.byType(CourseGrid)).top,
        lessThanOrEqualTo(150.0),
      );

      final grid = find.byKey(const Key('schedule-grid'));
      final navigationTop = tester
          .getTopLeft(find.byType(GlassNavigationBar))
          .dy;
      final scroll = find.byKey(const PageStorageKey('schedule-scroll'));
      expect(tester.getBottomLeft(scroll).dy, lessThan(navigationTop));
      if (size.height >= 800) {
        final section11 = find.descendant(of: grid, matching: find.text('11'));
        expect(tester.getBottomLeft(section11).dy, lessThan(navigationTop));
        final time11 = find.descendant(
          of: grid,
          matching: find.text('20:25\n21:10'),
        );
        expect(tester.getBottomLeft(time11).dy, lessThan(navigationTop));
      }

      await tester.drag(
        find.byKey(const PageStorageKey('schedule-scroll')),
        const Offset(0, -1000),
      );
      await tester.pumpAndSettle();
      final lastSection = find.descendant(
        of: grid,
        matching: find.text('${vm.sectionCount}'),
      );
      expect(tester.getBottomLeft(lastSection).dy, lessThan(navigationTop));
      expect(tester.takeException(), isNull);

      await tester.tap(find.byKey(const Key('selected-week')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('week-option-3')));
      await tester.pumpAndSettle();
      expect(vm.selectedWeek, 3);
      await tester.pumpWidget(const SizedBox.shrink());
      dependencies.dispose();
    }, variant: TargetPlatformVariant.only(TargetPlatform.android));
  }

  testWidgets('宽屏课表：日期与「当前为第 N 周」并在同一行且不重叠', (tester) async {
    tester.view.physicalSize = const Size(800, 800);
    tester.view.devicePixelRatio = 1;
    tester.view.padding = FakeViewPadding(top: 24, bottom: 24);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPadding);

    final dependencies = (await tester.runAsync(testDependencies))!;
    await dependencies.settings.setLightweightGlass(true);
    dependencies.session.enterDemo();
    await tester.pumpWidget(ChengxinApp(dependencies: dependencies));
    await tester.pumpAndSettle();
    final vm = dependencies.schedule!;
    // 选到非当前周，徽标才会显示当前周次。
    vm.selectWeek(12);
    await tester.pumpAndSettle();
    expect(vm.currentWeek, isNotNull);
    expect(vm.selectedWeek == vm.currentWeek, isFalse);

    final dateRect = tester.getRect(find.text(vm.dateTitle));
    final badge = find.textContaining('当前为第');
    expect(badge, findsOneWidget);
    final badgeRect = tester.getRect(badge);
    expect(badgeRect.left, greaterThanOrEqualTo(dateRect.right));
    final pill = tester.getRect(
      find
          .ancestor(
            of: find.byKey(const Key('selected-week')),
            matching: find.byType(DecoratedBox),
          )
          .first,
    );
    expect(badgeRect.bottom, lessThanOrEqualTo(pill.top));
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
    dependencies.dispose();
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));
}
