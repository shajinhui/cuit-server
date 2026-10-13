const courseToneNames = [
  'haze-blue',
  'terracotta',
  'sage',
  'dusty-purple',
  'mustard',
  'rose-brown',
  'blue-gray',
  'caramel',
  'slate-blue',
  'olive',
  'muted-coral',
  'seafoam',
  'lavender-gray',
  'sand',
  'pine',
];
const courseToneLabels = [
  '雾霾蓝',
  '陶土橙',
  '鼠尾草绿',
  '灰紫',
  '芥末黄',
  '玫瑰棕',
  '青灰',
  '焦糖棕',
  '石板蓝',
  '橄榄灰',
  '柔珊瑚',
  '海沫青',
  '薰衣草灰',
  '沙岩色',
  '松针绿',
];

class CourseArrangement {
  const CourseArrangement({
    required this.room,
    required this.teachers,
    required this.weeks,
    this.startTime = '',
    this.endTime = '',
    this.activityType = '',
    this.projectName = '',
  });
  final String room, startTime, endTime, activityType, projectName;
  final List<String> teachers;
  final List<int> weeks;
  bool activeIn(int week) => week <= 0 || weeks.isEmpty || weeks.contains(week);
  CourseArrangement withWeeks(List<int> value) => CourseArrangement(
    room: room,
    teachers: teachers,
    weeks: value,
    startTime: startTime,
    endTime: endTime,
    activityType: activityType,
    projectName: projectName,
  );
  Map<String, Object> toJson() => {
    'room': room,
    'teachers': teachers,
    'weeks': weeks,
    if (startTime.isNotEmpty) 'startTime': startTime,
    if (endTime.isNotEmpty) 'endTime': endTime,
    if (activityType.isNotEmpty) 'activityType': activityType,
    if (projectName.isNotEmpty) 'projectName': projectName,
  };
}

/// courses 保存合并前的原始课程，详情、编辑和导出不能丢失这些信息。
class CourseBlock {
  const CourseBlock({
    required this.id,
    required this.name,
    required this.room,
    required this.day,
    required this.start,
    required this.span,
    required this.colorKey,
    required this.tone,
    required this.muted,
    required this.weeks,
    required this.arrangements,
    this.code = '',
    this.credits = '',
    this.teachingClass = '',
    this.teachers = const [],
    this.source = 'jwxt',
    this.experimentStartTime = '',
    this.experimentEndTime = '',
    this.courses = const [],
    this.conflict = false,
  });
  final String id, name, room, colorKey, code, credits, teachingClass, source;
  final String experimentStartTime, experimentEndTime;
  final int day, start, span, tone;
  final bool muted, conflict;
  final List<int> weeks;
  final List<String> teachers;
  final List<CourseArrangement> arrangements;
  final List<CourseBlock> courses;
  int get end => start + span - 1;
  bool get isManual => source == 'manual';
  List<CourseBlock> get entries => courses.isEmpty ? [this] : courses;
  CourseBlock copyWith({
    String? id,
    String? name,
    String? room,
    int? day,
    int? start,
    int? span,
    List<int>? weeks,
    List<CourseArrangement>? arrangements,
    bool? muted,
    List<CourseBlock>? courses,
    bool? conflict,
    bool clearExperiment = false,
  }) => CourseBlock(
    id: id ?? this.id,
    name: name ?? this.name,
    room: room ?? this.room,
    day: day ?? this.day,
    start: start ?? this.start,
    span: span ?? this.span,
    weeks: weeks ?? this.weeks,
    arrangements: arrangements ?? this.arrangements,
    muted: muted ?? this.muted,
    courses: courses ?? this.courses,
    conflict: conflict ?? this.conflict,
    colorKey: colorKey,
    tone: tone,
    code: code,
    credits: credits,
    teachingClass: teachingClass,
    teachers: teachers,
    source: source,
    experimentStartTime: clearExperiment ? '' : experimentStartTime,
    experimentEndTime: clearExperiment ? '' : experimentEndTime,
  );
  Map<String, Object> toJson({bool includeGroup = true}) => {
    'id': id,
    'name': name,
    'room': room,
    'day': day,
    'start': start,
    'span': span,
    'code': code,
    'credits': credits,
    'teachingClass': teachingClass,
    'teachers': teachers,
    'weeks': weeks,
    'source': source,
    'colorKey': colorKey,
    'tone': courseToneNames[tone],
    'muted': muted,
    'arrangements': arrangements.map((a) => a.toJson()).toList(),
    if (experimentStartTime.isNotEmpty)
      'experimentStartTime': experimentStartTime,
    if (experimentEndTime.isNotEmpty) 'experimentEndTime': experimentEndTime,
    if (includeGroup)
      'courses': courses.map((b) => b.toJson(includeGroup: false)).toList(),
    if (includeGroup) 'conflict': conflict,
  };
}

String formatCourseTime(CourseBlock course) =>
    '周${'一二三四五六日'[course.day - 1]} · 第 ${course.start}${course.span > 1 ? '–${course.end}' : ''} 节';
String formatWeeks(List<int> weeks) {
  if (weeks.isEmpty) return '每周';
  final sorted = weeks.toSet().toList()..sort();
  final ranges = <String>[];
  var first = sorted.first;
  var last = first;
  for (final week in sorted.skip(1)) {
    if (week == last + 1) {
      last = week;
      continue;
    }
    ranges.add(first == last ? '$first' : '$first–$last');
    first = last = week;
  }
  ranges.add(first == last ? '$first' : '$first–$last');
  return '第${ranges.join('、')}周';
}

String formatArrangement(CourseArrangement a) =>
    '${formatWeeks(a.weeks)} · ${a.room}${a.startTime.isNotEmpty && a.endTime.isNotEmpty ? ' · ${a.startTime}–${a.endTime}' : ''}${a.projectName.isEmpty ? '' : ' · ${a.projectName}'}';
