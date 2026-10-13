import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../ui/components/page_selection.dart';

import '../../models/course_block.dart';
import '../../models/local_course.dart';
import '../schedule_view_model.dart';
import 'schedule_sheet.dart';

class CourseEditorSheet extends StatefulWidget {
  const CourseEditorSheet({super.key, required this.vm, this.course});
  final ScheduleViewModel vm;
  final CourseBlock? course;
  @override
  State<CourseEditorSheet> createState() => _CourseEditorSheetState();
}

class _CourseEditorSheetState extends State<CourseEditorSheet> {
  late final TextEditingController _name = TextEditingController(
    text: widget.course?.name ?? '',
  );
  late final TextEditingController _room = TextEditingController(
    text: widget.course?.room == '地点待定' ? '' : widget.course?.room ?? '',
  );
  late int _day = widget.course?.day ?? widget.vm.selectedDate.weekday;
  late int _start = widget.course?.start ?? 1, _end = widget.course?.end ?? 2;
  late int _firstWeek = widget.course?.weeks.firstOrNull ?? 1;
  late int _lastWeek = widget.course?.weeks.lastOrNull ?? widget.vm.weekCount;
  late WeekRepeat _repeat = _initialRepeat();
  bool _weeksChanged = false, _saving = false;
  String? _error;
  WeekRepeat _initialRepeat() {
    final weeks = widget.course?.weeks ?? [];
    if (weeks.isNotEmpty && weeks.every((w) => w.isOdd)) return WeekRepeat.odd;
    if (weeks.isNotEmpty && weeks.every((w) => w.isEven)) {
      return WeekRepeat.even;
    }
    return WeekRepeat.weekly;
  }

