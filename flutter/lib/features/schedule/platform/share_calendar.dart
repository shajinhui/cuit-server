import 'dart:io';
import 'dart:ui';

import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../models/calendar_export.dart';

/// 交给系统文件分享面板，由用户选择日历应用并确认导入。
Future<bool> shareCalendar(CalendarExport calendar, Rect origin) async {
  final cache = await getTemporaryDirectory();
  final directory = await Directory(
    '${cache.path}/calendar-${DateTime.now().microsecondsSinceEpoch}',
  ).create();
  final file = File('${directory.path}/${calendar.fileName}');
  try {
    await file.writeAsString(calendar.content, flush: true);
    final result = await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path, mimeType: 'text/calendar')],
        title: calendar.calendarName,
        sharePositionOrigin: origin,
      ),
    );
    return result.status == ShareResultStatus.success;
  } finally {
    // 只清理本次创建的临时目录，不碰其他缓存和用户文件。
    if (await directory.exists()) await directory.delete(recursive: true);
  }
}
