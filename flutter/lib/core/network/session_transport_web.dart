import 'package:dio/browser.dart';
import 'package:dio/dio.dart';

import '../storage/app_storage.dart';
import 'api_exception.dart';
import 'session_transport_contract.dart';

Future<SessionTransport> configureSessionTransport(
  Dio dio,
  AppStorage secureStorage,
) async {
  dio.httpClientAdapter = BrowserHttpClientAdapter(withCredentials: true);
  // HttpOnly Cookie 由浏览器管理，退出时由服务端 DELETE 接口撤销。
  return SessionTransport(
    clearCookies: () async {},
    // 浏览器不能读取 HttpOnly Cookie，也不持久保存身份到本机缓存。
    hasStoredCookies: () async => false,
  );
}

// 浏览器自行管理 Cookie，不经过移动端的安全存储。
ApiException? sessionTransportFailure(DioException error) => null;
