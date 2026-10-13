import 'package:dio/browser.dart';
import 'package:dio/dio.dart';

import '../storage/app_storage.dart';
import 'api_exception.dart';

Future<Future<void> Function()> configureSessionTransport(
  Dio dio,
  AppStorage secureStorage,
) async {
  dio.httpClientAdapter = BrowserHttpClientAdapter(withCredentials: true);
  // HttpOnly Cookie 由浏览器管理，退出时由服务端 DELETE 接口撤销。
  return () async {};
}

// 浏览器自行管理 Cookie，不经过移动端的安全存储。
ApiException? sessionTransportFailure(DioException error) => null;
