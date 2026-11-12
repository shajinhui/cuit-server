import 'dart:async';
import 'dart:convert';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../../core/platform/app_platform.dart';
import '../community/data/community_repository.dart';
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
      return value is Map ? fromData(Map<String, dynamic>.from(value)) : null;
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
    required this.repository,
    required this.session,
    required this.platform,
    this.appVersion = '0.1.4+6',
  }) {
    session.addListener(_onSessionChanged);
  }

  final CommunityRepository repository;
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
  String? _registeredToken;
  bool _disposed = false;
  PushNotificationTarget? _pendingTarget;
  bool _pendingAnnouncement = false;
  void Function(PushNotificationTarget target)? onNotificationTap;
  VoidCallback? onAnnouncementTap;

  Future<void> initialize() {
    if (_disposed) return Future.value();
    return _initializing ??= _initialize().whenComplete(
      () => _initializing = null,
    );
  }

  Future<void> _initialize() async {
    if (kIsWeb || isHarmonyOS) return;
    try {
      await _initializeFirebase();
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

  Future<void> _initializeFirebase() async {
    const apiKey = String.fromEnvironment('FIREBASE_API_KEY');
    const appId = String.fromEnvironment('FIREBASE_APP_ID');
    const messagingSenderId = String.fromEnvironment(
      'FIREBASE_MESSAGING_SENDER_ID',
    );
    const projectId = String.fromEnvironment('FIREBASE_PROJECT_ID');
    if (apiKey.isEmpty ||
        appId.isEmpty ||
        messagingSenderId.isEmpty ||
        projectId.isEmpty) {
      await Firebase.initializeApp();
      return;
    }
    await Firebase.initializeApp(
      options: FirebaseOptions(
        apiKey: apiKey,
        appId: appId,
        messagingSenderId: messagingSenderId,
        projectId: projectId,
        iosBundleId: defaultTargetPlatform == TargetPlatform.iOS
            ? const String.fromEnvironment(
                'FIREBASE_IOS_BUNDLE_ID',
                defaultValue: 'org.dpdns.fanxiaogao05.chengxin.flutter',
              )
            : null,
      ),
    );
  }

  Future<void> _initializeLocalNotifications() async {
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const darwin = DarwinInitializationSettings();
    await _local.initialize(
      settings: const InitializationSettings(android: android, iOS: darwin),
      onDidReceiveNotificationResponse: (response) {
        if (_isAnnouncementPayload(response.payload)) {
          _deliverAnnouncement();
        } else {
          _deliverTarget(
            PushNotificationTarget.fromLocalPayload(response.payload),
          );
        }
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
    const announcementChannel = AndroidNotificationChannel(
      'app_announcements',
      '应用公告',
      description: '版本更新和服务公告',
      importance: Importance.high,
    );
    await _local
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(announcementChannel);
  }

  Future<void> _showForegroundMessage(RemoteMessage message) async {
    final target = PushNotificationTarget.fromRemoteMessage(message);
    final isAnnouncement = message.data['type'] == 'announcement';
    if (target == null && !isAnnouncement) return;
    final title = message.notification?.title ?? '新的互动消息';
    final body = message.notification?.body ?? '有人回复了你的帖子或回复';
    try {
      await _local.show(
        id: message.hashCode & 0x7fffffff,
        title: title,
        body: body,
        notificationDetails: NotificationDetails(
          android: AndroidNotificationDetails(
            isAnnouncement ? 'app_announcements' : 'community_messages',
            isAnnouncement ? '应用公告' : '互动消息',
            channelDescription: isAnnouncement ? '版本更新和服务公告' : '论坛帖子和回复提醒',
            importance: Importance.high,
            priority: Priority.high,
          ),
          iOS: const DarwinNotificationDetails(),
        ),
        payload: target?.toPayload() ?? jsonEncode(message.data),
      );
    } catch (_) {
      // The in-app inbox remains available if a platform channel is unavailable.
    }
  }

  void _handleOpenedMessage(RemoteMessage? message) {
    if (message == null) return;
    if (message.data['type'] == 'announcement') {
      _deliverAnnouncement();
    } else {
      _deliverTarget(PushNotificationTarget.fromRemoteMessage(message));
    }
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

  void _deliverAnnouncement() {
    final callback = onAnnouncementTap;
    if (callback == null) {
      _pendingAnnouncement = true;
    } else {
      callback();
    }
  }

  bool _isAnnouncementPayload(String? payload) {
    if (payload == null || payload.isEmpty) return false;
    try {
      final value = jsonDecode(payload);
      return value is Map && value['type'] == 'announcement';
    } catch (_) {
      return false;
    }
  }

  Future<void> _registerToken(String? token) async {
    if (_disposed || token == null || token.isEmpty) return;
    _token = token;
    if (session.student == null || session.isDemo) return;
    try {
      final previous = _registeredToken;
      if (previous != null && previous != token) {
        await _unregisterToken(previous);
      }
      await repository.registerPushDevice(
        token: token,
        platform: platform,
        appVersion: appVersion,
        locale: 'zh-CN',
      );
      _registeredToken = token;
    } catch (_) {
      // Retry on the next token refresh or foreground session change.
    }
  }

  Future<void> _unregisterToken(String token) async {
    try {
      await repository.unregisterPushDevice(token);
    } catch (_) {
      // Expired sessions are cleaned up by the next successful registration.
    }
  }

  void _onSessionChanged() {
    if (_disposed) return;
    if (session.student == null || session.isDemo) {
      final registered = _registeredToken;
      _registeredToken = null;
      if (registered != null) unawaited(_unregisterToken(registered));
      return;
    }
    if (_token == null) return;
    unawaited(_registerToken(_token));
  }

  void flushPendingTarget() {
    final target = _pendingTarget;
    _pendingTarget = null;
    if (target != null) _deliverTarget(target);
    if (_pendingAnnouncement) {
      _pendingAnnouncement = false;
      _deliverAnnouncement();
    }
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
