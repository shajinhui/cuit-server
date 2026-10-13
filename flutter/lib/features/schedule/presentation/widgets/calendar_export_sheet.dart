import 'package:flutter/material.dart';

import '../../../../ui/components/page_selection.dart';

import '../../models/calendar_export.dart';
import '../../platform/share_calendar.dart';
import '../schedule_view_model.dart';
import 'schedule_sheet.dart';

class CalendarExportSheet extends StatefulWidget {
  const CalendarExportSheet({
    super.key,
    required this.vm,
    required this.campus,
  });
  final ScheduleViewModel vm;
  final String campus;
  @override
  State<CalendarExportSheet> createState() => _CalendarExportSheetState();
}

class _CalendarExportSheetState extends State<CalendarExportSheet> {
  int _reminder = 10;
  bool _busy = false;
  String? _error;
  CalendarExport? _export;
  @override
  void initState() {
    super.initState();
    _prepare();
  }

  void _prepare() {
    try {
      final semester = widget.vm.selectedSemester,
          table = widget.vm.snapshot?.table;
      if (semester == null || table == null) {
        throw const FormatException('当前学期没有可以导入的课程');
      }
      _export = createCalendarExport(
        calendar: widget.vm.calendar,
        order: widget.vm.order,
        semester: semester,
        table: table,
        manual: widget.vm.manualCourses,
        overrides: widget.vm.overrides,
        campus: widget.campus,
        reminderMinutes: _reminder,
      );
      _error = null;
    } catch (error) {
      _export = null;
      _error = error is FormatException ? error.message : '生成日历失败，请重试';
    }
  }

  Future<void> _share() async {
    if (_busy || _export == null) return;
    final box = context.findRenderObject() as RenderBox;
    final origin = box.localToGlobal(Offset.zero) & box.size;
    setState(() => _busy = true);
    try {
      final shared = await shareCalendar(_export!, origin);
      if (mounted) Navigator.pop(context, shared);
    } catch (_) {
      if (mounted) setState(() => _error = '无法打开系统分享面板，请重试');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final blue = dark ? const Color(0xff409cff) : const Color(0xff0878e8);
    final group = dark
        ? const Color(0xff1c1c1e).withValues(alpha: .62)
        : Colors.white.withValues(alpha: .62);
    return PopScope(
      canPop: !_busy,
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
                      onPressed: _busy ? null : () => Navigator.pop(context),
                      child: const Text('取消'),
                    ),
                    const Expanded(
                      child: Text(
                        '导入系统日历',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 64),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      constraints: const BoxConstraints(minHeight: 92),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: group,
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: blue.withValues(alpha: dark ? .16 : .09),
                              borderRadius: BorderRadius.circular(15),
                            ),
                            child: Icon(
                              Icons.event_available_outlined,
                              size: 27,
                              color: blue,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  widget.vm.selectedSemester?.label ?? '请选择学期',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  '共 ${_export?.courseCount ?? 0} 门课程，生成 ${_export?.eventCount ?? 0} 个上课日程',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: Colors.grey,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    Container(
                      constraints: const BoxConstraints(minHeight: 56),
                      padding: const EdgeInsets.symmetric(
                        vertical: 4,
                        horizontal: 12,
                      ),
                      decoration: BoxDecoration(
                        color: group,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        children: [
                          const Expanded(
                            child: Text(
                              '上课提醒',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          PageDropdown<int>(
                            value: _reminder,
                            style: TextStyle(
                              fontSize: 15,
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                            values: {
                              for (final n in [0, 5, 10, 15, 30])
                                n: n == 0 ? '不提醒' : '提前 $n 分钟',
                            },
                            onChanged: _busy
                                ? null
                                : (v) => setState(() {
                                    _reminder = v!;
                                    _prepare();
                                  }),
                          ),
                        ],
                      ),
                    ),
                    if (_error != null)
                      Text(
                        _error!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    const Padding(
                      padding: EdgeInsets.symmetric(
                        vertical: 11,
                        horizontal: 4,
                      ),
                      child: Text(
                        '将包含教务课程、手动课程和本机修改。系统日历会在下一步让你确认导入。',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12,
                          height: 1.5,
                          color: Colors.grey,
                        ),
                      ),
                    ),
                    FilledButton(
                      key: const Key('export-calendar'),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(50),
                        backgroundColor: blue,
                        textStyle: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                      ),
                      onPressed: _busy || _export == null ? null : _share,
                      child: Text(_busy ? '正在生成…' : '生成并导入'),
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
}
