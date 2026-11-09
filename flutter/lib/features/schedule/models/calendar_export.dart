import 'dart:convert';
import 'dart:math' as math;

import 'academic_calendar.dart';
import 'course.dart';
import 'local_course.dart';
import 'schedule_layout.dart';
import 'schedule_order.dart';
import 'semester.dart';

class CalendarExport {
  const CalendarExport({
    required this.content,
    required this.courseCount,
    required this.eventCount,
    required this.fileName,
    required this.calendarName,
    required this.events,
  });
  final String content, fileName, calendarName;
  final int courseCount, eventCount;

  /// 与 ICS 完全同源的结构化日程，供原生日历写入使用。
  final List<CalendarEventDraft> events;
}

/// 一条待写入系统日历的日程。
///
/// [uid] 与 ICS 中的 UID 同源，原生侧也用它作为可重复导入的标记，
/// 因此在同一学期内重复导入不会产生重复日程。
class CalendarEventDraft {
  const CalendarEventDraft({
    required this.uid,
    required this.title,
    required this.start,
    required this.end,
    this.detail = '',
    this.location = '',
    this.reminderMinutes = 0,
  });
  final String uid, title, detail, location;
  final DateTime start, end;
  final int reminderMinutes;

  Map<String, Object?> toJson() => {
    'uid': uid,
    'title': title,
    'detail': detail,
    'location': location,
    'start': start.millisecondsSinceEpoch,
    'end': end.millisecondsSinceEpoch,
    'reminderMinutes': reminderMinutes,
  };
}

CalendarExport createCalendarExport({
  required AcademicCalendar calendar,
  required ScheduleOrder order,
  required Semester semester,
  required CourseTable table,
  List<LocalCourse> manual = const [],
  List<LocalCourse> overrides = const [],
  String campus = '',
  int reminderMinutes = 10,
  DateTime? generatedAt,
}) {
  if (calendar.firstMonday(semester) == null) {
    throw const FormatException('该学期校历日期尚未收录，暂时无法导入系统日历');
  }
  final entries = buildScheduleEntries(
    table.courses,
    0,
    order: order,
    manual: manual.where((c) => c.semesterId == semester.id).toList(),
    overrides: overrides.where((c) => c.semesterId == semester.id).toList(),
  );
  if (entries.isEmpty) throw const FormatException('当前学期没有可以导入的课程');
  final maxWeek = entries
      .expand((b) => b.arrangements)
      .expand((a) => a.weeks)
      .fold(0, math.max);
  final weekCount = [
    table.weekCount,
    calendar.publishedWeekCount(semester),
    maxWeek,
  ].reduce(math.max);
  final name = '成信友友 · ${semester.schoolYear} 第${semester.term}学期';
  final stamp = _utc(generatedAt ?? DateTime.now());
  final lines = [
    'BEGIN:VCALENDAR',
    'VERSION:2.0',
    'PRODID:-//Chengxin Youyou//Schedule Calendar//ZH-CN',
    'CALSCALE:GREGORIAN',
    'METHOD:PUBLISH',
    'X-WR-CALNAME:${_escape(name)}',
    'X-WR-TIMEZONE:Asia/Shanghai',
    'BEGIN:VTIMEZONE',
    'TZID:Asia/Shanghai',
    'X-LIC-LOCATION:Asia/Shanghai',
    'BEGIN:STANDARD',
    'TZOFFSETFROM:+0800',
    'TZOFFSETTO:+0800',
    'TZNAME:CST',
    'DTSTART:19700101T000000',
    'END:STANDARD',
    'END:VTIMEZONE',
  ];
  var count = 0;
  final drafts = <CalendarEventDraft>[];
  // 必须用合并显示之前的条目导出，否则同一时段的冲突课会被吞掉。
  for (final entry in entries) {
    for (var week = 1; week <= weekCount; week++) {
      final active = entry.arrangements.where((a) => a.activeIn(week)).toList();
      if (active.isEmpty) continue;
      final first = active.first;
      final start = first.startTime.isNotEmpty
          ? first.startTime
          : sectionStart(entry.start, semester, campus);
      final end = first.endTime.isNotEmpty
          ? first.endTime
          : sectionEnd(entry.end, semester, campus);
      if (start.isEmpty || end.isEmpty) {
        throw FormatException(
          '“${entry.name}”使用了尚未配置时间的第 ${entry.start}–${entry.end} 节',
        );
      }
      final date = calendar.dateFor(semester, week, entry.day)!;
      final teachers = _unique(active.expand((a) => a.teachers));
      final effectiveTeachers = teachers.isEmpty ? entry.teachers : teachers;
      final location = _unique(
        active.map((a) => a.room).where((room) => room != '地点待定'),
      ).join(' / ');
      final description = [
        if (first.activityType.isNotEmpty) '课程类型：${first.activityType}',
        if (first.projectName.isNotEmpty) '授课项目：${first.projectName}',
        if (effectiveTeachers.isNotEmpty) '教师：${effectiveTeachers.join('、')}',
        if (entry.teachingClass.isNotEmpty) '教学班：${entry.teachingClass}',
        if (entry.code.isNotEmpty) '课程代码：${entry.code}',
        '第 $week 周 · 第 ${entry.start}–${entry.end} 节',
      ].join('\n');
      final uid = _hash(
        '${semester.id}\u0000${entry.id}\u0000${_date(date)}\u0000${entry.start}\u0000${entry.end}',
      );
      lines.addAll([
        'BEGIN:VEVENT',
        'UID:$uid@fanxiaogao05.dpdns.org',
        'DTSTAMP:$stamp',
        'DTSTART;TZID=Asia/Shanghai:${_withTime(date, start)}',
        'DTEND;TZID=Asia/Shanghai:${_withTime(date, end)}',
        'SUMMARY:${_escape(entry.name)}',
        'DESCRIPTION:${_escape(description)}',
        if (location.isNotEmpty && location != '地点待定')
          'LOCATION:${_escape(location)}',
        if (reminderMinutes > 0) ...[
          'BEGIN:VALARM',
          'TRIGGER:-PT${reminderMinutes}M',
          'ACTION:DISPLAY',
          'DESCRIPTION:${_escape('${entry.name}即将开始')}',
          'END:VALARM',
        ],
        'END:VEVENT',
      ]);
      drafts.add(
        CalendarEventDraft(
          uid: '$uid@fanxiaogao05.dpdns.org',
          title: entry.name,
          detail: description,
          location: location,
          start: _at(date, start),
          end: _at(date, end),
          reminderMinutes: reminderMinutes,
        ),
      );
      count++;
    }
  }
  if (count == 0) throw const FormatException('当前学期没有可以导入的上课日期');
  lines.add('END:VCALENDAR');
  return CalendarExport(
    content: '${lines.map(_fold).join('\r\n')}\r\n',
    courseCount: entries.map((b) => b.colorKey).toSet().length,
    eventCount: count,
    fileName: '成信友友课表-${semester.schoolYear}-第${semester.term}学期.ics',
    calendarName: name,
    events: drafts,
  );
}

