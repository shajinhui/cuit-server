import 'dart:async';

import 'package:dio/dio.dart';

import '../../../core/storage/app_storage.dart';
import '../models/autorun_models.dart';

class AutoRunFailure implements Exception {
  const AutoRunFailure(this.message, {this.status = 0, this.code = 0});
  final String message;
  final int status, code;
  bool get expired =>
      status == 401 ||
      code == 40100 ||
      RegExp(
        r'登录态.*(?:失效|过期)|登录过期|请重新登录|unauthorized|token',
        caseSensitive: false,
      ).hasMatch(message);
  @override
  String toString() => message;
}

class AutoRunResult {
  const AutoRunResult(this.data, this.message);
  final Map<String, dynamic> data;
  final String message;
}

/// 校园跑使用独立的响应结构与登录凭证，不携带教务 Cookie。
class AutoRunRepository {
  AutoRunRepository(
    this.storage, {
    Dio? dio,
    String baseUrl = const String.fromEnvironment(
      'AUTORUN_API_BASE_URL',
      defaultValue: 'https://autorun-api.fanxiaogao05.dpdns.org',
    ),
  }) : dio =
           dio ??
           Dio(
             BaseOptions(
               baseUrl: baseUrl.replaceAll(RegExp(r'/+$'), ''),
               connectTimeout: const Duration(seconds: 15),
               receiveTimeout: const Duration(seconds: 60),
               sendTimeout: const Duration(seconds: 60),
               validateStatus: (_) => true,
               followRedirects: false,
               headers: {'Accept': 'application/json'},
             ),
           );
  final AppStorage storage;
  final Dio dio;
  String _sessionKey = '';
  int _generation = 0;
  bool _disposed = false;
  CancelToken _cancel = CancelToken();
  Future<void> _calls = Future.value();
  String get _storageKey => 'autorun.session:${dio.options.baseUrl}';
  bool get hasSession => _sessionKey.isNotEmpty;

  Future<AutoRunResult?> restore() {
    final generation = _generation;
    // 重新进入页面时，先等上一页的凭证轮换落盘，再恢复当前凭证。
    return _queue(() async {
      _check(generation);
      final saved = await storage.read(_storageKey);
      _check(generation);
      _sessionKey = saved?.trim() ?? '';
      return hasSession ? _request('run_info', {}, generation, true) : null;
    });
  }

  Future<AutoRunResult> login(String phone, String password) async {
    await logout();
    final result = await _call('login', {
      'phone': phone.trim(),
      'password': password.trim(),
    }, authenticate: false);
    if (!hasSession) throw const AutoRunFailure('校园跑登录凭证格式异常');
    return result;
  }

  Future<AutoRunResult> runInfo() => _call('run_info', {});
  Future<AutoRunResult> bootstrap() => _call('session_bootstrap', {});
  Future<AutoRunResult> prepareRun() => _call('run_prepare', {});
  Future<AutoRunResult> submitRun(Map<String, Object?> record) =>
      _call('run', {'record': record});
  Future<AutoRunResult> clubData(String date) =>
      _call('club_data', {'queryDate': date});
  Future<AutoRunResult> sign(AutoRunSignTask task) => _call('club_sign', {
    'activityId': task.id,
    'latitude': task.latitude,
    'longitude': task.longitude,
    'signType': task.signType,
  });
  Future<AutoRunResult> setSchedule(bool enabled) =>
      _call('club_schedule_set', {'enabled': enabled});
  Future<AutoRunResult> changeMembership(AutoRunActivity activity) async {
    final result = await _call(
      activity.isJoined ? 'club_cancel' : 'club_join',
      {'activityId': activity.id},
    );
    if (result.data['success'] == false) {
      throw AutoRunFailure(
        autoRunText(result.data['message']).isEmpty
            ? '报名操作未成功'
            : autoRunText(result.data['message']),
        status: 409,
        code: 40900,
      );
    }
    return result;
  }

  Future<AutoRunResult> _call(
    String action,
    Map<String, Object?> body, {
    bool authenticate = true,
  }) {
    final generation = _generation;
    // 按顺序处理凭证轮换，避免并发响应把新的 sessionKey 覆盖成旧值。
    return _queue(() => _request(action, body, generation, authenticate));
  }

  Future<T> _queue<T>(Future<T> Function() operation) {
    final task = _calls.then((_) => operation());
    _calls = task.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return task;
  }

  Future<AutoRunResult> _request(
    String action,
    Map<String, Object?> body,
    int generation,
    bool authenticate,
  ) async {
    _check(generation);
    if (authenticate && !hasSession) {
      throw const AutoRunFailure('请先登录校园跑', status: 401);
    }
    try {
      final response = await dio.post<Object?>(
        '/api/$action',
        data: body,
        cancelToken: _cancel,
        options: Options(
          receiveTimeout: Duration(seconds: action == 'login' ? 20 : 60),
          headers: {if (authenticate) 'Authorization': 'Bearer $_sessionKey'},
        ),
      );
      _check(generation);
      if (response.data is! Map) throw const AutoRunFailure('校园跑服务响应格式异常');
      final payload = autoRunMap(response.data);
      final code = (autoRunNumber(payload['code']) ?? 0).toInt();
      final status = response.statusCode ?? 500;
      if (status >= 400 || code != 10000) {
        var message = autoRunText(payload['msg']);
        if ((code >= 50200 && code < 50300) ||
            (status >= 500 &&
                RegExp(
                  '上游|upstream',
                  caseSensitive: false,
                ).hasMatch(message))) {
          message = '校园跑上游服务暂时不可用，请稍后重试';
        }
        throw AutoRunFailure(
          message.isEmpty ? '校园跑请求失败' : message,
          status: status,
          code: code,
        );
      }
      if (payload['response'] is! Map) throw const AutoRunFailure('校园跑数据格式异常');
      final data = autoRunMap(payload['response']);
      final rotated = autoRunText(data['sessionKey']);
      if (rotated.isNotEmpty) {
        _sessionKey = rotated;
        await storage.write(_storageKey, rotated);
        _check(generation);
      }
      return AutoRunResult(data, autoRunText(payload['msg']));
    } on DioException catch (error) {
      _check(generation);
      if (error.type == DioExceptionType.receiveTimeout ||
          error.type == DioExceptionType.connectionTimeout ||
          error.type == DioExceptionType.sendTimeout) {
        throw const AutoRunFailure('请求超时，请检查网络后重试', code: 40800);
      }
      throw const AutoRunFailure('无法连接校园跑服务，请检查网络后重试', code: 50300);
    }
  }

  void _check(int generation) {
    if (_disposed || generation != _generation) {
      throw const AutoRunFailure('校园跑账号已切换，请重新操作');
    }
  }

  Future<void> logout() async {
    _generation++;
    _cancel.cancel();
    _cancel = CancelToken();
    _sessionKey = '';
    // 等待旧请求的本机写入结束，再删除凭证，避免退出后旧响应恢复登录。
    await _calls;
    await storage.delete(_storageKey);
  }

  void dispose() {
    _disposed = true;
    _generation++;
    _cancel.cancel();
    dio.close(force: true);
  }
}
