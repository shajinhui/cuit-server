import 'dart:math' as math;

import 'package:chengxin_youyou/core/network/api_exception.dart';
import 'package:chengxin_youyou/core/storage/app_storage.dart';
import 'package:flutter/foundation.dart';

import '../data/schedule_local_store.dart';
import '../data/schedule_repository.dart';
import '../models/academic_calendar.dart';
import '../models/course_block.dart';
import '../models/local_course.dart';
import '../models/schedule_layout.dart';
import '../models/schedule_order.dart';
import '../models/semester.dart';
import '../platform/schedule_order_builder.dart';

class ScheduleViewModel extends ChangeNotifier {
  ScheduleViewModel(
    this.repository,
    this.calendar, {
    required this.onSessionExpired,
    this.onOnline,
    DateTime Function()? now,
    ScheduleLocalStore? localStore,
    ScheduleOrderBuilder? orderBuilder,
  }) : orderBuilder = orderBuilder ?? prepareScheduleOrder,
       _now = now ?? DateTime.now,
       localStore =
           localStore ?? ScheduleLocalStore(MemoryAppStorage(), 'demo') {
    selectedDate = _now();
  }
  final ScheduleOrderBuilder orderBuilder;
  ScheduleOrder order = ScheduleOrder(chinese: [], standard: []);
  final ScheduleRepository repository;
  final AcademicCalendar calendar;
  final ScheduleLocalStore localStore;
  final VoidCallback onSessionExpired;
  final VoidCallback? onOnline;
  final DateTime Function() _now;
  List<Semester> semesters = [];
  Semester? selectedSemester;
  ScheduleSnapshot? snapshot;
  ScheduleLocalData local = ScheduleLocalData();
  late DateTime selectedDate;
  int selectedWeek = 1;
  bool isLoading = false, isRefreshing = false, _manualWeek = false;
  String? error, weekError;
  int? _serverWeek;
  int _requestNumber = 0;
  bool _disposed = false;
  final Map<int, List<CourseBlock>> _blocks = {};
  Future<void> _localWrites = Future.value();

  bool get hasData => snapshot != null;
  int? get currentWeek => calendar.currentSchoolWeek(_now()) ?? _serverWeek;
  bool get isCurrentSemester {
    final current = calendar.semesterForDate(_now());
    return selectedSemester?.schoolYear == current.schoolYear &&
        selectedSemester?.term == current.term;
  }

  int get weekCount => [
    snapshot?.table.weekCount == 0 ? 0 : snapshot?.table.weekCount ?? 0,
    if ((snapshot?.table.weekCount ?? 0) == 0 && selectedSemester != null)
      calendar.publishedWeekCount(selectedSemester!),
    if (isCurrentSemester) currentWeek ?? 0,
    selectedWeek,
    1,
  ].reduce(math.max);
  int get sectionCount =>
      visibleEntries.fold(12, (max, b) => math.max(max, b.end));
  List<CourseBlock> get visibleEntries => _blocks.putIfAbsent(
    selectedWeek,
    () => groupCourseBlocks(entriesFor(selectedWeek), selectedWeek, order),
  );
  List<LocalCourse> get manualCourses => local.courses
      .where((c) => c.semesterId == selectedSemester?.id && c.targetId == null)
      .toList();
  List<LocalCourse> get overrides => local.courses
      .where((c) => c.semesterId == selectedSemester?.id && c.targetId != null)
      .toList();
  List<CourseBlock> entriesFor(int week) => buildScheduleEntries(
    snapshot?.table.courses ?? [],
    week,
    order: order,
    manual: manualCourses,
    overrides: overrides,
    colors: local.colors[selectedSemester?.id] ?? {},
  );
  bool get hasCalendar =>
      selectedSemester != null &&
      calendar.firstMonday(selectedSemester!) != null;
  String get dateTitle => hasCalendar
      ? '${selectedDate.year}/${selectedDate.month}/${selectedDate.day}'
      : '校历日期待更新';
  String get weekStatus {
    if (isLoading && !hasData) return '同步中';
    if (!hasCalendar) return '校历待更新';
    if (!isCurrentSemester) {
      return calendar.firstMonday(selectedSemester!)!.isAfter(_now())
          ? '未来学期'
          : '历史学期';
    }
    if ((currentWeek ?? 0) <= 0) return weekError != null ? '当前周不可用' : '非教学周';
    return selectedWeek == currentWeek ? '本周' : '非本周';
  }

