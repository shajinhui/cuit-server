import 'dart:io' show Directory, File;

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/network/native_dio_adapter.dart';
import '../../../core/platform/app_platform.dart';

class FullAppUpdate {
  const FullAppUpdate({
    required this.platform,
    required this.versionName,
    required this.versionCode,
    required this.minimumVersionCode,
    required this.downloadPath,
    required this.storeUrl,
    required this.sha256,
    required this.size,
    required this.forceUpdate,
    required this.releaseNotes,
  });

  final String platform;
  final String versionName;
  final int versionCode;
  final int minimumVersionCode;
  final String? downloadPath;
  final Uri? storeUrl;
  final String? sha256;
  final int? size;
  final bool forceUpdate;
  final List<String> releaseNotes;
}

abstract interface class FullAppUpdateRepository {
  bool get isAvailable;
  Future<FullAppUpdate?> check();
  Future<void> install(FullAppUpdate update);
}

class RemoteFullAppUpdateRepository implements FullAppUpdateRepository {
  RemoteFullAppUpdateRepository({
    required this.platform,
    Dio? dio,
    String baseUrl = const String.fromEnvironment(
      'RATINGS_API_BASE_URL',
      defaultValue: 'https://lehi.top',
    ),
  }) : _dio = dio ?? _createDio(baseUrl);

  final Dio _dio;
  final String platform;

  static Dio _createDio(String baseUrl) {
    final dio = Dio(
      BaseOptions(
        baseUrl: baseUrl.replaceAll(RegExp(r'/$'), ''),
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(minutes: 10),
        followRedirects: true,
        headers: const {'Accept': 'application/json'},
      ),
    );
    configureNativeDioAdapter(dio);
    return dio;
  }

  @override
  bool get isAvailable =>
      !kIsWeb && !isHarmonyOS && (platform == 'android' || platform == 'ios');

  @override
  Future<FullAppUpdate?> check() async {
    if (!isAvailable) return null;
    final package = await PackageInfo.fromPlatform();
    final response = await _dio.get<Map<String, dynamic>>(
      '/api/v1/ratings/app-updates',
      queryParameters: {
        'platform': platform,
        'channel': 'stable',
        'version_code': int.tryParse(package.buildNumber) ?? 0,
      },
    );
    final envelope = response.data;
    if (envelope == null || envelope['code'] != 0 || envelope['data'] is! Map) {
      throw const FormatException('更新响应格式无效');
    }
    final data = envelope['data'] as Map<String, dynamic>;
    final raw = data['update'];
    if (raw == null) return null;
    if (raw is! Map<String, dynamic>) {
      throw const FormatException('更新响应格式无效');
    }
    return _parse(raw);
  }

  @override
  Future<void> install(FullAppUpdate update) async {
    if (platform == 'ios') {
      final url = update.storeUrl;
      if (url == null ||
          !await launchUrl(url, mode: LaunchMode.externalApplication)) {
        throw StateError('无法打开应用商店');
      }
      return;
    }
    final downloadPath = update.downloadPath;
    if (downloadPath == null) throw StateError('安装包地址缺失');
    final directory = await getTemporaryDirectory();
    final targetDirectory = Directory(path.join(directory.path, 'app-updates'));
    await targetDirectory.create(recursive: true);
    final target = File(
      path.join(
        targetDirectory.path,
        'chengxin-youyou-${update.versionName}.apk',
      ),
    );
    await _dio.download(
      downloadPath,
      target.path,
      deleteOnError: true,
      options: Options(responseType: ResponseType.bytes),
    );
    final size = await target.length();
    if (update.size != null && size != update.size) {
      throw StateError('安装包大小校验失败');
    }
    if (update.sha256 != null) {
      final digest = await sha256.bind(target.openRead()).first;
      if (digest.toString().toLowerCase() != update.sha256!.toLowerCase()) {
        throw StateError('安装包校验失败');
      }
    }
    await const MethodChannel(
      'chengxin_youyou/app_installer',
    ).invokeMethod<void>('installApk', target.path);
  }

  FullAppUpdate _parse(Map<String, dynamic> raw) {
    final versionName = raw['version_name'];
    final versionCode = raw['version_code'];
    final minimumVersionCode = raw['minimum_version_code'];
    if (versionName is! String ||
        versionCode is! num ||
        minimumVersionCode is! num ||
        raw['platform'] is! String) {
      throw const FormatException('更新字段无效');
    }
    final storeUrl = raw['store_url'];
    return FullAppUpdate(
      platform: raw['platform'] as String,
      versionName: versionName,
      versionCode: versionCode.toInt(),
      minimumVersionCode: minimumVersionCode.toInt(),
      downloadPath: raw['download_path'] as String?,
      storeUrl: storeUrl is String ? Uri.tryParse(storeUrl) : null,
      sha256: raw['sha256'] as String?,
      size: (raw['size'] as num?)?.toInt(),
      forceUpdate: raw['force_update'] == true,
      releaseNotes: (raw['release_notes'] as List<dynamic>? ?? const [])
          .whereType<String>()
          .toList(growable: false),
    );
  }
}

class UnavailableFullAppUpdateRepository implements FullAppUpdateRepository {
  const UnavailableFullAppUpdateRepository();

  @override
  bool get isAvailable => false;

  @override
  Future<FullAppUpdate?> check() async => null;

  @override
  Future<void> install(FullAppUpdate update) async =>
      throw UnsupportedError('当前平台未提供完整安装包更新');
}
