import 'dart:convert';

import 'package:chengxin_youyou/core/storage/app_storage.dart';

import '../models/local_course.dart';

class ScheduleLocalData {
  ScheduleLocalData({
    this.courses = const [],
    this.colors = const {},
    this.opacity = .48,
    this.semesterId,
  });
  final List<LocalCourse> courses;
  // 学期与课程 ID 分开存储，避免历史学期同名课程共用设置。
  final Map<String, Map<String, int>> colors;
  final double opacity;
  final String? semesterId;
  ScheduleLocalData copyWith({
    List<LocalCourse>? courses,
    Map<String, Map<String, int>>? colors,
    double? opacity,
    String? semesterId,
  }) => ScheduleLocalData(
    courses: courses ?? this.courses,
    colors: colors ?? this.colors,
    opacity: opacity ?? this.opacity,
    semesterId: semesterId ?? this.semesterId,
  );
}

class ScheduleLocalStore {
  ScheduleLocalStore(this.storage, this.key);
  final AppStorage storage;
  final String key;
  Future<ScheduleLocalData> read() async {
    final value = await storage.read(key);
    if (value == null) return ScheduleLocalData();
    try {
      final json = jsonDecode(value) as Map<String, dynamic>;
      final colors = <String, Map<String, int>>{};
      for (final entry
          in (json['colors'] as Map<String, dynamic>? ?? {}).entries) {
        colors[entry.key] = (entry.value as Map<String, dynamic>).map(
          (key, value) => MapEntry(key, value as int),
        )..removeWhere((key, value) => value < 0 || value >= 15);
      }
      return ScheduleLocalData(
        courses: (json['courses'] as List? ?? [])
            .map((v) => LocalCourse.fromJson(v as Map<String, dynamic>))
            .toList(),
        colors: colors,
        opacity: ((json['opacity'] as num?)?.toDouble() ?? .48).clamp(0, 1),
        semesterId: json['semesterId'] as String?,
      );
    } on FormatException {
      return ScheduleLocalData();
    } on TypeError {
      return ScheduleLocalData();
    }
  }

  Future<void> write(ScheduleLocalData value) => storage.write(
    key,
    jsonEncode({
      'courses': value.courses.map((c) => c.toJson()).toList(),
      'colors': value.colors,
      'opacity': value.opacity,
      'semesterId': value.semesterId,
    }),
  );
}