  Future<void> initialize() async {
    final request = ++_requestNumber;
    isLoading = true;
    error = null;
    _notify();
    try {
      try {
        local = await localStore.read();
      } catch (_) {
        error = '读取本机课程失败，请重试';
      }
      final result = await repository.semesters();
      if (!_current(request)) return;
      semesters = result;
      if (result.isEmpty) {
        selectedSemester = null;
        snapshot = null;
        isLoading = false;
        _notify();
        return;
      }
      final selected =
          result.where((s) => s.id == local.semesterId).firstOrNull ??
          calendar.chooseSemester(result, _now());
      await selectSemester(selected);
    } catch (failure) {
      if (_current(request)) {
        isLoading = false;
        _handleError(failure);
      }
    }
  }

  Future<void> selectSemester(Semester semester) async =>
      _load(semester, refresh: false, changing: true);
  Future<void> refresh() async {
    if (isLoading || isRefreshing || selectedSemester == null) return;
    await _load(selectedSemester!, refresh: true, changing: false);
  }

  Future<void> retry() async {
    if (selectedSemester == null) {
      await initialize();
    } else {
      await _load(selectedSemester!, refresh: true, changing: false);
    }
  }

  Future<void> _load(
    Semester semester, {
    required bool refresh,
    required bool changing,
  }) async {
    final request = ++_requestNumber;
    isLoading = snapshot == null;
    isRefreshing = snapshot != null;
    error = null;
    _notify();
    try {
      var target = semester;
      if (refresh || (changing && hasData)) {
        final fresh = await repository.semesters(refresh: true);
        if (!_current(request)) return;
        semesters = fresh;
        if (fresh.isEmpty) {
          snapshot = null;
          selectedSemester = null;
          _blocks.clear();
          return;
        }
        target =
            fresh.where((s) => s.id == semester.id).firstOrNull ??
            calendar.chooseSemester(fresh, _now());
      }
      final result = await repository.load(target.id, refresh: refresh);
      if (!_current(request)) return;
      try {
        final serverWeek = await repository.currentWeek(
          refresh: !result.fromCache,
        );
        if (!_current(request)) return;
        _serverWeek = serverWeek;
        weekError = null;
      } catch (failure) {
        if (failure is ApiException &&
            failure.kind == FailureKind.authentication) {
          rethrow;
        }
        if (calendar.currentSchoolWeek(_now()) == null) weekError = '当前周不可用';
      }
      if (!_current(request)) return;
      final nextOrder = await orderBuilder(result.table.courses, local.courses);
      if (!_current(request)) return;
      order = nextOrder;
      selectedSemester = target;
      snapshot = result;
      if (!result.fromCache) onOnline?.call();
      _blocks.clear();
      if (changing || !_manualWeek) resetWeekSelection(notify: false);
      // 记住用户浏览的学期；缓存写失败不影响已加载的课表。
      try {
        await _saveLocal((value) => value.copyWith(semesterId: target.id));
      } catch (_) {}
    } catch (failure) {
      if (_current(request)) _handleError(failure);
    } finally {
      if (_current(request)) {
        isLoading = false;
        isRefreshing = false;
        _notify();
      }
    }
  }

  void resetWeekSelection({bool notify = true}) {
    _manualWeek = false;
    selectedWeek = isCurrentSemester && (currentWeek ?? 0) > 0
        ? currentWeek!
        : 1;
    final today = _now();
    selectedDate = selectedSemester == null
        ? today
        : calendar.dateFor(selectedSemester!, selectedWeek, today.weekday) ??
              today;
    if (notify) _notify();
  }

