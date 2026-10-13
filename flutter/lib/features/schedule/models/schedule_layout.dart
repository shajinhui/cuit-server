import 'dart:math' as math;

import 'package:collection/collection.dart';

import 'course.dart';
import 'course_block.dart';
import 'local_course.dart';
import 'schedule_order.dart';

List<String> _strings(Iterable<String> values) =>
    values.map((s) => s.trim()).where((s) => s.isNotEmpty).toSet().toList();
List<int> _numbers(Iterable<int> values) => values.toSet().toList()..sort();
String _identity(Course c) =>
    [c.code, c.id].where((v) => v.isNotEmpty).join('\u0000');
int _distance(List<int> weeks, int week) => week <= 0 || weeks.isEmpty
    ? 0
    : weeks.map((w) => (w - week).abs()).reduce(math.min);

List<CourseBlock> buildScheduleEntries(
  List<Course> courses,
  int week, {
  required ScheduleOrder order,
  List<LocalCourse> manual = const [],
  List<LocalCourse> overrides = const [],
  Map<String, int> colors = const {},
}) {
  final identities = _strings([
    ...courses.map((c) => _identity(c).isEmpty ? c.name : _identity(c)),
    ...manual.map((c) => c.id),
  ])..sort(order.chinese);
  final tones = {
    for (var i = 0; i < identities.length; i++)
      identities[i]: i % courseToneNames.length,
  };
  final result = <CourseBlock>[];
  for (final course in courses) {
    final identity = course.id.isNotEmpty
        ? course.id
        : course.code.isNotEmpty
        ? course.code
        : course.name;
    final colorKey = _identity(course).isEmpty
        ? course.name
        : _identity(course);
    final slots = <String, List<CourseActivity>>{};
    for (final a in course.activities) {
      if (a.day < 1 || a.day > 7 || a.start < 1 || a.end < a.start) continue;
      slots.putIfAbsent('${a.day}-${a.start}-${a.end}', () => []).add(a);
    }
    final blocks = <CourseBlock>[];
    for (final slot in slots.values) {
      final a = slot.first;
      final arrangements = _arrangements(slot, order);
      final active = arrangements.where((a) => a.activeIn(week)).toList();
      final visible = active.isNotEmpty
          ? active
          : [
              arrangements.reduce(
                (a, b) =>
                    _distance(b.weeks, week) < _distance(a.weeks, week) ? b : a,
              ),
            ];
      final experiment = visible.firstWhereOrNull(
        (a) =>
            a.activityType.contains('实验') &&
            a.startTime.isNotEmpty &&
            a.endTime.isNotEmpty,
      );
      blocks.add(
        CourseBlock(
          id: '$identity-${a.day}-${a.start}-${a.end}',
          name: course.name.isEmpty ? '未命名课程' : course.name,
          room: _strings(visible.map((a) => a.room)).join(' / '),
          day: a.day,
          start: a.start,
          span: a.end - a.start + 1,
          colorKey: colorKey,
          tone: colors[colorKey] ?? tones[colorKey] ?? 0,
          muted: week > 0 && active.isEmpty,
          weeks: _numbers(arrangements.expand((a) => a.weeks)),
          arrangements: arrangements,
          code: course.code,
          credits: course.credits,
          teachingClass: course.teachingClass,
          teachers: _strings([
            ...course.teachers,
            ...arrangements.expand((a) => a.teachers),
          ]),
          experimentStartTime: experiment?.startTime ?? '',
          experimentEndTime: experiment?.endTime ?? '',
        ),
      );
    }
    // 先按完整安排合并，再应用本机覆盖，保证覆盖目标 ID 不随当前周改变。
    final merged = <CourseBlock>[];
    mergeSort(
      blocks,
      compare: (a, b) => a.day - b.day != 0 ? a.day - b.day : a.start - b.start,
    );
    for (final block in blocks) {
      final previous = merged.lastOrNull;
      if (previous != null &&
          previous.day == block.day &&
          block.start <= previous.end + 1 &&
          _signature(previous.arrangements) == _signature(block.arrangements)) {
        final end = math.max(previous.end, block.end);
        merged[merged.length - 1] = previous.copyWith(
          id: '$identity-${previous.day}-${previous.start}-$end',
          span: end - previous.start + 1,
        );
      } else {
        merged.add(block);
      }
    }
    for (final block in merged) {
      final edit = overrides.lastWhereOrNull((c) => c.targetId == block.id);
      result.add(
        edit == null
            ? block
            : block.copyWith(
                name: edit.name,
                room: edit.room.isEmpty ? '地点待定' : edit.room,
                day: edit.day,
                start: edit.start,
                span: edit.end - edit.start + 1,
                weeks: edit.weeks,
                clearExperiment: true,
                muted: week > 0 && !edit.weeks.contains(week),
                arrangements: [
                  CourseArrangement(
                    room: edit.room.isEmpty ? '地点待定' : edit.room,
                    teachers: block.teachers,
                    weeks: edit.weeks,
                  ),
                ],
              ),
      );
    }
  }
  for (final c in manual) {
    final room = c.room.isEmpty ? '地点待定' : c.room;
    result.add(
      CourseBlock(
        id: c.id,
        name: c.name,
        room: room,
        day: c.day,
        start: c.start,
        span: c.end - c.start + 1,
        colorKey: c.id,
        tone: colors[c.id] ?? tones[c.id] ?? 0,
        muted: week > 0 && !c.weeks.contains(week),
        weeks: c.weeks,
        arrangements: [
          CourseArrangement(room: room, teachers: [], weeks: c.weeks),
        ],
        source: 'manual',
      ),
    );
  }
  return result;
}

