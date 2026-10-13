import 'package:chengxin_youyou/features/schedule/models/schedule_order.dart';

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:chengxin_youyou/features/schedule/models/course.dart';
import 'package:chengxin_youyou/features/schedule/models/course_block.dart';
import 'package:chengxin_youyou/features/schedule/models/local_course.dart';
import 'package:chengxin_youyou/features/schedule/models/schedule_layout.dart';
import 'package:chengxin_youyou/features/schedule/models/calendar_export.dart';
import 'package:chengxin_youyou/features/schedule/models/academic_calendar.dart';
import 'package:chengxin_youyou/features/schedule/models/semester.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final reference =
      jsonDecode(
            File('test/fixtures/schedule_reference.json').readAsStringSync(),
          )
          as Map<String, dynamic>;
  List<LocalCourse> locals(Object? raw) => (raw as List)
      .map((v) => LocalCourse.fromJson(v as Map<String, dynamic>))
      .toList();
  for (final sample in reference['examples'] as List) {
    test('与原版一致：${sample['name']}', () {
      final order = ScheduleOrder(
        chinese: (sample['order']['chinese'] as List).cast<String>(),
        standard: (sample['order']['standard'] as List).cast<String>(),
      );
      final courses = (sample['courses'] as List)
          .map((v) => Course.fromJson(v as Map<String, dynamic>))
          .toList();
      final entries = buildScheduleEntries(
        courses,
        sample['week'] as int,
        order: order,
        manual: locals(sample['manual']),
        overrides: locals(sample['overrides']),
        colors: {
          for (final c in sample['colors'] as List)
            c['courseKey'] as String: courseToneNames.indexOf(
              c['tone'] as String,
            ),
        },
      );
      expect(entries.map((b) => b.toJson()).toList(), sample['entries']);
      expect(
        groupCourseBlocks(
          entries,
          sample['week'] as int,
          order,
        ).map((b) => b.toJson()).toList(),
        sample['blocks'],
      );
    });
  }
  test('ICS 内容、UID、中文折行及本机覆盖与原版逐字相同', () async {
    final data = reference['export'] as Map<String, dynamic>;
    final result = createCalendarExport(
      calendar: await AcademicCalendar.load(),
      order: ScheduleOrder(
        chinese: (data['order']['chinese'] as List).cast<String>(),
        standard: (data['order']['standard'] as List).cast<String>(),
      ),
      semester: Semester.fromJson(data['semester'] as Map<String, dynamic>),
      table: CourseTable.fromJson(data['table'] as Map<String, dynamic>),
      manual: locals(data['manual']),
      overrides: locals(data['overrides']),
      generatedAt: DateTime.parse('2026-09-30T01:02:03Z'),
    );
    expect(result.content, data['content']);
    expect(result.eventCount, data['eventCount']);
    expect(result.courseCount, data['courseCount']);
    expect(result.fileName, data['fileName']);
    expect(result.calendarName, data['calendarName']);
  });
}
