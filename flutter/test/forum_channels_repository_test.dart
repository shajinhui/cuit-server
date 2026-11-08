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
}
