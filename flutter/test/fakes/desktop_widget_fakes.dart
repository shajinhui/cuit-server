import 'dart:convert';

import 'package:chengxin_youyou/core/platform/desktop_widgets.dart';
import 'package:chengxin_youyou/features/schedule/data/schedule_repository.dart';
import 'package:chengxin_youyou/features/schedule/models/academic_calendar.dart';
import 'package:chengxin_youyou/features/schedule/models/course.dart';
import 'package:chengxin_youyou/features/schedule/models/local_course.dart';
import 'package:chengxin_youyou/features/schedule/models/schedule_order.dart';
import 'package:chengxin_youyou/features/schedule/models/semester.dart';
import 'package:chengxin_youyou/features/session/session.dart';
import 'package:flutter/foundation.dart';

const widgetSemester = Semester(
  id: 'current',
  schoolYear: '2026-2027',
  term: '1',
  isCurrent: true,
);
const widgetHistory = Semester(
  id: 'history',
  schoolYear: '2025-2026',
  term: '2',
);

AcademicCalendar widgetCalendar() => AcademicCalendar([
  {
    'schoolYear': '2026-2027',
    'term': '1',
    'firstWeekMonday': '2026-09-07',
    'weekCount': 20,
  },
  {
    'schoolYear': '2025-2026',
    'term': '2',
    'firstWeekMonday': '2026-03-02',
    'weekCount': 20,
  },
]);

ScheduleSnapshot widgetFixture({String semester = 'current'}) =>
    ScheduleSnapshot(
      CourseTable(
        semesterId: semester,
        weekCount: 20,
        sectionsPerDay: 12,
        courses: semester == 'history'
            ? [_course('history', '历史学期课程', 1, 2)]
            : [
                _course('math', '高等数学', 1, 2, weeks: [5]),
                _course('conflict', '操作系统', 1, 2, weeks: [5]),
                _course(
                  'experiment',
                  '软件工程实验',
                  5,
                  6,
                  weeks: [5],
                  experiment: true,
                ),
                _course('english', '大学英语', 10, 11),
              ],
      ),
      DateTime(2026, 10, 8, 8),
    );

Course _course(
  String id,
  String name,
  int start,
  int end, {
  List<int> weeks = const [],
  bool experiment = false,
}) => Course(
  id: id,
  name: name,
  activities: [
    CourseActivity(
      day: 4,
      start: start,
      end: end,
      weeks: weeks,
      room: experiment ? '实验楼 B412' : 'H1208',
      activityType: experiment ? '实验' : '',
      startTime: experiment ? '14:15' : '',
      endTime: experiment ? '15:20' : '',
    ),
  ],
);

Future<ScheduleOrder> widgetOrder(
  List<Course> courses,
  List<LocalCourse> local,
) async {
  final values = ScheduleOrder.values(courses, local).toList()..sort();
  return ScheduleOrder(chinese: values, standard: values);
}

class WidgetScheduleRepository extends ScheduleRepository {
  final loads = <String>[];
  Future<ScheduleSnapshot> Function(String)? loader;
  @override
  Future<List<Semester>> semesters({bool refresh = false}) async => [
    widgetSemester,
    widgetHistory,
  ];
  @override
  Future<ScheduleSnapshot> load(
    String semesterId, {
    bool refresh = false,
  }) async {
    loads.add(semesterId);
    return loader == null
        ? widgetFixture(semester: semesterId)
        : await loader!(semesterId);
  }

  @override
  Future<void> clear() async {}
  @override
  void invalidate() {}
}

class FakeDesktopWidgets implements DesktopWidgets {
  final publications = <Map<String, Object?>>[];
  @override
  bool canRequestPin = true;
  bool pinSupported = true;
  bool initialLaunch = false;
  VoidCallback? onOpen;
  @override
  set onOpenSchedule(VoidCallback? callback) => onOpen = callback;
  @override
  Future<bool> consumeLaunch() async => initialLaunch;
  @override
  Future<void> publish(Map<String, Object?> snapshot) async {
    publications.add(
      (jsonDecode(jsonEncode(snapshot)) as Map).cast<String, Object?>(),
    );
  }

  @override
  Future<bool> requestPin() async => pinSupported;
}

class WidgetSessionRepository implements SessionRepository {
  static const student = Student(
    number: 'WIDGET-TEST',
    name: '测试同学',
    campus: '航空港校区',
  );
  @override
  Future<Student> login(String number, String password) async => student;
  @override
  Future<RestoredSession?> restore() async =>
      const RestoredSession(student, offline: true);
  @override
  Future<void> logout() async {}
}