List<CourseArrangement> _arrangements(
  List<CourseActivity> activities,
  ScheduleOrder order,
) {
  final result = <String, CourseArrangement>{};
  for (final a in activities) {
    var next = CourseArrangement(
      room: a.room.isEmpty ? '地点待定' : a.room,
      teachers: _strings(a.teachers),
      weeks: _numbers(a.weeks),
      startTime: a.startTime.trim(),
      endTime: a.endTime.trim(),
      activityType: a.activityType.trim(),
      projectName: a.projectName.trim(),
    );
    final key = _signature([next.withWeeks([])]);
    final previous = result[key];
    if (previous != null) {
      next = next.withWeeks(
        previous.weeks.isEmpty || next.weeks.isEmpty
            ? []
            : _numbers([...previous.weeks, ...next.weeks]),
      );
    }
    result[key] = next;
  }
  final values = result.values.toList();
  mergeSort(
    values,
    compare: (a, b) {
      final week = (a.weeks.firstOrNull ?? 0) - (b.weeks.firstOrNull ?? 0);
      if (week != 0) return week;
      final room = order.standard(a.room, b.room);
      return room != 0
          ? room
          : order.standard(
              a.teachers.join('\u0000'),
              b.teachers.join('\u0000'),
            );
    },
  );
  return values;
}

String _signature(List<CourseArrangement> values) => values
    .map(
      (a) =>
          '${a.room}\u0000${a.teachers.join('\u0000')}\u0000${a.weeks.join(',')}\u0000${a.startTime}\u0000${a.endTime}\u0000${a.activityType}\u0000${a.projectName}',
    )
    .join('\u0001');
String _activeSignature(CourseBlock block, int week) {
  final values =
      block.arrangements
          .where((a) => a.activeIn(week))
          .map((a) {
            final teachers = [...a.teachers]..sort();
            return _signature([
              CourseArrangement(
                room: a.room.trim(),
                teachers: teachers,
                weeks: [],
                startTime: a.activityType.contains('实验') ? a.startTime : '',
                endTime: a.activityType.contains('实验') ? a.endTime : '',
                activityType: a.activityType,
                projectName: a.projectName,
              ),
            ]);
          })
          .toSet()
          .toList()
        ..sort();
  return values.join('\u0001');
}

bool _overlap(CourseBlock a, CourseBlock b) =>
    a.day == b.day && a.start <= b.end && b.start <= a.end;
bool _continuous(CourseBlock a, CourseBlock b, int week) =>
    a.source == 'jwxt' &&
    b.source == 'jwxt' &&
    a.colorKey == b.colorKey &&
    a.name == b.name &&
    a.day == b.day &&
    a.end + 1 == b.start &&
    _activeSignature(a, week) == _activeSignature(b, week);
