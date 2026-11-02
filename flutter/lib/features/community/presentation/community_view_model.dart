import 'package:flutter/foundation.dart';
import '../../campus/data/campus_repository.dart';
import '../../campus/models/campus_models.dart';
import '../data/community_repository.dart';

class CommunityViewModel extends ChangeNotifier {
  CommunityViewModel(this.repository, this.campus);
  final CommunityRepository repository;
  final CampusRepository campus;
  CampusAuthor? profile;
  String? error;
  bool? supported;
  bool loading = false;
  int unreadCount = 0;
  bool _disposed = false;
  bool _attempted = false;
  Future<void>? _loadingProfile;
  Future<void>? _loadingUnread;
  DateTime? _lastUnread;

  CampusAuthor resolveAuthor(CampusAuthor author) =>
      profile?.id == author.id &&
          profile!.profileVersion >= author.profileVersion
      ? profile!
      : author;

  Future<void> loadProfile({bool refresh = false}) {
    if (_disposed || (!refresh && _attempted)) {
      return _loadingProfile ?? Future.value();
    }
    _attempted = true;
    return _loadingProfile ??= _loadProfile().whenComplete(
      () => _loadingProfile = null,
    );
  }

  Future<void> _loadProfile() async {
    loading = true;
    error = null;
    _notify();
    try {
      final value = await repository.getCommunityProfile();
      if (_disposed) return;
      profile = value;
      supported = true;
    } catch (exception) {
      if (_disposed) return;
      error =
          exception is CampusRepositoryException && exception.statusCode == 404
          ? '社区资料服务尚未上线，请稍后再试。'
          : exception.toString();
      if (exception is CampusRepositoryException &&
          exception.statusCode == 404) {
        supported = false;
      }
    } finally {
      if (!_disposed) {
        loading = false;
        _notify();
      }
    }
  }

  Future<void> refreshUnread({bool force = false}) {
    if (_disposed ||
        supported == false ||
        (!force &&
            _lastUnread != null &&
            DateTime.now().difference(_lastUnread!) <
                const Duration(seconds: 30))) {
      return Future.value();
    }
    return _loadingUnread ??= _refreshUnread().whenComplete(
      () => _loadingUnread = null,
    );
  }

  Future<void> _refreshUnread() async {
    _lastUnread = DateTime.now();
    try {
      final count = await repository.getUnreadCount();
      if (_disposed) return;
      unreadCount = count;
      _notify();
    } catch (_) {
      /* Optional foreground refresh must not interrupt navigation. */
    }
  }

  void setUnreadCount(int value) {
    if (_disposed) return;
    unreadCount = value;
    _notify();
  }

  Future<void> saveProfile({
    required String displayName,
    required int avatarPreset,
    String? avatarAssetId,
  }) async {
    final current = profile;
    if (_disposed || current == null) {
      throw const CampusRepositoryException('请先加载公开资料。');
    }
    final updated = await repository.updateCommunityProfile(
      displayName: displayName,
      avatarPreset: avatarPreset,
      avatarAssetId: avatarAssetId,
      expectedVersion: current.profileVersion,
    );
    if (_disposed) throw const CampusRepositoryException('账号已切换，请重新操作。');
    profile = updated;
    _notify();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    profile = null;
    unreadCount = 0;
    super.dispose();
  }
}
