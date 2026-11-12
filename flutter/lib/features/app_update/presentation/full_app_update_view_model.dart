import 'dart:async';

import 'package:flutter/foundation.dart';

import '../data/full_app_update_repository.dart';

enum FullAppUpdateState {
  idle,
  unavailable,
  checking,
  upToDate,
  available,
  downloading,
  failed,
}

class FullAppUpdateViewModel extends ChangeNotifier {
  FullAppUpdateViewModel(this._repository, {DateTime Function()? now})
    : _now = now ?? DateTime.now;

  final FullAppUpdateRepository _repository;
  final DateTime Function() _now;
  FullAppUpdateState state = FullAppUpdateState.idle;
  FullAppUpdate? update;
  String? error;
  Future<void>? _inFlight;
  DateTime? _lastCheckStarted;
  bool _disposed = false;

  bool get isBusy =>
      state == FullAppUpdateState.checking ||
      state == FullAppUpdateState.downloading;

  Future<void> checkInBackground() {
    if (_disposed || !_repository.isAvailable) return Future<void>.value();
    final lastCheck = _lastCheckStarted;
    if (lastCheck != null &&
        !_now().difference(lastCheck).isNegative &&
        _now().difference(lastCheck) < const Duration(minutes: 5) &&
        state != FullAppUpdateState.failed) {
      return Future<void>.value();
    }
    return check();
  }

  Future<void> check() {
    if (_disposed) return Future<void>.value();
    return _inFlight ??= Future<void>.microtask(
      _check,
    ).whenComplete(() => _inFlight = null);
  }

  Future<void> _check() async {
    _lastCheckStarted = _now();
    error = null;
    if (!_repository.isAvailable) {
      _setState(FullAppUpdateState.unavailable);
      return;
    }
    _setState(FullAppUpdateState.checking);
    try {
      update = await _repository.check();
      _setState(
        update == null
            ? FullAppUpdateState.upToDate
            : FullAppUpdateState.available,
      );
    } catch (failure) {
      debugPrint('Full app update failed (${failure.runtimeType})');
      error = '完整更新检查失败，请稍后重试';
      _setState(FullAppUpdateState.failed);
    }
  }

  Future<void> install() async {
    final pending = update;
    if (pending == null || _disposed || isBusy) return;
    error = null;
    _setState(FullAppUpdateState.downloading);
    try {
      await _repository.install(pending);
      if (!_disposed) _setState(FullAppUpdateState.upToDate);
    } catch (failure) {
      debugPrint('Full app install failed (${failure.runtimeType})');
      error = '完整更新失败，请稍后重试';
      _setState(FullAppUpdateState.available);
    }
  }

  void _setState(FullAppUpdateState next) {
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
