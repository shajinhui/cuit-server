import 'package:chengxin_youyou/features/schedule/platform/schedule_order_builder.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:chengxin_youyou/app/app.dart';
import 'package:chengxin_youyou/features/schedule/data/demo_schedule_repository.dart';
import 'package:chengxin_youyou/features/schedule/models/schedule_layout.dart';
import 'package:chengxin_youyou/features/schedule/models/course.dart';
import 'package:chengxin_youyou/features/schedule/presentation/widgets/course_grid.dart';

import 'fakes/test_dependencies.dart';

void main() {
  testWidgets('登录校验和后端错误清晰可见', (tester) async {
    tester.view.physicalSize = const Size(390, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final dependencies = (await tester.runAsync(testDependencies))!;
    await tester.pumpWidget(ChengxinApp(dependencies: dependencies));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('login-submit')));
    await tester.tap(find.byKey(const Key('login-submit')));
    await tester.pumpAndSettle();
    expect(find.text('请输入学号'), findsOneWidget);
    expect(find.text('请输入密码'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('student-number')), '20260001');
    await tester.enterText(find.byKey(const Key('password')), 'test-only');
    await tester.ensureVisible(find.byKey(const Key('login-submit')));
    await tester.tap(find.byKey(const Key('login-submit')));
    await tester.pumpAndSettle();
    expect(find.text('学号或密码错误'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    dependencies.dispose();
  });

  testWidgets('体验流程：选周、课程详情、返回课表重置周次、退出回登录', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final dependencies = (await tester.runAsync(testDependencies))!;
    await tester.pumpWidget(ChengxinApp(dependencies: dependencies));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('demo-entry')));
    await tester.tap(find.byKey(const Key('demo-entry')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('schedule-grid')), findsOneWidget);
    await tester.tap(find.byKey(const Key('selected-week')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('week-option-3')));
    await tester.pumpAndSettle();
    expect(dependencies.schedule!.selectedWeek, 3);
    await tester.tap(find.byKey(const Key('course-demo-lesson-001-1-1-2')));
    await tester.pumpAndSettle();
    expect(find.text('演示老师甲'), findsOneWidget);
    await tester.tap(find.byTooltip('关闭课程详情'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('nav-1')));
    await tester.pumpAndSettle();
    expect(find.text('校园工具'), findsOneWidget);
    await tester.tap(find.byKey(const Key('nav-0')));
    await tester.pumpAndSettle();
    expect(dependencies.schedule!.selectedWeek, 1);
    await tester.tap(find.byKey(const Key('nav-3')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('profile-plan-completion')));
    await tester.pumpAndSettle();
    expect(find.text('学业完成情况'), findsOneWidget);
    expect(find.byKey(const Key('nav-3')), findsNothing);
    await tester.tap(find.byTooltip('返回'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('profile-feedback')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('feedback-content')), findsOneWidget);
    await tester.tap(find.byTooltip('返回'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('lightweight-glass')));
    await tester.tap(find.byKey(const Key('lightweight-glass')));
    await tester.pumpAndSettle();
    expect(dependencies.settings.lightweightGlass, isTrue);
    await tester.ensureVisible(find.byKey(const Key('logout')));
    await tester.tap(find.byKey(const Key('logout')));
    await tester.pumpAndSettle();
    expect(find.text('登录教务账号'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    dependencies.dispose();
  });

  testWidgets('工具入口可以打开对应的工具页并返回', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final dependencies = (await tester.runAsync(testDependencies))!;
    dependencies.session.enterDemo();
    await tester.pumpWidget(ChengxinApp(dependencies: dependencies));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('nav-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('tool-card-grades')));
    await tester.pumpAndSettle();
    expect(find.text('查成绩'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.byTooltip('返回工具页'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('tool-search')), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    dependencies.dispose();
  });

  testWidgets('小屏和大字体不会溢出，深色模式可切换', (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 1.5;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final dependencies = (await tester.runAsync(testDependencies))!;
    await tester.pumpWidget(ChengxinApp(dependencies: dependencies));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    dependencies.session.enterDemo();
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await dependencies.settings.setThemeMode(ThemeMode.dark);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    dependencies.dispose();
  });

  testWidgets('单节重叠课程在大字体下不溢出', (tester) async {
    final activity = CourseActivity(
      day: 1,
      start: 1,
      end: 1,
      weeks: [1],
      room: '实验楼203',
    );
    final course = Course(id: 'a', name: '单节课程', activities: [activity]);
    final order = await prepareScheduleOrder([course], []);
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(1.5)),
          child: Scaffold(
            body: SizedBox(
              width: 320,
              child: SizedBox(
                height: 568,
                child: CourseGrid(
                  blocks: groupCourseBlocks(
                    buildScheduleEntries([course], 1, order: order),
                    1,
                    order,
                  ),
                  opacity: .48,
                  semester: DemoScheduleRepository.semester,
                  rowCount: 12,
                  campus: '航空港',
                  onCourse: (_) {},
                ),
              ),
            ),
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
  });
  testWidgets('本机课程添加、修改、配色、删除及日历预览', (tester) async {
    tester.view.physicalSize = const Size(402, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final dependencies = (await tester.runAsync(testDependencies))!;
    dependencies.session.enterDemo();
    await tester.pumpWidget(ChengxinApp(dependencies: dependencies));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('添加课程'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('course-name')), '本机自习');
    await tester.enterText(find.byKey(const Key('course-room')), '图书馆');
    // 周日没有演示课，避免与当日默认的第 1–2 节课程合并成冲突时段。
    await tester.tap(find.byKey(const ValueKey('星期')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('周日'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('save-course')));
    await tester.pumpAndSettle();
    final vm = dependencies.schedule!;
    final id = vm.manualCourses.single.id;
    await tester.tap(find.byKey(Key('course-$id')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('课程颜色'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byTooltip('松针绿'));
    await tester.tap(find.byTooltip('松针绿'));
    await tester.pumpAndSettle();
    expect(vm.local.colors[vm.selectedSemester!.id]![id], 14);
    await tester.ensureVisible(find.text('修改课程'));
    await tester.tap(find.text('修改课程'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('course-name')), '改后的自习');
    await tester.tap(find.byKey(const Key('save-course')));
    await tester.pumpAndSettle();
    expect(vm.manualCourses.single.name, '改后的自习');
    await tester.tap(find.byKey(Key('course-$id')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('删除本机课程'));
    await tester.tap(find.text('删除本机课程'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('确认删除'));
    await tester.pumpAndSettle();
    expect(vm.manualCourses, isEmpty);
    await tester.tap(find.byTooltip('更多操作'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('导入系统日历'));
    await tester.pumpAndSettle();
    expect(find.text('生成并导入'), findsOneWidget);
    expect(find.textContaining('门课程，生成'), findsOneWidget);
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    dependencies.dispose();
  });
}
