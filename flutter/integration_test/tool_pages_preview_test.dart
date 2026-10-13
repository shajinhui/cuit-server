import 'package:chengxin_youyou/core/storage/app_storage.dart';
import 'package:chengxin_youyou/features/autorun/data/autorun_repository.dart';
import 'package:chengxin_youyou/features/tools/presentation/academic_tool_pages.dart';
import 'package:chengxin_youyou/features/tools/presentation/autorun_page.dart';
import 'package:chengxin_youyou/features/tools/presentation/calendar_page.dart';
import 'package:chengxin_youyou/features/tools/presentation/campus_map_page.dart';
import 'package:chengxin_youyou/features/tools/presentation/library_page.dart';
import 'package:chengxin_youyou/features/tools/presentation/past_exams_page.dart';
import 'package:chengxin_youyou/ui/components/page_selection.dart';
import 'package:chengxin_youyou/ui/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import '../test/fakes/tool_preview_api.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('在模拟器预览正式工具页并验证筛选、预约弹窗与切页', (tester) async {
    final api = toolPreviewApi();
    Future<void> show(
      Widget page, {
      bool dark = false,
      bool settle = true,
    }) async {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.build(dark ? Brightness.dark : Brightness.light),
          home: page,
        ),
      );
      if (settle) await tester.pumpAndSettle();
    }

    Future<void> capture(String name) async {
      await tester.pump();
      expect(tester.takeException(), isNull, reason: name);
      await binding.takeScreenshot('tools-$name');
    }

    await show(GradesPage(api: api.client));
    await capture('grades');
    await show(ExamsPage(api: api.client));
    await capture('exams');
    await show(ClassroomsPage(api: api.client));
    await capture('classrooms');
    await tester.tap(find.text('更多筛选'));
    await tester.pumpAndSettle();
    await capture('classrooms-filters');
    final buildingPicker = find.byWidgetPredicate(
      (widget) =>
          widget is PageDropdownField<String> &&
          widget.values.containsValue('全部教学楼'),
    );
    await tester.ensureVisible(buildingPicker);
    await tester.tap(buildingPicker);
    await tester.pumpAndSettle();
    await capture('classrooms-dropdown');
    await tester.tap(find.text('全部教学楼').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('完成'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('查询空教室'));
    await tester.pumpAndSettle();
    await capture('classrooms-results');
    await show(LibraryPage(api: api.client));
    await capture('library');
    await tester.tap(find.text('查询可预约座位'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('A-001'), 160);
    await capture('library-seats');
    await tester.tap(find.text('A-001'));
    await tester.pumpAndSettle();
    await capture('library-confirm');
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('我的预约'));
    await tester.pumpAndSettle();
    await capture('library-reservations');
    await show(const PastExamsPage());
    await capture('past-exams');
    await show(const CampusMapPage());
    await precacheImage(
      const AssetImage('assets/maps/campus-map-airport.jpg'),
      tester.element(find.byType(CampusMapPage)),
    );
    await tester.pumpAndSettle();
    await capture('campus-map');
    await show(const AcademicCalendarPage(), settle: false);
    // 教务处原图照常联网读取；不因网络等待阻塞其它页面预览。
    await Future<void>.delayed(const Duration(seconds: 3));
    await tester.pump();
    await capture('calendar');
    await show(GradesPage(api: api.client), dark: true);
    await capture('grades-dark');
    await tester.pumpWidget(const SizedBox.shrink());
    api.client.dispose();

    final runApi = toolPreviewApi();
    final repository = AutoRunRepository(
      MemoryAppStorage(),
      dio: runApi.client.dio,
    );
    await show(AutoRunPage(repository: repository));
    await capture('autorun-login');
    await tester.enterText(
      find.byKey(const Key('autorun-phone')),
      '13800138000',
    );
    await tester.enterText(
      find.byKey(const Key('autorun-password')),
      'preview-only',
    );
    await tester.tap(find.byKey(const Key('autorun-login')));
    await tester.pumpAndSettle();
    await capture('autorun');
    await tester.tap(find.byKey(const Key('autorun-tab-1')));
    await tester.pumpAndSettle();
    await capture('club');
    await tester.tap(find.byKey(const Key('autorun-tab-2')));
    await tester.pumpAndSettle();
    await capture('autorun-account');
    await tester.pumpWidget(const SizedBox.shrink());
    repository.dispose();
  });
}
