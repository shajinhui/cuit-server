import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:chengxin_youyou/core/network/api_client.dart';

/// 在 HTTP 边界替换响应，验证生产 Repository 的真实解析和请求参数。
class FakeApi {
  FakeApi() {
    final dio = Dio(
      BaseOptions(baseUrl: 'https://example.test', validateStatus: (_) => true),
    );
    dio.httpClientAdapter = _Adapter(this);
    client = ApiClient(dio, () async {
      cookiesCleared++;
    });
  }
  late final ApiClient client;
  final List<RequestOptions> requests = [];
  int cookiesCleared = 0;
  Future<ResponseBody> Function(RequestOptions)? handler;
  static ResponseBody response(
    Object? data, {
    int status = 200,
    int code = 0,
    String message = '',
  }) => ResponseBody.fromString(
    jsonEncode({'code': code, 'message': message, 'data': data}),
    status,
    headers: {
      Headers.contentTypeHeader: ['application/json'],
    },
  );
}

class _Adapter implements HttpClientAdapter {
  _Adapter(this.owner);
  final FakeApi owner;
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? stream,
    Future<void>? cancelFuture,
  ) async {
    owner.requests.add(options);
    return owner.handler!(options);
  }

  @override
  void close({bool force = false}) {}
}
