import 'dart:async';
import 'package:flutter/foundation.dart';
import '../data/announcement_repository.dart';
import '../models/app_announcement.dart';

class AnnouncementViewModel extends ChangeNotifier {
  AnnouncementViewModel(this._repository, {DateTime Function()? now})
    : _now = now ?? DateTime.now;
  final AnnouncementRepository _repository;
  final DateTime Function() _now;
  List<AppAnnouncement> _items = [];
  Map<String, int> _views = {};
  bool initialized = false;
  bool loading = false;
  bool hasFreshFeed = false;
  bool isPresenting = false;
  String? error;
  String? cacheWarning;
  bool _disposed = false;
  bool _autoPresented = false;
  DateTime? _lastCheck;
  Future<void>? _inFlight;
  Future<void> _writes = Future.value();

  List<AppAnnouncement> get items =>
      List.unmodifiable(_items.where((item) => item.isActive(_now())));
  AppAnnouncement? get latest => items.firstOrNull;
  int viewCount(AppAnnouncement item) => _views[item.viewKey] ?? 0;
  bool get isOffline => error != null && items.isNotEmpty;
  AppAnnouncement? get autoCandidate {
    final item = latest;
    if (!initialized ||
        loading ||
        !hasFreshFeed ||
        _autoPresented ||
        isPresenting ||
        item == null ||
        !item.autoShow ||
        viewCount(item) >= 2) {
      return null;
    }
    return item;
  }

  /// 启动、返回前台和手动刷新合并请求，自动检查间隔至少五分钟。
  Future<void> refresh({bool force = false}) {
    if (_disposed) return Future.value();
    if (_inFlight != null) return _inFlight!;
    if (!force &&
        _lastCheck != null &&
        _now().difference(_lastCheck!) < const Duration(minutes: 5)) {
      return Future.value();
    }
    return _inFlight = Future<void>.microtask(
      _refresh,
    ).whenComplete(() => _inFlight = null);
  }

  Future<void> _refresh() async {
    loading = true;
    error = null;
    _notify();
    if (!initialized) {
      try {
        final cache = await _repository.readCache();
        if (_disposed) return;
        _items = cache.items;
        _views = Map.of(cache.views);
      } catch (_) {
        // 公开缓存损坏或不可读不阻止在线拉取。
        cacheWarning = '本机公告记录暂时不可用';
      }
      if (_disposed) return;
      _notify();
    }
    try {
      final latest = await _repository.fetch();
      if (_disposed) return;
      _items = latest;
      hasFreshFeed = true;
      await _save();
    } catch (_) {
      if (_disposed) return;
      // 断网可手动查看缓存，但不自动弹出可能已被后台撤回的旧公告。
      hasFreshFeed = false;
      error = '公告更新失败，请检查网络后重试';
    } finally {
      if (!_disposed) {
        initialized = true;
        loading = false;
        _lastCheck = _now();
        _notify();
      }
    }
  }

  bool beginPresentation(AppAnnouncement item, {bool automatic = false}) {
    if (_disposed || isPresenting) return false;
    if (automatic && autoCandidate?.viewKey != item.viewKey) return false;
    // 手动查看也算本次启动已提醒，关闭后不再自动补弹同一条。
    _autoPresented = true;
    isPresenting = true;
    _notify();
    return true;
  }

  Future<void> finishPresentation(AppAnnouncement item) async {
    if (_disposed) return;
    _views[item.viewKey] = (viewCount(item) + 1).clamp(0, 2);
    isPresenting = false;
    _notify();
    await _save();
  }

  Future<void> _save() {
    // 保留当前列表及最近的阅读记录，防止累计公告无限增长。
    final keys = _views.keys.toList();
    if (keys.length > 100) {
      for (final key in keys.take(keys.length - 100)) {
        _views.remove(key);
      }
    }
    final snapshot = AnnouncementSnapshot(items: _items, views: _views);
    _writes = _writes.then((_) async {
      if (_disposed) return;
      try {
        await _repository.saveCache(snapshot);
      } catch (_) {
        if (!_disposed) {
          cacheWarning = '阅读记录未能保存，下次启动可能再次提醒';
          _notify();
        }
      }
    });
    return _writes;
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _repository.dispose();
    super.dispose();
  }
}
