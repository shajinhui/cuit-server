import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:native_dio_adapter/native_dio_adapter.dart';

void configureNativeAdapter(Dio dio) {
  dio.httpClientAdapter = NativeAdapter(
    // 国产 ROM 和 AOSP 设备通常没有可用的 Cronet provider（没有或禁用了
    // Google Play 服务）。不配置回退时，第一次请求就会初始化失败，表现为
    // “暂时无法连接服务”。这里回退到 dart:io，保证这些设备能正常联网。
    createFallbackAdapter: (error, stackTrace) => IOHttpClientAdapter(),
  );
}
