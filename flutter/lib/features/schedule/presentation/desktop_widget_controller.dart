import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/platform/desktop_widgets.dart';
import '../data/schedule_repository.dart';
import '../models/desktop_widget_snapshot.dart';
import '../models/semester.dart';
import '../models/local_course.dart';
import 'schedule_view_model.dart';

/// 桌面始终使用实际日期对应的学期，与页面正在浏览的周次、学期分开。
class DesktopWidgetController extends ChangeNotifier {
  DesktopWidgetController({
    required this.platform,
    required this.schedule,
    required this.campus,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now {
    schedule.addListener(_scheduleChanged);
  }

  final DesktopWidgets platform;
  final ScheduleViewModel schedule;
  final String campus;
  final DateTime Function() _now;
  final Map<String, ScheduleSnapshot> _snapshots = {};
  ScheduleSnapshot? _lastData;
  List<LocalCourse>? _lastCourses;
  Map<String, int>? _lastColors;
  Timer? _timer;
  Future<void>? _pending;
  bool _disposed = false;
  bool _syncAgain = false;
  bool syncing = false;
  String? error;
  Map<String, Object?> snapshot = desktopWidgetMessage('loading', '打开应用同步课表');

  Semester? get currentSemester {
    final current = schedule.calendar.semesterForDate(_now());
    return schedule.semesters
        .where(
          (semester) =>
              semester.schoolYear == current.schoolYear &&
              semester.term == current.term,
        )
        .firstOrNull;
  }

  void _scheduleChanged() {
    final loaded = schedule.snapshot;
    if (loaded != null) _snapshots[loaded.table.semesterId] = loaded;
    _timer?.cancel();
    // 连续修改、加载状态变化合并一次，不在切周或滚动时反复刷新桌面。
    _timer = Timer(const Duration(milliseconds: 200), () {
      unawaited(synchronize());
    });
    if (_pending != null) _syncAgain = true;
  }

  Future<void> synchronize({bool refresh = false}) {
    if (_disposed) return Future.value();
    if (_pending != null) return _pending!;
    final task = _synchronize(refresh);
    _pending = task.whenComplete(() {
      _pending = null;
      if (_syncAgain && !_disposed) {
        _syncAgain = false;
        unawaited(synchronize());
      }
    });
    return _pending!;
  }

  Future<void> _synchronize(bool refresh) async {
    if (schedule.isLoading || schedule.isRefreshing) return;
    syncing = true;
    error = null;
    notifyListeners();
    try {
      final semester = currentSemester;
      Map<String, Object?> next;
      if (semester == null) {
        _lastData = null;
        next = desktopWidgetMessage('noSemester', '打开应用同步本学期课表');
      } else {
        var refreshedPage = false;
        if (refresh && schedule.selectedSemester?.id == semester.id) {
          // 页面也持有本学期数据时一起刷新，避免切周把旧课表重新写回桌面。
          await schedule.refresh();
          if (_disposed) return;
          if (schedule.error != null) throw StateError(schedule.error!);
          refreshedPage = schedule.selectedSemester?.id == semester.id;
        }
        var data = _snapshots[semester.id];
        if (schedule.selectedSemester?.id == semester.id &&
            schedule.snapshot != null) {
          data = schedule.snapshot;
        }
        if (data == null || (refresh && !refreshedPage)) {
          data = await schedule.repository.loadForWidget(
            semester.id,
            refresh: refresh,
          );
          if (_disposed) return;
          _snapshots[semester.id] = data;
        }
        final local = schedule.local;
        final colors = local.colors[semester.id];
        if (!refresh &&
            identical(data, _lastData) &&
            identical(local.courses, _lastCourses) &&
            identical(colors, _lastColors)) {
          return;
        }
        // 历史学期的排序索引不包含本学期课程，必须为这份数据单独准备。
        final order = await schedule.orderBuilder(
          data.table.courses,
          local.courses,
        );
        if (_disposed) return;
        next = createDesktopWidgetSnapshot(
          calendar: schedule.calendar,
          semester: semester,
          table: data.table,
          order: order,
          updatedAt: data.updatedAt,
          localCourses: local.courses,
          colors: colors ?? {},
          campus: campus,
        );
        await platform.publish(next);
        if (_disposed) return;
        _lastData = data;
        _lastCourses = local.courses;
        _lastColors = colors;
        snapshot = next;
        return;
      }
      if (_disposed) return;
      await platform.publish(next);
      if (!_disposed) snapshot = next;
    } catch (_) {
      if (!_disposed) error = '暂时无法更新桌面小组件，请稍后重试。';
    } finally {
      if (!_disposed) {
        syncing = false;
        notifyListeners();
      }
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    schedule.removeListener(_scheduleChanged);
    super.dispose();
  }
}
