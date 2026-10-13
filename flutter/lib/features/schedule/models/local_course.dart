/// 本机添加与教务课程覆盖共用一份字段，targetId 只用于教务课程覆盖。
class LocalCourse {
  const LocalCourse({
    required this.id,
    required this.semesterId,
    required this.name,
    required this.room,
    required this.day,
    required this.start,
    required this.end,
    required this.weeks,
    this.targetId,
  });
  final String id, semesterId, name, room;
  final String? targetId;
  final int day, start, end;
  final List<int> weeks;

  factory LocalCourse.fromJson(Map<String, dynamic> json) => LocalCourse(
    id: json['id'] as String? ?? json['targetID'] as String,
    targetId: json['targetID'] as String?,
    semesterId: json['semesterID'] as String,
    name: json['name'] as String,
    room: json['room'] as String,
    day: json['weekday'] as int,
    start: json['startSection'] as int,
    end: json['endSection'] as int,
    weeks: (json['weeks'] as List).cast<int>(),
  );
  Map<String, Object> toJson() => {
    'id': id,
    'targetID': ?targetId,
    'semesterID': semesterId,
    'name': name,
    'room': room,
    'weekday': day,
    'startSection': start,
    'endSection': end,
    'weeks': weeks,
  };
}

enum WeekRepeat { weekly, odd, even }

/// 周次范围仅在编辑过范围或单双周时展开；不规则周次可原样保存。
List<int> expandWeeks(int start, int end, WeekRepeat repeat) {
  if (start < 1 || end < start) throw const FormatException('请选择正确的上课周次');
  final weeks = <int>[];
  for (var week = start; week <= end; week++) {
    if (repeat == WeekRepeat.weekly ||
        (repeat == WeekRepeat.odd && week.isOdd) ||
        (repeat == WeekRepeat.even && week.isEven)) {
      weeks.add(week);
    }
  }
  if (weeks.isEmpty) throw const FormatException('当前周次范围没有符合条件的教学周');
  return weeks;
}
