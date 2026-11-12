import 'package:chengxin_youyou/app/app.dart';
import 'package:chengxin_youyou/features/schedule/presentation/widgets/course_grid.dart';
import 'package:chengxin_youyou/features/schedule/presentation/widgets/schedule_week_strip.dart';
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
    testWidgets('安卓课表在 ${size.width.toInt()} 宽屏幕：头部只占一行、课表从导航后面穿过', (
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
      // 周次现在只保留文字和下拉箭头，不再有玻璃底；日期仍需完整显示在它上方。
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
      // 导航是浮在内容上的一层玻璃：课表要一直铺到屏幕底边，从导航后面
      // 穿过去。旧版按「屏高 − 导航高」压缩网格，课程色块会在导航上沿被
      // 切一刀，看起来像页面到那里就结束了。
      expect(tester.getBottomLeft(scroll).dy, size.height);
      expect(tester.getBottomLeft(grid).dy, greaterThan(navigationTop));
      if (size.height >= 800) {
        final section11 = find.descendant(of: grid, matching: find.text('11'));
        expect(
          tester.getBottomLeft(section11).dy,
          lessThanOrEqualTo(size.height),
        );
      }

      await tester.drag(
        find.byKey(const PageStorageKey('schedule-scroll')),
        const Offset(0, -1000),
      );
      await tester.pumpAndSettle();
      final navigationScope = AutoHideNavigationScope.maybeOf(
        tester.element(find.byType(CourseGrid)),
      );
      expect(navigationScope?.visible, isFalse);
      // 底部滚动余量要真的存在：滑到底时最后一节完整落在安全区上方，
      // 而不是永远被导航压住。
      final position = tester
          .state<ScrollableState>(
            find.descendant(of: scroll, matching: find.byType(Scrollable)),
          )
          .position;
      expect(position.pixels, greaterThan(0));
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

  testWidgets('课表左右滑动切换上一周和下一周', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    tester.view.padding = const FakeViewPadding(top: 24, bottom: 24);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPadding);

    final dependencies = (await tester.runAsync(testDependencies))!;
    await dependencies.settings.setLightweightGlass(true);
    dependencies.session.enterDemo();
    await tester.pumpWidget(ChengxinApp(dependencies: dependencies));
    await tester.pumpAndSettle();
    final vm = dependencies.schedule!;
    vm.selectWeek(vm.weekCount > 1 ? 2 : 1);
    await tester.pumpAndSettle();

    final grid = find.byKey(const PageStorageKey('schedule-scroll'));
    final pageController = tester
        .widget<PageView>(find.byType(PageView))
        .controller!;
    expect(pageController.page, closeTo(1, .01));

    final gesture = await tester.startGesture(tester.getCenter(grid));
    for (var step = 0; step < 4; step++) {
      await gesture.moveBy(const Offset(65, 0));
      await tester.pump();
    }
    // 拖动过程中页码要跟着手指移动，而不是松手后才切页。
    expect(pageController.page, greaterThan(0));
    expect(pageController.page, lessThan(1));
    await gesture.up();
    await tester.pumpAndSettle();
    // 未越过一半时松手会弹回原周。
    expect(vm.selectedWeek, 2);

    await tester.fling(grid, const Offset(260, 0), 1200);
    await tester.pump(const Duration(milliseconds: 80));
    // 日期条和课程网格作为同一页一起参与横向切换动画。
    expect(find.byType(ScheduleWeekStrip), findsNWidgets(2));
    expect(find.byKey(const Key('schedule-grid')), findsNWidgets(2));
    await tester.pumpAndSettle();
    expect(vm.selectedWeek, 1);

    await tester.fling(grid, const Offset(-260, 0), 1200);
    await tester.pumpAndSettle();
    expect(vm.selectedWeek, 2);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
    dependencies.dispose();
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

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

  testWidgets('宽屏课表：去掉当前周徽标后日期与操作按钮不重叠', (tester) async {
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
    vm.selectWeek(12);
    await tester.pumpAndSettle();
    expect(vm.currentWeek, isNotNull);
    expect(vm.selectedWeek == vm.currentWeek, isFalse);

    expect(find.textContaining('当前为第'), findsNothing);
    final dateRect = tester.getRect(find.text(vm.dateTitle));
    for (final label in ['添加课程', '重新同步课表', '更多操作']) {
      final button = find.byTooltip(label);
      expect(tester.getRect(button).left, greaterThanOrEqualTo(dateRect.right));
    }
    expect(
      tester.getRect(find.byKey(const Key('selected-week'))).top,
      greaterThan(dateRect.bottom),
    );
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
    dependencies.dispose();
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));
}
