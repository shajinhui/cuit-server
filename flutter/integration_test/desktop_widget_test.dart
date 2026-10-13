import 'dart:io';

import 'package:chengxin_youyou/app/app.dart';
import 'package:chengxin_youyou/app/app_dependencies.dart';
import 'package:chengxin_youyou/core/config/app_settings.dart';
import 'package:chengxin_youyou/core/platform/desktop_widgets.dart';
import 'package:chengxin_youyou/features/schedule/models/desktop_widget_snapshot.dart';
import 'package:chengxin_youyou/features/session/session.dart';
import 'package:chengxin_youyou/ui/platform/native_tab_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import '../test/fakes/desktop_widget_fakes.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('原生小组件共享课程、打开今天课表并在退出后清空', (tester) async {
    Future<void> hostCommand(String command) async {
      final client = HttpClient();
      try {
        final request = await client.getUrl(
          Uri.parse('http://127.0.0.1:18765/$command'),
        );
        final response = await request.close();
        await response.drain<void>();
        expect(response.statusCode, HttpStatus.ok);
      } finally {
        client.close(force: true);
      }
    }

    final platform = NativeDesktopWidgets();
    final session = SessionViewModel(WidgetSessionRepository());
    await session.restore();
    final dependencies = AppDependencies(
      session: session,
      calendar: widgetCalendar(),
      settings: AppSettings(),
      desktopWidgets: platform,
      createScheduleRepository: (_) => WidgetScheduleRepository(),
    );
    await tester.pumpWidget(ChengxinApp(dependencies: dependencies));
    await tester.pumpAndSettle();
    await dependencies.desktopWidget!.synchronize();
    expect(dependencies.desktopWidget!.error, isNull);
    final schedule = dependencies.schedule!;
    schedule.selectWeek(12);

    tester.widget<NativeTabBar>(find.byType(NativeTabBar)).onSelected(3);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('桌面小组件'), 200);
    await tester.tap(find.text('桌面小组件'));
    await tester.pumpAndSettle();
    expect(find.text('内容预览'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await binding.takeScreenshot('widget-settings');

    // 请求主机调用 simctl openurl，经过真实 SceneDelegate 和通道。
    await binding.takeScreenshot('widget-before-deeplink');
    await hostCommand('open-schedule');
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('schedule-grid')), findsOneWidget);
    expect(schedule.selectedWeek, schedule.currentWeek);
    expect(tester.takeException(), isNull);
    await binding.takeScreenshot('widget-after-deeplink');

    await session.logout();
    await tester.pumpAndSettle();
    // 等待清空真正写到原生存储；通道按顺序执行，不只检查 Dart 内存。
    await platform.publish(desktopWidgetMessage('loggedOut', '登录后查看今日课程'));
    await hostCommand('verify-cleared');
    await binding.takeScreenshot('widget-logged-out');
    await tester.pumpWidget(const SizedBox.shrink());
    dependencies.dispose();
  });
}
