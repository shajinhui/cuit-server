import 'package:chengxin_youyou/features/schedule/models/schedule_order.dart';
import 'package:chengxin_youyou/features/schedule/data/demo_schedule_repository.dart';
import 'package:native_collator/native_collator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:integration_test/integration_test.dart';
import 'package:chengxin_youyou/app/app.dart';
import 'package:chengxin_youyou/core/storage/cache_storage.dart';

import '../test/fakes/test_dependencies.dart';

import 'package:chengxin_youyou/ui/platform/native_tab_bar.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('本机存储与完整体验流程', (tester) async {
    expect(
      await NativeCollator.sort([
        '物理',
        '高等数学',
        '大学英语',
        '操作系统',
        '软件工程',
        '数据结构',
      ], 'zh-CN'),
      ['操作系统', '大学英语', '高等数学', '软件工程', '数据结构', '物理'],
    );
    expect(await NativeCollator.sort(['AA\u0000BB', 'CC\u0000DD'], 'en-US'), [
      'AA\u0000BB',
      'CC\u0000DD',
    ]);
    final sample = (await DemoScheduleRepository().load(
      DemoScheduleRepository.semester.id,
    )).table;
    final values = ScheduleOrder.values(sample.courses, []).toList();
    expect(values, contains('DEMO101\u0000demo-lesson-001'));
    final ordered = await NativeCollator.sort(values, 'zh-CN');
    expect(ordered.toSet(), values.toSet());
    // 只使用独立测试键，不读取真实账号；演示页面不请求教务接口。
    const secure = FlutterSecureStorage();
    const testKey = 'integration:storage-roundtrip';
    try {
      await secure.write(key: testKey, value: 'test-session');
      expect(await secure.read(key: testKey), 'test-session');
    } finally {
      await secure.delete(key: testKey);
    }
    final cache = await createCacheStorage();
    try {
      await cache.write(testKey, 'test-course');
      expect(await cache.read(testKey), 'test-course');
    } finally {
      await cache.delete(testKey);
    }

    final dependencies = await testDependencies();
    await tester.pumpWidget(ChengxinApp(dependencies: dependencies));
    await tester.pumpAndSettle();
    await binding.takeScreenshot('ios-login');
    await tester.ensureVisible(find.byKey(const Key('demo-entry')));
    await tester.tap(find.byKey(const Key('demo-entry')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('schedule-grid')), findsOneWidget);
    dependencies.schedule!.selectWeek(1);
    await tester.pumpAndSettle();
    await binding.takeScreenshot('ios-schedule');
    await tester.tap(find.byKey(const Key('selected-week')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('week-option-3')));
    await tester.pumpAndSettle();
    expect(dependencies.schedule!.selectedWeek, 3);
    await tester.tap(find.byKey(const Key('course-demo-lesson-001-1-1-2')));
    await tester.pumpAndSettle();
    expect(find.text('演示老师甲'), findsOneWidget);
    await binding.takeScreenshot('ios-course-detail');
    await tester.tap(find.byTooltip('关闭课程详情'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('添加课程'));
    await tester.pumpAndSettle();
    await binding.takeScreenshot('ios-course-editor');
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('更多操作'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('导入系统日历'));
    await tester.pumpAndSettle();
    await binding.takeScreenshot('ios-calendar-export');
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    _selectBranch(tester, 2);
    await tester.pumpAndSettle();
    expect(find.text('校园'), findsOneWidget);
    _selectBranch(tester, 3);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('lightweight-glass')));
    await tester.tap(find.byKey(const Key('lightweight-glass')));
    await tester.pumpAndSettle();
    expect(dependencies.settings.lightweightGlass, isTrue);
    await dependencies.settings.setThemeMode(ThemeMode.dark);
    await tester.pumpAndSettle();
    _selectBranch(tester, 0);
    await tester.pumpAndSettle();
    await binding.takeScreenshot('ios-schedule-dark');
    _selectBranch(tester, 3);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('logout')));
    await tester.tap(find.byKey(const Key('logout')));
    await tester.pumpAndSettle();
    expect(find.text('登录教务账号'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    dependencies.dispose();
  });
}

void _selectBranch(WidgetTester tester, int index) {
  // 在原生视图中使用同一个 Dart 选中回调，真实 UIKit 触摸另行验收。
  tester.widget<NativeTabBar>(find.byType(NativeTabBar)).onSelected(index);
}
