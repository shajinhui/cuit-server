class CourseActivity {
  CourseActivity({
    required this.day,
    required this.start,
    required this.end,
    required List<int> weeks,
    this.room = '',
    List<String> teachers = const [],
    this.startTime = '',
    this.endTime = '',
    this.projectName = '',
    this.activityType = '',
  }) : weeks = List.unmodifiable(weeks),
       teachers = List.unmodifiable(teachers);

  final int day;
  final int start;
  final int end;
  final List<int> weeks;
  final String room;
  final List<String> teachers;
  final String startTime;
  final String endTime;
  final String projectName;
  final String activityType;

  factory CourseActivity.fromJson(Map<String, dynamic> json) => CourseActivity(
    day: (json['Weekday'] as num).toInt(),
    start: (json['StartSection'] as num).toInt(),
    end: (json['EndSection'] as num).toInt(),
    room: json['RoomName'] as String? ?? '',
    weeks: (json['Weeks'] as List? ?? [])
        .map((value) => (value as num).toInt())
        .toList(),
    teachers: (json['Teachers'] as List? ?? []).cast<String>(),
    startTime: json['StartTime'] as String? ?? '',
    endTime: json['EndTime'] as String? ?? '',
    projectName: json['ProjectName'] as String? ?? '',
    activityType: json['ActivityType'] as String? ?? '',
  );

  Map<String, Object> toJson() => {
    'Weekday': day,
    'StartSection': start,
    'EndSection': end,
    'Weeks': weeks,
    'RoomName': room,
    'Teachers': teachers,
    'StartTime': startTime,
    'EndTime': endTime,
    'ProjectName': projectName,
    'ActivityType': activityType,
  };
}

class Course {
  Course({
    required this.id,
    required this.name,
    this.code = '',
    this.credits = '',
    this.teachingClass = '',
    List<String> teachers = const [],
    required List<CourseActivity> activities,
  }) : teachers = List.unmodifiable(teachers),
       activities = List.unmodifiable(activities);

  final String id;
  final String name;
  final String code;
  final String credits;
  final String teachingClass;
  final List<String> teachers;
  final List<CourseActivity> activities;

  factory Course.fromJson(Map<String, dynamic> json) => Course(
    id: json['LessonID'] as String? ?? json['Code'] as String? ?? '',
    name: json['Name'] as String,
    code: json['Code'] as String? ?? '',
    credits: json['Credits']?.toString() ?? '',
    teachingClass: json['TeachingClass'] as String? ?? '',
    teachers: (json['Teachers'] as List? ?? []).cast<String>(),
    activities: (json['Activities'] as List? ?? [])
        .map((item) => CourseActivity.fromJson(item as Map<String, dynamic>))
        .toList(),
  );
  Map<String, Object> toJson() => {
    'LessonID': id,
    'Name': name,
    'Code': code,
    'Credits': credits,
    'TeachingClass': teachingClass,
    'Teachers': teachers,
    'Activities': activities.map((item) => item.toJson()).toList(),
  };
}

class CourseTable {
  CourseTable({
    required this.semesterId,
    required this.weekCount,
    required this.sectionsPerDay,
    required List<Course> courses,
  }) : courses = List.unmodifiable(courses);
  final String semesterId;
  final int weekCount;
  final int sectionsPerDay;
  final List<Course> courses;

  factory CourseTable.fromJson(Map<String, dynamic> json) {
    final weeks = (json['WeekCount'] as num).toInt();
    final sections = (json['SectionsPerDay'] as num).toInt();
    if (weeks < 0 || weeks > 60 || sections < 1 || sections > 24) {
      throw const FormatException('课表范围无效');
    }
    return CourseTable(
      semesterId: json['SemesterID'] as String,
      weekCount: weeks,
      sectionsPerDay: sections,
      courses: (json['Courses'] as List? ?? [])
          .map((item) => Course.fromJson(item as Map<String, dynamic>))
          .toList(),
    );
  }
  Map<String, Object> toJson() => {
    'SemesterID': semesterId,
    'WeekCount': weekCount,
    'SectionsPerDay': sectionsPerDay,
    'Courses': courses.map((course) => course.toJson()).toList(),
  };
}
