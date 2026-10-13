import 'dart:convert';

import 'package:flutter/services.dart';

import 'semester.dart';

class AcademicCalendar {
  AcademicCalendar(this.records);
  final List<Map<String, dynamic>> records;

  static Future<AcademicCalendar> load() async {
    final raw = await rootBundle.loadString('assets/data/calendars.json');
    return AcademicCalendar(
      (jsonDecode(raw) as List).cast<Map<String, dynamic>>(),
    );
  }

  Map<String, dynamic>? _record(Semester semester) {
    for (final record in records) {
      if (record['schoolYear'] == semester.schoolYear &&
          record['term'].toString() == semester.term) {
        return record;
      }
    }
    return null;
  }

  DateTime? firstMonday(Semester semester) {
    final value = _record(semester)?['firstWeekMonday'] as String?;
    return value == null ? null : DateTime.parse(value);
  }

  /// 与原版一致：校历是本地日期，不通过 UTC 字符串解析。
  DateTime schoolDate(DateTime now) => DateTime(now.year, now.month, now.day);

  Semester semesterForDate(DateTime date) {
    final start = date.month >= 9 ? date.year : date.year - 1;
    return Semester(
      id: '',
      schoolYear: '$start-${start + 1}',
      term: date.month == 1 || date.month >= 9 ? '1' : '2',
    );
  }

  int? currentSchoolWeek(DateTime date) =>
      currentWeek(semesterForDate(date), date);
  int publishedWeekCount(Semester semester) =>
      _record(semester)?['weekCount'] as int? ?? 0;

  int? currentWeek(Semester semester, DateTime now) {
    final monday = firstMonday(semester);
    if (monday == null) return null;
    final days = DateTime.utc(
      now.year,
      now.month,
      now.day,
    ).difference(DateTime.utc(monday.year, monday.month, monday.day)).inDays;
    if (days < 0) return 0;
    final week = days ~/ 7 + 1;
    final count = _record(semester)!['weekCount'] as int;
    return week <= count ? week : 0;
  }

  DateTime? dateFor(Semester semester, int week, int day) =>
      _dateFor(semester, week, day);

  DateTime? _dateFor(Semester semester, int week, int day) {
    final monday = firstMonday(semester);
    if (monday == null || week < 1 || day < 1 || day > 7) return null;
    return DateTime(
      monday.year,
      monday.month,
      monday.day + (week - 1) * 7 + day - 1,
    );
  }

  Semester chooseSemester(List<Semester> semesters, DateTime now) {
    for (final semester in semesters) {
      if (semester.isCurrent) return semester;
    }
    for (final semester in semesters) {
      final week = currentWeek(semester, now);
      if (week != null && week > 0) return semester;
    }
    return semesters.first;
  }
}

const sectionStartTimes = [
  '08:20',
  '09:15',
  '10:20',
  '11:15',
  '14:00',
  '14:55',
  '15:50',
  '16:45',
  '17:40',
  '19:30',
  '20:25',
  '21:20',
];
const sectionEndTimes = [
  '09:05',
  '10:00',
  '11:05',
  '12:00',
  '14:45',
  '15:40',
  '16:35',
  '17:30',
  '18:25',
  '20:15',
  '21:10',
  '22:05',
];

String sectionStart(int section, Semester semester, String campus) {
  final startYear = int.tryParse(semester.schoolYear.split('-').first);
  if (campus.contains('龙泉') && startYear != null && startYear < 2026) {
    if (section == 1) return '08:30';
    if (section == 2) return '09:25';
  }
  return section >= 1 && section <= sectionStartTimes.length
      ? sectionStartTimes[section - 1]
      : '';
}

String sectionEnd(int section, Semester semester, String campus) {
  final startYear = int.tryParse(semester.schoolYear.split('-').first);
  if (campus.contains('龙泉') && startYear != null && startYear < 2026) {
    if (section == 1) return '09:15';
    if (section == 2) return '10:10';
  }
  return section >= 1 && section <= sectionEndTimes.length
      ? sectionEndTimes[section - 1]
      : '';
}
