import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:chengxin_youyou/core/network/api_client.dart';
import 'package:chengxin_youyou/core/network/api_exception.dart';
import 'package:chengxin_youyou/core/storage/app_storage.dart';
import 'package:chengxin_youyou/features/session/session.dart';
import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes/fake_api.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const origin = 'https://api.example.test';

  Future<ApiClient> createClient(
    AppStorage storage,
    _SessionAdapter adapter,
  ) async {
    // 使用正式 Cookie 拦截器和安全存储适配，只替换最底层 HTTP 响应。
    final client = await ApiClient.create(origin, storage);
    client.dio.httpClientAdapter = adapter;
    addTearDown(client.dispose);
    return client;
  }

  DefaultSessionRepository repository(ApiClient client, AppStorage storage) =>
      DefaultSessionRepository(client, storage, clearUserData: (_) async {});

  Future<ApiClient> savedSession(
    MemoryAppStorage storage,
    _SessionAdapter adapter,
  ) async {
    adapter.handler = (request) async => request.method == 'POST'
        ? _loginResponse()
        : FakeApi.response(Student.demo.toJson());
    final first = await createClient(storage, adapter);
    await repository(first, storage).login('20260001', 'test-only-password');
    adapter.requests.clear();
    return createClient(storage, adapter);
  }

  test('启动从安全存储恢复本机身份，不等待会话或个人信息接口', () async {
    final storage = MemoryAppStorage();
    final adapter = _SessionAdapter();
    final client = await savedSession(storage, adapter);
    adapter.handler = (_) => Completer<ResponseBody>().future;
    final session = SessionViewModel(repository(client, storage));
    addTearDown(session.dispose);

    await session.restore(cacheOnly: true).timeout(const Duration(seconds: 1));

    expect(session.student?.number, Student.demo.number);
    expect(session.isOffline, isTrue);
    expect(session.isRestoring, isFalse);
    expect(adapter.requests, isEmpty);
  });

  test('仅有缓存身份但没有可用 Cookie 时，不恢复为已登录页面', () async {
    final storage = MemoryAppStorage();
    await storage.write('profile:$origin', jsonEncode(Student.demo.toJson()));
    final adapter = _SessionAdapter();
    final client = await createClient(storage, adapter);

    expect(await repository(client, storage).restoreCached(), isNull);
    expect(adapter.requests, isEmpty);
  });

  test('启动读取 Cookie 失败时，不伪装成可用的离线登录', () async {
    final storage = _FailingStorage();
    final adapter = _SessionAdapter();
    final client = await savedSession(storage, adapter);
    storage.failCookieReads = true;

    await expectLater(
      repository(client, storage).restoreCached(),
      throwsA(
        isA<ApiException>().having((e) => e.kind, 'kind', FailureKind.storage),
      ),
    );
    expect(adapter.requests, isEmpty);
  });

  test('缓存先显示后，受保护的请求仍拒绝 401，过期退出清理身份', () async {
    final storage = MemoryAppStorage();
    final adapter = _SessionAdapter();
    final client = await savedSession(storage, adapter);
    final session = SessionViewModel(repository(client, storage));
    addTearDown(session.dispose);
    await session.restore(cacheOnly: true);
    adapter.handler = (_) async => FakeApi.response(null, status: 401);

    await expectLater(
      client.request('/api/v1/jwxt/semesters'),
      throwsA(
        isA<ApiException>().having(
          (e) => e.kind,
          'kind',
          FailureKind.authentication,
        ),
      ),
    );
    await session.logout(expired: true);

    expect(session.student, isNull);
    expect(session.error, '登录已过期，请重新登录。');
    expect(storage.values, isEmpty);
  });

  test('原生登录 Cookie 用于读取个人信息，重建客户端后仍可恢复，退出会清理', () async {
    final storage = MemoryAppStorage();
    final adapter = _SessionAdapter();
    adapter.handler = (request) async {
      if (request.method == 'POST') return _loginResponse();
      if (request.method == 'DELETE') {
        return FakeApi.response({'authenticated': false});
      }
      if (request.headers[HttpHeaders.cookieHeader] !=
          'jwxt_session=test-session') {
        return FakeApi.response(null, status: 401, message: '教务登录已失效');
      }
      return FakeApi.response(
        request.path.endsWith('/profile')
            ? Student.demo.toJson()
            : {'authenticated': true},
      );
    };
    final first = await createClient(storage, adapter);
    final student = await repository(
      first,
      storage,
    ).login('20260001', 'test-only-password');
    expect(student.number, Student.demo.number);
    expect(
      adapter.requests.last.headers[HttpHeaders.cookieHeader],
      'jwxt_session=test-session',
    );
    expect(storage.values.values.join(), isNot(contains('test-only-password')));

    final second = await createClient(storage, adapter);
    final restored = await repository(second, storage).restore();
    expect(restored?.student.number, Student.demo.number);
    expect(restored?.offline, isFalse);
    await repository(second, storage).logout();
    expect(storage.values, isEmpty);
  });

  test('Cookie 保存失败和后续清理失败时，仍展示最初的保存错误', () async {
    final storage = _FailingStorage();
    final adapter = _SessionAdapter();
    adapter.handler = (_) async {
      storage.failCookieWrites = true;
      storage.failDeletes = true;
      return _loginResponse();
    };
    final client = await createClient(storage, adapter);
    await expectLater(
      repository(client, storage).login('20260001', 'test-only-password'),
      throwsA(
        isA<ApiException>()
            .having((e) => e.kind, 'kind', FailureKind.storage)
            .having((e) => e.message, 'message', '无法保存本机登录状态，请重启应用后重试。'),
      ),
    );
    // 凭证没有保存成功，不能继续请求个人信息或保存已登录身份。
    expect(adapter.requests, hasLength(1));
    expect(storage.values.keys, isNot(contains('profile:$origin')));
  });

  test('Cookie 读取故障不能被误判为断网并恢复离线登录', () async {
    final storage = _FailingStorage();
    await storage.write('profile:$origin', '{"StudentNo":"DEMO"}');
    storage.failCookieReads = true;
    final adapter = _SessionAdapter();
    final client = await createClient(storage, adapter);
    await expectLater(
      repository(client, storage).restore(),
      throwsA(
        isA<ApiException>().having((e) => e.kind, 'kind', FailureKind.storage),
      ),
    );
    expect(adapter.requests, isEmpty);
  });

  test('登录前安全存储失败时显示明确原因，且不发送账号密码', () async {
    final storage = _FailingStorage()..failProfileReads = true;
    final adapter = _SessionAdapter();
    final client = await createClient(storage, adapter);
    await expectLater(
      repository(client, storage).login('20260001', 'test-only-password'),
      throwsA(
        isA<ApiException>()
            .having((e) => e.kind, 'kind', FailureKind.storage)
            .having((e) => e.message, 'message', '无法读写本机登录状态，请重启应用后重试。'),
      ),
    );
    expect(adapter.requests, isEmpty);
  });
}

