import 'dart:async';

import 'package:flutter/foundation.dart';

import '../data/autorun_repository.dart';
import '../models/autorun_models.dart';
import '../models/run_record.dart';

/// 页面状态只接收当前会话、当前查询的结果，返回后台后的校验不会重复执行。
class AutoRunViewModel extends ChangeNotifier {
  AutoRunViewModel(this.repository);
  final AutoRunRepository repository;
  bool authenticated = false;
  bool checking = true;
  bool busy = false;
  bool loadingRun = false;
  bool loadingClub = false;
  bool scheduleEnabled = false;
  String scheduleMessage = '定时未开启';
  String? error;
  String? message;
  List<AutoRunProgress> progress = [];
  List<AutoRunActivity> activities = [];
  AutoRunSignTask? signTask;
  int joined = 0;
  int target = 12;
  String queryDate = autoRunDate(DateTime.now());
  int _sessionVersion = 0;
  int _runRequest = 0;
  int _clubRequest = 0;
  bool _disposed = false;
  bool _revalidating = false;

  Future<void> initialize() async {
    final version = ++_sessionVersion;
    try {
      final result = await repository.restore();
      if (!_current(version)) return;
      authenticated = repository.hasSession;
      if (result != null) progress = AutoRunProgress.fromJson(result.data);
    } catch (failure) {
      if (!_current(version)) return;
      authenticated = repository.hasSession;
      await _failure(failure, version);
    } finally {
      if (_current(version)) {
        checking = false;
        _notify();
      }
    }
  }

  Future<void> login(String phone, String password) async {
    if (_disposed || busy || checking) return;
    final version = ++_sessionVersion;
    busy = true;
    error = null;
    message = null;
    _notify();
    try {
      await repository.login(phone, password);
      if (!_current(version)) return;
      authenticated = true;
      _clearAccountData();
      message = '登录成功';
      await loadRun();
    } catch (failure) {
      await _failure(failure, version);
    } finally {
      if (_current(version)) {
        busy = false;
        _notify();
      }
    }
  }

  Future<void> logout() async {
    if (_disposed || busy) return;
    final version = ++_sessionVersion;
    authenticated = false;
    busy = true;
    checking = false;
    _clearAccountData();
    error = null;
    message = null;
    _runRequest++;
    _clubRequest++;
    _notify();
    try {
      await repository.logout();
    } catch (_) {
      if (_current(version)) error = '本机凭证清理失败，请重试。';
    } finally {
      if (_current(version)) {
        busy = false;
        loadingRun = false;
        loadingClub = false;
        _notify();
      }
    }
  }

  Future<void> loadRun() async {
    if (_disposed || !authenticated) return;
    final version = _sessionVersion, request = ++_runRequest;
    loadingRun = true;
    error = null;
    _notify();
    try {
      final result = await repository.runInfo();
      if (_current(version) && request == _runRequest) {
        progress = AutoRunProgress.fromJson(result.data);
      }
    } catch (failure) {
      if (request == _runRequest) await _failure(failure, version);
    } finally {
      if (_current(version) && request == _runRequest) {
        loadingRun = false;
        _notify();
      }
    }
  }

  Future<void> loadClub({String? date}) async {
    if (_disposed || !authenticated) return;
    if (date != null) queryDate = date;
    final selectedDate = queryDate;
    final version = _sessionVersion, request = ++_clubRequest;
    loadingClub = true;
    error = null;
    _notify();
    try {
      final result = await repository.clubData(selectedDate);
      if (!_current(version) || request != _clubRequest) return;
      final data = result.data;
      activities = (data['activities'] as List? ?? [])
          .map((v) => AutoRunActivity.fromJson(autoRunMap(v)))
          .where((v) => v.id > 0)
          .toList();
      final task = AutoRunSignTask(autoRunMap(data['signTask']));
      signTask = task.id > 0 ? task : null;
      final counts = autoRunMap(data['joinProgress']);
      joined = (autoRunNumber(counts['joinNum']) ?? 0).toInt();
      target = (autoRunNumber(counts['totalNum']) ?? 12).toInt().clamp(
        joined > 0 ? joined : 1,
        1 << 30,
      );
      _applySchedule(autoRunMap(data['schedule']));
    } catch (failure) {
      if (request == _clubRequest) await _failure(failure, version);
    } finally {
      if (_current(version) && request == _clubRequest) {
        loadingClub = false;
        _notify();
      }
    }
  }

