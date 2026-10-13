import '../models/course.dart';
import '../models/semester.dart';

class ScheduleSnapshot {
  const ScheduleSnapshot(this.table, this.updatedAt, {this.fromCache = false});
  final CourseTable table;
  final DateTime updatedAt;
  final bool fromCache;
}

abstract class ScheduleRepository {
  /// 获取学期目录；断网可回退已保存的目录，不能伪造学期。
  Future<List<Semester>> semesters({bool refresh = false});

  Future<int?> currentWeek({bool refresh = false}) async => null;

  /// 默认优先读缓存；主动刷新时访问服务端，失败保留已有缓存。
  Future<ScheduleSnapshot> load(String semesterId, {bool refresh = false});

  /// 桌面读取本学期；页面浏览历史学期后仍允许使用本学期的离线缓存。
  Future<ScheduleSnapshot> loadForWidget(
    String semesterId, {
    bool refresh = false,
  }) => load(semesterId, refresh: refresh);

  /// 删除当前账号缓存，并使该仓库失效。
  Future<void> clear();

  /// 阻止旧请求返回或写入数据；由账号范围的创建方调用。
  void invalidate();
}
