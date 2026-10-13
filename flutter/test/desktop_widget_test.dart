import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:chengxin_youyou/app/app.dart';
import 'package:chengxin_youyou/app/app_dependencies.dart';
import 'package:chengxin_youyou/core/config/app_settings.dart';
import 'package:chengxin_youyou/core/platform/desktop_widgets.dart';
import 'package:chengxin_youyou/core/storage/app_storage.dart';
import 'package:chengxin_youyou/features/schedule/data/default_schedule_repository.dart';
import 'package:chengxin_youyou/features/schedule/data/schedule_local_store.dart';
import 'package:chengxin_youyou/features/schedule/data/schedule_repository.dart';
import 'package:chengxin_youyou/features/schedule/models/academic_calendar.dart';
import 'package:chengxin_youyou/features/schedule/models/course.dart';
import 'package:chengxin_youyou/features/schedule/models/desktop_widget_snapshot.dart';
import 'package:chengxin_youyou/features/schedule/models/local_course.dart';
import 'package:chengxin_youyou/features/schedule/presentation/desktop_widget_controller.dart';
import 'package:chengxin_youyou/features/schedule/presentation/desktop_widget_page.dart';
import 'package:chengxin_youyou/features/schedule/presentation/schedule_view_model.dart';
import 'package:chengxin_youyou/features/session/session.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes/desktop_widget_fakes.dart';
import 'fakes/fake_api.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final now = DateTime(2026, 10, 8, 8);

  Future<Map<String, Object?>> snapshot({
    List<LocalCourse> local = const [],
    String campus = '',
  }) async {
    final fixture = widgetFixture();
    return createDesktopWidgetSnapshot(
      calendar: widgetCalendar(),
      semester: widgetSemester,
      table: fixture.table,
      order: await widgetOrder(fixture.table.courses, local),
      updatedAt: now,
      localCourses: local,
      campus: campus,
    );
  }

  List<Map> coursesOn(Map<String, Object?> data, String date) =>
      ((data['days'] as List).cast<Map>().firstWhere(
                (day) => day['date'] == date,
              )['courses']
              as List)
          .cast<Map>();

  test('课程摘要保留冲突、教学周与实验时间，不包含身份和登录信息', () async {
    final data = await snapshot();
    final today = coursesOn(data, '2026-10-08');
    expect(
      today.map((c) => c['name']),
      containsAll(['高等数学', '操作系统', '软件工程实验', '大学英语']),
    );
    expect(coursesOn(data, '2026-10-15').map((c) => c['name']), ['大学英语']);
    final experiment = today.firstWhere((course) => course['name'] == '软件工程实验');
    expect(experiment['time'], '14:15–15:20');
    expect(
      experiment['startMillis'],
      DateTime.utc(2026, 10, 8, 6, 15).millisecondsSinceEpoch,
    );
    final text = jsonEncode(data);
    expect(text.contains('StudentNo'), isFalse);
    expect(text.contains('Cookie'), isFalse);
    expect(text.contains('WIDGET-TEST'), isFalse);
    final directory = Directory('build/widget-tests')
      ..createSync(recursive: true);
    File('${directory.path}/snapshot.json').writeAsStringSync(text);
  });

  test('本机覆盖会替换原课，本机添加不会混入另一学期', () async {
    final data = await snapshot(
      local: const [
        LocalCourse(
          id: 'edit',
          targetId: 'math-4-1-2',
          semesterId: 'current',
          name: '修改后的数学',
          room: '新教室',
          day: 5,
          start: 3,
          end: 4,
          weeks: [5],
        ),
        LocalCourse(
          id: 'manual',
          semesterId: 'current',
          name: '本机课程',
          room: 'A101',
          day: 4,
          start: 7,
          end: 8,
          weeks: [5],
        ),
        LocalCourse(
          id: 'other',
          semesterId: 'history',
          name: '别的学期',
          room: 'A101',
          day: 4,
          start: 7,
          end: 8,
          weeks: [5],
        ),
      ],
    );
    expect(
      coursesOn(data, '2026-10-08').map((c) => c['name']),
      isNot(contains('高等数学')),
    );
    expect(
      coursesOn(data, '2026-10-08').map((c) => c['name']),
      contains('本机课程'),
    );
    expect(coursesOn(data, '2026-10-09').first['name'], '修改后的数学');
    expect(jsonEncode(data), isNot(contains('别的学期')));
  });

  test('校历缺失给出状态，不以浏览的教学周冒充真实日期', () async {
    final fixture = widgetFixture();
    final data = createDesktopWidgetSnapshot(
      calendar: AcademicCalendar([]),
      semester: widgetSemester,
      table: fixture.table,
      order: await widgetOrder(fixture.table.courses, []),
      updatedAt: now,
    );
    expect(data['status'], 'noCalendar');
    expect(data['days'], isEmpty);
  });

  test('浏览历史学期时仍生成本学期；切周不重复发布，本机修改能同步', () async {
    final repository = WidgetScheduleRepository();
    final storage = MemoryAppStorage();
    final local = ScheduleLocalStore(storage, 'local');
    await local.write(ScheduleLocalData(semesterId: 'history'));
    final vm = ScheduleViewModel(
      repository,
      widgetCalendar(),
      onSessionExpired: () {},
      now: () => now,
      localStore: local,
      orderBuilder: widgetOrder,
    );
    await vm.initialize();
    final platform = FakeDesktopWidgets();
    final controller = DesktopWidgetController(
      platform: platform,
      schedule: vm,
      campus: '',
      now: () => now,
    );
    await controller.synchronize();
    expect(controller.error, isNull);
    expect(platform.publications.last['semester'], widgetSemester.label);
    expect(vm.selectedSemester?.id, 'history');
    vm.selectWeek(12);
    await controller.synchronize();
    expect(platform.publications.length, 1);
    await vm.saveCourse(
      const LocalCourse(
        id: 'manual',
        semesterId: 'current',
        name: '新增课程',
        room: 'A101',
        day: 4,
        start: 7,
        end: 8,
        weeks: [5],
      ),
    );
    await controller.synchronize();
    expect(
      coursesOn(platform.publications.last, '2026-10-08').map((c) => c['name']),
      contains('新增课程'),
    );
    controller.dispose();
    vm.dispose();
  });

  test('主动同步更新页面和小组件，后续切周不能恢复旧课程', () async {
    final repository = WidgetScheduleRepository();
    final vm = ScheduleViewModel(
      repository,
      widgetCalendar(),
      onSessionExpired: () {},
      now: () => now,
      orderBuilder: widgetOrder,
    );
    await vm.initialize();
    final platform = FakeDesktopWidgets();
    final controller = DesktopWidgetController(
      platform: platform,
      schedule: vm,
      campus: '',
      now: () => now,
    );
    await controller.synchronize();
    repository.loader = (_) async => ScheduleSnapshot(
      CourseTable(
        semesterId: 'current',
        weekCount: 20,
        sectionsPerDay: 12,
        courses: [
          Course(
            id: 'updated',
            name: '更新后的课程',
            activities: [
              CourseActivity(
                day: 4,
                start: 3,
                end: 4,
                room: 'A101',
                weeks: [5],
              ),
            ],
          ),
        ],
      ),
      now.add(const Duration(hours: 1)),
    );
    await controller.synchronize(refresh: true);
    expect(vm.snapshot!.table.courses.single.name, '更新后的课程');
    vm.selectWeek(12);
    await controller.synchronize();
    expect(
      coursesOn(platform.publications.last, '2026-10-08').map((c) => c['name']),
      ['更新后的课程'],
    );
    expect(controller.error, isNull);
    controller.dispose();
    vm.dispose();
  });

  test('退出期间返回的旧课表不能重新写入桌面', () async {
    final repository = WidgetScheduleRepository();
    final vm = ScheduleViewModel(
      repository,
      widgetCalendar(),
      onSessionExpired: () {},
      now: () => now,
      orderBuilder: widgetOrder,
    );
    await vm.selectSemester(widgetHistory);
    vm.semesters = [widgetSemester, widgetHistory];
    final response = Completer<ScheduleSnapshot>();
    repository.loader = (_) => response.future;
    final platform = FakeDesktopWidgets();
    final controller = DesktopWidgetController(
      platform: platform,
      schedule: vm,
      campus: '',
      now: () => now,
    );
    final task = controller.synchronize();
    controller.dispose();
    await platform.publish(desktopWidgetMessage('loggedOut', '登录后查看今日课程'));
    response.complete(widgetFixture());
    await task;
    expect(platform.publications.length, 1);
    expect(platform.publications.last['status'], 'loggedOut');
    vm.dispose();
  });

  test('桌面读取本学期旧缓存不受页面最新浏览学期影响', () async {
    final api = FakeApi();
    final storage = MemoryAppStorage();
    final prefix = 'v1:${api.client.dio.options.baseUrl}:student:';
    await storage.write('${prefix}latestTable', 'history');
    await storage.write(
      '${prefix}table:current',
      jsonEncode({
        'table': widgetFixture().table.toJson(),
        'updatedAt': now.toIso8601String(),
      }),
    );
    final repository = DefaultScheduleRepository(
      api.client,
      storage,
      'student',
    );
    final result = await repository.loadForWidget('current');
    expect(result.fromCache, isTrue);
    expect(result.table.semesterId, 'current');
    expect(api.requests, isEmpty);
    api.client.dispose();
  });

  test('平台发布串行执行、重复内容去重，保存失败允许重试', () async {
    const channel = MethodChannel('chengxin_youyou/desktop_widgets');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    final blocked = Completer<void>();
    final calls = <String>[];
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call.arguments as String);
      if (calls.length == 1) await blocked.future;
      return null;
    });
    final platform = NativeDesktopWidgets();
    final ready = platform.publish(desktopWidgetMessage('ready', 'ready'));
    final clear = platform.publish(desktopWidgetMessage('loggedOut', 'clear'));
    await Future<void>.delayed(Duration.zero);
    expect(calls.length, 1);
    blocked.complete();
    await Future.wait([ready, clear]);
    await platform.publish(desktopWidgetMessage('loggedOut', 'clear'));
    expect(calls.length, 2);
    var attempts = 0;
    messenger.setMockMethodCallHandler(channel, (_) async {
      if (++attempts == 1) throw PlatformException(code: 'widget_storage');
      return null;
    });
    await expectLater(
      platform.publish(desktopWidgetMessage('ready', 'changed')),
      throwsA(isA<PlatformException>()),
    );
    await platform.publish(desktopWidgetMessage('ready', 'changed'));
    expect(attempts, 2);
    messenger.setMockMethodCallHandler(channel, null);
    channel.setMethodCallHandler(null);
  });

  testWidgets('小组件入口在窄屏大字体可用，不支持固定时提供手动添加方式', (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final platform = FakeDesktopWidgets()..pinSupported = false;
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(1.5)),
          child: child!,
        ),
        home: DesktopWidgetPage(platform: platform),
      ),
    );
    final add = find.byKey(const Key('desktop-widget-pin'));
    await tester.scrollUntilVisible(add, 200);
    await tester.tap(add);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.textContaining('当前桌面不支持直接添加'), 100);
    expect(find.textContaining('当前桌面不支持直接添加'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('退出清空桌面数据，点击小组件在未登录时仍显示登录页', (tester) async {
    final session = SessionViewModel(WidgetSessionRepository());
    await session.restore();
    final platform = FakeDesktopWidgets();
    final dependencies = AppDependencies(
      session: session,
      calendar: widgetCalendar(),
      settings: AppSettings(),
      desktopWidgets: platform,
      createScheduleRepository: (_) => WidgetScheduleRepository(),
    );
    await tester.pumpWidget(ChengxinApp(dependencies: dependencies));
    await tester.pumpAndSettle();
    await session.logout();
    await tester.pumpAndSettle();
    expect(platform.publications.last['status'], 'loggedOut');
    platform.onOpen!();
    await tester.pumpAndSettle();
    expect(find.text('登录教务账号'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    dependencies.dispose();
  });
}
