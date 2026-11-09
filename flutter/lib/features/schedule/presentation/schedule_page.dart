import 'dart:async';
import 'dart:ui';

import 'package:chengxin_youyou/features/session/session.dart';
import 'package:flutter/material.dart';

import '../../../ui/components/page_menu.dart';

import '../models/course_block.dart';
import '../models/semester.dart';
import '../platform/system_calendar.dart';
import 'schedule_view_model.dart';
import 'widgets/calendar_export_sheet.dart';
import 'widgets/course_detail_sheet.dart';
import 'widgets/course_editor_sheet.dart';
import 'widgets/course_grid.dart';
import 'widgets/hamster_loader.dart';
import 'widgets/schedule_header.dart';
import 'widgets/schedule_sheet.dart';
import 'widgets/schedule_week_strip.dart';

class SchedulePage extends StatefulWidget {
  const SchedulePage({
    super.key,
    required this.viewModel,
    required this.student,
    required this.isDemo,
    required this.isOffline,
  });
  final ScheduleViewModel viewModel;
  final Student student;
  final bool isDemo, isOffline;
  @override
  State<SchedulePage> createState() => _SchedulePageState();
}

class _SchedulePageState extends State<SchedulePage>
    with WidgetsBindingObserver {
  final _weekAnchor = GlobalKey(), _moreAnchor = GlobalKey();
  PageController? _pageController;
  bool _switching = false;
  bool _weekPageSyncScheduled = false;
  int _lastWeek = 1;
  String? _lastSemesterId;
  ScheduleViewModel get vm => widget.viewModel;

  // 延迟创建，兼容热重载时 State 不会重新执行 initState 的情况。
  PageController get _weekPageController =>
      _pageController ??= PageController(initialPage: vm.selectedWeek - 1);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _lastWeek = vm.selectedWeek;
    _lastSemesterId = vm.selectedSemester?.id;
    vm.addListener(_handleViewModelChanged);
    _scheduleWeekPageSync();
  }

  @override
  void didUpdateWidget(covariant SchedulePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.viewModel == widget.viewModel) return;
    oldWidget.viewModel.removeListener(_handleViewModelChanged);
    _lastWeek = vm.selectedWeek;
    _lastSemesterId = vm.selectedSemester?.id;
    vm.addListener(_handleViewModelChanged);
    _scheduleWeekPageSync();
  }

  @override
  void dispose() {
    vm.removeListener(_handleViewModelChanged);
    _pageController?.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) vm.resetWeekSelection();
  }

  Future<void> _edit([CourseBlock? course]) async {
    final saved = await showScheduleSheet<bool>(
      context,
      CourseEditorSheet(vm: vm, course: course),
    );
    if (saved == true && mounted) _notice(course == null ? '课程已添加' : '课程已修改');
  }

  Future<void> _detail(CourseBlock course) async {
    final edit = await showScheduleSheet<CourseBlock>(
      context,
      CourseDetailSheet(course: course, vm: vm),
      floating: true,
    );
    if (edit != null && mounted) await _edit(edit);
  }

  void _notice(String text) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text),
        duration: const Duration(milliseconds: 1800),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.fromLTRB(24, 0, 24, 108),
      ),
    );
  }

  Future<void> _refresh() async {
    await vm.refresh();
    if (!mounted) return;
    _notice(vm.error ?? (vm.weekError == null ? '课表已更新' : '课表已更新，教学周暂时不可用'));
  }

  Future<void> _switchSemester(Semester semester) async {
    if (semester.id == vm.selectedSemester?.id) return;
    setState(() => _switching = true);
    await Future.wait([
      vm.selectSemester(semester),
      Future<void>.delayed(const Duration(milliseconds: 420)),
    ]);
    if (mounted) {
      setState(() => _switching = false);
      _notice(vm.error ?? '已切换至 ${semester.label}');
    }
  }

  Future<void> _chooseWeek() async {
    final week = await showPagePopover<int>(
      context,
      anchor: _weekAnchor,
      builder: (dialog) => ListView(
        padding: const EdgeInsets.all(6),
        shrinkWrap: true,
        children: [
          for (var week = 1; week <= vm.weekCount; week++)
            ListTile(
              key: ValueKey('week-option-$week'),
              dense: true,
              selected: week == vm.selectedWeek,
              selectedTileColor: Colors.blue.withValues(alpha: .10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              title: Text('第 $week 周'),
              trailing: week == vm.selectedWeek
                  ? const Icon(Icons.check, size: 18)
                  : null,
              onTap: () => Navigator.pop(dialog, week),
            ),
        ],
      ),
      width: 190,
    );
    if (week != null && mounted && week != vm.selectedWeek) {
      await _goToWeek(week);
    }
  }

  Future<void> _more() async {
    final action = await showPagePopover<String>(
      context,
      anchor: _moreAnchor,
      glass: true,
      builder: (dialog) => ListenableBuilder(
        listenable: vm,
        builder: (context, _) => SingleChildScrollView(
          padding: const EdgeInsets.all(8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                dense: true,
                title: const Text(
                  '切换学期',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
                subtitle: Text(
                  vm.selectedSemester?.label ?? '请选择学期',
                  style: const TextStyle(fontSize: 13),
                ),
                trailing: const Icon(Icons.unfold_more, size: 18),
                onTap: () => Navigator.pop(dialog, 'semester'),
              ),
              const Divider(height: 1),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text('非本周透明度', style: TextStyle(fontSize: 13)),
                    ),
                    Text(
                      '${(vm.local.opacity * 100).round()}%',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ),
              SizedBox(
                height: 32,
                child: Slider(
                  value: vm.local.opacity,
                  min: 0,
                  max: 1,
                  divisions: 20,
                  label: '${(vm.local.opacity * 100).round()}%',
                  onChanged: (v) => unawaited(vm.setOpacity(v)),
                ),
              ),
              const Padding(
                padding: EdgeInsets.fromLTRB(10, 0, 10, 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '更淡',
                      style: TextStyle(fontSize: 10, color: Colors.grey),
                    ),
                    Text(
                      '更清晰',
                      style: TextStyle(fontSize: 10, color: Colors.grey),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              ListTile(
                dense: true,
                leading: const Icon(Icons.event_available_outlined, size: 19),
                title: const Text('导入系统日历', style: TextStyle(fontSize: 13)),
                subtitle: const Text(
                  '一键写入本机日历',
                  style: TextStyle(fontSize: 11),
                ),
                onTap: () => Navigator.pop(dialog, 'export'),
              ),
            ],
          ),
        ),
      ),
    );
    if (!mounted) return;
    if (action == 'semester') {
      final semester = await showPagePopover<Semester>(
        context,
        anchor: _moreAnchor,
        builder: (dialog) => ListView(
          padding: const EdgeInsets.all(6),
          shrinkWrap: true,
          children: [
            for (final semester in vm.semesters)
              ListTile(
                dense: true,
                title: Text(
                  semester.label,
                  style: const TextStyle(fontSize: 13),
                ),
                trailing: semester.id == vm.selectedSemester?.id
                    ? const Icon(Icons.check, size: 18)
                    : null,
                onTap: () => Navigator.pop(dialog, semester),
              ),
          ],
        ),
      );
      if (semester != null && mounted) await _switchSemester(semester);
    } else if (action == 'export') {
      final result = await showScheduleSheet<SystemCalendarResult>(
        context,
        CalendarExportSheet(vm: vm, campus: widget.student.campus),
      );
      if (result != null && mounted) {
        _notice(switch (result.status) {
          SystemCalendarStatus.imported => '已导入 ${result.eventCount} 个日程到系统日历',
          SystemCalendarStatus.shared => '课表文件已交给系统日历',
          SystemCalendarStatus.denied => result.message ?? '未获得日历权限',
          SystemCalendarStatus.failed => result.message ?? '导入系统日历失败',
        });
      }
    }
  }

  void _handleViewModelChanged() {
    final week = vm.selectedWeek;
    final semesterId = vm.selectedSemester?.id;
    final changed = week != _lastWeek || semesterId != _lastSemesterId;
    _lastWeek = week;
    _lastSemesterId = semesterId;
    if (changed) _scheduleWeekPageSync();
  }

  void _scheduleWeekPageSync() {
    if (_weekPageSyncScheduled) return;
    _weekPageSyncScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _weekPageSyncScheduled = false;
      if (!mounted || !_weekPageController.hasClients) return;
      final target = vm.selectedWeek - 1;
      if (_weekPageController.page?.round() != target) {
        _weekPageController.jumpToPage(target);
      }
    });
  }

  void _onWeekPageChanged(int index) {
    final week = index + 1;
    if (week != vm.selectedWeek) vm.selectWeek(week);
  }

  Future<void> _goToWeek(int week) async {
    if (!_weekPageController.hasClients) {
      vm.selectWeek(week);
      return;
    }
    final maxIndex = vm.weekCount - 1;
    final raw = week - 1;
    final target = raw < 0
        ? 0
        : raw > maxIndex
        ? maxIndex
        : raw;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    await _weekPageController.animateToPage(
      target,
      duration: reduceMotion
          ? Duration.zero
          : const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: vm,
    builder: (context, _) {
      final dark = Theme.of(context).brightness == Brightness.dark;
      final ink = dark ? const Color(0xfff2f2f7) : const Color(0xff101722);
      return MediaQuery.withClampedTextScaling(
        maxScaleFactor: 1,
        child: ColoredBox(
          color: dark ? const Color(0xff0f141c) : const Color(0xffc9d5e7),
          child: SafeArea(
            bottom: false,
            child: DefaultTextStyle(
              style: TextStyle(
                color: ink,
                fontFamily: Theme.of(context).textTheme.bodyMedium?.fontFamily,
              ),
              child: Column(
                children: [
                  ScheduleHeader(
                    vm: vm,
                    weekAnchor: _weekAnchor,
                    moreAnchor: _moreAnchor,
                    onWeek: _chooseWeek,
                    onMore: _more,
                    onAdd: () => _edit(),
                    onRefresh: _refresh,
                  ),
                  Expanded(
                    child: PageView.builder(
                      key: const ValueKey('schedule-week-pager'),
                      controller: _weekPageController,
                      physics: const PageScrollPhysics(
                        parent: BouncingScrollPhysics(),
                      ),
                      // 预构建相邻页，滑动到下一周时不用临时构建整张课表。
                      allowImplicitScrolling: true,
                      itemCount: vm.weekCount,
                      onPageChanged: _onWeekPageChanged,
                      itemBuilder: (context, index) => RepaintBoundary(
                        key: ValueKey('schedule-week-page-${index + 1}'),
                        child: _buildWeekBody(context, index + 1),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    },
  );

  Widget _buildWeekBody(BuildContext context, int week) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final muted = dark ? const Color(0xb8d1d1d6) : const Color(0x9426343d);
    return Column(
      key: ValueKey(week),
      children: [
        ScheduleWeekStrip(
          vm: vm,
          week: week,
          date: vm.dateForWeek(week),
          onDayTap: week == vm.selectedWeek ? vm.selectDay : null,
        ),
        Expanded(
          child: Stack(
            children: [
              if (vm.selectedSemester != null)
                CourseGrid(
                  blocks: vm.visibleEntriesFor(week),
                  semester: vm.selectedSemester!,
                  campus: widget.student.campus,
                  rowCount: vm.sectionCountFor(week),
                  opacity: vm.local.opacity,
                  onCourse: _detail,
                ),
              if (vm.isLoading && !vm.hasData)
                const Center(child: HamsterLoader(label: '正在同步课表…')),
              if (!vm.isLoading && !vm.hasData)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.all(28),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          vm.error == null ? '暂无可用学期' : '课表加载失败',
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          vm.error ?? '教务系统暂未返回学期信息。',
                          textAlign: TextAlign.center,
                        ),
                        TextButton(
                          onPressed: vm.retry,
                          child: const Text('重新加载'),
                        ),
                      ],
                    ),
                  ),
                ),
              if (_switching)
                Positioned.fill(
                  child: ClipRect(
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 4, sigmaY: 4),
                      child: ColoredBox(
                        color: Colors.white.withValues(alpha: .12),
                        child: const Center(
                          child: HamsterLoader(label: '正在切换学期…'),
                        ),
                      ),
                    ),
                  ),
                ),
              // 演示标记不改变网格密度，避免把虚拟数据误认为真实教务数据。
              if (widget.isDemo)
                Positioned(
                  right: 10,
                  bottom: 112,
                  child: IgnorePointer(
                    child: Text(
                      '演示模式',
                      style: TextStyle(color: muted, fontSize: 10),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
