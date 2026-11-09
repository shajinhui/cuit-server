import 'dart:io';
import 'dart:ui' as ui;

import 'package:chengxin_youyou/features/campus/models/campus_models.dart';
import 'package:chengxin_youyou/features/campus/presentation/campus_page.dart';
import 'package:chengxin_youyou/features/campus/presentation/forum_editor_page.dart';
import 'package:chengxin_youyou/features/campus/presentation/forum_widgets.dart';
import 'package:chengxin_youyou/ui/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes/campus_preview_repository.dart';

const _post = ForumThread(
  id: 'compact-test',
  categoryId: 'cat-general',
  categoryName: '日常',
  title: '问候',
  body: '大家好',
  author: CampusAuthor(id: 'test-author', displayName: '体验同学', avatarPreset: 1),
  imageAssetIds: [],
  replyCount: 0,
  likeCount: 0,
  isPinned: false,
  isLocked: false,
  status: 'normal',
  version: 1,
  createdAt: '2026-10-01T00:00:00Z',
  lastActivityAt: '2026-10-01T00:00:00Z',
  canEdit: false,
  canDelete: false,
);

class _PreviewRepository extends CampusPreviewRepository {
  @override
  Future<CampusPageResult<ForumThread>> listForumThreads({
    bool mine = false,
    String? categoryId,
    String query = '',
    String sort = 'latest',
    String? cursor,
  }) async {
    lastForumSort = sort;
    return const CampusPageResult(
      items: [_post],
      nextCursor: null,
      hasMore: false,
    );
  }
}

