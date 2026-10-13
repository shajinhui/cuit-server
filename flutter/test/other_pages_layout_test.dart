import 'package:chengxin_youyou/app/app.dart';
import 'package:chengxin_youyou/features/campus/presentation/campus_page.dart';
import 'package:chengxin_youyou/features/campus/presentation/campus_widgets.dart';
import 'package:chengxin_youyou/features/campus/presentation/marketplace_editor_page.dart';
import 'package:chengxin_youyou/features/campus/presentation/marketplace_item_page.dart';
import 'package:chengxin_youyou/features/campus/presentation/marketplace_mine_page.dart';
import 'package:chengxin_youyou/features/campus/presentation/rating_board_page.dart';
import 'package:chengxin_youyou/features/campus/presentation/rating_editor_page.dart';
import 'package:chengxin_youyou/features/campus/presentation/rating_item_page.dart';
import 'package:chengxin_youyou/features/campus/presentation/ratings_mine_page.dart';
import 'package:chengxin_youyou/features/profile/data/profile_repository.dart';
import 'package:chengxin_youyou/features/profile/presentation/feedback_page.dart';
import 'package:chengxin_youyou/features/profile/presentation/about_page.dart';
import 'package:chengxin_youyou/features/profile/presentation/plan_completion_page.dart';
import 'package:chengxin_youyou/ui/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes/campus_preview_repository.dart';
import 'fakes/fake_api.dart';
import 'fakes/test_dependencies.dart';

void main() {
  testWidgets('小屏、大字体和深色下校园各页可以显示与滚动', (tester) async {
    _smallScreen(tester);
    final repository = CampusPreviewRepository();
    Future<void> show(Widget page) async {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpWidget(
        MaterialApp(theme: AppTheme.build(Brightness.dark), home: page),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: '${page.runtimeType} 首屏');
      final scroll = find.byType(ListView).first;
      if (scroll.evaluate().isNotEmpty) {
        await tester.drag(scroll, const Offset(0, -600));
        await tester.pumpAndSettle();
        expect(
          tester.takeException(),
          isNull,
          reason: '${page.runtimeType} 滚动',
        );
      }
    }

    await show(Scaffold(body: CampusPage(repository: repository)));
    await tester.tap(find.text('二手'));
    await tester.pumpAndSettle();
    expect(find.text('校园二手车'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('求购'));
    await tester.pumpAndSettle();
    expect(find.text('求购校园卡'), findsOneWidget);
    expect(tester.takeException(), isNull);
    for (final page in <Widget>[
      RatingBoardPage(repository: repository, boardId: 'board-1'),
      RatingItemPage(repository: repository, itemId: 'rating-item-1'),
      MarketplaceItemPage(repository: repository, itemId: 'listing-1'),
      RatingsMinePage(repository: repository),
      MarketplaceMinePage(repository: repository),
      RatingEditorPage(repository: repository),
      RatingEditorPage(repository: repository, boardId: 'board-1'),
      MarketplaceEditorPage(repository: repository),
      MarketplaceEditorPage(repository: repository, initialType: 'wanted'),
    ]) {
      await show(page);
    }
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('封面重建复用请求，切换资源才重新加载', (tester) async {
    final repository = CampusPreviewRepository();
    Future<void> show(String asset) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CampusAssetImage(
              assetId: asset,
              repository: repository,
              fallback: Icons.image_outlined,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    await show('one');
    await show('one');
    expect(repository.assetLoads, 1);
    await show('two');
    expect(repository.assetLoads, 2);
  });

  testWidgets('个人中心、课表详情、课程编辑和日历弹层适配小屏大字体', (tester) async {
    _smallScreen(tester);
    final dependencies = (await tester.runAsync(testDependencies))!;
    dependencies.session.enterDemo();
    await dependencies.settings.setThemeMode(ThemeMode.dark);
    await tester.pumpWidget(ChengxinApp(dependencies: dependencies));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('course-demo-lesson-001-1-1-2')));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.tap(find.byTooltip('关闭课程详情'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('添加课程'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.ensureVisible(find.text('取消'));
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('更多操作'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('导入系统日历'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('nav-3')));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.scrollUntilVisible(find.byKey(const Key('theme-mode')), 200);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    dependencies.dispose();
  });

  testWidgets('反馈和学业明细在小屏大字体下保留内容与统计', (tester) async {
    _smallScreen(tester);
    final api = FakeApi();
    addTearDown(api.client.dispose);
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
          'Name': '专业必修课程',
          'RequiredCredits': '70',
          'EarnedCredits': '43',
          'Status': '未完成',
        },
        {
          'Kind': 'course',
          'Name': '操作系统与计算机组成原理',
          'CourseCode': 'DEMO101',
          'EarnedCredits': '5',
          'Score': '90',
          'Status': '通过',
        },
      ],
    });
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.build(Brightness.dark),
        home: PlanCompletionPage(repository: ProfileRepository(api.client)),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('64%'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.drag(find.byType(ListView), const Offset(0, -400));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.build(Brightness.dark),
        home: const FeedbackPage(repository: null),
      ),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const Key('feedback-content')),
      200,
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('feedback-content')),
      '这是一条足够长的演示反馈内容',
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.build(Brightness.dark),
        home: const AboutPage(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView), const Offset(0, -400));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}

void _smallScreen(WidgetTester tester) {
  tester.view.physicalSize = const Size(320, 568);
  tester.view.devicePixelRatio = 1;
  tester.platformDispatcher.textScaleFactorTestValue = 1.5;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
}
