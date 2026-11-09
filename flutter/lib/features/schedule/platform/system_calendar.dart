import 'dart:io';

import 'package:flutter/services.dart';

import '../models/calendar_export.dart';
import 'share_calendar.dart';

/// 导入系统日历的结果。
enum SystemCalendarStatus {
  /// 已直接写入本机日历，用户不需要再做任何确认。
  imported,

  /// 当前平台没有原生日历通道（鸿蒙等），退回系统分享面板。
  shared,

  /// 用户拒绝了日历权限。
  denied,

  /// 写入过程中出错。
  failed,
}

class SystemCalendarResult {
  const SystemCalendarResult(this.status, {this.eventCount = 0, this.message});
  final SystemCalendarStatus status;
  final int eventCount;
  final String? message;

  bool get ok =>
      status == SystemCalendarStatus.imported ||
      status == SystemCalendarStatus.shared;
}

const MethodChannel _channel = MethodChannel('chengxin_youyou/system_calendar');

/// 只有 Android / iOS 走原生写入，其它平台保持原来的分享方式。
bool get nativeCalendarSupported {
  try {
    return Platform.isAndroid || Platform.isIOS;
  } catch (_) {
    return false;
  }
}

/// 一键把课表写进系统日历。
///
/// 与旧流程的区别：不再生成文件交给分享面板，而是申请一次日历权限后
/// 直接调用 EventKit / CalendarContract 写入。同一学期重复导入会先清掉
/// 上次写入的日程，因此不会出现重复条目。
Future<SystemCalendarResult> importToSystemCalendar({
  required CalendarExport export,
  required String semesterId,
  Rect? shareOrigin,
}) async {
  if (!nativeCalendarSupported) return _shareFallback(export, shareOrigin);
  try {
    final granted = await _channel.invokeMethod<bool>('requestAccess') ?? false;
    if (!granted) {
      return const SystemCalendarResult(
        SystemCalendarStatus.denied,
        message: '需要日历权限才能写入课表，请在系统设置中允许“成信友友”访问日历',
      );
    }
    final written = await _channel.invokeMethod<int>('importEvents', {
      'calendarName': export.calendarName,
      'marker': 'chengxin-youyou://schedule/$semesterId',
      'events': [for (final event in export.events) event.toJson()],
    });
    final count = written ?? 0;
    if (count <= 0) {
      return const SystemCalendarResult(
        SystemCalendarStatus.failed,
        message: '没有日程写入系统日历，请稍后重试',
      );
    }
    return SystemCalendarResult(
      SystemCalendarStatus.imported,
      eventCount: count,
    );
  } on MissingPluginException {
    // 鸿蒙、桌面端没有实现该通道，保持原有的分享流程。
    return _shareFallback(export, shareOrigin);
  } on PlatformException catch (error) {
    if (error.code == 'permission_denied') {
      return const SystemCalendarResult(
        SystemCalendarStatus.denied,
        message: '需要日历权限才能写入课表，请在系统设置中允许“成信友友”访问日历',
      );
    }
    return SystemCalendarResult(
      SystemCalendarStatus.failed,
      message: error.message ?? '写入系统日历失败，请稍后重试',
    );
  }
}

/// 权限被拒时跳转到系统设置页。
Future<void> openCalendarPermissionSettings() async {
  if (!nativeCalendarSupported) return;
  try {
    await _channel.invokeMethod<void>('openSettings');
  } on MissingPluginException {
    // 没有原生通道时静默忽略。
  } on PlatformException {
    // 设置页打不开不影响主流程。
  }
}

Future<SystemCalendarResult> _shareFallback(
  CalendarExport export,
  Rect? origin,
) async {
  try {
    final shared = await shareCalendar(export, origin ?? Rect.zero);
    return SystemCalendarResult(
      shared ? SystemCalendarStatus.shared : SystemCalendarStatus.failed,
      eventCount: export.eventCount,
      message: shared ? null : '未完成导入',
    );
  } catch (_) {
    return const SystemCalendarResult(
      SystemCalendarStatus.failed,
      message: '无法打开系统分享面板，请重试',
    );
  }
}