void main() {
  for (final width in [320.0, 390.0, 430.0]) {
    testWidgets('论坛 $width 宽首屏紧凑，控件点击区域保留 44，筛选排序仍可操作', (tester) async {
      _screen(tester, width);
      final repository = _PreviewRepository();
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.build(Brightness.light),
          home: Scaffold(body: CampusPage(repository: repository)),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('论坛'));
      await tester.pumpAndSettle();
      expect(find.text('大家都在聊'), findsNothing);
      expect(find.text('校园论坛'), findsNothing);
      final publish = find.byKey(const ValueKey('campus-create-thread'));
      expect(publish, findsOneWidget);
      // 发帖入口不再挤在版块和筛选按钮之间，改为右下角悬浮操作。
      final filterRow = find.byKey(const ValueKey('campus-forum-filter-row'));
      expect(find.descendant(of: filterRow, matching: publish), findsNothing);
      expect(
        tester.getTopLeft(publish).dy,
        greaterThan(tester.getRect(filterRow).bottom),
      );
      // 默认不展开搜索，首屏应该让给内容。
      expect(find.byKey(const ValueKey('campus-search')), findsNothing);
      final areaTabs = find.byKey(const ValueKey('campus-area-segment'));
      expect(tester.getSize(areaTabs).height, lessThanOrEqualTo(36));
      final row = find.byKey(const ValueKey('campus-forum-filter-row'));
      expect(tester.getSize(row).height, lessThanOrEqualTo(48));
      // 首页只保留一排主分类，主题入口收进右侧筛选面板。
      expect(
        find.byKey(const ValueKey('campus-forum-shortcuts')),
        findsNothing,
      );
      final filter = find.byKey(const ValueKey('campus-forum-filter'));
      expect(tester.getSize(filter).width, greaterThanOrEqualTo(44));
      expect(tester.getSize(filter).height, greaterThanOrEqualTo(44));
      final card = find.byKey(const ValueKey('forum-thread-card-compact-test'));
      // 去掉第二排主题栏后，首屏能更早露出正文。
      expect(tester.getTopLeft(card).dy, lessThanOrEqualTo(200));
      // 加入表情、评论和转发操作后，短帖仍保持在紧凑的信息流高度内。
      expect(tester.getSize(card).height, lessThanOrEqualTo(170));
      expect(tester.widget<Text>(find.text('问候')).style?.fontSize, 15);
      // 搜索框只在点击右上角入口后展开，并保持 44 的点击高度。
      await tester.tap(find.byKey(const ValueKey('campus-search-toggle')));
      await tester.pumpAndSettle();
      final search = find.byKey(const ValueKey('campus-search'));
      expect(tester.getSize(search).height, inInclusiveRange(44, 48));
      expect(tester.widget<TextField>(search).style?.fontSize, 14);
      // 搜索入口移到顶部后，发帖按钮仍是独立的 44 高点击区域。
      expect(tester.getSize(publish).height, greaterThanOrEqualTo(44));
      await tester.tap(filter);
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.byKey(const ValueKey('campus-forum-sort-segment')),
          matching: find.text('热门'),
        ),
      );
      await tester.pumpAndSettle();
      expect(repository.lastForumSort, 'active');
      await tester.tap(find.byKey(const ValueKey('campus-forum-filter-done')));
      await tester.pumpAndSettle();
      final categories = find.byKey(const ValueKey('campus-forum-categories'));
      await tester.drag(categories, const Offset(-220, 0));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('forum-channel-more')));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('forum-channel-tile-cat-study')),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  for (final scale in [1.5, 2.0, 3.0]) {
    testWidgets('论坛 320 宽 $scale 倍字体深色模式不溢出，不压缩系统字号', (tester) async {
      _screen(tester, 320, scale: scale);
      final repository = _PreviewRepository();
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.build(Brightness.dark),
          home: Scaffold(body: CampusPage(repository: repository)),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('论坛'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(
        tester
            .getSize(find.byKey(const ValueKey('campus-create-thread')))
            .height,
        greaterThanOrEqualTo(34),
      );
      expect(
        MediaQuery.textScalerOf(
          tester.element(find.byType(ForumThreadCard)),
        ).scale(13),
        13 * scale,
      );
      // 大字体下展开/收起搜索也不能挤压或溢出顶部操作区。
      await tester.tap(find.byKey(const ValueKey('campus-search-toggle')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('campus-search')), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.byKey(const ValueKey('campus-search-cancel')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('campus-search')), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.tap(find.byKey(const ValueKey('campus-forum-filter')));
      await tester.pumpAndSettle();
      final hotSort = find.descendant(
        of: find.byKey(const ValueKey('campus-forum-sort-segment')),
        matching: find.text('热门'),
      );
      await tester.ensureVisible(hotSort);
      await tester.pumpAndSettle();
      await tester.tap(hotSort);
      await tester.pumpAndSettle();
      expect(repository.lastForumSort, 'active');
      expect(tester.takeException(), isNull);
      await tester.tap(find.byKey(const ValueKey('campus-forum-filter-done')));
      await tester.pumpAndSettle();
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  testWidgets('更多版块面板在 320 宽 3 倍字体下可滚动且无溢出', (tester) async {
    _screen(tester, 320, scale: 3);
    final repository = _PreviewRepository();
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.build(Brightness.dark),
        home: Scaffold(body: CampusPage(repository: repository)),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('论坛'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('forum-channel-more')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('forum-channels-sheet')), findsOneWidget);
    expect(tester.takeException(), isNull);

    final sheetScroll = find.descendant(
      of: find.byKey(const ValueKey('forum-channels-sheet')),
      matching: find.byType(Scrollable),
    );
    expect(sheetScroll, findsOneWidget);
    await tester.drag(sheetScroll, const Offset(0, -320));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('投票选项人数与占比在窄屏大字号下换行且仍可投票', (tester) async {
    _screen(tester, 320, scale: 3);
    const poll = ForumPollData(
      question: '走过路过帮忙选个 offer，顺丰科技和华为怎么选？',
      options: ['华为 AI 应用开发', '顺丰科技 Java 开发'],
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.build(Brightness.dark),
        home: const Scaffold(
          body: SingleChildScrollView(
            padding: EdgeInsets.all(16),
            child: ForumPollCard(data: poll),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('0人参与'), findsOneWidget);
    expect(find.text('0人 | 0.0%'), findsNWidgets(2));
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('华为 AI 应用开发'));
    await tester.pumpAndSettle();
    expect(find.text('1人参与'), findsOneWidget);
    expect(find.text('1人 | 100.0%'), findsOneWidget);
    expect(find.text('0人 | 0.0%'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('帖子长标题、多个标签和大计数在窄屏大字号下自然换行', (tester) async {
    _screen(tester, 320, scale: 3);
    final post = ForumThread.fromJson({
      ..._post.toJsonForTest(),
      'title': '较长帖子标题' * 6,
      'body': '长正文' * 20,
      'is_pinned': true,
      'is_locked': true,
      'reply_count': 123456,
      'like_count': 123456,
    });
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: ForumThreadCard(
              thread: post,
              showCategory: true,
              onTap: () {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('发帖工具栏在 320 宽 3 倍字体下可横向滚动且无溢出', (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.build(Brightness.light),
        home: ForumEditorPage(repository: CampusPreviewRepository()),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byKey(const ValueKey('forum-toolbar-scroll')), findsOneWidget);
    expect(find.byKey(const ValueKey('forum-tool-team')), findsOneWidget);
  });

  // 可选的本机截图：不增加字体或图像依赖，普通 CI 不写截图文件。
  final captureDirectory = Platform.environment['FORUM_CAPTURE_DIR'];
  if (captureDirectory != null) {
    for (final brightness in Brightness.values) {
      testWidgets('导出论坛紧凑布局 ${brightness.name} 预览', (tester) async {
        _screen(tester, 390);
        final fontPath = Platform.environment['FORUM_PREVIEW_FONT'];
        if (fontPath != null) {
          await tester.runAsync(() async {
            final bytes = await File(fontPath).readAsBytes();
            // Widget 测试默认使用 Ahem；截图才用开发机中文字体替换占位字形。
            for (final family in ['PingFang SC', 'Roboto', 'Ahem']) {
              final loader = FontLoader(family)
                ..addFont(Future.value(ByteData.sublistView(bytes)));
              await loader.load();
            }
            final icons = FontLoader('MaterialIcons')
              ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
            await icons.load();
          });
        }
        final boundary = GlobalKey();
        final theme = AppTheme.build(brightness).copyWith(
          textTheme: AppTheme.build(
            brightness,
          ).textTheme.apply(fontFamily: 'PingFang SC'),
        );
        await tester.pumpWidget(
          RepaintBoundary(
            key: boundary,
            child: MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: theme,
              home: Scaffold(
                body: CampusPage(repository: CampusPreviewRepository()),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('论坛'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await tester.runAsync(() async {
          final render =
              boundary.currentContext!.findRenderObject()!
                  as RenderRepaintBoundary;
          final image = await render.toImage(pixelRatio: 2);
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          await File(
            '$captureDirectory/forum-compact-${brightness.name}.png',
          ).writeAsBytes(bytes!.buffer.asUint8List());
          image.dispose();
        });
        await tester.pumpWidget(const SizedBox.shrink());
      });
    }
  }
}

void _screen(WidgetTester tester, double width, {double scale = 1}) {
  tester.view.physicalSize = Size(width, 844);
  tester.view.devicePixelRatio = 1;
  tester.view.padding = const FakeViewPadding(top: 24, bottom: 34);
  tester.platformDispatcher.textScaleFactorTestValue = scale;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPadding);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
}

extension on ForumThread {
  Map<String, Object?> toJsonForTest() => {
    'id': id,
    'category_id': categoryId,
    'category_name': categoryName,
    'title': title,
    'body': body,
    'author': {
      'id': author.id,
      'display_name': author.displayName,
      'avatar_preset': author.avatarPreset,
    },
    'image_asset_ids': imageAssetIds,
    'reply_count': replyCount,
    'like_count': likeCount,
    'is_pinned': isPinned,
    'is_locked': isLocked,
    'status': status,
    'version': version,
    'created_at': createdAt,
    'last_activity_at': lastActivityAt,
  };
}
