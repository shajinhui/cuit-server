import 'course.dart';
import 'local_course.dart';

/// 系统排序只在数据变化时执行一次；排课算法按已准备的索引比较字符串。
class ScheduleOrder {
  ScheduleOrder({required List<String> chinese, required List<String> standard})
    : _chinese = {for (var i = 0; i < chinese.length; i++) chinese[i]: i},
      _standard = {for (var i = 0; i < standard.length; i++) standard[i]: i};
  final Map<String, int> _chinese, _standard;
  int chinese(String a, String b) => _compare(_chinese, a, b);
  int standard(String a, String b) => _compare(_standard, a, b);
  int _compare(Map<String, int> order, String a, String b) {
    if (a == b) return 0;
    final left = order[a], right = order[b];
    if (left == null || right == null) throw StateError('课表排序索引未准备完整');
    return left.compareTo(right);
  }

  static Set<String> values(List<Course> courses, List<LocalCourse> local) {
    final values = <String>{'', '地点待定', '未命名课程'};
    for (final course in courses) {
      final identity = [
        course.code,
        course.id,
      ].where((v) => v.isNotEmpty).join('\u0000');
      values.add(identity.isEmpty ? course.name : identity);
      values.add(course.name);
      for (final activity in course.activities) {
        values.add(activity.room.isEmpty ? '地点待定' : activity.room);
        values.add(
          activity.teachers
              .map((s) => s.trim())
              .where((s) => s.isNotEmpty)
              .toSet()
              .join('\u0000'),
        );
      }
    }
    for (final course in local) {
      values.addAll([course.id, course.name, course.room]);
    }
    // 原版颜色分配会 trim identity，而房间和名称比较保留原字符串。
    values.addAll(values.map((s) => s.trim()).toList());
    return values;
  }
}