List<String> _unique(Iterable<String> values) =>
    values.map((s) => s.trim()).where((s) => s.isNotEmpty).toSet().toList();
String _two(int n) => n.toString().padLeft(2, '0');
String _date(DateTime d) => '${d.year}${_two(d.month)}${_two(d.day)}';
String _utc(DateTime date) {
  final d = date.toUtc();
  return '${_date(d)}T${_two(d.hour)}${_two(d.minute)}${_two(d.second)}Z';
}

String _withTime(DateTime d, String time) {
  final parts = time.split(':').map(int.parse).toList();
  final normalized = DateTime(d.year, d.month, d.day, parts[0], parts[1]);
  return '${_date(normalized)}T${_two(normalized.hour)}${_two(normalized.minute)}00';
}

/// 与 [_withTime] 完全一致的时间点，供结构化日程复用。
DateTime _at(DateTime d, String time) {
  final parts = time.split(':').map(int.parse).toList();
  return DateTime(d.year, d.month, d.day, parts[0], parts[1]);
}

String _escape(String value) => value
    .replaceAll('\\', '\\\\')
    .replaceAll('\r\n', '\\n')
    .replaceAll('\r', '\\n')
    .replaceAll('\n', '\\n')
    .replaceAll(',', '\\,')
    .replaceAll(';', '\\;');
String _fold(String line) {
  final output = <String>[];
  var current = '';
  var bytes = 0;
  for (final rune in line.runes) {
    final character = String.fromCharCode(rune),
        length = utf8.encode(String.fromCharCode(rune)).length;
    if (bytes + length > 75) {
      output.add(current);
      current = ' ';
      bytes = 1;
    }
    current += character;
    bytes += length;
  }
  output.add(current);
  return output.join('\r\n');
}

String _hash(String value) {
  var left = 0x811c9dc5, right = 0x9e3779b9;
  for (final code in value.codeUnits) {
    left = ((left ^ code) * 0x01000193) & 0xffffffff;
    right = ((right ^ code) * 0x85ebca6b) & 0xffffffff;
  }
  return '${left.toRadixString(16).padLeft(8, '0')}${right.toRadixString(16).padLeft(8, '0')}';
}
