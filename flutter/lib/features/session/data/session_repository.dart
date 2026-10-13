import 'dart:convert';

import 'package:flutter/services.dart';

import 'package:chengxin_youyou/core/network/api_client.dart';
import 'package:chengxin_youyou/core/network/api_exception.dart';
import 'package:chengxin_youyou/core/storage/app_storage.dart';

import '../models/student.dart';

class RestoredSession {
  const RestoredSession(this.student, {this.offline = false});
  final Student student;
  final bool offline;
}

abstract interface class SessionRepository {
  Future<RestoredSession?> restore();
  Future<Student> login(String number, String password);
  Future<void> logout();
}

class DefaultSessionRepository implements SessionRepository {
  DefaultSessionRepository(
    this.api,
    this.storage, {
    required this.clearUserData,
  }) : _profileKey = 'profile:${api.dio.options.baseUrl}';
  final ApiClient api;
  final AppStorage storage;
  final String _profileKey;
  final Future<void> Function(String account) clearUserData;

  @override
  Future<RestoredSession?> restore() async {
    final saved = await storage.read(_profileKey);
    if (saved == null) return null;
    Student student;
    try {
      student = Student.fromJson(jsonDecode(saved) as Map<String, dynamic>);
    } on FormatException {
      await _clear();
      return null;
    } on TypeError {
      await _clear();
      return null;
    }
    try {
      final status = await api.request('/api/v1/jwxt/session');
      if (status is! Map || status['authenticated'] != true) {
        await _clear();
        return null;
      }
      return RestoredSession(await _profile());
    } on ApiException catch (error) {
      if (error.kind == FailureKind.authentication) {
        await _clear();
        return null;
      }
      // 只有本机已有上次验证过的身份，才允许断网时进入离线课表。
      if (error.kind == FailureKind.network) {
        return RestoredSession(student, offline: true);
      }
      rethrow;
    }
  }

  @override
  Future<Student> login(String number, String password) async {
    try {
      await _clear();
      final result = await api.request(
        '/api/v1/jwxt/session',
        method: 'POST',
        data: {'username': number, 'password': password},
      );
      if (result is! Map || result['authenticated'] != true) {
        throw const ApiException('登录未完成，请检查学号和密码。');
      }
      return await _profile();
    } catch (error) {
      try {
        await _clear();
      } catch (_) {
        // 保留最初的失败原因；下次登录仍会先清理旧会话。
      }
      if (error is PlatformException) {
        throw const ApiException(
          '无法读写本机登录状态，请重启应用后重试。',
          kind: FailureKind.storage,
        );
      }
      rethrow;
    }
  }

  Future<Student> _profile() async {
    final data = await api.request('/api/v1/jwxt/profile');
    try {
      final student = Student.fromJson(data as Map<String, dynamic>);
      await storage.write(_profileKey, jsonEncode(student.toJson()));
      return student;
    } on FormatException {
      throw const ApiException(
        '个人信息不完整，暂时无法确认账号。',
        kind: FailureKind.invalidResponse,
      );
    } on TypeError {
      throw const ApiException(
        '个人信息格式异常，请稍后重试。',
        kind: FailureKind.invalidResponse,
      );
    }
  }

  @override
  Future<void> logout() async {
    api.cancelRequests();
    try {
      await api.request('/api/v1/jwxt/session', method: 'DELETE');
    } on ApiException catch (error) {
      // 服务端已认定会话失效时，无需再次撤销，但仍清理本机数据。
      if (error.kind != FailureKind.authentication) rethrow;
    } finally {
      await _clear();
    }
  }

  Future<void> _clear() async {
    final saved = await storage.read(_profileKey);
    String? account;
    if (saved != null) {
      try {
        account = Student.fromJson(
          jsonDecode(saved) as Map<String, dynamic>,
        ).number;
      } on FormatException {
        /* 无法识别的身份只清理会话。 */
      } on TypeError {
        /* 无法识别的身份只清理会话。 */
      }
    }
    // 即使缓存清理失败，也必须撤销本机登录状态。
    try {
      if (account != null) await clearUserData(account);
    } finally {
      try {
        await api.clearCookies();
      } finally {
        await storage.delete(_profileKey);
      }
    }
  }
}
