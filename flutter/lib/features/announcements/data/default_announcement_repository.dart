import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/app_announcement.dart';
import 'announcement_repository.dart';

class DefaultAnnouncementRepository implements AnnouncementRepository {
  DefaultAnnouncementRepository({
    required SharedPreferences preferences,
    required String platform,
    String baseUrl = const String.fromEnvironment(
      'ANNOUNCEMENTS_API_BASE_URL',
      defaultValue: 'https://lehi.top',
    ),
    Dio? dio,
  }) : _preferences = preferences,
       _platform = platform,
       _key =
           'announcements:v1:${baseUrl.replaceAll(RegExp(r'/$'), '')}:$platform',
       _dio =
           dio ??
           Dio(
             BaseOptions(
               baseUrl: baseUrl.replaceAll(RegExp(r'/$'), ''),
               connectTimeout: const Duration(seconds: 6),
               receiveTimeout: const Duration(seconds: 6),
               followRedirects: false,
               headers: const {'Accept': 'application/json'},
             ),
           );

  final SharedPreferences _preferences;
  final String _platform;
  final String _key;
  // 独立客户端不携带教务 Cookie、校园 Token，也不会因公告失败触发退出。
  final Dio _dio;
  final CancelToken _cancel = CancelToken();

  @override
  Future<AnnouncementSnapshot> readCache() async {
    final saved = _preferences.getString(_key);
    if (saved == null) return AnnouncementSnapshot();
    try {
      final data = jsonDecode(saved);
      if (data is! Map || data['items'] is! List || data['views'] is! Map) {
        throw const FormatException();
      }
      final items = _items(data['items']);
      final views = <String, int>{};
      for (final entry in (data['views'] as Map).entries.take(100)) {
        if (entry.key is String && entry.value is int && entry.value >= 0) {
          views[entry.key as String] = (entry.value as int).clamp(0, 2);
        }
      }
      return AnnouncementSnapshot(items: items, views: views);
    } on FormatException {
      return AnnouncementSnapshot();
    }
  }

  @override
  Future<List<AppAnnouncement>> fetch() async {
    final response = await _dio.get<Object?>(
      '/api/v1/ratings/announcements',
      queryParameters: {'platform': _platform},
      cancelToken: _cancel,
    );
    final payload = response.data;
    if (payload is! Map || payload['code'] != 0 || payload['data'] is! Map) {
      throw const FormatException('公告服务响应格式异常');
    }
    return _items((payload['data'] as Map)['items']);
  }

  @override
  Future<void> saveCache(AnnouncementSnapshot snapshot) async {
    final saved = await _preferences.setString(
      _key,
      jsonEncode({
        'items': snapshot.items.map((item) => item.toJson()).toList(),
        'views': snapshot.views,
      }),
    );
    if (!saved) throw StateError('公告缓存保存失败');
  }

  @override
  void dispose() {
    _cancel.cancel();
    _dio.close();
  }
}

List<AppAnnouncement> _items(Object? value) {
  if (value is! List || value.length > 20) {
    throw const FormatException('公告列表格式异常');
  }
  final items = value.map(AppAnnouncement.fromJson).toList();
  if (items.map((item) => item.id).toSet().length != items.length) {
    throw const FormatException('公告列表重复');
  }
  return items;
}