List<List<CourseBlock>> _exactGroups(List<CourseBlock> blocks) {
  final groups = <String, List<CourseBlock>>{};
  for (final b in blocks) {
    groups.putIfAbsent('${b.day}-${b.start}-${b.span}', () => []).add(b);
  }
  return groups.values.toList();
}

CourseBlock _primary(List<CourseBlock> group, int week) =>
    group.firstWhereOrNull((b) => !b.muted) ??
    group.reduce(
      (a, b) => _distance(b.weeks, week) < _distance(a.weeks, week) ? b : a,
    );

/// 原版显示规则：活动课重叠或相邻同课合并；非本周课附在详情中，避免遮住活动课。
List<CourseBlock> groupCourseBlocks(
  List<CourseBlock> blocks,
  int week,
  ScheduleOrder order,
) {
  var groups = <List<CourseBlock>>[];
  if (week <= 0) {
    groups = _exactGroups(blocks);
  } else {
    final active = blocks.where((b) => !b.muted).toList();
    mergeSort(
      active,
      compare: (a, b) {
        if (a.day != b.day) return a.day - b.day;
        if (a.start != b.start) return a.start - b.start;
        if (a.span != b.span) return a.span - b.span;
        return order.standard(a.name, b.name);
      },
    );
    for (final b in active) {
      final connected = groups
          .where((g) => g.any((a) => _overlap(a, b) || _continuous(a, b, week)))
          .toList();
      if (connected.isEmpty) {
        groups.add([b]);
        continue;
      }
      connected.first.add(b);
      for (final g in connected.skip(1)) {
        connected.first.addAll(g);
        groups.remove(g);
      }
    }
    final inactive = <CourseBlock>[];
    for (final b in blocks.where((b) => b.muted)) {
      final group = groups.firstWhereOrNull(
        (g) => g.any((a) => _overlap(a, b)),
      );
      if (group == null) {
        inactive.add(b);
      } else {
        group.add(b);
      }
    }
    final candidates = _exactGroups(inactive);
    mergeSort(
      candidates,
      compare: (ga, gb) {
        final a = _primary(ga, week), b = _primary(gb, week);
        final distance = _distance(a.weeks, week) - _distance(b.weeks, week);
        if (distance != 0) return distance;
        if (a.span != b.span) return a.span - b.span;
        if (a.day != b.day) return a.day - b.day;
        if (a.start != b.start) return a.start - b.start;
        return order.standard(a.name, b.name);
      },
    );
    final selected = <List<CourseBlock>>[];
    for (final group in candidates) {
      if (!selected.any(
        (g) => _overlap(_primary(g, week), _primary(group, week)),
      )) {
        selected.add(group);
      }
    }
    groups.addAll(selected);
  }
  final result = groups.map((group) {
    if (group.length == 1) return group.first.copyWith(courses: [group.first]);
    final primary = _primary(group, week);
    final active = group.where((b) => !b.muted).toList();
    final geometry = active.isEmpty ? [primary] : active;
    final start = geometry.map((b) => b.start).reduce(math.min);
    final end = geometry.map((b) => b.end).reduce(math.max);
    final courses = [...group];
    mergeSort(
      courses,
      compare: (a, b) {
        if (a.muted != b.muted) return a.muted ? 1 : -1;
        final week = (a.weeks.firstOrNull ?? 0) - (b.weeks.firstOrNull ?? 0);
        return week != 0 ? week : order.standard(a.name, b.name);
      },
    );
    final ids = courses.map((b) => b.id).toList()..sort();
    return primary.copyWith(
      id: 'slot-${primary.day}-$start-${end - start + 1}-${ids.join('|')}',
      start: start,
      span: end - start + 1,
      courses: courses,
      conflict: active.map((b) => b.colorKey).toSet().length > 1,
    );
  }).toList();
  mergeSort(
    result,
    compare: (a, b) => a.muted == b.muted
        ? 0
        : a.muted
        ? 1
        : -1,
  );
  return result;
}
