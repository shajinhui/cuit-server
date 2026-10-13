import 'academic_calendar.dart';
import 'course.dart';
import 'local_course.dart';
import 'schedule_layout.dart';
import 'schedule_order.dart';
import 'semester.dart';

/// 将排课规则在 Dart 中计算一次，两端原生小组件只负责展示。
Map<String, Object?> createDesktopWidgetSnapshot({
  required AcademicCalendar calendar,
  required Semester semester,
  required CourseTable table,
  required ScheduleOrder order,
  required DateTime updatedAt,
  List<LocalCourse> localCourses = const [],
  Map<String, int> colors = const {},
  String campus = '',
}) {
  final monday = calendar.firstMonday(semester);
  if (monday == null) {
    return desktopWidgetMessage('noCalendar', '本学期校历待更新');
  }
  final entries = buildScheduleEntries(
    table.courses,
    0,
    order: order,
    manual: localCourses
        .where((c) => c.semesterId == semester.id && c.targetId == null)
        .toList(),
    overrides: localCourses
        .where((c) => c.semesterId == semester.id && c.targetId != null)
        .toList(),
    colors: colors,
  );
  final published = calendar.publishedWeekCount(semester);
  final weekCount = published > 0 ? published : table.weekCount;
  final days = <Map<String, Object?>>[];
  for (var week = 1; week <= weekCount; week++) {
    for (var day = 1; day <= 7; day++) {
      final date = calendar.dateFor(semester, week, day)!;
      final courses = <Map<String, Object?>>[];
      // 不使用网格合并结果，保留同一时段的冲突课程。
      for (final entry in entries.where((entry) => entry.day == day)) {
        final active = entry.arrangements.where((a) => a.activeIn(week));
        if (active.isEmpty) continue;
        final first = active.first;
        final start = first.startTime.isNotEmpty
            ? first.startTime
            : sectionStart(entry.start, semester, campus);
        final end = first.endTime.isNotEmpty
            ? first.endTime
            : sectionEnd(entry.end, semester, campus);
        final startMillis = _schoolTime(date, start);
        final endMillis = _schoolTime(date, end);
        courses.add({
          'id': entry.id,
          'name': entry.name,
          'room': active.map((a) => a.room).toSet().join(' / '),
          'time': start.isEmpty || end.isEmpty
              ? '第 ${entry.start}–${entry.end} 节'
              : '$start–$end',
          'startMillis': startMillis,
          'endMillis': endMillis,
          'section': entry.start,
          'tone': entry.tone,
        });
      }
      courses.sort((a, b) {
        final time = ((a['startMillis'] as int?) ?? 0).compareTo(
          (b['startMillis'] as int?) ?? 0,
        );
        return time != 0
            ? time
            : (a['name'] as String).compareTo(b['name'] as String);
      });
      days.add({
        'date': desktopWidgetDate(date),
        'week': week,
        'courses': courses,
      });
    }
  }
  return {
    'version': 1,
    'status': 'ready',
    'message': '',
    'semester': semester.label,
    'updatedAt': updatedAt.millisecondsSinceEpoch,
    'days': days,
  };
}

Map<String, Object?> desktopWidgetMessage(String status, String message) => {
  'version': 1,
  'status': status,
  'message': message,
  'days': <Object>[],
};

String desktopWidgetDate(DateTime date) =>
    '${date.year}-${_two(date.month)}-${_two(date.day)}';

String _two(int value) => value.toString().padLeft(2, '0');

int? _schoolTime(DateTime date, String time) {
  final match = RegExp(r'^(\d{1,2}):(\d{2})(?::\d{2})?$').firstMatch(time);
  if (match == null) return null;
  final hour = int.parse(match[1]!);
  final minute = int.parse(match[2]!);
  if (hour > 23 || minute > 59) return null;
  // 课程时间固定为北京时间，不随手机时区改变。
  return DateTime.utc(
    date.year,
    date.month,
    date.day,
    hour - 8,
    minute,
  ).millisecondsSinceEpoch;
}
