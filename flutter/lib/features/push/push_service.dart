import 'dart:async';
import 'dart:convert';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../../core/network/api_client.dart';
import '../../core/platform/app_platform.dart';
import '../session/presentation/session_view_model.dart';

class PushNotificationTarget {
  const PushNotificationTarget({required this.threadId, this.replyId});
  final String threadId;
  final String? replyId;

  static PushNotificationTarget? fromData(Map<String, dynamic> data) {
    if (data['type'] != 'community_reply') return null;
    final thread = data['thread_id'];
    if (thread is! String || thread.isEmpty) return null;
    final reply = data['reply_id'];
    return PushNotificationTarget(
      threadId: thread,
      replyId: reply is String && reply.isNotEmpty ? reply : null,
    );
  }

  static PushNotificationTarget? fromRemoteMessage(RemoteMessage message) =>
      fromData(message.data);

  static PushNotificationTarget? fromLocalPayload(String? payload) {
    if (payload == null || payload.isEmpty) return null;
    try {
      final value = jsonDecode(payload);
      return value is Map
          ? fromData(Map<String, dynamic>.from(value))
          : null;
    } catch (_) {
      return null;
    }
  }

  String toPayload() => jsonEncode({
    'type': 'community_reply',
    'thread_id': threadId,
    if (replyId != null) 'reply_id': replyId,
  });
}

/// Registers FCM tokens after login and forwards notification taps to the app.
/// Firebase setup is optional for local/demo builds; failures never block startup.
class PushNotificationService {
  PushNotificationService({
    required this.api,
    required this.session,
    required this.platform,
    this.appVersion = '0.1.0+2',
  }) {
    session.addListener(_onSessionChanged);
  }

  final ApiClient api;
  final SessionViewModel session;
  final String platform;
  final String appVersion;
  final FlutterLocalNotificationsPlugin _local =
      FlutterLocalNotificationsPlugin();
  StreamSubscription<String>? _tokenSubscription;
  StreamSubscription<RemoteMessage>? _messageSubscription;
  StreamSubscription<RemoteMessage>? _openedSubscription;
  Future<void>? _initializing;
  String? _token;
  bool _disposed = false;
  PushNotificationTarget? _pendingTarget;
  void Function(PushNotificationTarget target)? onNotificationTap;

  Future<void> initialize() {
    if (_disposed) return Future.value();
    return _initializing ??= _initialize().whenComplete(
      () => _initializing = null,
    );
  }

  Future<void> _initialize() async {
    if (kIsWeb || isHarmonyOS) return;
    try {
      await Firebase.initializeApp();
      final messaging = FirebaseMessaging.instance;
      await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );
      await _initializeLocalNotifications();
      _messageSubscription = FirebaseMessaging.onMessage.listen(
        _showForegroundMessage,
      );
      _openedSubscription = FirebaseMessaging.onMessageOpenedApp.listen(
        _handleOpenedMessage,
      );
      _tokenSubscription = messaging.onRegistered.listen(_registerToken);
      _handleOpenedMessage(await messaging.getInitialMessage());
      await messaging.register();
    } catch (_) {
      // Missing Firebase config or denied permission must not break the app.
    }
  }

  Future<void> _initializeLocalNotifications() async {
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const darwin = DarwinInitializationSettings();
    await _local.initialize(
      settings: const InitializationSettings(android: android, iOS: darwin),
      onDidReceiveNotificationResponse: (response) {
        _deliverTarget(PushNotificationTarget.fromLocalPayload(response.payload));
      },
    );
    await _local
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.requestNotificationsPermission();
    await _local
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >()
        ?.requestPermissions(alert: true, badge: true, sound: true);
    const channel = AndroidNotificationChannel(
      'community_messages',
      '互动消息',
      description: '论坛帖子和回复提醒',
      importance: Importance.high,
    );
    await _local
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(channel);
  }

  Future<void> _showForegroundMessage(RemoteMessage message) async {
    final target = PushNotificationTarget.fromRemoteMessage(message);
    if (target == null) return;
    final title = message.notification?.title ?? '新的互动消息';
    final body = message.notification?.body ?? '有人回复了你的帖子或回复';
    try {
      await _local.show(
        id: message.hashCode & 0x7fffffff,
        title: title,
        body: body,
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            'community_messages',
            '互动消息',
            channelDescription: '论坛帖子和回复提醒',
            importance: Importance.high,
            priority: Priority.high,
          ),
          iOS: DarwinNotificationDetails(),
        ),
        payload: target.toPayload(),
      );
    } catch (_) {
      // The in-app inbox remains available if a platform channel is unavailable.
    }
  }

  void _handleOpenedMessage(RemoteMessage? message) {
    if (message == null) return;
    _deliverTarget(PushNotificationTarget.fromRemoteMessage(message));
  }

  void _deliverTarget(PushNotificationTarget? target) {
    if (target == null) return;
    final callback = onNotificationTap;
    if (callback == null) {
      _pendingTarget = target;
    } else {
      callback(target);
    }
  }

  Future<void> _registerToken(String? token) async {
    if (_disposed || token == null || token.isEmpty) return;
    _token = token;
    if (session.student == null || session.isDemo) return;
    try {
      await api.request(
        '/api/v1/ratings/community/me/push-devices',
        method: 'POST',
        data: {
          'token': token,
          'platform': platform,
          'app_version': appVersion,
          'locale': 'zh-CN',
        },
      );
    } catch (_) {
      // Retry on the next token refresh or foreground session change.
    }
  }

  void _onSessionChanged() {
    if (_disposed || _token == null || session.student == null || session.isDemo) {
      return;
    }
    unawaited(_registerToken(_token));
  }

  void flushPendingTarget() {
    final target = _pendingTarget;
    _pendingTarget = null;
    if (target != null) _deliverTarget(target);
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    session.removeListener(_onSessionChanged);
    unawaited(_tokenSubscription?.cancel());
    unawaited(_messageSubscription?.cancel());
    unawaited(_openedSubscription?.cancel());
  }
}
