import 'dart:async';
import 'package:chengxin_youyou/features/campus/data/default_campus_repository.dart';
import 'package:chengxin_youyou/features/campus/data/campus_repository.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'fakes/fake_api.dart';

void main() {
  late FakeApi auth, api;
  late DefaultCampusRepository repo;
  setUp(() {
    auth = FakeApi();
    api = FakeApi();
    repo = DefaultCampusRepository(auth.client, dio: api.client.dio);
    auth.handler = (_) async => FakeApi.response({
      'access_token': 'test-token',
      'expires_at': '2099-01-01T00:00:00Z',
    });
    api.handler = (_) async => FakeApi.response({
      'id': 'me',
      'display_name': '公开昵称',
      'avatar_preset': 2,
      'avatar_asset_id': 'photo',
      'profile_version': 3,
    });
  });
  tearDown(() {
    repo.dispose();
    auth.client.dispose();
  });
  test('公开资料版本与头像资源通过现有认证传输，默认 GET 本人资料', () async {
    final profile = await repo.getCommunityProfile();
    expect(profile.avatarAssetId, 'photo');
    expect(profile.profileVersion, 3);
    expect(api.requests.single.path, '/api/v1/ratings/community/me/profile');
    expect(api.requests.single.headers['Authorization'], 'Bearer test-token');
    await repo.updateCommunityProfile(
      displayName: '新昵称',
      avatarPreset: 2,
      expectedVersion: 3,
    );
    expect(api.requests.last.method, 'PATCH');
    expect(api.requests.last.data, {
      'display_name': '新昵称',
      'avatar_preset': 2,
      'expected_version': 3,
      'avatar_asset_id': null,
    });
  });
  test('消息使用独立私有接口，批量已读携带服务端字符串水位', () async {
    api.handler = (_) async => FakeApi.response({
      'items': [],
      'next_cursor': null,
      'has_more': false,
      'read_watermark': '9007199254740993',
      'unread_count': 2,
    });
    final inbox = await repo.listNotifications();
    expect(inbox.readWatermark, '9007199254740993');
    await repo.readAllNotifications(inbox.readWatermark);
    expect(api.requests.last.data, {'read_watermark': '9007199254740993'});
    expect(api.requests.last.method, 'PUT');
    await repo.readNotification('23');
    expect(api.requests.last.path, endsWith('/me/notifications/23/read'));
  });
  test('收藏采用幂等目标状态，删除已经不可见的收藏仍走 DELETE', () async {
    api.handler = (request) async =>
        FakeApi.response({'favorited': request.method == 'PUT'});
    expect(await repo.setForumFavorite('post', true), isTrue);
    expect(await repo.setForumFavorite('post', false), isFalse);
    expect(api.requests.map((r) => r.method), ['PUT', 'DELETE']);
  });
  test('账号切换取消旧私有请求，迟到消息响应不能返回给新会话', () async {
    final pending = Completer<ResponseBody>();
    final started = Completer<void>();
    api.handler = (_) {
      started.complete();
      return pending.future;
    };
    final request = repo.listNotifications();
    final assertion = expectLater(
      request,
      throwsA(isA<CampusRepositoryException>()),
    );
    await started.future;
    repo.clearSession();
    pending.complete(
      FakeApi.response({
        'items': [],
        'read_watermark': '100',
        'unread_count': 99,
      }),
    );
    await assertion;
  });
}
