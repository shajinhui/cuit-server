import 'dart:convert';

import 'package:chengxin_youyou/app/app.dart';
import 'package:chengxin_youyou/core/storage/app_storage.dart';
import 'package:chengxin_youyou/features/autorun/data/autorun_repository.dart';
import 'package:chengxin_youyou/features/profile/data/profile_repository.dart';
import 'package:chengxin_youyou/features/profile/presentation/feedback_page.dart';
import 'package:chengxin_youyou/features/profile/presentation/plan_completion_page.dart';
import 'package:chengxin_youyou/features/tools/presentation/autorun_page.dart';
import 'package:chengxin_youyou/ui/platform/native_tab_bar.dart';
import 'package:chengxin_youyou/ui/theme/app_theme.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import '../test/fakes/fake_api.dart';
import '../test/fakes/test_dependencies.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('原生个人中心、头像选择和新增个人功能', (tester) async {
    final dependencies = await testDependencies();
    dependencies.session.enterDemo();
    await tester.pumpWidget(ChengxinApp(dependencies: dependencies));
    await tester.pumpAndSettle();
    // Flutter 测试通过导航回调切页；UIKit 的真实触摸需要另做人工验收。
    tester.widget<NativeTabBar>(find.byType(NativeTabBar)).onSelected(3);
    await tester.pumpAndSettle();
    await precacheImage(
      AssetImage(dependencies.avatar!.assetPath),
      tester.element(find.byKey(const Key('profile-avatar'))),
    );
    await tester.pumpAndSettle(const Duration(milliseconds: 300));
    await Future<void>.delayed(const Duration(milliseconds: 500));
    await tester.pump();
    await binding.takeScreenshot('ios-profile-updated');
    await tester.tap(find.byKey(const Key('profile-avatar')));
    await tester.pumpAndSettle();
    await binding.takeScreenshot('ios-avatar-picker');
    await tester.tap(
      find
          .descendant(of: find.byType(GridView), matching: find.byType(InkWell))
          .at(5),
    );
    await tester.pumpAndSettle();
    expect(dependencies.avatar!.presetId, 6);
    await tester.tap(find.byKey(const Key('profile-plan-completion')));
    await tester.pumpAndSettle();
    expect(find.text('体验账号没有真实培养方案数据。'), findsOneWidget);
    await tester.tap(find.byTooltip('返回'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('profile-feedback')));
    await tester.pumpAndSettle();
    await binding.takeScreenshot('ios-feedback');
    expect(find.byType(FeedbackPage), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    dependencies.dispose();

    // 固定样例只替换 HTTP 响应，仍运行正式页面的解析和原生渲染。
    final api = FakeApi();
    api.handler = (_) async => FakeApi.response({
      'Summary': {
        'RequiredCredits': '160',
        'EarnedCredits': '102',
        'GPA': '3.5',
        'AuditResult': '未完成',
      },
      'Items': [
        {
          'Kind': 'requirement',
          'Name': '公共必修课程',
          'RequiredCredits': '45',
          'EarnedCredits': '45',
          'Status': '完成',
        },
        {
          'Kind': 'course',
          'Name': '高等数学',
          'CourseCode': 'DEMO101',
          'EarnedCredits': '5',
          'Score': '90',
          'Status': '通过',
        },
        {
          'Kind': 'requirement',
          'Name': '专业必修课程',
          'RequiredCredits': '70',
          'EarnedCredits': '43',
          'Status': '未完成',
        },
      ],
    });
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.build(Brightness.light),
        debugShowCheckedModeBanner: false,
        home: PlanCompletionPage(repository: ProfileRepository(api.client)),
      ),
    );
    await tester.pumpAndSettle();
    await binding.takeScreenshot('ios-plan-completion');
    await tester.pumpWidget(const SizedBox.shrink());
    api.client.dispose();
  });

  testWidgets('校园跑在 iOS 运行正式页面，独立登录和俱乐部数据', (tester) async {
    final api = FakeApi();
    final repository = AutoRunRepository(
      MemoryAppStorage(),
      dio: api.client.dio,
    );
    api.handler = (request) async {
      final Map<String, Object?> data;
      if (request.path.endsWith('/login')) {
        data = {'sessionKey': 'integration-test'};
      } else if (request.path.endsWith('/run_info')) {
        data = {
          'runInfo': {'runValidCount': 8, 'runValidDistance': 24000},
        };
      } else if (request.path.endsWith('/club_data')) {
        data = {
          'activities': [
            {
              'clubActivityId': 7,
              'activityName': '羽毛球训练',
              'startTime': '17:00',
              'endTime': '18:00',
              'addressDetail': '体育馆',
              'maxStudent': 30,
              'signInStudent': 8,
              'optionStatus': '0',
            },
          ],
          'joinProgress': {'joinNum': 3, 'totalNum': 12},
          'schedule': {'enabled': false},
        };
      } else {
        throw StateError('未预期的请求 ${request.path}');
      }
      return ResponseBody.fromString(
        jsonEncode({'code': 10000, 'msg': '', 'response': data}),
        200,
        headers: {
          Headers.contentTypeHeader: ['application/json'],
        },
      );
    };
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.build(Brightness.light),
        debugShowCheckedModeBanner: false,
        home: AutoRunPage(repository: repository),
      ),
    );
    await tester.pumpAndSettle();
    await binding.takeScreenshot('ios-autorun-login');
    await tester.enterText(
      find.byKey(const Key('autorun-phone')),
      '13800138000',
    );
    await tester.enterText(
      find.byKey(const Key('autorun-password')),
      'test-only',
    );
    await tester.tap(find.byKey(const Key('autorun-login')));
    await tester.pumpAndSettle();
    await binding.takeScreenshot('ios-autorun-progress');
    await tester.tap(find.text('俱乐部'));
    await tester.pumpAndSettle();
    await binding.takeScreenshot('ios-autorun-club');
    expect(find.text('羽毛球训练'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    repository.dispose();
  });
}
