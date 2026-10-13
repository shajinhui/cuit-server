import 'dart:convert';

import 'package:flutter/services.dart';

import '../models/course.dart';
import '../models/semester.dart';
import 'schedule_repository.dart';

/// 直接使用原版 Vue 的虚拟课表样例，便于逐项对照两端界面。
class DemoScheduleRepository extends ScheduleRepository {
  static const semester = Semester(
    id: '2025-2026-2',
    schoolYear: '2025-2026',
    term: '2',
    isCurrent: true,
  );
  static Map<String, dynamic>? _fixture;
  static Future<void> prepare() async {
    _fixture ??=
        jsonDecode(
              await rootBundle.loadString('assets/data/demo_schedule.json'),
            )
            as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> _data() async {
    if (_fixture == null) await prepare();
    return _fixture!;
  }

  @override
  Future<List<Semester>> semesters({bool refresh = false}) async =>
      ((await _data())['semesters'] as List)
          .map((v) => Semester.fromJson(v as Map<String, dynamic>))
          .toList();
  @override
  Future<ScheduleSnapshot> load(
    String semesterId, {
    bool refresh = false,
  }) async {
    final raw = Map<String, dynamic>.from((await _data())['table'] as Map);
    raw['SemesterID'] = semesterId;
    if (semesterId != semester.id) raw['Courses'] = [];
    return ScheduleSnapshot(
      CourseTable.fromJson(raw),
      DateTime(2026, 9, 30, 8, 30),
    );
  }

  @override
  Future<void> clear() async {}
  @override
  void invalidate() {}
}
