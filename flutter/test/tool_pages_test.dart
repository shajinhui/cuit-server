import 'package:chengxin_youyou/core/storage/app_storage.dart';
import 'package:chengxin_youyou/features/autorun/data/autorun_repository.dart';
import 'package:chengxin_youyou/features/tools/presentation/academic_tool_pages.dart';
import 'package:chengxin_youyou/features/tools/presentation/autorun_page.dart';
import 'package:chengxin_youyou/features/tools/presentation/calendar_page.dart';
import 'package:chengxin_youyou/features/tools/presentation/campus_map_page.dart';
import 'package:chengxin_youyou/features/tools/presentation/library_page.dart';
import 'package:chengxin_youyou/features/tools/presentation/past_exams_page.dart';
import 'package:chengxin_youyou/ui/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes/tool_preview_api.dart';

Widget _app(Widget page, {bool dark = false, double textScale = 1}) =>
    MaterialApp(
      theme: AppTheme.build(dark ? Brightness.dark : Brightness.light),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      home: page,
    );

void main() {
  testWidgets('空教室弹层选择校区后查询使用真实选项，并展示教学楼分组', (tester) async {
    final api = toolPreviewApi();
    addTearDown(api.client.dispose);
    await tester.pumpWidget(_app(ClassroomsPage(api: api.client)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('更多筛选'));
    await tester.pumpAndSettle();
    final campus = find.byKey(const ValueKey('校区-airport'));
    await tester.ensureVisible(campus);
    await tester.tap(campus);
    await tester.pumpAndSettle();
    await tester.tap(find.text('龙泉').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('完成'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('查询空教室'));
    await tester.pumpAndSettle();
    final query = api.requests
        .singleWhere(
          (request) => request.path.endsWith('/available-classrooms'),
        )
        .queryParameters;
    expect(query['campus_id'], 'longquan');
    expect(query['sections'], '1,2');
    expect(find.text('第一教学楼'), findsOneWidget);
    expect(find.text('A101'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('成绩明细保留分项，统计只计算已出成绩', (tester) async {
    final api = toolPreviewApi();
    addTearDown(api.client.dispose);
    await tester.pumpWidget(_app(GradesPage(api: api.client)));
    await tester.pumpAndSettle();
    expect(find.text('平时 92'), findsOneWidget);
    expect(find.text('期末 88'), findsOneWidget);
    expect(find.text('绩点 4.0'), findsOneWidget);
    expect(find.text('2 门'), findsOneWidget);
    expect(find.text('1 门'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('图书馆座位网格仍可预约，记录卡直接提供取消入口', (tester) async {
    tester.view.physicalSize = const Size(390, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final api = toolPreviewApi();
    addTearDown(api.client.dispose);
    await tester.pumpWidget(_app(LibraryPage(api: api.client)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('查询可预约座位'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('A-001'));
    await tester.tap(find.text('A-001'));
    await tester.pumpAndSettle();
    expect(find.text('确认座位预约'), findsOneWidget);
    await tester.enterText(find.byType(TextField), '课程自习');
    await tester.pump();
    await tester.tap(find.text('确认预约'));
    await tester.pumpAndSettle();
    final request = api.requests.singleWhere(
      (request) => request.method == 'POST',
    );
    expect(request.data['SeatID'], '1');
    expect(request.data['Memo'], '课程自习');
    await tester.tap(find.text('我的预约'));
    await tester.pumpAndSettle();
    expect(find.text('取消预约'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('工具二级页在 320 宽与 1.5 倍字体下无溢出，深色也可操作', (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final api = toolPreviewApi();
    addTearDown(api.client.dispose);
    final storage = MemoryAppStorage();
    await storage.write('autorun.session:https://example.test', 'preview-only');
    final runRepository = AutoRunRepository(storage, dio: api.client.dio);
    addTearDown(runRepository.dispose);
    for (final page in <Widget>[
      GradesPage(api: api.client),
      ExamsPage(api: api.client),
      ClassroomsPage(api: api.client),
      LibraryPage(api: api.client),
      const PastExamsPage(),
      const CampusMapPage(),
      const AcademicCalendarPage(),
      AutoRunPage(repository: runRepository),
    ]) {
      await tester.pumpWidget(_app(page, dark: true, textScale: 1.5));
      // 资源读取经过宿主异步 I/O；校历的联网等待不影响布局检查。
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      if (page is AcademicCalendarPage) {
        await tester.pump(const Duration(seconds: 1));
      } else {
        await tester.pumpAndSettle();
      }
      expect(
        tester.takeException(),
        isNull,
        reason: '${page.runtimeType} 小屏大字',
      );
      if (page is ClassroomsPage) {
        await tester.tap(find.text('更多筛选'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await tester.tap(find.text('完成'));
        await tester.pumpAndSettle();
      }
      if (page is LibraryPage) {
        await tester.scrollUntilVisible(find.text('查询可预约座位'), 150);
        await tester.pumpAndSettle();
        await tester.tap(find.text('查询可预约座位'));
        await tester.pumpAndSettle();
        await tester.scrollUntilVisible(find.text('A-001'), 150);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      }
      if (page is AutoRunPage) {
        await tester.tap(find.byKey(const Key('autorun-tab-1')));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      }
      await tester.pumpWidget(const SizedBox.shrink());
    }
  });
}
