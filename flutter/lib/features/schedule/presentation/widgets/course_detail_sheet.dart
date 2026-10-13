import 'package:flutter/material.dart';

import '../../models/course_block.dart';
import '../schedule_view_model.dart';
import 'course_palette.dart';

class CourseDetailSheet extends StatefulWidget {
  const CourseDetailSheet({super.key, required this.course, required this.vm});
  final CourseBlock course;
  final ScheduleViewModel vm;
  @override
  State<CourseDetailSheet> createState() => _CourseDetailSheetState();
}

class _CourseDetailSheetState extends State<CourseDetailSheet> {
  String? _expanded, _error;
  CourseBlock? _pendingRemoval;
  bool _busy = false;
  Future<void> _setColor(CourseBlock course, int? tone) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.vm.setColor(course.colorKey, tone);
    } catch (_) {
      if (mounted) setState(() => _error = '保存颜色失败，请重试');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _remove() async {
    final course = _pendingRemoval;
    if (course == null) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.vm.deleteCourse(course);
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) setState(() => _error = '删除失败，请重试');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.vm,
    builder: (context, _) {
      final dark = Theme.of(context).brightness == Brightness.dark;
      final ink = dark ? const Color(0xffd1d1d6) : const Color(0xff26343d);
      final editStyle = FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(44),
        backgroundColor: const Color(
          0xff787880,
        ).withValues(alpha: dark ? .24 : .12),
        foregroundColor: ink,
        textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
      );
      final course =
          widget.vm.visibleEntries
              .where((b) => b.id == widget.course.id)
              .firstOrNull ??
          widget.course;
      final entries = course.entries;
      final colors = {for (final e in entries) e.colorKey: e}.values;
      final preferences =
          widget.vm.local.colors[widget.vm.selectedSemester?.id] ?? {};
      final details = <String, String>{'上课时间': formatCourseTime(course)};
      if (entries.length > 1) {
        details['课程安排'] = entries
            .map(
              (e) =>
                  '${e.name} · ${formatCourseTime(e)}\n${e.arrangements.map(formatArrangement).join('；')}${e.teachers.isEmpty ? '' : ' · ${e.teachers.join('、')}'}',
            )
            .join('\n\n');
      } else {
        if (course.arrangements.length > 1) {
          details['上课安排'] = course.arrangements
              .map(formatArrangement)
              .join('\n');
        } else {
          details['上课地点'] = course.room;
          details['教学周'] = formatWeeks(course.weeks);
        }
        details['任课教师'] = course.teachers.isEmpty
            ? '教师待定'
            : course.teachers.join('、');
        if (course.code.isNotEmpty) details['课程代码'] = course.code;
        if (course.credits.isNotEmpty) details['学分'] = course.credits;
        if (course.teachingClass.isNotEmpty) {
          details['教学班'] = course.teachingClass;
        }
      }
      return PopScope(
        canPop: !_busy,
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 18, 12, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Row(
                    children: [
                      Container(
                        width: 11,
                        height: 42,
                        decoration: BoxDecoration(
                          color: course.color,
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                      const SizedBox(width: 11),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${entries.length > 1
                                  ? '时段详情'
                                  : course.isManual
                                  ? '本机添加'
                                  : '课程详情'}${course.conflict
                                  ? '  课程冲突'
                                  : course.muted
                                  ? '  非本周'
                                  : ''}',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              course.name,
                              style: const TextStyle(
                                fontSize: 21,
                                fontWeight: FontWeight.w700,
                                height: 1.3,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        style: IconButton.styleFrom(
                          minimumSize: const Size(34, 34),
                          maximumSize: const Size(34, 34),
                          padding: EdgeInsets.zero,
                          backgroundColor: const Color(
                            0xff787880,
                          ).withValues(alpha: dark ? .24 : .12),
                        ),
                        tooltip: '关闭课程详情',
                        onPressed: _busy ? null : () => Navigator.pop(context),
                        icon: const Icon(Icons.close_rounded, size: 16),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 17),
                _DetailGroup(
                  child: Column(
                    children: [
                      for (final row in details.entries)
                        Container(
                          constraints: const BoxConstraints(minHeight: 48),
                          margin: const EdgeInsets.symmetric(horizontal: 14),
                          padding: const EdgeInsets.symmetric(vertical: 11),
                          decoration: BoxDecoration(
                            border: Border(
                              top: BorderSide(
                                color: row.key == details.keys.first
                                    ? Colors.transparent
                                    : Colors.grey.withValues(alpha: .13),
                              ),
                            ),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Padding(
                                padding: const EdgeInsets.only(right: 10),
                                child: Text(
                                  row.key,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ),
                              Expanded(
                                child: Text(
                                  row.value,
                                  textAlign: TextAlign.right,
                                  style: TextStyle(
                                    color: ink,
                                    fontSize: 14,
                                    height: 1.4,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                _DetailGroup(
                  child: Column(
                    children: [
                      for (final entry in colors) ...[
                        InkWell(
                          onTap: _busy
                              ? null
                              : () => setState(
                                  () => _expanded = _expanded == entry.id
                                      ? null
                                      : entry.id,
                                ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              vertical: 10,
                              horizontal: 14,
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        '课程颜色',
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      Text(
                                        colors.length > 1
                                            ? entry.name
                                            : preferences.containsKey(
                                                entry.colorKey,
                                              )
                                            ? '自定义'
                                            : '自动分配',
                                        style: const TextStyle(
                                          fontSize: 11,
                                          color: Colors.grey,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  width: 22,
                                  height: 22,
                                  decoration: BoxDecoration(
                                    color: entry.color,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Icon(
                                  _expanded == entry.id
                                      ? Icons.keyboard_arrow_up
                                      : Icons.keyboard_arrow_down,
                                  size: 18,
                                ),
                              ],
                            ),
                          ),
                        ),
                        if (_expanded == entry.id) ...[
                          GridView.count(
                            crossAxisCount: 5,
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            childAspectRatio: 1.35,
                            children: [
                              for (
                                var tone = 0;
                                tone < courseToneColors.length;
                                tone++
                              )
                                Semantics(
                                  selected: preferences[entry.colorKey] == tone,
                                  child: IconButton(
                                    tooltip: courseToneLabels[tone],
                                    onPressed: _busy
                                        ? null
                                        : () => _setColor(entry, tone),
                                    icon: Container(
                                      width: 28,
                                      height: 28,
                                      decoration: BoxDecoration(
                                        color: courseToneColors[tone],
                                        shape: BoxShape.circle,
                                        border:
                                            preferences[entry.colorKey] == tone
                                            ? Border.all(
                                                color: Colors.white,
                                                width: 3,
                                              )
                                            : null,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          TextButton(
                            onPressed: _busy
                                ? null
                                : () => _setColor(entry, null),
                            child: const Text('自动分配'),
                          ),
                        ],
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                _DetailGroup(
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (_pendingRemoval == null) ...[
                          for (final entry in entries)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 6),
                              child: FilledButton(
                                style: editStyle,
                                onPressed: _busy
                                    ? null
                                    : () => Navigator.pop(context, entry),
                                child: Text(
                                  entries.length > 1
                                      ? '修改“${entry.name}”（${formatCourseTime(entry)}）'
                                      : '修改课程',
                                ),
                              ),
                            ),
                          for (final entry in entries.where((e) => e.isManual))
                            TextButton(
                              onPressed: _busy
                                  ? null
                                  : () =>
                                        setState(() => _pendingRemoval = entry),
                              style: TextButton.styleFrom(
                                minimumSize: const Size.fromHeight(44),
                                backgroundColor: const Color(
                                  0xffb64646,
                                ).withValues(alpha: .09),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(13),
                                ),
                              ),
                              child: Text(
                                entries.where((e) => e.isManual).length > 1
                                    ? '删除“${entry.name}”'
                                    : '删除本机课程',
                                style: const TextStyle(
                                  color: Color(0xffb64646),
                                ),
                              ),
                            ),
                        ] else ...[
                          Text(
                            '确定删除“${_pendingRemoval!.name}”吗？',
                            textAlign: TextAlign.center,
                          ),
                          const Text(
                            '删除后无法恢复。',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                          Row(
                            children: [
                              Expanded(
                                child: TextButton(
                                  onPressed: _busy
                                      ? null
                                      : () => setState(
                                          () => _pendingRemoval = null,
                                        ),
                                  child: const Text('取消'),
                                ),
                              ),
                              Expanded(
                                child: TextButton(
                                  onPressed: _busy ? null : _remove,
                                  child: Text(
                                    _busy ? '正在删除…' : '确认删除',
                                    style: const TextStyle(
                                      color: Color(0xffb64646),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                if (_error != null)
                  Text(
                    _error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

/// 详情里的信息、配色和操作共用原版圆角分组。
class _DetailGroup extends StatelessWidget {
  const _DetailGroup({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => Container(
    clipBehavior: Clip.antiAlias,
    decoration: BoxDecoration(
      color: Theme.of(context).brightness == Brightness.dark
          ? const Color(0xff1c1c1e).withValues(alpha: .62)
          : Colors.white.withValues(alpha: .62),
      borderRadius: BorderRadius.circular(18),
    ),
    child: child,
  );
}
