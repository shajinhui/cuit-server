import 'package:chengxin_youyou/features/campus/data/campus_repository.dart';
import 'package:chengxin_youyou/features/campus/models/campus_models.dart';
import 'package:chengxin_youyou/features/campus/presentation/campus_page.dart';
import 'package:chengxin_youyou/features/campus/presentation/forum_editor_page.dart';
import 'package:chengxin_youyou/features/campus/presentation/forum_thread_page.dart';
import 'package:chengxin_youyou/features/campus/presentation/forum_widgets.dart';
import 'package:chengxin_youyou/ui/components/page_layout.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'fakes/campus_preview_repository.dart';

class _EmptyForumDirectoryRepository extends CampusPreviewRepository {
  @override
  Future<List<ForumCategory>> listForumCategories() async => const [];

  @override
  Future<List<String>> getForumHomeCategories() async => const [];
}

void main() {
  testWidgets('论坛投票卡片选择后展示结果', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.topCenter,
            child: Padding(
              padding: EdgeInsets.fromLTRB(68, 16, 16, 0),
              child: ForumPollCard(
                data: ForumPollData(
                  question: '你更喜欢哪种活动？',
                  options: ['社团活动', '体育活动'],
                ),
              ),
            ),
          ),
        ),
      ),
    );

    expect(find.text('0人参与'), findsOneWidget);
    expect(find.text('0人 | 0.0%'), findsNWidgets(2));
    await tester.tap(find.text('社团活动'));
    await tester.pumpAndSettle();

    expect(find.text('1人参与'), findsOneWidget);
    expect(find.text('1人 | 100.0%'), findsOneWidget);
    expect(find.text('0人 | 0.0%'), findsOneWidget);
    // 选中态直接通过选项背景加深表达，不再显示左侧圆形选中框。
    expect(find.byIcon(Icons.check_rounded), findsNothing);

    // 结果展示后不能重复投票。
    await tester.tap(find.text('体育活动'));
    await tester.pumpAndSettle();
    expect(find.text('1人参与'), findsOneWidget);
    expect(find.text('1人 | 100.0%'), findsOneWidget);
    expect(find.text('0人 | 0.0%'), findsOneWidget);
  });

  test('投票自动标题不会在卡片外重复展示', () {
    const poll = ForumPollData(question: '今晚吃什么？', options: ['食堂', '外卖']);
    expect(forumDisplayTitle('投票：今晚吃什么？', poll), isEmpty);
    expect(forumDisplayTitle('今晚吃什么？', poll), '今晚吃什么？');
    expect(forumDisplayTitle('周末聚餐征集', poll), '周末聚餐征集');
  });

  testWidgets('论坛首次进入展示正式版块', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final repository = _EmptyForumDirectoryRepository();
    final router = _createRouter(repository);
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();
    await tester.tap(find.text('论坛'));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('forum-channel-general')), findsOneWidget);
    expect(find.byKey(const ValueKey('forum-channel-study')), findsOneWidget);
    expect(find.byKey(const ValueKey('forum-channel-mutual')), findsOneWidget);
    expect(find.byKey(const ValueKey('forum-channel-more')), findsOneWidget);
  });

  testWidgets('校园页切换到论坛栏目并筛选版块', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final repository = CampusPreviewRepository();
    final router = _createRouter(repository);
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();

    await tester.tap(find.text('论坛'));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('campus-forum-filter-row')),
      findsOneWidget,
    );
    // 第二排主题入口已移除，首页只保留一排主分类。
    expect(find.byKey(const ValueKey('campus-forum-shortcuts')), findsNothing);
    expect(find.byKey(const ValueKey('forum-topic-study')), findsNothing);
    expect(find.text('大家都在聊'), findsNothing);
    expect(find.text('图书馆晚上能不能延长闭馆时间'), findsOneWidget);
    expect(find.text('操作系统实验报告模板分享'), findsOneWidget);
    // 普通用户默认只看到固定的「全部」「热门」和更多入口。
    expect(find.byKey(const ValueKey('forum-channel-all')), findsOneWidget);
    expect(find.byKey(const ValueKey('forum-channel-hot')), findsOneWidget);
    expect(find.byKey(const ValueKey('forum-channel-more')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('forum-channel-cat-study')),
      findsOneWidget,
    );

    // 主题筛选收进主分类右侧的面板。
    await tester.tap(find.byKey(const ValueKey('campus-forum-filter')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('forum-topic-study')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('campus-forum-filter-done')));
    await tester.pumpAndSettle();
    expect(find.text('操作系统实验报告模板分享'), findsOneWidget);
    expect(find.text('图书馆晚上能不能延长闭馆时间'), findsNothing);
    expect(
      find.byKey(const ValueKey('campus-forum-topic-chip')),
      findsOneWidget,
    );

    // 点掉条件标签恢复全部帖子。
    await tester.tap(find.byKey(const ValueKey('campus-forum-topic-chip')));
    await tester.pumpAndSettle();
    expect(find.text('图书馆晚上能不能延长闭馆时间'), findsOneWidget);

    // 点击更多板块，从完整目录中进入「学习」。
    await tester.tap(find.byKey(const ValueKey('forum-channel-more')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('forum-channels-sheet')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('forum-channel-tile-cat-study')),
      findsOneWidget,
    );
    await tester.tap(
      find.byKey(const ValueKey('forum-channel-tile-cat-study')),
    );
    await tester.pumpAndSettle();
    expect(find.text('操作系统实验报告模板分享'), findsOneWidget);
    expect(find.text('图书馆晚上能不能延长闭馆时间'), findsNothing);
    expect(
      find.byKey(const ValueKey('forum-channel-cat-study')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('campus-forum-filter')));
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
  });

  testWidgets('用户可以设置首页版块并创建自己的版块', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final repository = CampusPreviewRepository();
    final router = _createRouter(repository);
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();
    await tester.tap(find.text('论坛'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('forum-channel-more')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('forum-channels-edit')));
    await tester.pumpAndSettle();
    // 首次进入默认展示 7 个正式版块；编辑首页时先清空，再只保留两个示例版块。
    for (final id in [
      'cat-general',
      'cat-study',
      'cat-mutual',
      'cat-lost',
      'cat-partner',
      'cat-activity',
      'cat-treehole',
    ]) {
      await tester.tap(find.byKey(ValueKey('forum-channel-tile-$id')));
    }
    await tester.tap(
      find.byKey(const ValueKey('forum-channel-tile-cat-general')),
    );
    await tester.tap(
      find.byKey(const ValueKey('forum-channel-tile-cat-study')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('forum-channels-save-or-done')));
    await tester.pumpAndSettle();

    expect(repository.forumHomeCategoryIds, ['cat-general', 'cat-study']);
    expect(
      find.byKey(const ValueKey('forum-channel-cat-general')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('forum-channel-cat-study')),
      findsOneWidget,
    );

    // 创建自定义版块后立即加入首页，关闭面板即可使用。
    await tester.tap(find.byKey(const ValueKey('forum-channel-more')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('forum-channels-create')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('forum-channel-create-name')),
      '摄影',
    );
    await tester.enterText(
      find.byKey(const ValueKey('forum-channel-create-description')),
      '分享校园里的好照片。',
    );
    await tester.tap(find.byKey(const ValueKey('forum-channel-create-submit')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('forum-channel-tile-cat-custom-1')),
      findsOneWidget,
    );
    expect(repository.forumHomeCategoryIds, contains('cat-custom-1'));

    await tester.tap(find.byKey(const ValueKey('forum-channels-save-or-done')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('forum-channel-cat-custom-1')),
      findsOneWidget,
    );
    expect(find.text('摄影'), findsOneWidget);
  });

  testWidgets('校园评分、二手和论坛统一白底石墨黑', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final repository = CampusPreviewRepository();
    final router = _createRouter(repository);
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();

    void expectCampusPalette() {
      final context = tester.element(
        find.byKey(const ValueKey('campus-area-segment')),
      );
      expect(Theme.of(context).brightness, Brightness.light);
      expect(Theme.of(context).colorScheme.surface, const Color(0xFFFFFFFF));
      expect(pageBackground(context), const Color(0xFFFFFFFF));
      expect(pageAccent(context), const Color(0xFF1A1A1A));
    }

    await tester.tap(find.text('论坛'));
    await tester.pumpAndSettle();
    expectCampusPalette();

    // 已选频道也必须使用统一石墨黑强调色，不能残留全局蓝色。
    final selectedChip = find.byKey(const ValueKey('forum-channel-all'));
    final selectedLabel = find.descendant(
      of: selectedChip,
      matching: find.text('全部'),
    );
    expect(
      tester.widget<Text>(selectedLabel).style?.color,
      const Color(0xFF1A1A1A),
    );

    await tester.tap(find.text('评分'));
    await tester.pumpAndSettle();
    expectCampusPalette();

    await tester.tap(find.text('二手'));
    await tester.pumpAndSettle();
    expectCampusPalette();
  });

  testWidgets('校园顶部栏随上滑隐藏并在回滑时恢复', (tester) async {
    tester.view.physicalSize = const Size(390, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final repository = CampusPreviewRepository();
    final router = _createRouter(repository);
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();
    await tester.tap(find.text('论坛'));
    await tester.pumpAndSettle();

    final header = find.byKey(const ValueKey('campus-collapsible-header'));
    expect(tester.getSize(header).height, greaterThan(0));
    expect(
      tester.getTopLeft(find.byKey(const ValueKey('campus-area-segment'))).dy,
      lessThanOrEqualTo(56),
    );

    await tester.drag(find.byType(ListView).first, const Offset(0, -240));
    await tester.pumpAndSettle();
    expect(tester.getSize(header).height, 0);

    await tester.drag(find.byType(ListView).first, const Offset(0, 120));
    await tester.pumpAndSettle();
    expect(tester.getSize(header).height, greaterThan(0));
  });

  testWidgets('论坛详情和编辑页沿用统一白底石墨黑', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final repository = CampusPreviewRepository();
    final router = _createRouter(repository);
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();
    await tester.tap(find.text('论坛'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('图书馆晚上能不能延长闭馆时间'));
    await tester.pumpAndSettle();

    final replyContext = tester.element(
      find.byKey(const ValueKey('forum-reply-input')),
    );
    expect(pageAccent(replyContext), const Color(0xFF1A1A1A));
    expect(Theme.of(replyContext).colorScheme.surface, const Color(0xFFFFFFFF));

    await tester.tap(find.byKey(const ValueKey('forum-thread-edit')));
    await tester.pumpAndSettle();
    final editorContext = tester.element(
      find.byKey(const ValueKey('forum-thread-title')),
    );
    expect(pageAccent(editorContext), const Color(0xFF1A1A1A));
    expect(
      Theme.of(editorContext).colorScheme.surface,
      const Color(0xFFFFFFFF),
    );
  });

  testWidgets('论坛帖子打开详情并展开楼中楼回复', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final repository = CampusPreviewRepository();
    final router = _createRouter(repository);
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();

    await tester.tap(find.text('论坛'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('图书馆晚上能不能延长闭馆时间'));
    await tester.pumpAndSettle();

    expect(find.text('全部回复 / 2'), findsOneWidget);
    expect(find.text('支持，上次十点被赶出来书还没看完。'), findsOneWidget);

    await tester.tap(find.text('查看 1 条回复'));
    await tester.pumpAndSettle();
    expect(find.textContaining('我也是，准备去反馈一下。'), findsOneWidget);
  });

  testWidgets('楼中楼点赞靠右，举报从长按菜单进入', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final repository = CampusPreviewRepository();
    final router = _createRouter(repository);
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();

    await tester.tap(find.text('论坛'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('图书馆晚上能不能延长闭馆时间'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('查看 1 条回复'));
    await tester.pumpAndSettle();

    final likeButton = find.byKey(const ValueKey('forum-reply-like-reply-1-1'));
    expect(tester.getCenter(likeButton).dx, greaterThan(330));
    expect(
      find.byKey(const ValueKey('forum-reply-report-reply-1-1')),
      findsNothing,
    );

    await tester.longPress(find.byKey(const ValueKey('forum-reply-reply-1-1')));
    await tester.pumpAndSettle();
    expect(find.text('举报回复'), findsOneWidget);
    // 无删除权限时，长按菜单同样不能出现删除入口。
    expect(find.text('删除回复'), findsNothing);

    await tester.tap(
      find.byKey(const ValueKey('forum-reply-report-reply-1-1')),
    );
    await tester.pumpAndSettle();
    expect(find.text('举报内容'), findsOneWidget);
  });

  testWidgets('论坛回复可以点赞并更新计数', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final repository = CampusPreviewRepository();
    final router = _createRouter(repository);
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();

    await tester.tap(find.text('论坛'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('图书馆晚上能不能延长闭馆时间'));
    await tester.pumpAndSettle();

    final likeButton = find.byKey(const ValueKey('forum-reply-like-reply-1'));
    expect(tester.getCenter(likeButton).dx, greaterThan(330));
    expect(
      find.byKey(const ValueKey('forum-reply-delete-reply-1')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('forum-reply-report-reply-1')),
      findsNothing,
    );
    expect(
      find.descendant(of: likeButton, matching: find.text('3')),
      findsOneWidget,
    );

    await tester.tap(likeButton);
    await tester.pumpAndSettle();
    expect(
      find.descendant(of: likeButton, matching: find.text('4')),
      findsOneWidget,
    );
  });

  testWidgets('论坛发帖表单需要选择版块并可以返回帖子', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final repository = CampusPreviewRepository();
    final router = _createRouter(repository);
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();

    await tester.tap(find.text('论坛'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('campus-create-thread')));
    await tester.pumpAndSettle();

    expect(find.text('发新帖'), findsOneWidget);
    expect(find.text('日常'), findsWidgets);
    expect(find.byKey(const ValueKey('forum-tool-emoji')), findsOneWidget);
    expect(find.byKey(const ValueKey('forum-tool-file')), findsOneWidget);
    expect(find.byKey(const ValueKey('forum-tool-poll')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('forum-tool-long-article')),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const ValueKey('forum-category-selector')));
    await tester.pumpAndSettle();
    expect(find.text('学习'), findsOneWidget);
    await tester.tap(find.text('日常').last);
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('forum-thread-title')),
      '新教学楼自习室体验',
    );
    await tester.enterText(
      find.byKey(const ValueKey('forum-thread-body')),
      '插座数量够，但是晚上有点冷。',
    );
    await tester.tap(find.byKey(const ValueKey('forum-thread-submit')));
    await tester.pumpAndSettle();

    // 假数据仓库返回 thread-new，发帖成功后进入详情页。
    expect(find.text('帖子详情'), findsOneWidget);
  });

  testWidgets('论坛投票可以在没有正文时发布', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final repository = CampusPreviewRepository();
    final router = _createRouter(repository);
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();

    await tester.tap(find.text('论坛'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('campus-create-thread')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('forum-tool-poll')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('forum-poll-question')),
      '今晚吃什么？',
    );
    await tester.enterText(
      find.byKey(const ValueKey('forum-poll-option-0')),
      '食堂',
    );
    await tester.enterText(
      find.byKey(const ValueKey('forum-poll-option-1')),
      '外卖',
    );
    await tester.tap(find.text('完成'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('forum-thread-submit')));
    await tester.pumpAndSettle();

    expect(find.text('帖子详情'), findsOneWidget);
  });

  testWidgets('论坛编辑帖子保留原内容并保存修改', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final repository = CampusPreviewRepository();
    final router = _createRouter(repository);
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();

    await tester.tap(find.text('论坛'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('图书馆晚上能不能延长闭馆时间'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('forum-thread-edit')));
    await tester.pumpAndSettle();

    expect(find.text('编辑帖子'), findsOneWidget);
    expect(
      tester
          .widget<TextField>(find.byKey(const ValueKey('forum-thread-title')))
          .controller!
          .text,
      '图书馆晚上能不能延长闭馆时间',
    );

    await tester.enterText(
      find.byKey(const ValueKey('forum-thread-title')),
      '图书馆闭馆时间讨论（更新）',
    );
    await tester.tap(find.byKey(const ValueKey('forum-thread-submit')));
    await tester.pumpAndSettle();

    // 保存后回到详情页，并记录了编辑结果。
    expect(repository.lastUpdatedThreadId, 'thread-1');
    expect(repository.lastUpdatedThreadTitle, '图书馆闭馆时间讨论（更新）');
    expect(find.text('帖子详情'), findsOneWidget);
    expect(find.text('图书馆闭馆时间讨论（更新）'), findsOneWidget);
  });

  testWidgets('论坛删除自己的帖子需要确认', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final repository = CampusPreviewRepository();
    final router = _createRouter(repository);
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();

    await tester.tap(find.text('论坛'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('图书馆晚上能不能延长闭馆时间'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('forum-thread-delete')));
    await tester.pumpAndSettle();
    expect(find.text('删除后无法恢复，确定删除这篇帖子吗？'), findsOneWidget);

    // 取消不删除。
    await tester.tap(find.byKey(const ValueKey('forum-thread-delete-cancel')));
    await tester.pumpAndSettle();
    expect(repository.deletedThreadIds, isEmpty);
    expect(find.text('帖子详情'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('forum-thread-delete')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('forum-thread-delete-confirm')));
    await tester.pumpAndSettle();

    expect(repository.deletedThreadIds, ['thread-1']);
    // 删除成功后返回校园页。
    expect(
      find.byKey(const ValueKey('campus-forum-filter-row')),
      findsOneWidget,
    );
    expect(find.text('图书馆晚上能不能延长闭馆时间'), findsNothing);
  });

  testWidgets('论坛删除自己的回复并同步计数', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final repository = CampusPreviewRepository();
    final router = _createRouter(repository);
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();

    await tester.tap(find.text('论坛'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('图书馆晚上能不能延长闭馆时间'));
    await tester.pumpAndSettle();

    expect(find.text('全部回复 / 2'), findsOneWidget);
    await tester.longPress(find.byKey(const ValueKey('forum-reply-reply-1')));
    await tester.pumpAndSettle();
    expect(find.text('删除回复'), findsOneWidget);
    expect(find.text('举报回复'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('forum-reply-delete-reply-1')));
    await tester.pumpAndSettle();

    expect(repository.deletedReplyIds, ['reply-1']);
    expect(find.text('支持，上次十点被赶出来书还没看完。'), findsNothing);
    // 删除主回复同时移除它的楼中楼，由重新读取的服务端计数确认。
    expect(find.text('全部回复 / 0'), findsOneWidget);
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
          path: 'forum/new',
          name: 'forum-create',
          builder: (context, state) => ForumEditorPage(repository: repository),
        ),
        GoRoute(
          path: 'forum/threads/:threadId',
          name: 'forum-thread',
          builder: (context, state) => ForumThreadPage(
            repository: repository,
            threadId: state.pathParameters['threadId']!,
          ),
        ),
        GoRoute(
          path: 'forum/threads/:threadId/edit',
          name: 'forum-edit',
          builder: (context, state) => state.extra is ForumThread
              ? ForumEditorPage(
                  repository: repository,
                  editingThread: state.extra as ForumThread,
                )
              : ForumThreadPage(
                  repository: repository,
                  threadId: state.pathParameters['threadId']!,
                ),
        ),
      ],
    ),
  ],
);
