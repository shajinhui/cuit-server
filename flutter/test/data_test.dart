import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:chengxin_youyou/core/network/api_exception.dart';
import 'package:chengxin_youyou/core/storage/app_storage.dart';
import 'package:chengxin_youyou/features/session/session.dart';
import 'package:chengxin_youyou/features/schedule/schedule.dart';
import 'package:chengxin_youyou/features/schedule/models/semester.dart';

import 'fakes/fake_api.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late FakeApi api;
  late MemoryAppStorage storage;
  setUp(() {
    api = FakeApi();
    storage = MemoryAppStorage();
  });
  tearDown(() => api.client.dispose());

  test('区分未授权、业务错误与网络故障', () async {
    api.handler = (_) async => FakeApi.response(null, status: 401);
    await expectLater(
      api.client.request('/test'),
      throwsA(
        isA<ApiException>().having(
          (e) => e.kind,
          'kind',
          FailureKind.authentication,
        ),
      ),
    );
    api.handler = (_) async =>
        FakeApi.response(null, code: 1, message: '学号或密码错误');
    await expectLater(
      api.client.request('/test'),
      throwsA(
        isA<ApiException>().having((e) => e.message, 'message', '学号或密码错误'),
      ),
    );
    api.handler = (request) async => throw DioException(
      requestOptions: request,
      type: DioExceptionType.connectionError,
    );
    await expectLater(
      api.client.request('/test'),
      throwsA(
        isA<ApiException>().having((e) => e.kind, 'kind', FailureKind.network),
      ),
    );
  });

  test('401 保留服务端的账号错误提示，不统一显示为登录过期', () async {
    api.handler = (_) async =>
        FakeApi.response(null, status: 401, code: 40100, message: '学号或密码错误');
    await expectLater(
      api.client.request('/api/v1/jwxt/session', method: 'POST'),
      throwsA(
        isA<ApiException>()
            .having((e) => e.kind, 'kind', FailureKind.authentication)
            .having((e) => e.message, 'message', '学号或密码错误'),
      ),
    );
  });

  test('超时和证书错误分别提示，不显示底层异常中的敏感内容', () async {
    const messages = {
      DioExceptionType.connectionTimeout: '连接服务超时，请切换网络后重试。',
      DioExceptionType.sendTimeout: '发送请求超时，请检查网络后重试。',
      DioExceptionType.receiveTimeout: '服务响应超时，请稍后重试。',
      DioExceptionType.badCertificate: '无法验证服务证书，请检查手机日期、时间和网络。',
    };
    for (final entry in messages.entries) {
      api.handler = (request) async => throw DioException(
        requestOptions: request,
        type: entry.key,
        error: 'test-only-secret',
      );
      await expectLater(
        api.client.request('/api/v1/jwxt/session', method: 'POST'),
        throwsA(
          isA<ApiException>()
              .having((e) => e.kind, 'kind', FailureKind.network)
              .having((e) => e.message, 'message', entry.value),
        ),
      );
    }
  });

  test('登录只保存验证后的身份，不保存密码；退出清理账号数据', () async {
    final clearedAccounts = <String>[];
    final repository = DefaultSessionRepository(
      api.client,
      storage,
      clearUserData: (account) async {
        clearedAccounts.add(account);
      },
    );
    api.handler = (request) async => FakeApi.response(
      request.path.endsWith('/profile')
          ? Student.demo.toJson()
          : {'authenticated': true},
    );
    final student = await repository.login('20260001', 'test-only-password');
    expect(student.number, 'DEMO');
    expect(api.requests.first.data, {
      'username': '20260001',
      'password': 'test-only-password',
    });
    expect(storage.values.values.join(), isNot(contains('test-only-password')));
    await repository.logout();
    expect(clearedAccounts, ['DEMO']);
    expect(storage.values, isEmpty);
    expect(api.requests.last.method, 'DELETE');
  });

  test('服务端会话已过期时退出仍完成本机清理', () async {
    await storage.write(
      'profile:https://example.test',
      jsonEncode(Student.demo.toJson()),
    );
    final cleared = <String>[];
    final repository = DefaultSessionRepository(
      api.client,
      storage,
      clearUserData: (account) async {
        cleared.add(account);
      },
    );
    api.handler = (_) async => FakeApi.response(null, status: 401);
    await repository.logout();
    expect(cleared, ['DEMO']);
    expect(storage.values, isEmpty);
  });

  test('断网允许恢复已验证身份，401 必须清除身份', () async {
    await storage.write(
      'profile:https://example.test',
      jsonEncode(Student.demo.toJson()),
    );
    final cleared = <String>[];
    final repository = DefaultSessionRepository(
      api.client,
      storage,
      clearUserData: (account) async {
        cleared.add(account);
      },
    );
    api.handler = (request) async => throw DioException(
      requestOptions: request,
      type: DioExceptionType.connectionError,
    );
    expect((await repository.restore())?.offline, isTrue);
    api.handler = (_) async => FakeApi.response(null, status: 401);
    expect(await repository.restore(), isNull);
    expect(cleared, ['DEMO']);
    expect(storage.values, isEmpty);
  });

  test('课表缓存隔离账号，强制刷新带 refresh=1', () async {
    final table = (await DemoScheduleRepository().load('s1')).table;
    api.handler = (request) async => FakeApi.response(table.toJson());
    final first = DefaultScheduleRepository(api.client, storage, 'one');
    expect((await first.load('s1')).fromCache, isFalse);
    expect((await first.load('s1')).fromCache, isTrue);
    expect(api.requests, hasLength(1));
    await first.load('s1', refresh: true);
    expect(api.requests.last.queryParameters['refresh'], '1');
    await DefaultScheduleRepository(api.client, storage, 'two').load('s1');
    expect(api.requests, hasLength(3));
    await first.clear();
    expect(storage.values.keys.any((key) => key.contains(':one:')), isFalse);
    expect(storage.values.keys.any((key) => key.contains(':two:')), isTrue);
  });

  test('退出后的迟到响应不会重新写入缓存', () async {
    final response = Completer<ResponseBody>();
    api.handler = (_) => response.future;
    final repository = DefaultScheduleRepository(api.client, storage, 'one');
    final load = repository.load('s1');
    final expectation = expectLater(
      load,
      throwsA(
        isA<ApiException>().having(
          (e) => e.kind,
          'kind',
          FailureKind.cancelled,
        ),
      ),
    );
    await Future<void>.delayed(Duration.zero);
    await repository.clear();
    response.complete(
      FakeApi.response(
        (await DemoScheduleRepository().load('s1')).table.toJson(),
      ),
    );
    await expectation;
    expect(storage.values, isEmpty);
  });

  test('主动刷新学期目录，断网时回退已有目录', () async {
    final key = 'v1:https://example.test:one:semesters';
    await storage.write(
      key,
      jsonEncode([DemoScheduleRepository.semester.toJson()]),
    );
    api.handler = (request) async => throw DioException(
      requestOptions: request,
      type: DioExceptionType.connectionError,
    );
    final repository = DefaultScheduleRepository(api.client, storage, 'one');
    expect(
      (await repository.semesters(refresh: true)).first.id,
      DemoScheduleRepository.semester.id,
    );
    api.handler = (_) async => FakeApi.response([
      {'ID': 'new', 'SchoolYear': '2027-2028', 'Term': '1'},
    ]);
    expect((await repository.semesters(refresh: true)).first.id, 'new');
    expect(api.requests, hasLength(2));
  });

  test('校历沿用原版本地日期和周一边界，不猜测未知学期', () async {
    final calendar = await AcademicCalendar.load();
    const semester = Semester(id: '2026', schoolYear: '2026-2027', term: '1');
    expect(calendar.currentWeek(semester, DateTime(2026, 9, 6, 23, 59, 59)), 0);
    expect(calendar.currentWeek(semester, DateTime(2026, 9, 7)), 1);
    expect(
      calendar.currentWeek(semester, DateTime.parse('2026-09-30T12:00:00Z')),
      4,
    );
    expect(
      calendar.currentWeek(semester, DateTime.parse('2027-01-18T00:00:00Z')),
      0,
    );
    expect(sectionStart(1, semester, '龙泉校区'), '08:20');
  });
}
