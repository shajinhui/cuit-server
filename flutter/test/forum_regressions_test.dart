import 'dart:async';

import 'package:chengxin_youyou/features/campus/data/campus_repository.dart';
import 'package:chengxin_youyou/features/campus/models/campus_models.dart';
import 'package:chengxin_youyou/features/campus/presentation/forum_thread_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes/campus_preview_repository.dart';

void main() {
  testWidgets('回复失败原样重试沿用幂等键，修改正文或目标后换新键', (tester) async {
    final repository = _ReplyFailureRepository();
    await _mount(tester, repository);
    final input = find.byKey(const ValueKey('forum-reply-input'));
    final submit = find.byKey(const ValueKey('forum-reply-submit'));
    await tester.enterText(input, '第一次正文');
    await tester.tap(submit);
    await tester.pumpAndSettle();
    await tester.tap(submit);
    await tester.pumpAndSettle();
    expect(repository.requests[1], repository.requests[0]);
    await tester.enterText(input, '修改后的正文');
    await tester.tap(submit);
    await tester.pumpAndSettle();
    expect(repository.requests[2], isNot(repository.requests[1]));
    await tester.tap(find.text('回复'));
    await tester.pumpAndSettle();
    await tester.tap(submit);
    await tester.pumpAndSettle();
    expect(repository.requests[3], isNot(repository.requests[2]));
  });

  testWidgets('点赞成功后取消失败，回滚到本次操作前而非首屏状态', (tester) async {
    await _mount(tester, _LikeFailureRepository());
    final button = find.byKey(const ValueKey('forum-thread-like'));
    await tester.tap(button);
    await tester.pumpAndSettle();
    await tester.tap(button);
    await tester.pumpAndSettle();
    expect(
      find.descendant(of: button, matching: find.text('6')),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: button,
        matching: find.byIcon(Icons.thumb_up_alt_rounded),
      ),
      findsOneWidget,
    );
  });

  testWidgets('楼中楼可继续分页并按 id 去重，刷新重新获取展开内容', (tester) async {
    final repository = _ChildrenRepository();
    await _mount(tester, repository);
    await tester.tap(find.text('查看 1 条回复'));
    await tester.pumpAndSettle();
    final more = find.byKey(const ValueKey('forum-children-more-reply-1'));
    await tester.ensureVisible(more);
    await tester.tap(more);
    await tester.pumpAndSettle();
    expect(repository.cursors, [null, 'second-page']);
    expect(find.textContaining('第一页正文'), findsOneWidget);
    expect(find.textContaining('第二页正文'), findsOneWidget);
    expect(more, findsNothing);
    repository.body = '刷新后的正文';
    await tester
        .widget<RefreshIndicator>(find.byType(RefreshIndicator))
        .onRefresh();
    await tester.pumpAndSettle();
    expect(find.textContaining('刷新后的正文'), findsOneWidget);
    expect(find.textContaining('第二页正文'), findsNothing);
  });

  testWidgets('楼中楼加载失败后可以重试', (tester) async {
    final repository = _ChildrenRepository()..failNext = true;
    await _mount(tester, repository);
    await tester.tap(find.text('查看 1 条回复'));
    await tester.pumpAndSettle();
    final retry = find.byKey(const ValueKey('forum-children-more-reply-1'));
    await tester.ensureVisible(retry);
    await tester.tap(retry);
    await tester.pumpAndSettle();
    expect(find.textContaining('第一页正文'), findsOneWidget);
    expect(repository.cursors, [null, null]);
  });

  testWidgets('刷新期间旧楼中楼请求迟到，不覆盖刷新后的内容', (tester) async {
    final repository = _ChildrenRaceRepository();
    await _mount(tester, repository);
    final stale = await repository.firstPage();
    await tester.tap(find.text('查看 1 条回复'));
    await tester.pump();
    repository.body = '新回复正文';
    await tester
        .widget<RefreshIndicator>(find.byType(RefreshIndicator))
        .onRefresh();
    repository.pending.complete(stale);
    await tester.pumpAndSettle();
    expect(find.textContaining('新回复正文'), findsOneWidget);
    expect(find.textContaining('第一页正文'), findsNothing);
  });
}

Future<void> _mount(WidgetTester tester, CampusRepository repository) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      home: ForumThreadPage(repository: repository, threadId: 'thread-1'),
    ),
  );
  await tester.pumpAndSettle();
}

class _ReplyFailureRepository extends CampusPreviewRepository {
  final requests = <String?>[];
  @override
  Future<ForumReply> createForumReply({
    required String threadId,
    required String body,
    String? parentId,
    String? requestId,
  }) async {
    requests.add(requestId);
    throw const CampusRepositoryException('模拟网络失败');
  }
}

class _LikeFailureRepository extends CampusPreviewRepository {
  int requests = 0;
  @override
  Future<ForumThreadLike> toggleForumThreadLike({
    required String threadId,
    required bool like,
  }) async {
    requests++;
    if (requests == 2) throw const CampusRepositoryException('模拟网络失败');
    return const ForumThreadLike(liked: true, likeCount: 6);
  }
}

class _ChildrenRepository extends CampusPreviewRepository {
  final cursors = <String?>[];
  String body = '第一页正文';
  bool failNext = false;
  @override
  Future<CampusPageResult<ForumReply>> listForumReplyChildren({
    required String replyId,
    String? cursor,
  }) async {
    cursors.add(cursor);
    if (failNext) {
      failNext = false;
      throw const CampusRepositoryException('模拟网络失败');
    }
    final original = (await super.listForumReplyChildren(
      replyId: replyId,
    )).items.first;
    ForumReply child(String id, String body) => ForumReply(
      id: id,
      threadId: original.threadId,
      parentId: original.parentId,
      author: original.author,
      body: body,
      likeCount: 1,
      liked: false,
      replyCount: 0,
      version: 1,
      createdAt: original.createdAt,
      canDelete: false,
    );
    return CampusPageResult(
      items: [
        child(original.id, body),
        if (cursor != null) child('reply-1-2', '第二页正文'),
      ],
      nextCursor: cursor == null ? 'second-page' : null,
      hasMore: cursor == null,
    );
  }
}

class _ChildrenRaceRepository extends _ChildrenRepository {
  final pending = Completer<CampusPageResult<ForumReply>>();
  bool first = true;
  Future<CampusPageResult<ForumReply>> firstPage() =>
      super.listForumReplyChildren(replyId: 'reply-1');
  @override
  Future<CampusPageResult<ForumReply>> listForumReplyChildren({
    required String replyId,
    String? cursor,
  }) {
    if (first) {
      first = false;
      return pending.future;
    }
    return super.listForumReplyChildren(replyId: replyId, cursor: cursor);
  }
}
