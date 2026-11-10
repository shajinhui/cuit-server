import 'dart:async';
import 'dart:typed_data';

import 'package:chengxin_youyou/features/campus/data/default_campus_repository.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes/fake_api.dart';

void main() {
  late FakeApi auth;
  late FakeApi campus;
  late DefaultCampusRepository repository;

  setUp(() {
    auth = FakeApi();
    campus = FakeApi();
    repository = DefaultCampusRepository(auth.client, dio: campus.client.dio);
    auth.handler = (_) async => FakeApi.response({
      'access_token': 'A',
      'expires_at': '2099-01-01T00:00:00Z',
    });
    campus.handler = (_) async => _image();
  });

  tearDown(() {
    repository.dispose();
    auth.client.dispose();
  });

  test('图片并发请求复用下载，手动重试会绕过已缓存的坏图', () async {
    final first = repository.loadAsset('one');
    final same = repository.loadAsset('one');
    expect(identical(first, same), isTrue);
    await Future.wait([first, same]);
    expect(campus.requests, hasLength(1));
    await repository.loadAsset('one', refresh: true);
    expect(campus.requests, hasLength(2));
    expect(campus.requests.last.headers['Authorization'], 'Bearer A');
  });

  testWidgets('图片持续慢速返回也在总时限后取消，失败后可以重新下载', (tester) async {
    campus.client.dio.options.receiveTimeout = const Duration(seconds: 2);
    final chunks = StreamController<Uint8List>();
    addTearDown(() {
      unawaited(chunks.close());
    });
    campus.handler = (_) async => ResponseBody(
      chunks.stream,
      200,
      headers: {
        Headers.contentTypeHeader: ['image/png'],
      },
    );
    var completed = false;
    Object? result;
    repository
        .loadAsset('slow')
        .then<void>(
          (value) {
            completed = true;
            result = value;
          },
          onError: (Object error) {
            completed = true;
            result = error;
          },
        );
    await tester.pump();

    // 每秒仍有字节到达，不会触发两秒的断流超时，但不能一直等待整张大图。
    for (var second = 0; second < 30; second++) {
      chunks.add(Uint8List.fromList([1]));
      await tester.pump(const Duration(seconds: 1));
    }
    expect(completed, isTrue);
    expect(result, isNull);
    expect(campus.requests.single.cancelToken!.isCancelled, isTrue);
    expect(chunks.hasListener, isFalse);

    campus.handler = (_) async => _image();
    expect(await tester.runAsync(() => repository.loadAsset('slow')), [
      1,
      2,
      3,
    ]);
    expect(campus.requests, hasLength(2));
  });

  test('缩略图和原图分别请求并缓存，重试小图不会清除原图', () async {
    await repository.loadAsset('one', thumbnail: true);
    await repository.loadAsset('one');
    await repository.loadAsset('one', thumbnail: true);
    await repository.loadAsset('one');
    expect(campus.requests, hasLength(2));
    expect(campus.requests.first.queryParameters, {'variant': 'thumbnail'});
    expect(campus.requests.last.queryParameters, isEmpty);
    await repository.loadAsset('one', thumbnail: true, refresh: true);
    await repository.loadAsset('one');
    expect(campus.requests, hasLength(3));
    expect(campus.requests.last.headers['Authorization'], 'Bearer A');
  });

  test('投票提交后重新读取服务端帖子状态', () async {
    Map<String, dynamic> thread({required Map<String, dynamic> poll}) => {
      'id': 'poll-thread',
      'category_id': 'general',
      'category': {'id': 'general', 'name': '日常'},
      'title': '投票帖',
      'body': '',
      'author': {'id': 'user-1', 'display_name': '小高', 'avatar_preset': 1},
      'image_asset_ids': <String>[],
      'reply_count': 0,
      'like_count': 0,
      'my_like': false,
      'is_pinned': false,
      'is_locked': false,
      'status': 'normal',
      'version': 1,
      'created_at': '2026-11-10T00:00:00.000Z',
      'last_activity_at': '2026-11-10T00:00:00.000Z',
      'capabilities': {'can_reply': true},
      'poll': poll,
    };

    final voteResponse = {
      'question': '你更喜欢哪种活动？',
      'total_votes': 1,
      'my_option_id': null,
      'options': [
        {'id': 'option-a', 'label': '社团活动', 'count': 1, 'percent': 100},
        {'id': 'option-b', 'label': '体育活动', 'count': 0, 'percent': 0},
      ],
    };
    final refreshedPoll = {...voteResponse, 'my_option_id': 'option-a'};
    var voteSubmitted = false;
    campus.handler = (request) async {
      if (request.method == 'POST' && request.path.endsWith('/poll/vote')) {
        voteSubmitted = true;
        return FakeApi.response(voteResponse);
      }
      if (request.method == 'GET' && request.path.endsWith('/poll-thread')) {
        return FakeApi.response(
          thread(poll: voteSubmitted ? refreshedPoll : voteResponse),
        );
      }
      return FakeApi.response({'message': 'unexpected request'}, status: 500);
    };

    final voted = await repository.voteForumPoll(
      threadId: 'poll-thread',
      optionId: 'option-a',
    );
    expect(voted.myOptionId, 'option-a');
    expect(campus.requests.map((request) => request.method), ['POST', 'GET']);
    expect(campus.requests.last.path, '/api/v1/forum/threads/poll-thread');
  });

  testWidgets('鉴权超过图片总时限后不再启动过期的下载', (tester) async {
    final token = Completer<ResponseBody>();
    auth.handler = (_) => token.future;
    var completed = false;
    Object? result = 'pending';
    repository.loadAsset('late').then((value) {
      completed = true;
      result = value;
    });
    await tester.pump();
    await tester.pump(const Duration(seconds: 30));
    expect(completed, isTrue);
    expect(result, isNull);
    token.complete(
      FakeApi.response({
        'access_token': 'A',
        'expires_at': '2099-01-01T00:00:00Z',
      }),
    );
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pump(const Duration(milliseconds: 1));
    expect(campus.requests, isEmpty);
    Object? retryResult = 'pending';
    repository.loadAsset('late').then((value) => retryResult = value);
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pump(const Duration(milliseconds: 1));
    expect(retryResult, [1, 2, 3]);
    expect(campus.requests, hasLength(1));
  });

  test('退出账号会取消所有独立的图片下载', () async {
    final response = Completer<ResponseBody>();
    final started = Completer<void>();
    campus.handler = (_) {
      if (campus.requests.length == 2) started.complete();
      return response.future;
    };
    final images = [repository.loadAsset('one'), repository.loadAsset('two')];
    final checks = images
        .map((image) => expectLater(image, throwsA(isA<Exception>())))
        .toList();
    await started.future;
    repository.clearSession();
    await Future.wait(checks);
    expect(
      campus.requests.every((request) => request.cancelToken!.isCancelled),
      isTrue,
    );
    response.complete(_image());
  });

  test('200 错误页面和空文件不进入成功缓存，之后可以重新下载', () async {
    campus.handler = (_) async => ResponseBody.fromString(
      '<html>暂时不可用</html>',
      200,
      headers: {
        Headers.contentTypeHeader: ['text/html'],
      },
    );
    expect(await repository.loadAsset('one'), isNull);
    campus.handler = (_) async => _image(bytes: []);
    expect(await repository.loadAsset('one'), isNull);
    campus.handler = (_) async => _image();
    expect(await repository.loadAsset('one'), [1, 2, 3]);
    expect(campus.requests, hasLength(3));
  });

  test('长列表缓存淘汰旧图，最近访问的图片仍然复用', () async {
    for (var i = 0; i < 64; i++) {
      await repository.loadAsset('$i');
    }
    await repository.loadAsset('0');
    await repository.loadAsset('64');
    await repository.loadAsset('0');
    expect(campus.requests, hasLength(65));
    await repository.loadAsset('1');
    expect(campus.requests, hasLength(66));
  });

  test('并发旧图片的迟到 401 不会清除新凭证或反复刷新登录', () async {
    var tokenRequests = 0;
    auth.handler = (_) async => FakeApi.response({
      'access_token': ++tokenRequests == 1 ? 'A' : 'B',
      'expires_at': '2099-01-01T00:00:00Z',
    });
    final firstResponse = Completer<ResponseBody>();
    final secondResponse = Completer<ResponseBody>();
    final bothStarted = Completer<void>();
    var oldRequests = 0;
    campus.handler = (request) async {
      if (request.headers['Authorization'] == 'Bearer B') return _image();
      if (++oldRequests == 2) bothStarted.complete();
      return request.path.contains('/one/')
          ? firstResponse.future
          : secondResponse.future;
    };
    final first = repository.loadAsset('one');
    final second = repository.loadAsset('two');
    await bothStarted.future;
    firstResponse.complete(ResponseBody.fromString('expired', 401));
    expect(await first, [1, 2, 3]);
    secondResponse.complete(ResponseBody.fromString('expired', 401));
    expect(await second, [1, 2, 3]);
    expect(tokenRequests, 2);
  });

  test('切换账号会清除图片缓存，新账号重新鉴权下载', () async {
    await repository.loadAsset('one');
    repository.clearSession();
    await repository.loadAsset('one');
    expect(auth.requests, hasLength(2));
    expect(campus.requests, hasLength(2));
  });
}

ResponseBody _image({List<int> bytes = const [1, 2, 3]}) =>
    ResponseBody.fromBytes(
      bytes,
      200,
      headers: {
        Headers.contentTypeHeader: ['image/png'],
      },
    );
