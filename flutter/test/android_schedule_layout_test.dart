import 'package:chengxin_youyou/app/app.dart';
import 'package:chengxin_youyou/features/schedule/presentation/widgets/course_grid.dart';
import 'package:chengxin_youyou/ui/components/auto_hide_scaffold.dart';
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
      final bottomInset = size.width == 320 ? 0.0 : 24.0;
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      tester.view.padding = FakeViewPadding(top: 24, bottom: bottomInset);
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

      final scrollViewportBottomBefore = tester.getBottomLeft(scroll).dy;
      await tester.drag(
        find.byKey(const PageStorageKey('schedule-scroll')),
        const Offset(0, -1000),
      );
      await tester.pumpAndSettle();
      final navigationScope = AutoHideNavigationScope.maybeOf(
        tester.element(find.byType(CourseGrid)),
      );
      expect(navigationScope?.visible, isFalse);
      // 导航收起后视口要真正铺到系统安全区上方，不能继续预留整条导航高度。
      expect(
        tester.getBottomLeft(scroll).dy,
        greaterThan(scrollViewportBottomBefore),
      );
      final lastSection = find.descendant(
        of: grid,
        matching: find.text('${vm.sectionCount}'),
      );
      expect(
        tester.getBottomLeft(lastSection).dy,
        lessThanOrEqualTo(size.height - bottomInset + .5),
      );
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

  testWidgets('系统栏透明后课表背景铺到顶部和底部，导航胶囊避让三键系统栏', (tester) async {
    const size = Size(360, 800);
    const topInset = 24.0;
    // 三键导航的系统栏比手势导航高得多，最容易露出黑边。
    const bottomInset = 48.0;
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    tester.view.padding = const FakeViewPadding(
      top: topInset,
      bottom: bottomInset,
    );
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPadding);

    final dependencies = (await tester.runAsync(testDependencies))!;
    await dependencies.settings.setLightweightGlass(true);
    dependencies.session.enterDemo();
    await tester.pumpWidget(ChengxinApp(dependencies: dependencies));
    await tester.pumpAndSettle();

    // 课表背景由页面自己绘制，必须覆盖到屏幕上下边缘：
    // 任何一端缩进系统栏，透明系统栏后面就会透出窗口底色，看起来就是黑边/灰边。
    final backdrop = find.byWidgetPredicate(
      (widget) =>
          widget is ColoredBox && widget.color == const Color(0xffc9d5e7),
    );
    expect(backdrop, findsOneWidget);
    expect(tester.getRect(backdrop), Offset.zero & size);

    // 状态栏区域透明，但头部仍要躲在状态栏下方，不能被时间电量压住。
    expect(
      tester.getTopLeft(find.text(dependencies.schedule!.dateTitle)).dy,
      greaterThanOrEqualTo(topInset),
    );

    // 导航胶囊整体位于系统导航栏之上，不再压着系统栏画。
    final barRect = tester.getRect(find.byType(GlassNavigationBar));
    expect(barRect.bottom, lessThanOrEqualTo(size.height - bottomInset));
    expect(barRect.right, lessThanOrEqualTo(size.width));
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
    dependencies.dispose();
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

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
