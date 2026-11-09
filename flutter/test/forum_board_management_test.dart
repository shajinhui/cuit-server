import 'package:chengxin_youyou/features/campus/models/campus_models.dart';
import 'package:chengxin_youyou/features/campus/presentation/forum_category_page.dart';
import 'package:chengxin_youyou/features/campus/presentation/forum_thread_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes/campus_preview_repository.dart';

class _ManageableForumRepository extends CampusPreviewRepository {
  @override
  Future<ForumCategory> getForumCategory(String categoryId) async =>
      const ForumCategory(
        id: 'cat-general',
        name: '日常',
        description: '校园生活。',
        sortOrder: 1,
        canManage: true,
        canReviewReports: true,
      );
}

void main() {
  testWidgets('未加入的用户版块可以在详情页加入并进入版块', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final repository = CampusPreviewRepository();
    repository.forumCategories.add(
      const ForumCategory(
        id: 'cat-photo',
        name: '摄影',
        description: '校园摄影与器材交流。',
        sortOrder: 9,
        isOfficial: false,
        visibility: 'unlisted',
        memberCount: 0,
        canJoin: true,
        canPost: false,
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: ForumCategoryPage(
          repository: repository,
          categoryId: 'cat-photo',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('摄影'), findsOneWidget);
    expect(find.text('加入版块'), findsOneWidget);
    expect(find.text('未公开'), findsWidgets);

    await tester.tap(find.byKey(const ValueKey('forum-category-join')));
    await tester.pumpAndSettle();

    expect(find.text('进入版块'), findsOneWidget);
    expect(find.text('已退出'), findsNothing);
    expect(find.text('退出'), findsOneWidget);
  });

  testWidgets('版主可以编辑版块简介与规则', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final repository = CampusPreviewRepository();
    repository.forumCategories.add(
      const ForumCategory(
        id: 'cat-photo',
        name: '摄影',
        description: '旧介绍',
        rules: '旧规则',
        sortOrder: 9,
        isOfficial: false,
        isMember: true,
        visibility: 'unlisted',
        memberCount: 1,
        canManage: true,
        canPost: true,
        canJoin: false,
        canReviewReports: true,
        moderators: [
          ForumCategoryModerator(
            author: CampusAuthor(
              id: 'p-owner',
              displayName: '版主同学',
              avatarPreset: 1,
            ),
            role: 'owner',
          ),
        ],
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: ForumCategoryPage(
          repository: repository,
          categoryId: 'cat-photo',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('旧介绍'), findsOneWidget);
    expect(find.text('旧规则'), findsOneWidget);
    expect(find.text('版主同学'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('forum-category-manage-menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('编辑简介与规则').last);
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('forum-category-edit-description')),
      '新的介绍',
    );
    await tester.enterText(
      find.byKey(const ValueKey('forum-category-edit-rules')),
      '新的规则：只发本人作品。',
    );
    await tester.tap(find.byKey(const ValueKey('forum-category-edit-submit')));
    await tester.pumpAndSettle();

    expect(find.text('新的介绍'), findsOneWidget);
    expect(find.text('新的规则：只发本人作品。'), findsOneWidget);
    expect(find.text('旧介绍'), findsNothing);
  });

  testWidgets('版主可以从帖子菜单置顶和取消置顶', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final repository = _ManageableForumRepository();
    await tester.pumpWidget(
      MaterialApp(
        home: ForumThreadPage(
          repository: repository,
          threadId: 'thread-1',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('forum-thread-manage')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('forum-thread-manage')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('取消置顶'));
    await tester.pumpAndSettle();
    expect(find.text('已取消置顶'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('forum-thread-manage')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('置顶帖子'));
    await tester.pumpAndSettle();
    expect(find.text('已置顶'), findsOneWidget);
  });
}
