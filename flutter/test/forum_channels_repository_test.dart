import 'package:chengxin_youyou/features/campus/data/default_campus_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes/fake_api.dart';

void main() {
  test('论坛首页偏好与用户版块使用论坛私有接口', () async {
    final auth = FakeApi();
    final api = FakeApi();
    final repository = DefaultCampusRepository(
      auth.client,
      dio: api.client.dio,
    );
    addTearDown(repository.dispose);
    addTearDown(auth.client.dispose);
    addTearDown(api.client.dispose);

    auth.handler = (_) async => FakeApi.response({
      'access_token': 'test-token',
      'expires_at': '2099-01-01T00:00:00Z',
    });
    api.handler = (request) async {
      if (request.path.endsWith('/categories') && request.method == 'GET') {
        return FakeApi.response([
          {
            'id': 'daily',
            'name': '日常',
            'description': '校园日常。',
            'sort_order': 1,
            'is_official': true,
            'is_mine': false,
          },
        ]);
      }
      if (request.path.endsWith('/categories') && request.method == 'POST') {
        return FakeApi.response({
          'id': 'c_new',
          'name': request.data['name'],
          'description': request.data['description'],
          'sort_order': 18,
          'is_official': false,
          'is_mine': true,
        });
      }
      if (request.path.endsWith('/me/home-categories') &&
          request.method == 'GET') {
        return FakeApi.response({
          'category_ids': ['daily'],
        });
      }
      if (request.path.endsWith('/me/home-categories') &&
          request.method == 'PUT') {
        return FakeApi.response({'category_ids': request.data['category_ids']});
      }
      return FakeApi.response(
        {'message': 'unexpected request'},
        status: 500,
        code: 50000,
      );
    };

    final categories = await repository.listForumCategories();
    expect(categories.single.name, '日常');
    expect(categories.single.isOfficial, isTrue);
    expect(categories.single.isMine, isFalse);

    final created = await repository.createForumCategory(
      name: '摄影',
      description: '校园摄影分享。',
    );
    expect(created.id, 'c_new');
    expect(created.isOfficial, isFalse);
    expect(created.isMine, isTrue);
    expect(api.requests.last.path, '/api/v1/forum/categories');
    expect(api.requests.last.data, {'name': '摄影', 'description': '校园摄影分享。'});

    expect(await repository.getForumHomeCategories(), ['daily']);
    expect(await repository.setForumHomeCategories(['daily', 'c_new']), [
      'daily',
      'c_new',
    ]);
    expect(api.requests.last.method, 'PUT');
    expect(api.requests.last.path, '/api/v1/forum/me/home-categories');
    expect(api.requests.last.data, {
      'category_ids': ['daily', 'c_new'],
    });
  });

  test('版块详情、成员、管理与日志沿用论坛私有接口', () async {
    final auth = FakeApi();
    final api = FakeApi();
    final repository = DefaultCampusRepository(
      auth.client,
      dio: api.client.dio,
    );
    addTearDown(repository.dispose);
    addTearDown(auth.client.dispose);
    addTearDown(api.client.dispose);

    auth.handler = (_) async => FakeApi.response({
      'access_token': 'test-token',
      'expires_at': '2099-01-01T00:00:00Z',
    });
    Map<String, Object?> categoryJson({
      bool member = false,
      bool moderator = false,
      int members = 1,
    }) => {
      'id': 'c_photo',
      'name': '摄影',
      'description': '校园摄影。',
      'rules': '只发本人作品。',
      'sort_order': 8,
      'is_official': false,
      'is_mine': true,
      'visibility': 'unlisted',
      'status': 'active',
      'member_count': members,
      'version': 3,
      'created_at': '2026-11-01T00:00:00.000Z',
      'is_member': member,
      'is_moderator': moderator,
      'capabilities': {
        'can_manage': moderator,
        'can_post': member || moderator,
        'can_join': !member && !moderator,
        'can_review_reports': moderator,
      },
      'moderators': [
        {
          'id': 'p_owner',
          'role': 'owner',
          'display_name': '版主',
          'avatar_preset': 2,
        },
      ],
    };
    Map<String, Object?> threadJson() => {
      'id': 't1',
      'category_id': 'c_photo',
      'category': {'id': 'c_photo', 'name': '摄影'},
      'title': '校园光影',
      'body': '测试正文',
      'author': {'id': 'p1', 'display_name': '同学', 'avatar_preset': 1},
      'image_asset_ids': <String>[],
      'reply_count': 0,
      'like_count': 0,
      'is_pinned': true,
      'is_locked': false,
      'status': 'normal',
      'version': 2,
      'created_at': '2026-11-01T00:00:00.000Z',
      'last_activity_at': '2026-11-01T00:00:00.000Z',
      'capabilities': {'can_reply': true},
    };

    api.handler = (request) async {
      final path = request.path;
      if (path == '/api/v1/forum/categories/c_photo' && request.method == 'GET') {
        return FakeApi.response(categoryJson(moderator: true));
      }
      if (path == '/api/v1/forum/categories/c_photo' &&
          request.method == 'PATCH') {
        return FakeApi.response(categoryJson(moderator: true, members: 2));
      }
      if (path == '/api/v1/forum/categories/c_photo/join') {
        return FakeApi.response(
          categoryJson(member: request.method == 'POST', members: 2),
        );
      }
      if (path == '/api/v1/forum/categories/c_photo/members') {
        return FakeApi.response({
          'items': [
            {
              'id': 'p1',
              'display_name': '同学',
              'avatar_preset': 1,
              'joined_at': '2026-11-01T00:00:00.000Z',
            },
          ],
          'has_more': false,
          'next_cursor': null,
        });
      }
      if (path == '/api/v1/forum/categories/c_photo/members/p1') {
        return FakeApi.response({'removed': true});
      }
      if (path == '/api/v1/forum/me/moderated-categories') {
        return FakeApi.response([categoryJson(moderator: true)]);
      }
      if (path == '/api/v1/forum/categories/c_photo/report') {
        return FakeApi.response({'reported': true});
      }
      if (path == '/api/v1/forum/categories/c_photo/moderation-log') {
        return FakeApi.response({
          'items': [
            {
              'id': '9',
              'action': 'pin',
              'target_type': 'thread',
              'target_id': 't1',
              'reason': null,
              'created_at': '2026-11-01T00:00:00.000Z',
              'actor': {
                'id': 'p_owner',
                'display_name': '版主',
                'avatar_preset': 2,
              },
            },
          ],
          'has_more': false,
          'next_cursor': null,
        });
      }
      if (path ==
          '/api/v1/forum/categories/c_photo/threads/t1/pin') {
        return FakeApi.response(threadJson());
      }
      if (path ==
          '/api/v1/forum/categories/c_photo/threads/t1/lock') {
        return FakeApi.response({...threadJson(), 'is_locked': false});
      }
      if (path == '/api/v1/forum/threads/t1/hide') {
        return FakeApi.response({'hidden': true});
      }
      return FakeApi.response(
        {'message': 'unexpected request'},
        status: 500,
        code: 50000,
      );
    };

    final detail = await repository.getForumCategory('c_photo');
    expect(detail.isUnlisted, isTrue);
    expect(detail.canManage, isTrue);
    expect(detail.moderators.single.isOwner, isTrue);
    expect(detail.rules, '只发本人作品。');

    final joined = await repository.joinForumCategory('c_photo');
    expect(joined.isMember, isTrue);
    expect(joined.memberCount, 2);
    expect(api.requests.last.method, 'POST');
    expect(api.requests.last.path, '/api/v1/forum/categories/c_photo/join');

    final updated = await repository.updateForumCategory(
      categoryId: 'c_photo',
      expectedVersion: 3,
      description: '新的介绍',
      rules: '新的规则',
    );
    expect(updated.rules, '只发本人作品。');
    expect(api.requests.last.method, 'PATCH');
    expect(api.requests.last.data, {
      'description': '新的介绍',
      'rules': '新的规则',
      'expected_version': 3,
    });

    final members = await repository.listForumCategoryMembers('c_photo');
    expect(members.items.single.author.displayName, '同学');
    expect(api.requests.last.queryParameters['limit'], 20);
    await repository.removeForumCategoryMember(
      categoryId: 'c_photo',
      userId: 'p1',
      reason: '测试移除',
    );
    expect(api.requests.last.method, 'DELETE');
    expect(api.requests.last.data, {'reason': '测试移除'});

    expect(
      (await repository.listModeratedForumCategories()).single.id,
      'c_photo',
    );
    await repository.reportForumCategory(
      categoryId: 'c_photo',
      reason: '版块介绍与实际不符',
    );
    expect(api.requests.last.path, '/api/v1/forum/categories/c_photo/report');

    final logs = await repository.listForumModerationLogs('c_photo');
    expect(logs.items.single.action, 'pin');
    expect(logs.items.single.actor.displayName, '版主');

    final pinned = await repository.setForumThreadPinned(
      categoryId: 'c_photo',
      threadId: 't1',
      pinned: true,
    );
    expect(pinned.isPinned, isTrue);
    expect(api.requests.last.path, '/api/v1/forum/categories/c_photo/threads/t1/pin');

    final locked = await repository.setForumThreadLocked(
      categoryId: 'c_photo',
      threadId: 't1',
      locked: false,
    );
    expect(locked.isLocked, isFalse);
    expect(api.requests.last.method, 'DELETE');

    await repository.hideForumThread(
      threadId: 't1',
      reason: '人身攻击',
      expectedVersion: 2,
    );
    expect(api.requests.last.data, {'reason': '人身攻击', 'expected_version': 2});
  });
}