ResponseBody _loginResponse() => FakeApi.response({'authenticated': true})
  ..headers[HttpHeaders.setCookieHeader] = [
    'jwxt_session=test-session; Domain=.example.test; Path=/; HttpOnly; Secure; SameSite=Lax',
  ];

class _SessionAdapter implements HttpClientAdapter {
  final requests = <RequestOptions>[];
  Future<ResponseBody> Function(RequestOptions)? handler;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    return handler!(options);
  }

  @override
  void close({bool force = false}) {}
}

class _FailingStorage extends MemoryAppStorage {
  bool failCookieReads = false;
  bool failCookieWrites = false;
  bool failProfileReads = false;
  bool failDeletes = false;

  @override
  Future<String?> read(String key) async {
    if ((failCookieReads && key.startsWith('cookies:')) ||
        (failProfileReads && key.startsWith('profile:'))) {
      throw PlatformException(code: 'test_read_failure');
    }
    return super.read(key);
  }

  @override
  Future<void> write(String key, String value) async {
    if (failCookieWrites && key.startsWith('cookies:')) {
      throw PlatformException(code: 'test_write_failure');
    }
    await super.write(key, value);
  }

  @override
  Future<void> delete(String key) async {
    if (failDeletes) throw PlatformException(code: 'test_delete_failure');
    await super.delete(key);
  }
}
