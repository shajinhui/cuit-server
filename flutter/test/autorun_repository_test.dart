import 'dart:async';
import 'dart:convert';

import 'package:chengxin_youyou/core/storage/app_storage.dart';
import 'package:chengxin_youyou/features/autorun/data/autorun_repository.dart';
import 'package:chengxin_youyou/features/autorun/models/autorun_models.dart';
import 'package:chengxin_youyou/features/autorun/presentation/autorun_view_model.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes/fake_api.dart';

ResponseBody _response(
  Map<String, Object?> data, {
  int status = 200,
  int code = 10000,
  String message = '成功',
}) => ResponseBody.fromString(
  jsonEncode({'code': code, 'msg': message, 'response': data}),
  status,
  headers: {
    Headers.contentTypeHeader: ['application/json'],
  },
);

void main() {
  late FakeApi api;
  late MemoryAppStorage storage;
  late AutoRunRepository repository;
  const key = 'autorun.session:https://example.test';
  setUp(() {
    api = FakeApi();
    storage = MemoryAppStorage();
    repository = AutoRunRepository(storage, dio: api.client.dio);
  });
  tearDown(() => repository.dispose());

  test('重新进入页面先等凭证轮换落盘，不读取旧凭证覆盖新值', () async {
    final delayed = _DelayedWriteStorage();
    delayed.values[key] = 'old';
    final queued = AutoRunRepository(delayed, dio: api.client.dio);
    addTearDown(queued.dispose);
    api.handler = (_) async => _response({});
    await queued.restore();
    delayed.blockWrites = true;
    api.handler = (_) async => _response({'sessionKey': 'new'});
    final refresh = queued.runInfo();
    await delayed.writeStarted.future;
    final restore = queued.restore();
    api.handler = (_) async => _response({});
    delayed.releaseWrite.complete();
    await Future.wait([refresh, restore]);
    expect(api.requests.last.headers['Authorization'], 'Bearer new');
    expect(delayed.values[key], 'new');
  });

  test('独立登录只保存凭证，串行请求沿用最新轮换凭证', () async {
    api.handler = (request) async {
      if (request.path.endsWith('/login')) {
        return _response({'sessionKey': 'one'});
      }
      if (request.path.endsWith('/run_info')) {
        return _response({'sessionKey': 'two'});
      }
      return _response({});
    };
    await repository.login(' 13800138000 ', ' test-password ');
    expect(api.requests.single.headers['Authorization'], isNull);
    expect(api.requests.single.data, {
      'phone': '13800138000',
      'password': 'test-password',
    });
    expect(api.requests.single.receiveTimeout, const Duration(seconds: 20));
    await Future.wait([
      repository.runInfo(),
      repository.clubData('2026-10-06'),
    ]);
    expect(api.requests[1].headers['Authorization'], 'Bearer one');
    expect(api.requests[2].headers['Authorization'], 'Bearer two');
    expect(api.requests[2].data, {'queryDate': '2026-10-06'});
    expect(storage.values, {key: 'two'});
    expect(api.requests.any((v) => v.headers.containsKey('Cookie')), isFalse);
  });

  test('恢复凭证、签到坐标、报名取消和定时使用原版接口参数', () async {
    storage.values[key] = 'saved';
    api.handler = (_) async => _response({'success': true});
    await repository.restore();
    expect(api.requests.single.path, '/api/run_info');
    expect(api.requests.single.headers['Authorization'], 'Bearer saved');
    await repository.sign(
      AutoRunSignTask({
        'activityId': 9,
        'latitude': 30.5,
        'longitude': '104.0',
        'signStatus': '2',
        'signInStatus': '1',
      }),
    );
    expect(api.requests.last.data, {
      'activityId': 9,
      'latitude': '30.5',
      'longitude': '104.0',
      'signType': '2',
    });
    await repository.changeMembership(
      AutoRunActivity.fromJson({'clubActivityId': 9, 'optionStatus': '1'}),
    );
    expect(api.requests.last.path, '/api/club_cancel');
    expect(api.requests.last.data, {'activityId': 9});
    await repository.setSchedule(true);
    expect(api.requests.last.path, '/api/club_schedule_set');
    expect(api.requests.last.data, {'enabled': true});
    await repository.logout();
    expect(storage.values, isEmpty);
    expect(repository.hasSession, isFalse);
  });

  test('业务失败和上游错误不会当成成功，也不重试写操作', () async {
    storage.values[key] = 'saved';
    api.handler = (_) async => _response({});
    await repository.restore();
    api.handler = (_) async =>
        _response({'success': false, 'message': '报名时段已结束'});
    await expectLater(
      repository.changeMembership(
        AutoRunActivity.fromJson({'clubActivityId': 1}),
      ),
      throwsA(
        isA<AutoRunFailure>().having((e) => e.message, 'message', '报名时段已结束'),
      ),
    );
    expect(api.requests.where((v) => v.path == '/api/club_join'), hasLength(1));
    api.handler = (_) async =>
        _response({}, status: 502, code: 50200, message: '上游请求失败');
    await expectLater(
      repository.setSchedule(true),
      throwsA(
        isA<AutoRunFailure>().having(
          (e) => e.message,
          'message',
          '校园跑上游服务暂时不可用，请稍后重试',
        ),
      ),
    );
    expect(repository.hasSession, isTrue);
  });

  test('退出取消迟到响应，旧凭证不能恢复登录或用于新会话', () async {
    storage.values[key] = 'old';
    final response = Completer<ResponseBody>();
    final started = Completer<void>();
    api.handler = (_) {
      started.complete();
      return response.future;
    };
    final pending = repository.restore();
    final failed = expectLater(pending, throwsA(isA<AutoRunFailure>()));
    await started.future;
    await repository.logout();
    response.complete(_response({'sessionKey': 'late-old'}));
    await failed;
    expect(storage.values, isEmpty);
    api.handler = (_) async => _response({'sessionKey': 'new'});
    await repository.login('13800138000', 'test-only');
    expect(storage.values[key], 'new');
    expect(api.requests.last.headers['Authorization'], isNull);
  });

  test('登录过期撤销页面身份，返回前台的重复校验只发一次', () async {
    api.handler = (request) async => request.path.endsWith('/login')
        ? _response({'sessionKey': 'one'})
        : _response({
            'runInfo': {'runValidCount': 4},
          });
    final model = AutoRunViewModel(repository);
    addTearDown(model.dispose);
    await model.initialize();
    await model.login('13800138000', 'test-only');
    expect(model.progress.first.current, 4);
    model.joined = 6;
    model.scheduleEnabled = true;
    final response = Completer<ResponseBody>();
    final started = Completer<void>();
    api.handler = (_) {
      started.complete();
      return response.future;
    };
    final check = model.revalidateOnResume();
    await started.future;
    await model.revalidateOnResume();
    expect(
      api.requests.where((v) => v.path == '/api/session_bootstrap'),
      hasLength(1),
    );
    response.complete(
      _response({}, status: 401, code: 40100, message: '请重新登录'),
    );
    await check;
    expect(model.authenticated, isFalse);
    expect(model.progress, isEmpty);
    expect(model.joined, 0);
    expect(model.scheduleEnabled, isFalse);
    expect(storage.values, isEmpty);
  });
}

class _DelayedWriteStorage extends MemoryAppStorage {
  bool blockWrites = false;
  final writeStarted = Completer<void>();
  final releaseWrite = Completer<void>();
  @override
  Future<void> write(String key, String value) async {
    if (blockWrites) {
      writeStarted.complete();
      await releaseWrite.future;
    }
    await super.write(key, value);
  }
}
