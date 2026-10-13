import 'package:chengxin_youyou/core/network/api_exception.dart';
import 'package:flutter/foundation.dart';

import '../data/session_repository.dart';
import '../models/student.dart';

class SessionViewModel extends ChangeNotifier {
  SessionViewModel(this.repository);
  final SessionRepository repository;
  Student? student;
  bool isRestoring = true;
  bool isSubmitting = false;
  bool isDemo = false;
  bool isOffline = false;
  String? error;
  int generation = 0;
  bool _disposed = false;

  Future<void> restore() async {
    final requestGeneration = ++generation;
    isRestoring = true;
    error = null;
    _notify();
    try {
      final result = await repository.restore();
      if (_disposed || requestGeneration != generation) return;
      student = result?.student;
      isOffline = result?.offline ?? false;
    } catch (_) {
      if (_disposed || requestGeneration != generation) return;
      error = '暂时无法恢复登录，你可以重试或重新登录。';
    } finally {
      if (!_disposed && requestGeneration == generation) {
        isRestoring = false;
        _notify();
      }
    }
  }

  Future<bool> login(String number, String password) async {
    if (isSubmitting) return false;
    final requestGeneration = ++generation;
    isSubmitting = true;
    error = null;
    _notify();
    try {
      final result = await repository.login(number.trim(), password);
      if (_disposed || requestGeneration != generation) return false;
      student = result;
      isDemo = false;
      isOffline = false;
      return true;
    } on ApiException catch (failure) {
      if (!_disposed && requestGeneration == generation) {
        error = failure.message;
      }
      return false;
    } catch (_) {
      if (!_disposed && requestGeneration == generation) error = '登录未完成，请稍后重试。';
      return false;
    } finally {
      if (!_disposed && requestGeneration == generation) {
        isSubmitting = false;
        _notify();
      }
    }
  }

  void markOnline() {
    if (student == null || !isOffline) return;
    isOffline = false;
    _notify();
  }

  void enterDemo() {
    if (isSubmitting) return;
    generation++;
    student = Student.demo;
    isDemo = true;
    isOffline = false;
    isRestoring = false;
    error = null;
    _notify();
  }

  /// 先使界面会话失效，旧请求返回后也不能恢复原账号页面。
  Future<void> logout({bool expired = false}) async {
    if (isSubmitting) return;
    final wasDemo = isDemo;
    generation++;
    student = null;
    isDemo = false;
    isOffline = false;
    isSubmitting = true;
    error = null;
    _notify();
    try {
      if (!wasDemo) await repository.logout();
      if (expired) error = '登录已过期，请重新登录。';
    } catch (_) {
      error = '退出清理未完全完成，请检查网络后重新登录。';
    } finally {
      isSubmitting = false;
      _notify();
    }
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    generation++;
    super.dispose();
  }
}
