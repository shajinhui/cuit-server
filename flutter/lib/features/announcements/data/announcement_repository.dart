import '../models/app_announcement.dart';

class AnnouncementSnapshot {
  AnnouncementSnapshot({
    List<AppAnnouncement> items = const [],
    Map<String, int> views = const {},
  }) : items = List.unmodifiable(items),
       views = Map.unmodifiable(views);
  final List<AppAnnouncement> items;
  final Map<String, int> views;
}

/// 公告与账号无关；缓存和阅读次数按公告服务地址、平台及内容版本隔离。
abstract interface class AnnouncementRepository {
  Future<AnnouncementSnapshot> readCache();
  Future<List<AppAnnouncement>> fetch();
  Future<void> saveCache(AnnouncementSnapshot snapshot);
  void dispose();
}
