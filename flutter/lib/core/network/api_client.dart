import 'package:dio/dio.dart';

import '../storage/app_storage.dart';
import 'api_exception.dart';
import 'session_transport.dart';

class ApiClient {
  ApiClient(this.dio, this.clearCookies);

  final Dio dio;
  final Future<void> Function() clearCookies;
  CancelToken _cancelToken = CancelToken();

  static Future<ApiClient> create(
    String baseUrl,
    AppStorage secureStorage,
  ) async {
    final uri = Uri.tryParse(baseUrl);
    if (uri == null ||
        !uri.hasAuthority ||
        !['https', 'http'].contains(uri.scheme)) {
      throw const ApiException('接口地址无效，请检查构建配置。');
    }
    final dio = Dio(
      BaseOptions(
        baseUrl: baseUrl.replaceAll(RegExp(r'/$'), ''),
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 30),
        sendTimeout: const Duration(seconds: 20),
        followRedirects: false,
        validateStatus: (status) => status != null && status < 600,
        headers: {'Accept': 'application/json'},
      ),
    );
    return ApiClient(dio, await configureSessionTransport(dio, secureStorage));
  }

  /// 统一解开已有服务端的 code / message / data 响应结构。
  Future<Object?> request(
    String path, {
    String method = 'GET',
    Map<String, Object?>? data,
    Map<String, Object?>? query,
  }) async {
    try {
      final response = await dio.request<Object?>(
        path,
        data: data,
        queryParameters: query,
        cancelToken: _cancelToken,
        options: Options(method: method),
      );
      final body = response.data;
      if (response.statusCode == 401) {
        final message = body is Map ? body['message'] : null;
        throw ApiException(
          message is String && message.isNotEmpty ? message : '登录已过期，请重新登录。',
          kind: FailureKind.authentication,
        );
      }
      if (body is! Map<String, dynamic> || body['code'] is! num) {
        throw const ApiException(
          '服务响应格式异常，请稍后重试。',
          kind: FailureKind.invalidResponse,
        );
      }
      if ((response.statusCode ?? 500) >= 400 || body['code'] != 0) {
        final message = body['message'];
        throw ApiException(
          message is String && message.isNotEmpty ? message : '请求失败，请稍后重试。',
        );
      }
      return body['data'];
    } on DioException catch (error) {
      final sessionFailure = sessionTransportFailure(error);
      if (sessionFailure != null) throw sessionFailure;
      if (error.type == DioExceptionType.cancel) {
        throw const ApiException('请求已取消。', kind: FailureKind.cancelled);
      }
      final message = switch (error.type) {
        DioExceptionType.connectionTimeout => '连接服务超时，请切换网络后重试。',
        DioExceptionType.sendTimeout => '发送请求超时，请检查网络后重试。',
        DioExceptionType.receiveTimeout => '服务响应超时，请稍后重试。',
        DioExceptionType.badCertificate => '无法验证服务证书，请检查手机日期、时间和网络。',
        _ => '暂时无法连接服务，请检查网络后重试。',
      };
      throw ApiException(message, kind: FailureKind.network);
    }
  }

  void cancelRequests() {
    _cancelToken.cancel();
    _cancelToken = CancelToken();
  }

  void dispose() {
    cancelRequests();
    dio.close(force: true);
  }
}
