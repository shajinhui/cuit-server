import 'dart:async';

import 'package:flutter/foundation.dart';

import '../data/app_update_repository.dart';

enum AppUpdateState {
  idle,
  unavailable,
  checking,
  upToDate,
  downloading,
  restartRequired,
  failed,
}

class AppUpdateViewModel extends ChangeNotifier {
  AppUpdateViewModel(this._repository);

  final AppUpdateRepository _repository;
  AppUpdateState state = AppUpdateState.idle;
  int? currentPatch;
  String? error;
  Future<void>? _inFlight;
  bool _disposed = false;

  bool get isBusy =>
      state == AppUpdateState.checking || state == AppUpdateState.downloading;

  /// 启动和手动检查共享一个任务，避免重复下载同一补丁。
  Future<void> checkAndDownload() {
    if (_disposed) return Future<void>.value();
    return _inFlight ??= Future<void>.microtask(
      _checkAndDownload,
    ).whenComplete(() => _inFlight = null);
  }

  Future<void> _checkAndDownload() async {
    if (_disposed) return;
    error = null;
    if (!_repository.isAvailable) {
      _setState(AppUpdateState.unavailable);
      return;
    }
    _setState(AppUpdateState.checking);
    if (_disposed) return;
    try {
      // 先读取本机状态，断网时也能识别已经下载、尚未生效的补丁。
      var patches = await _repository.readPatches();
      if (_disposed) return;
      currentPatch = patches.currentPatch;
      if (patches.restartRequired) {
        _setState(AppUpdateState.restartRequired);
        return;
      }

      final status = await _repository.checkForUpdate();
      if (_disposed) return;
      switch (status) {
        case AppPatchStatus.unavailable:
          _setState(AppUpdateState.unavailable);
        case AppPatchStatus.upToDate:
          _setState(AppUpdateState.upToDate);
        case AppPatchStatus.restartRequired:
          _setState(AppUpdateState.restartRequired);
        case AppPatchStatus.outdated:
          _setState(AppUpdateState.downloading);
          if (_disposed) return;
          await _repository.downloadUpdate();
          if (_disposed) return;
          patches = await _repository.readPatches();
          if (_disposed) return;
          _setState(
            patches.restartRequired
                ? AppUpdateState.restartRequired
                : AppUpdateState.upToDate,
          );
      }
    } catch (failure) {
      if (_disposed) return;
      // 只记录异常类型，避免更新服务的响应或地址进入日志。
      debugPrint('App update failed (${failure.runtimeType})');
      error = state == AppUpdateState.downloading
          ? '更新下载失败，请检查网络后重试'
          : '检查更新失败，请检查网络后重试';
      _setState(AppUpdateState.failed);
    }
  }

  void _setState(AppUpdateState next) {
    if (_disposed) return;
    state = next;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
