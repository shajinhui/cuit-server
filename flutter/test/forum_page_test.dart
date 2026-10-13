import 'package:chengxin_youyou/features/campus/data/campus_repository.dart';
import 'package:chengxin_youyou/features/campus/models/campus_models.dart';
import 'package:chengxin_youyou/features/campus/presentation/campus_page.dart';
import 'package:chengxin_youyou/features/campus/presentation/forum_editor_page.dart';
import 'package:chengxin_youyou/features/campus/presentation/forum_thread_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'fakes/campus_preview_repository.dart';

void main() {
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
    expect(find.text('大家都在聊'), findsOneWidget);
    expect(find.text('图书馆晚上能不能延长闭馆时间'), findsOneWidget);
    expect(find.text('操作系统实验报告模板分享'), findsOneWidget);

    await tester.tap(find.text('学习交流'));
    await tester.pumpAndSettle();
    expect(find.text('操作系统实验报告模板分享'), findsOneWidget);
    expect(find.text('图书馆晚上能不能延长闭馆时间'), findsNothing);

    await tester.tap(find.text('活跃'));
    await tester.pumpAndSettle();
    expect(repository.lastForumSort, 'active');
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

    expect(find.text('发布帖子'), findsWidgets);
    expect(find.text('综合讨论'), findsWidgets);
    expect(find.text('学习交流'), findsOneWidget);

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
    expect(find.text('大家都在聊'), findsOneWidget);
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
    await tester.tap(find.byKey(const ValueKey('forum-reply-delete-reply-1')));
    await tester.pumpAndSettle();

    expect(repository.deletedReplyIds, ['reply-1']);
    expect(find.text('支持，上次十点被赶出来书还没看完。'), findsNothing);
    expect(find.text('全部回复 / 1'), findsOneWidget);
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