  @override
  void dispose() {
    _name.dispose();
    _room.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final course = widget.course;
      final weeks = course != null && !_weeksChanged
          ? course.weeks
          : expandWeeks(_firstWeek, _lastWeek, _repeat);
      final id =
          course?.id ?? 'manual-${DateTime.now().microsecondsSinceEpoch}';
      await widget.vm.saveCourse(
        LocalCourse(
          id: id,
          targetId: course != null && !course.isManual ? id : null,
          semesterId: widget.vm.selectedSemester?.id ?? '',
          name: _name.text.trim(),
          room: _room.text.trim(),
          day: _day,
          start: _start,
          end: _end,
          weeks: weeks,
        ),
      );
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = error is FormatException ? error.message : '保存失败，请重试',
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final sections = math.max(
      math.max(widget.vm.snapshot?.table.sectionsPerDay ?? 11, 11),
      _end,
    );
    final weeks = math.max(widget.vm.weekCount, _lastWeek);
    final sectionOptions = {for (var n = 1; n <= sections; n++) n: '第 $n 节'};
    final weekOptions = {for (var n = 1; n <= weeks; n++) n: '第 $n 周'};
    return PopScope(
      canPop: !_saving,
      child: SingleChildScrollView(
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SheetHandle(),
              SizedBox(
                height: 52,
                child: Row(
                  children: [
                    TextButton(
                      onPressed: _saving ? null : () => Navigator.pop(context),
                      child: const Text('取消'),
                    ),
                    Expanded(
                      child: Text(
                        widget.course == null ? '添加课程' : '修改课程',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    TextButton(
                      key: const Key('save-course'),
                      onPressed: _saving ? null : _save,
                      child: Text(
                        _saving
                            ? '保存中'
                            : widget.course == null
                            ? '添加'
                            : '保存',
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 18),
                child: Column(
                  children: [
                    _group([
                      _input('课程名称', _name, '例如：高等数学', 'course-name', 40),
                      _input('上课地点', _room, '选填', 'course-room', 30),
                    ]),
                    _group([
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Row(
                          children: [
                            const Expanded(
                              child: Text(
                                '星期',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            _select('星期', _day, {
                              for (var d = 1; d <= 7; d++)
                                d: '周${'一二三四五六日'[d - 1]}',
                            }, (v) => setState(() => _day = v)),
                          ],
                        ),
                      ),
                      Row(
                        children: [
                          _split(
                            '开始节次',
                            _select(
                              '开始节次',
                              _start,
                              sectionOptions,
                              (v) => setState(() => _start = v),
                            ),
                          ),
                          _split(
                            '结束节次',
                            _select(
                              '结束节次',
                              _end,
                              sectionOptions,
                              (v) => setState(() => _end = v),
                            ),
                          ),
                        ],
                      ),
                    ]),
                    _group([
                      Row(
                        children: [
                          _split(
                            '开始周',
                            _select(
                              '开始周',
                              _firstWeek,
                              weekOptions,
                              (v) => setState(() {
                                _firstWeek = v;
                                _weeksChanged = true;
                              }),
                            ),
                          ),
                          _split(
                            '结束周',
                            _select(
                              '结束周',
                              _lastWeek,
                              weekOptions,
                              (v) => setState(() {
                                _lastWeek = v;
                                _weeksChanged = true;
                              }),
                            ),
                          ),
                        ],
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(10, 9, 10, 10),
                        child: Row(
                          children: [
                            for (final item in {
                              WeekRepeat.weekly: '每周',
                              WeekRepeat.odd: '单周',
                              WeekRepeat.even: '双周',
                            }.entries)
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 1,
                                  ),
                                  child: InkWell(
                                    onTap: _saving
                                        ? null
                                        : () => setState(() {
                                            _repeat = item.key;
                                            _weeksChanged = true;
                                          }),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 9,
                                      ),
                                      decoration: BoxDecoration(
                                        color: _repeat == item.key
                                            ? const Color(0xffdce8f6)
                                            : Colors.transparent,
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Text(
                                        item.value,
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: _repeat == item.key
                                              ? const Color(0xff33699d)
                                              : null,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ]),
                    if (_error != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Text(
                          _error!,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ),
                    Text(
                      widget.course == null
                          ? '手动课程仅保存在本机，不会修改教务系统课表。'
                          : '课程修改仅保存在本机，不会改动教务系统课表。',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _group(List<Widget> children) => Container(
    margin: const EdgeInsets.only(bottom: 14),
    decoration: BoxDecoration(
      color: Theme.of(context).brightness == Brightness.dark
          ? const Color(0xff2d3036)
          : Colors.white.withValues(alpha: .7),
      borderRadius: BorderRadius.circular(16),
    ),
    child: Column(children: children),
  );

  Widget _input(
    String label,
    TextEditingController controller,
    String hint,
    String key,
    int limit,
  ) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 12),
    child: Row(
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: TextField(
            key: ValueKey(key),
            controller: controller,
            maxLength: limit,
            enabled: !_saving,
            textAlign: TextAlign.right,
            style: const TextStyle(fontSize: 15),
            decoration: InputDecoration(
              hintText: hint,
              counterText: '',
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              filled: false,
              contentPadding: const EdgeInsets.symmetric(vertical: 16),
            ),
          ),
        ),
      ],
    ),
  );

  Widget _split(String label, Widget field) => Expanded(
    child: Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
          ),
          field,
        ],
      ),
    ),
  );

  Widget _select<T>(
    String label,
    T value,
    Map<T, String> options,
    ValueChanged<T> change,
  ) => PageDropdown<T>(
    key: ValueKey(label),
    value: value,
    // 两列的节次、周次选择占满各自列宽，大字体下不按最长选项撑宽。
    expanded: label != '星期',
    semanticLabel: label,
    style: TextStyle(
      fontSize: 15,
      color: Theme.of(context).colorScheme.onSurface,
    ),
    iconSize: 16,
    values: options,
    onChanged: _saving
        ? null
        : (v) {
            if (v != null) change(v);
          },
  );
}
