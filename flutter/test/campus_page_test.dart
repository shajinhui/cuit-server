import 'package:chengxin_youyou/features/campus/data/campus_repository.dart';
import 'package:chengxin_youyou/features/campus/models/campus_models.dart';
import 'package:chengxin_youyou/features/campus/presentation/campus_page.dart';
import 'package:chengxin_youyou/features/campus/presentation/rating_board_page.dart';
import 'package:chengxin_youyou/features/campus/presentation/marketplace_editor_page.dart';
import 'package:chengxin_youyou/features/campus/presentation/marketplace_mine_page.dart';
import 'package:chengxin_youyou/features/campus/presentation/rating_editor_page.dart';
import 'package:chengxin_youyou/features/campus/presentation/rating_item_page.dart';
import 'package:chengxin_youyou/ui/components/auto_hide_scaffold.dart';
import 'package:chengxin_youyou/ui/components/page_layout.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'fakes/campus_preview_repository.dart';

void main() {
  testWidgets('二手首屏不下载屏幕外的整批图片，滚动后再加载后续商品', (tester) async {
    tester.view.physicalSize = const Size(390, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final repository = _ManyListingsRepository();
    final router = _createRouter(repository);
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();
    // 只统计切到二手后新增的加载量。
    repository.assetLoads = 0;
    await tester.tap(find.text('二手'));
    await tester.pumpAndSettle();

    final firstScreenLoads = repository.assetLoads;
    expect(firstScreenLoads, greaterThan(0));
    expect(firstScreenLoads, lessThanOrEqualTo(8));
    expect(find.text('商品 39'), findsNothing);

    await tester.drag(
      find.byKey(const ValueKey('campus-listings')),
      const Offset(0, -900),
    );
    await tester.pumpAndSettle();
    expect(repository.assetLoads, greaterThan(firstScreenLoads));
    expect(repository.assetLoads, lessThan(40));
    expect(tester.takeException(), isNull);
  });

  testWidgets('校园页默认论坛栏目，切换评分和二手内容并保留列表筛选', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final repository = CampusPreviewRepository();
    final router = _createRouter(repository);
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();

    // 默认进入论坛栏目。
    expect(find.text('图书馆晚上能不能延长闭馆时间'), findsOneWidget);

    await tester.tap(find.text('评分'));
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

  testWidgets('评分栏目使用紧凑首屏布局', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final router = _createRouter(CampusPreviewRepository());
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();
    await tester.tap(find.text('评分'));
    await tester.pumpAndSettle();

    final intro = find.byKey(const ValueKey('campus-rating-intro'));
    expect(intro, findsOneWidget);
    expect(tester.getSize(intro).height, lessThanOrEqualTo(110));
    final sort = find.byKey(const ValueKey('campus-sort-segment'));
    expect(tester.getSize(sort).height, lessThanOrEqualTo(36));
    expect(tester.getSize(sort).width, lessThanOrEqualTo(108));
    final firstBoard = find.byKey(const ValueKey('rating-board-card-board-1'));
    expect(firstBoard, findsOneWidget);
    expect(tester.getSize(firstBoard).height, lessThanOrEqualTo(88));
    expect(tester.takeException(), isNull);
  });

  testWidgets('二手首页筛选、发布和刷新按钮使用紧凑尺寸', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final router = _createRouter(CampusPreviewRepository());
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();
    await tester.tap(find.text('二手'));
    await tester.pumpAndSettle();

    final bodyBackground = find.byKey(const ValueKey('campus-body-background'));
    final backgroundContext = tester.element(bodyBackground);
    expect(
      tester.widget<ColoredBox>(bodyBackground).color,
      pageBackground(backgroundContext),
    );

    final typeSelector = find.byKey(const ValueKey('campus-listing-type'));
    expect(tester.getSize(typeSelector).height, lessThanOrEqualTo(36));
    expect(tester.getSize(typeSelector).width, lessThanOrEqualTo(128));
    expect(
      tester
          .getSize(find.byKey(const ValueKey('campus-create-listing')))
          .height,
      lessThanOrEqualTo(36),
    );
    expect(
      tester
          .getSize(find.byKey(const ValueKey('campus-marketplace-refresh')))
          .height,
      lessThanOrEqualTo(36),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('二手页在窄屏大字体下按钮不溢出', (tester) async {
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    final router = _createRouter(CampusPreviewRepository());
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();
    await tester.tap(find.text('二手'));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('campus-listing-type')), findsOneWidget);
    expect(find.byKey(const ValueKey('campus-create-listing')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('campus-marketplace-refresh')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('校园搜索入口统一在右上角并按当前栏目切换搜索域', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final repository = CampusPreviewRepository();
    final router = _createRouter(repository);
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();

    // 默认进入论坛栏目。
    expect(find.byKey(const ValueKey('campus-search')), findsNothing);
    expect(find.byTooltip('搜索论坛'), findsOneWidget);
    expect(find.byKey(const ValueKey('campus-create-thread')), findsOneWidget);

    // 三个栏目位于“校园”标题和搜索入口之间，保持同一行。
    final titleRect = tester.getRect(find.text('校园'));
    final tabsRect = tester.getRect(
      find.byKey(const ValueKey('campus-area-segment')),
    );
    final searchRect = tester.getRect(
      find.byKey(const ValueKey('campus-search-toggle')),
    );
    expect(titleRect.right, lessThanOrEqualTo(tabsRect.left));
    expect(tabsRect.right, lessThanOrEqualTo(searchRect.left));
    expect((titleRect.center.dy - tabsRect.center.dy).abs(), lessThan(1));

    await tester.tap(find.byKey(const ValueKey('campus-search-toggle')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('campus-search')), findsOneWidget);
    expect(find.text('搜索帖子'), findsOneWidget);
    await tester.enterText(find.byKey(const ValueKey('campus-search')), '图书馆');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();
    expect(repository.lastForumQuery, '图书馆');

    // 切换栏目会关闭搜索并切到新栏目的搜索域。
    await tester.tap(find.text('二手'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('campus-search')), findsNothing);
    expect(find.byTooltip('搜索二手'), findsOneWidget);
    expect(find.byKey(const ValueKey('campus-create-listing')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('campus-search-toggle')));
    await tester.pumpAndSettle();
    expect(find.text('搜索想要的闲置'), findsOneWidget);
    await tester.enterText(find.byKey(const ValueKey('campus-search')), '自行车');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();
    expect(repository.lastListingQuery, '自行车');

    await tester.tap(find.text('评分'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('campus-search')), findsNothing);
    expect(find.byTooltip('搜索评分'), findsOneWidget);
    expect(find.byKey(const ValueKey('campus-create-board')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('campus-search-toggle')));
    await tester.pumpAndSettle();
    expect(find.text('搜索评分板块'), findsOneWidget);
    await tester.enterText(find.byKey(const ValueKey('campus-search')), '食堂');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();
    expect(repository.lastBoardQuery, '食堂');
  });

  testWidgets('发帖按钮会避开可见的底部导航，导航隐藏后落回右下角', (tester) async {
    tester.view.physicalSize = const Size(390, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    var navigationVisible = true;
    late StateSetter updateScope;
    final repository = CampusPreviewRepository();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) {
              updateScope = setState;
              return AutoHideNavigationScope(
                visible: navigationVisible,
                bottomBarHeight: 92,
                child: CampusPage(repository: repository),
              );
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final createButton = find.byKey(const ValueKey('campus-create-thread'));
    expect(createButton, findsOneWidget);
    final aboveNavigation = tester.getRect(createButton).bottom;
    expect(aboveNavigation, closeTo(900 - 92 - 8, .5));

    updateScope(() => navigationVisible = false);
    await tester.pumpAndSettle();
    final atBottomRight = tester.getRect(createButton).bottom;
    expect(atBottomRight, closeTo(900 - 18, .5));
    expect(atBottomRight - aboveNavigation, closeTo(82, .5));
  });

  testWidgets('评分和二手二级页沿用校园统一白底石墨黑', (tester) async {
    final repository = CampusPreviewRepository();

    await tester.pumpWidget(
      MaterialApp(home: RatingEditorPage(repository: repository)),
    );
    await tester.pumpAndSettle();
    final ratingContext = tester.element(find.byType(PageScaffold));
    expect(pageAccent(ratingContext), const Color(0xFF1A1A1A));
    expect(
      Theme.of(ratingContext).colorScheme.surface,
      const Color(0xFFFFFFFF),
    );

    await tester.pumpWidget(
      MaterialApp(home: MarketplaceMinePage(repository: repository)),
    );
    await tester.pumpAndSettle();
    final marketplaceContext = tester.element(find.byType(PageScaffold));
    expect(pageAccent(marketplaceContext), const Color(0xFF1A1A1A));
    expect(
      Theme.of(marketplaceContext).colorScheme.surface,
      const Color(0xFFFFFFFF),
    );
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
    await tester.tap(find.text('评分'));
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
    await tester.tap(find.text('评分'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('食堂推荐'));
    await tester.pumpAndSettle();
    expect(find.text('全部评分 / 5'), findsOneWidget);
    expect(find.text('麻辣烫窗口'), findsOneWidget);
    expect(
      tester.getSize(find.byKey(const ValueKey('rating-board-hero'))).height,
      lessThanOrEqualTo(120),
    );
    expect(
      tester
          .getSize(find.byKey(const ValueKey('rating-item-card-rating-item-1')))
          .height,
      lessThanOrEqualTo(80),
    );

    await tester.tap(find.text('麻辣烫窗口'));
    await tester.pumpAndSettle();
    expect(find.text('评分详情页面'), findsOneWidget);
  });

  testWidgets('评分对象详情页使用紧凑布局', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: RatingItemPage(
          repository: CampusPreviewRepository(),
          itemId: 'rating-item-1',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('麻辣烫窗口'), findsOneWidget);
    expect(
      tester.getSize(find.byKey(const ValueKey('rating-item-hero'))).height,
      lessThanOrEqualTo(120),
    );
    expect(
      tester.getSize(find.byKey(const ValueKey('rating-summary-card'))).height,
      lessThanOrEqualTo(110),
    );
    expect(
      tester.getSize(find.byKey(const ValueKey('rating-action-card'))).height,
      lessThanOrEqualTo(90),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('评分评论默认展示第一条回复，其余回复需要展开', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: RatingItemPage(
          repository: _CommentRepliesRepository(),
          itemId: 'rating-item-1',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('第一条回复'), findsOneWidget);
    expect(find.text('第二条回复'), findsNothing);
    final toggle = find.byKey(
      const ValueKey('rating-replies-toggle-comment-1'),
    );
    expect(toggle, findsOneWidget);
    await tester.ensureVisible(toggle);
    await tester.tap(toggle);
    await tester.pumpAndSettle();
    expect(find.text('第二条回复'), findsOneWidget);
    expect(tester.takeException(), isNull);
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

class _ManyListingsRepository extends CampusPreviewRepository {
  @override
  Future<CampusPageResult<CampusListing>> listListings({
    bool mine = false,
    String query = '',
    String type = 'sell',
    String? cursor,
  }) async => CampusPageResult(
    items: List.generate(
      40,
      (index) => CampusListing(
        id: 'listing-$index',
        title: '商品 $index',
        description: '测试商品',
        priceCents: 1000,
        campus: 'airport',
        imageAssetId: 'image-$index',
        seller: const CampusAuthor(
          id: 'seller',
          displayName: '测试卖家',
          avatarPreset: 0,
        ),
        listingType: type,
        status: 'on_sale',
        version: 1,
        createdAt: '2026-10-01T00:00:00Z',
        isMine: mine,
      ),
    ),
    nextCursor: null,
    hasMore: false,
  );
}

class _CommentRepliesRepository extends CampusPreviewRepository {
  @override
  Future<CampusPageResult<CampusComment>> listComments({
    required String itemId,
    String sort = 'newest',
    String? cursor,
  }) async => const CampusPageResult(
    items: [
      CampusComment(
        id: 'comment-1',
        itemId: 'rating-item-1',
        parentId: null,
        author: CampusAuthor(
          id: 'user-2',
          displayName: '体验同学',
          avatarPreset: 0,
        ),
        body: '主评论',
        starsSnapshot: null,
        replyCount: 2,
        version: 1,
        createdAt: '2026-10-01T00:00:00Z',
        canDelete: false,
      ),
    ],
    nextCursor: null,
    hasMore: false,
  );

  @override
  Future<CampusPageResult<CampusComment>> listReplies({
    required String commentId,
    String? cursor,
  }) async => const CampusPageResult(
    items: [
      CampusComment(
        id: 'reply-1',
        itemId: 'rating-item-1',
        parentId: 'comment-1',
        author: CampusAuthor(
          id: 'user-3',
          displayName: '回复同学',
          avatarPreset: 0,
        ),
        body: '第一条回复',
        starsSnapshot: null,
        replyCount: 0,
        version: 1,
        createdAt: '2026-10-01T01:00:00Z',
        canDelete: false,
      ),
      CampusComment(
        id: 'reply-2',
        itemId: 'rating-item-1',
        parentId: 'comment-1',
        author: CampusAuthor(
          id: 'user-4',
          displayName: '另一位同学',
          avatarPreset: 0,
        ),
        body: '第二条回复',
        starsSnapshot: null,
        replyCount: 0,
        version: 1,
        createdAt: '2026-10-01T02:00:00Z',
        canDelete: false,
      ),
    ],
    nextCursor: null,
    hasMore: false,
  );
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