  void selectWeek(int week) {
    if (week < 1 || week == selectedWeek) return;
    selectedWeek = week;
    _manualWeek = true;
    if (selectedSemester != null) {
      selectedDate =
          calendar.dateFor(selectedSemester!, week, selectedDate.weekday) ??
          selectedDate;
    }
    _notify();
  }

  void selectDay(int day) {
    selectedDate = DateTime(
      selectedDate.year,
      selectedDate.month,
      selectedDate.day - selectedDate.weekday + day,
    );
    _notify();
  }

  Future<void> saveCourse(LocalCourse course) async {
    if (course.name.trim().isEmpty) throw const FormatException('请输入课程名称');
    if (course.semesterId.isEmpty) throw const FormatException('请选择学期');
    if (course.day < 1 || course.day > 7) {
      throw const FormatException('请选择正确的上课日期');
    }
    if (course.start < 1 || course.end < course.start) {
      throw const FormatException('请选择正确的上课节次');
    }
    if (course.weeks.isEmpty || course.weeks.any((w) => w < 1)) {
      throw const FormatException('请选择正确的上课周次');
    }
    await _saveLocal(
      (value) => value.copyWith(
        courses: [
          ...value.courses.where(
            (c) => !(c.semesterId == course.semesterId && c.id == course.id),
          ),
          course,
        ],
      ),
    );
  }

  Future<void> deleteCourse(CourseBlock course) async {
    if (!course.isManual) return;
    await _saveLocal((value) {
      final colors = {
        for (final e in value.colors.entries) e.key: {...e.value},
      };
      colors[selectedSemester?.id]?.remove(course.colorKey);
      return value.copyWith(
        courses: value.courses
            .where(
              (c) =>
                  !(c.semesterId == selectedSemester?.id && c.id == course.id),
            )
            .toList(),
        colors: colors,
      );
    });
  }

  Future<void> setColor(String key, int? tone) async => _saveLocal((value) {
    final semester = selectedSemester?.id;
    if (semester == null) return value;
    final colors = {
      for (final e in value.colors.entries) e.key: {...e.value},
    };
    final selected = colors.putIfAbsent(semester, () => {});
    if (tone == null) {
      selected.remove(key);
    } else {
      selected[key] = tone;
    }
    return value.copyWith(colors: colors);
  });
  Future<void> setOpacity(double value) async {
    final normalized = (value.clamp(0, 1) * 100).round() / 100;
    local = local.copyWith(opacity: normalized);
    _notify();
    try {
      await _saveLocal((data) => data.copyWith(opacity: local.opacity));
    } catch (_) {}
  }

  Future<void> _saveLocal(
    ScheduleLocalData Function(ScheduleLocalData) update,
  ) {
    // 排队写入避免滑块、配色与课程保存互相覆盖。持久化成功后才提交课程变更。
    final task = _localWrites.then((_) async {
      if (_disposed) return;
      final value = update(local);
      final nextOrder = identical(value.courses, local.courses)
          ? order
          : await orderBuilder(snapshot?.table.courses ?? [], value.courses);
      if (_disposed) return;
      await localStore.write(value);
      if (_disposed) return;
      order = nextOrder;
      local = value;
      _blocks.clear();
      _notify();
    });
    _localWrites = task.catchError((Object _) {});
    return task;
  }

  bool _current(int request) => !_disposed && request == _requestNumber;
  void _notify() {
    if (!_disposed) notifyListeners();
  }

  void _handleError(Object failure) {
    if (failure is ApiException) {
      if (failure.kind == FailureKind.authentication) {
        onSessionExpired();
        return;
      }
      if (failure.kind == FailureKind.cancelled) return;
      error = hasData ? '网络不可用，继续显示离线课表' : failure.message;
    } else {
      error = hasData ? '网络不可用，继续显示离线课表' : '课表加载失败，请稍后重试。';
    }
    _notify();
  }

  @override
  void dispose() {
    _disposed = true;
    _requestNumber++;
    repository.invalidate();
    super.dispose();
  }
}