  Future<void> runOnce() => _action(() async {
    final preparation = await repository.prepareRun();
    final record = await prepareAutoRunRecord(preparation.data);
    if (_disposed || !authenticated) return;
    final result = await repository.submitRun(record);
    if (result.data['success'] == false) {
      throw AutoRunFailure(result.message.isEmpty ? '记录提交未成功' : result.message);
    }
    message = result.message.isEmpty ? '记录提交成功' : result.message;
    await loadRun();
  });
  Future<void> changeMembership(AutoRunActivity activity) => _action(() async {
    final result = await repository.changeMembership(activity);
    message = autoRunText(result.data['message']).isNotEmpty
        ? autoRunText(result.data['message'])
        : activity.isJoined
        ? '已取消报名'
        : '报名成功';
    await loadClub();
  });
  Future<void> sign() async {
    final task = signTask;
    if (task == null || !task.canSign) return;
    await _action(() async {
      final result = await repository.sign(task);
      if (result.data['success'] != true) {
        throw AutoRunFailure(
          result.message.isEmpty ? '当前暂不可操作' : result.message,
        );
      }
      message = task.signType == '2' ? '签退成功' : '签到成功';
      await loadClub();
    });
  }

  Future<void> setSchedule(bool enabled) => _action(() async {
    final result = await repository.setSchedule(enabled);
    if (result.data['success'] == false) {
      throw AutoRunFailure(
        result.message.isEmpty ? '定时配置保存失败' : result.message,
      );
    }
    _applySchedule({
      ...autoRunMap(result.data['schedule']),
      'enabled': autoRunMap(result.data['schedule'])['enabled'] ?? enabled,
    });
    message = enabled ? '已开启俱乐部定时' : '已关闭俱乐部定时';
  });
  void _applySchedule(Map<String, dynamic> schedule) {
    scheduleEnabled = schedule['enabled'] == true;
    final text = autoRunText(schedule['lastMessage']);
    scheduleMessage = text.isNotEmpty
        ? text
        : scheduleEnabled
        ? '定时已开启'
        : '定时未开启';
  }

  Future<void> revalidateOnResume() async {
    if (_disposed || checking || busy || !authenticated || _revalidating) {
      return;
    }
    final version = _sessionVersion;
    _revalidating = true;
    try {
      await repository.bootstrap();
    } catch (failure) {
      await _failure(failure, version);
    } finally {
      _revalidating = false;
    }
  }

  Future<void> _action(Future<void> Function() action) async {
    if (_disposed || busy || !authenticated || checking) return;
    final version = _sessionVersion;
    busy = true;
    error = null;
    message = null;
    _notify();
    try {
      await action();
    } catch (failure) {
      await _failure(failure, version);
    } finally {
      if (_current(version)) {
        busy = false;
        _notify();
      }
    }
  }

  Future<void> _failure(Object failure, int version) async {
    if (!_current(version)) return;
    error = failure is AutoRunFailure ? failure.message : '操作未完成，请稍后重试。';
    if (failure is AutoRunFailure && failure.expired) {
      authenticated = false;
      _clearAccountData();
      try {
        await repository.logout();
      } catch (_) {
        /* 界面仍撤销过期身份。 */
      }
    }
    if (_current(version)) _notify();
  }

  bool _current(int version) => !_disposed && version == _sessionVersion;

  void _clearAccountData() {
    progress = [];
    activities = [];
    signTask = null;
    joined = 0;
    target = 12;
    scheduleEnabled = false;
    scheduleMessage = '定时未开启';
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _sessionVersion++;
    super.dispose();
  }
}
