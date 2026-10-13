import 'package:chengxin_youyou/features/campus/data/campus_repository.dart';
import 'package:chengxin_youyou/features/campus/presentation/campus_page.dart';
import 'package:chengxin_youyou/features/campus/presentation/rating_board_page.dart';
import 'package:chengxin_youyou/features/campus/presentation/marketplace_editor_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'fakes/campus_preview_repository.dart';

void main() {
  testWidgets('校园页切换评分和二手内容，并保留列表筛选', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final repository = CampusPreviewRepository();
    final router = _createRouter(repository);
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();

    expect(find.text('大家都在评'), findsOneWidget);
    expect(find.text('食堂推荐'), findsOneWidget);

    await tester.tap(find.text('最新'));
    await tester.pumpAndSettle();
    expect(repository.lastBoardSort, 'newest');

    await tester.tap(find.text('二手'));
    await tester.pumpAndSettle();
    expect(find.text('校园二手车'), findsOneWidget);
    expect(repository.lastListingType, 'sell');

    await tester.tap(find.text('求购'));
    await tester.pumpAndSettle();
    expect(repository.lastListingType, 'wanted');
  });

  testWidgets('评分广场会进入评分板块创建表单', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final router = _createRouter(CampusPreviewRepository());
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('campus-create-board')));
    await tester.pumpAndSettle();
    expect(find.text('创建评分板块表单'), findsOneWidget);
  });

  testWidgets('评分板块打开对象列表，对象可以继续进入评分详情', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final repository = CampusPreviewRepository();
    final router = _createRouter(repository);
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();
    await tester.tap(find.text('食堂推荐'));
    await tester.pumpAndSettle();
    expect(find.text('全部评分 / 5'), findsOneWidget);
    expect(find.text('麻辣烫窗口'), findsOneWidget);

    await tester.tap(find.text('麻辣烫窗口'));
    await tester.pumpAndSettle();
    expect(find.text('评分详情页面'), findsOneWidget);
  });

  test('校园发布表单的价格和联系方式校验与 Vue 规则一致', () {
    expect(parseCampusPrice('0.01'), 1);
    expect(parseCampusPrice('99999.99'), 9999999);
    expect(parseCampusPrice('0'), isNull);
    expect(parseCampusPrice('100000'), isNull);
    expect(parseCampusPrice('1.234'), isNull);
    expect(isCampusContactValid('phone', '13800138000'), isTrue);
    expect(isCampusContactValid('phone', '12800138000'), isFalse);
    expect(isCampusContactValid('qq', '12345'), isTrue);
    expect(isCampusContactValid('qq', '012345'), isFalse);
  });
}

GoRouter _createRouter(CampusRepository repository) => GoRouter(
  initialLocation: '/campus',
  routes: [
    GoRoute(
      path: '/campus',
      name: 'campus',
      builder: (context, state) =>
          Scaffold(body: CampusPage(repository: repository)),
      routes: [
        GoRoute(
          path: 'ratings/new',
          name: 'rating-create-board',
          builder: (context, state) => const Scaffold(body: Text('创建评分板块表单')),
        ),
        GoRoute(
          path: 'ratings/boards/:boardId',
          name: 'rating-board',
          builder: (context, state) => RatingBoardPage(
            repository: repository,
            boardId: state.pathParameters['boardId']!,
          ),
          routes: [
            GoRoute(
              path: 'items/new',
              name: 'rating-create-item',
              builder: (context, state) =>
                  const Scaffold(body: Text('添加评分对象表单')),
            ),
          ],
        ),
        GoRoute(
          path: 'ratings/items/:itemId',
          name: 'rating-item',
          builder: (context, state) => const Scaffold(body: Text('评分详情页面')),
        ),
      ],
    ),
  ],
);
