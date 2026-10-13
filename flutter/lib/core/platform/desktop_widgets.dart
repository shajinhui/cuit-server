import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// 平台层只传递课表摘要，不接收账号、密码或登录 Cookie。
abstract class DesktopWidgets {
  bool get canRequestPin;
  set onOpenSchedule(VoidCallback? callback);
  Future<bool> consumeLaunch();
  Future<void> publish(Map<String, Object?> snapshot);
  Future<bool> requestPin();
}

class NativeDesktopWidgets implements DesktopWidgets {
  NativeDesktopWidgets() {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'openSchedule') _onOpenSchedule?.call();
    });
  }

  static const _channel = MethodChannel('chengxin_youyou/desktop_widgets');
  VoidCallback? _onOpenSchedule;
  Future<void> _writes = Future.value();
  String? _lastPayload;

  static bool get supported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.android);

  @override
  bool get canRequestPin => defaultTargetPlatform == TargetPlatform.android;

  @override
  set onOpenSchedule(VoidCallback? callback) => _onOpenSchedule = callback;

  @override
  Future<bool> consumeLaunch() async =>
      await _channel.invokeMethod<bool>('consumeLaunch') ?? false;

  @override
  Future<void> publish(Map<String, Object?> snapshot) {
    final payload = jsonEncode(snapshot);
    // 串行写入保证退出后的清空不会被旧课表覆盖；相同内容不请求系统刷新。
    final task = _writes.then((_) async {
      if (payload == _lastPayload) return;
      await _channel.invokeMethod<void>('publish', payload);
      _lastPayload = payload;
    });
    _writes = task.catchError((Object _) {});
    return task;
  }

  @override
  Future<bool> requestPin() async =>
      await _channel.invokeMethod<bool>('requestPin') ?? false;
}
