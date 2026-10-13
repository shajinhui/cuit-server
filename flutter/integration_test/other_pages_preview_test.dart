import 'package:chengxin_youyou/app/app.dart';
import 'package:chengxin_youyou/features/profile/data/profile_repository.dart';
import 'package:chengxin_youyou/features/profile/presentation/feedback_page.dart';
import 'package:chengxin_youyou/features/profile/presentation/plan_completion_page.dart';
import 'package:chengxin_youyou/ui/platform/native_tab_bar.dart';
import 'package:chengxin_youyou/ui/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import '../test/fakes/campus_preview_repository.dart';
import '../test/fakes/fake_api.dart';
import '../test/fakes/test_dependencies.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('预览登录、课表、个人中心和校园的正式页面', (tester) async {
    final dependencies = await testDependencies(
      campusRepository: CampusPreviewRepository(),
    );
    Future<void> capture(String name) async {
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: name);
      await binding.takeScreenshot('pages-$name');
    }

    Future<void> branch(int index) async {
      // iOS 原生导航复用正式回调，测试不伪造 UIKit 触摸事件。
      tester.widget<NativeTabBar>(find.byType(NativeTabBar)).onSelected(index);
      await tester.pumpAndSettle();
    }

    Future<void> back() async {
      await tester.tap(find.byTooltip('返回'));
      await tester.pumpAndSettle();
    }

    await tester.pumpWidget(ChengxinApp(dependencies: dependencies));
    await capture('login');
    await tester.ensureVisible(find.byKey(const Key('demo-entry')));
    await tester.tap(find.byKey(const Key('demo-entry')));
    await tester.pumpAndSettle();
    dependencies.schedule!.selectWeek(1);
    await capture('schedule');
    await tester.tap(find.byKey(const Key('selected-week')));
    await capture('week-menu');
    await tester.tap(find.byKey(const ValueKey('week-option-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('course-demo-lesson-001-1-1-2')));
    await capture('course-detail');
    await tester.tap(find.byTooltip('关闭课程详情'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('添加课程'));
    await capture('course-editor');
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();

    await branch(3);
    await precacheImage(
      AssetImage(dependencies.avatar!.assetPath),
      tester.element(find.byKey(const Key('profile-avatar'))),
    );
    await capture('profile');
    await tester.tap(find.byKey(const Key('profile-avatar')));
    await capture('avatar-picker');
    Navigator.of(tester.element(find.text('选择头像')), rootNavigator: true).pop();
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('关于成信友友'), 250);
    await tester.pumpAndSettle();
    await tester.tap(find.text('关于成信友友'));
    await tester.pumpAndSettle();
    await precacheImage(
      const AssetImage('assets/brand/app-icon.png'),
      tester.element(find.text('关于我们')),
    );
    await capture('about');
    await back();
    await branch(2);
    await capture('campus');
    await tester.tap(find.text('食堂推荐'));
    await capture('rating-board');
    await tester.tap(find.text('麻辣烫窗口'));
    await capture('rating-item');
    await tester.tap(find.byTooltip('举报对象'));
    await capture('report-dialog');
    await tester.enterText(find.byType(TextField).last, '用于预览，不提交举报');
    await capture('report-input');
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    await back();
    await back();
    await tester.tap(find.text('二手'));
    await capture('marketplace');
    await tester.tap(find.text('校园二手车'));
    await capture('marketplace-item');
    await back();
    await tester.tap(find.byKey(const ValueKey('campus-create-listing')));
    await capture('marketplace-editor');
    await back();
    await tester.tap(find.text('求购'));
    await capture('wanted');
    await dependencies.settings.setThemeMode(ThemeMode.dark);
    await branch(3);
    await tester.drag(find.byType(ListView).last, const Offset(0, 1000));
    await capture('profile-dark');
    await tester.pumpWidget(const SizedBox.shrink());
    dependencies.dispose();

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
        {
          'Kind': 'course',
          'Name': '操作系统',
          'CourseCode': 'DEMO102',
          'EarnedCredits': '3',
          'Score': '85',
          'Status': '通过',
        },
      ],
    });
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.build(Brightness.light),
        home: PlanCompletionPage(repository: ProfileRepository(api.client)),
      ),
    );
    await capture('plan-completion');
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.build(Brightness.light),
        home: const FeedbackPage(repository: null),
      ),
    );
    await capture('feedback');
    await tester.pumpWidget(const SizedBox.shrink());
    api.client.dispose();
  });
}
