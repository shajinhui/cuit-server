import 'dart:io';

import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';

import '../storage/app_storage.dart';
import 'api_exception.dart';

Future<Future<void> Function()> configureSessionTransport(
  Dio dio,
  AppStorage secureStorage,
) async {
  final jar = PersistCookieJar(
    storage: _SecureCookieStorage(secureStorage, dio.options.baseUrl),
    persistSession: true,
    ignoreExpires: false,
  );
  dio.interceptors.add(CookieManager(jar));
  return jar.deleteAll;
}

/// Cookie 读写失败不等于断网，不能因此恢复为离线登录。
ApiException? sessionTransportFailure(DioException error) {
  final cause = error.error;
  if (cause is CookieManagerLoadException) {
    return const ApiException(
      '无法读取本机登录状态，请重启应用后重试。',
      kind: FailureKind.storage,
    );
  }
  if (cause is CookieManagerSaveException) {
    if (cause.error is HttpException) {
      return const ApiException(
        '服务返回的登录凭证格式异常，请稍后重试。',
        kind: FailureKind.invalidResponse,
      );
    }
    return const ApiException(
      '无法保存本机登录状态，请重启应用后重试。',
      kind: FailureKind.storage,
    );
  }
  return null;
}

/// CookieJar 的持久数据进入系统安全存储，不落入明文文件。
class _SecureCookieStorage implements Storage {
  _SecureCookieStorage(this.storage, String origin)
    : prefix = 'cookies:$origin:';
  final AppStorage storage;
  final String prefix;

  @override
  Future<void> init(bool persistSession, bool ignoreExpires) async {}
  @override
  Future<String?> read(String key) => storage.read('$prefix$key');
  @override
  Future<void> write(String key, String value) =>
      storage.write('$prefix$key', value);
  @override
  Future<void> delete(String key) => storage.delete('$prefix$key');
  @override
  Future<void> deleteAll(List<String> keys) async {
    for (final key in keys) {
      await delete(key);
    }
  }
}
