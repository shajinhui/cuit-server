import 'package:chengxin_youyou/core/network/api_client.dart';
import 'package:chengxin_youyou/core/network/api_exception.dart';
import 'package:chengxin_youyou/features/schedule/models/semester.dart';
import 'package:flutter/material.dart';

import '../../../ui/components/page_selection.dart';
import '../../../ui/components/page_sheet.dart';

import 'tool_page_scaffold.dart';

import 'academic_tool_widgets.dart';

class ClassroomsPage extends StatefulWidget {
  const ClassroomsPage({super.key, required this.api});
  final ApiClient? api;
  @override
  State<ClassroomsPage> createState() => _ClassroomsPageState();
}

class _ClassroomsPageState extends State<ClassroomsPage> {
  List<Semester> _semesters = [];
  List<Map<String, dynamic>> _campuses = [];
  List<Map<String, dynamic>> _buildings = [];
  List<Map<String, dynamic>> _types = [];
  List<Map<String, dynamic>> _rooms = [];
  String? _semesterId;
  String _campusId = '';
  String _buildingId = '';
  String _typeId = '';
  int? _minCapacity;
  int _week = 1;
  int _weekday = DateTime.now().weekday;
  final Set<int> _sections = {1, 2};
  String? _error;
  bool _loading = true;
  bool _searched = false;
  String _resultContext = '';

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final semesters = await loadAcademicSemesters(widget.api);
      final semester = semesters.any((item) => item.id == _semesterId)
          ? semesters.firstWhere((item) => item.id == _semesterId)
          : preferredAcademicSemester(semesters);
      if (semester == null) {
        setState(() {
          _semesters = semesters;
          _loading = false;
        });
        return;
      }
      int? currentWeek;
      try {
        final week = await widget.api!.request('/api/v1/schedule/current-week');
        if (week is Map && week['CurrentWeek'] is num) {
          currentWeek = (week['CurrentWeek'] as num).toInt();
        }
      } catch (_) {
        // 学期接口仍可用时，当前周获取失败不阻止手动查询。
      }
      final options = await _loadOptions(semester.id, _campusId);
      final campuses = (options['Campuses'] as List? ?? const [])
          .cast<Map<String, dynamic>>();
      final selectedCampus =
          campuses.any((item) => '${item['ID']}' == _campusId)
          ? _campusId
          : (campuses.isEmpty ? '' : '${campuses.first['ID']}');
      final resolvedOptions = selectedCampus == _campusId
          ? options
          : await _loadOptions(semester.id, selectedCampus);
      if (!mounted) return;
      setState(() {
        _semesters = semesters;
        _semesterId = semester.id;
        _campuses = campuses;
        _campusId = selectedCampus;
        _week = semester.isCurrent && currentWeek != null && currentWeek > 0
            ? currentWeek
            : 1;
        _buildings = (resolvedOptions['Buildings'] as List? ?? const [])
            .cast<Map<String, dynamic>>();
        _types = (resolvedOptions['ClassroomTypes'] as List? ?? const [])
            .cast<Map<String, dynamic>>();
        _loading = false;
      });
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = academicErrorMessage(error);
          _loading = false;
        });
      }
    }
  }

  Future<Map<String, dynamic>> _loadOptions(
    String semester,
    String campus,
  ) async {
    final raw = await widget.api!.request(
      '/api/v1/jwxt/classroom-options',
      query: {
        'semester_id': semester,
        if (campus.isNotEmpty) 'campus_id': campus,
      },
    );
    if (raw is! Map<String, dynamic>) throw const ApiException('教室筛选项格式异常。');
    return raw;
  }

  Future<void> _changeSemester(String value) async {
    setState(() {
      _semesterId = value;
      _campusId = '';
      _buildingId = '';
      _typeId = '';
      _rooms = [];
      _searched = false;
      _loading = true;
    });
    await _initialize();
  }

  Future<void> _changeCampus(String value) async {
    setState(() {
      _campusId = value;
      _buildingId = '';
      _typeId = '';
      _rooms = [];
      _searched = false;
      _loading = true;
    });
    try {
      final options = await _loadOptions(_semesterId!, value);
      if (mounted) {
        setState(() {
          _buildings = (options['Buildings'] as List? ?? const [])
              .cast<Map<String, dynamic>>();
          _types = (options['ClassroomTypes'] as List? ?? const [])
              .cast<Map<String, dynamic>>();
          _loading = false;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = academicErrorMessage(error);
          _loading = false;
        });
      }
    }
  }

  Future<void> _search() async {
    if (_semesterId == null || _campusId.isEmpty || _sections.isEmpty) {
      setState(() => _error = '请选择校区并至少选择一组节次。');
      return;
    }
    setState(() {
      _loading = true;
      _searched = true;
      _error = null;
      // 结果描述保存查询时的条件，修改筛选后不会给旧结果贴上新条件。
      _resultContext =
          '$_filterSummary · ${(_sections.toList()..sort()).join('、')} 节';
    });
    try {
      final raw = await widget.api!.request(
        '/api/v1/jwxt/available-classrooms',
        query: {
          'semester_id': _semesterId,
          'week': '$_week',
          'weekday': '$_weekday',
          'sections': (_sections.toList()..sort()).join(','),
          'campus_id': _campusId,
          if (_buildingId.isNotEmpty) 'building_id': _buildingId,
          if (_typeId.isNotEmpty) 'classroom_type_id': _typeId,
          if (_minCapacity != null) 'min_capacity': '$_minCapacity',
        },
      );
      if (raw is! List) throw const ApiException('空教室结果格式异常。');
      if (mounted) {
        setState(() {
          _rooms = raw.cast<Map<String, dynamic>>();
          _loading = false;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = academicErrorMessage(error);
          _loading = false;
        });
      }
    }
  }

  String get _filterSummary {
    String selectedName(List<Map<String, dynamic>> values, String selected) {
      final matches = values.where((item) => '${item['ID']}' == selected);
      return matches.isEmpty ? '' : '${matches.first['Name'] ?? ''}';
    }

    return [
      selectedName(_campuses, _campusId),
      '第 $_week 周',
      '周${'一二三四五六日'[_weekday - 1]}',
      selectedName(_buildings, _buildingId),
      selectedName(_types, _typeId),
      if (_minCapacity != null) '$_minCapacity 人起',
    ].where((value) => value.isNotEmpty).join(' · ');
  }

  /// 原版把时间、校区和教室偏好收进底部弹层，首页只保留节次。
  Future<void> _showFilters() async {
    await showPageSheet<void>(
      context,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, updateSheet) {
          void change(VoidCallback update) {
            setState(update);
            updateSheet(() {});
          }

          Future<void> changeOptions(Future<void> Function() update) async {
            await update();
            if (context.mounted) updateSheet(() {});
          }

          return FractionallySizedBox(
            heightFactor: .9,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(22, 0, 14, 8),
                  child: Row(
                    children: [
                      const SizedBox(width: 48),
                      const Expanded(
                        child: Text(
                          '筛选条件',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('完成'),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(22, 8, 22, 32),
                    children: [
                      const Text(
                        '时间与校区',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (_semesters.isNotEmpty)
                        academicSemesterPicker(
                          semesters: _semesters,
                          selected: _semesterId,
                          onChanged: (value) =>
                              changeOptions(() => _changeSemester(value)),
                        ),
                      const SizedBox(height: 14),
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final week = _numberDropdown(
                            '教学周',
                            _week,
                            53,
                            (value) => change(() => _week = value),
                          );
                          final campus = _choiceDropdown(
                            '校区',
                            _campuses,
                            _campusId,
                            (value) =>
                                changeOptions(() => _changeCampus(value)),
                          );
                          if (constraints.maxWidth < 280 ||
                              MediaQuery.textScalerOf(context).scale(14) > 18) {
                            return Column(
                              children: [
                                week,
                                const SizedBox(height: 14),
                                campus,
                              ],
                            );
                          }
                          return Row(
                            children: [
                              Expanded(child: week),
                              const SizedBox(width: 12),
                              Expanded(child: campus),
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 14),
                      ToolField(
                        label: '星期',
                        child: LayoutBuilder(
                          builder: (context, constraints) => Wrap(
                            alignment: WrapAlignment.center,
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              for (var day = 1; day <= 7; day++)
                                SizedBox(
                                  width: (constraints.maxWidth - 24) / 4,
                                  child: ToolChoiceButton(
                                    label: '一二三四五六日'[day - 1],
                                    selected: _weekday == day,
                                    onPressed: () =>
                                        change(() => _weekday = day),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        '教室偏好',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _choiceDropdown(
                        '教学楼',
                        [
                          {'ID': '', 'Name': '全部教学楼'},
                          ..._buildings,
                        ],
                        _buildingId,
                        (value) => change(() => _buildingId = value),
                      ),
                      const SizedBox(height: 14),
                      _choiceDropdown(
                        '教室类型',
                        [
                          {'ID': '', 'Name': '全部类型'},
                          ..._types,
                        ],
                        _typeId,
                        (value) => change(() => _typeId = value),
                      ),
                      const SizedBox(height: 14),
                      ToolField(
                        label: '最低容量',
                        child: PageDropdownField<int?>(
                          value: _minCapacity,
                          values: const {
                            null: '不限',
                            20: '20 人以上',
                            40: '40 人以上',
                            60: '60 人以上',
                            100: '100 人以上',
                          },
                          onChanged: (value) =>
                              change(() => _minCapacity = value),
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        '教学楼、教室类型和最低容量可以留空。',
                        style: TextStyle(fontSize: 12),
                      ),
                      if (_loading) const LinearProgressIndicator(),
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
              ],
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final grouped = <String, List<Map<String, dynamic>>>{};
    for (final room in _rooms) {
      final building = '${room['Building'] ?? ''}'.trim();
      grouped
          .putIfAbsent(building.isEmpty ? '其他教学楼' : building, () => [])
          .add(room);
    }
    return ToolPageScaffold(
      title: '空教室',
      child: _loading && _semesters.isEmpty
          ? const ToolLoading(label: '正在准备查询条件…')
          : _error != null && _semesters.isEmpty
          ? ToolMessage(message: _error!, onRetry: _initialize)
          : _semesters.isEmpty
          ? const ToolMessage(message: '暂无可用学期。教务系统返回学期后即可查询空教室。')
          : ListView(
              padding: const EdgeInsets.fromLTRB(22, 16, 22, 32),
              children: [
                ToolCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const ToolField(label: '节次', child: SizedBox.shrink()),
                      LayoutBuilder(
                        builder: (context, constraints) => Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (var start = 1; start <= 11; start += 2)
                              SizedBox(
                                width: (constraints.maxWidth - 16) / 3,
                                child: ToolChoiceButton(
                                  label: '$start–${start + 1}',
                                  selected:
                                      _sections.contains(start) &&
                                      _sections.contains(start + 1),
                                  onPressed: _loading
                                      ? null
                                      : () => setState(() {
                                          if (_sections.contains(start) &&
                                              _sections.contains(start + 1)) {
                                            _sections
                                              ..remove(start)
                                              ..remove(start + 1);
                                          } else {
                                            _sections
                                              ..add(start)
                                              ..add(start + 1);
                                          }
                                        }),
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Divider(height: 1),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text(
                          '更多筛选',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        subtitle: Text(
                          _filterSummary,
                          style: const TextStyle(fontSize: 12),
                        ),
                        trailing: const Icon(
                          Icons.chevron_right_rounded,
                          size: 20,
                        ),
                        onTap: _loading ? null : _showFilters,
                      ),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: _loading ? null : _search,
                          child: Text(_loading ? '正在查询…' : '查询空教室'),
                        ),
                      ),
                      if (_error != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 10),
                          child: Text(
                            _error!,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                ToolSectionHeading(
                  title: _searched && !_loading
                      ? '找到 ${_rooms.length} 间'
                      : '查询结果',
                  subtitle: _searched ? _resultContext : null,
                ),
                const SizedBox(height: 14),
                if (_loading && _searched)
                  const Padding(
                    padding: EdgeInsets.all(24),
                    child: ToolLoading(label: '正在查询…'),
                  )
                else if (!_searched)
                  const AcademicEmptyCard(
                    text: '确认条件后开始查询',
                    detail: '选择节次，按需调整时间与校区。',
                  )
                else if (_rooms.isEmpty)
                  const AcademicEmptyCard(
                    text: '没有符合条件的空教室',
                    detail: '可以尝试取消教学楼、教室类型或最低容量限制。',
                  )
                else
                  for (final group in grouped.entries) ...[
                    ToolCard(
                      padding: EdgeInsets.zero,
                      child: Column(
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: ToolSectionHeading(
                              title: group.key,
                              titleSize: 15,
                              trailing: '${group.value.length} 间',
                            ),
                          ),
                          for (var i = 0; i < group.value.length; i++) ...[
                            if (i > 0)
                              const Padding(
                                padding: EdgeInsets.symmetric(horizontal: 16),
                                child: Divider(height: 1),
                              ),
                            Padding(
                              padding: const EdgeInsets.all(16),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          '${group.value[i]['Name'] ?? group.value[i]['Code'] ?? '教室'}',
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          '${group.value[i]['Type'] ?? '教室类型未提供'}',
                                          style: const TextStyle(fontSize: 12),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Text.rich(
                                    TextSpan(
                                      children: [
                                        TextSpan(
                                          text:
                                              '${group.value[i]['Capacity'] ?? '—'}',
                                          style: const TextStyle(
                                            fontSize: 22,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        const TextSpan(
                                          text: ' 人',
                                          style: TextStyle(fontSize: 12),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                  ],
              ],
            ),
    );
  }
}

Widget _choiceDropdown(
  String label,
  List<Map<String, dynamic>> values,
  String selected,
  ValueChanged<String> onChanged,
) => ToolField(
  label: label,
  child: PageDropdownField<String>(
    key: ValueKey('$label-$selected'),
    value: values.any((item) => '${item['ID']}' == selected)
        ? selected
        : (values.isEmpty ? null : '${values.first['ID']}'),
    values: {
      for (final item in values) '${item['ID']}': '${item['Name'] ?? ''}',
    },
    onChanged: (value) {
      if (value != null) onChanged(value);
    },
  ),
);

Widget _numberDropdown(
  String label,
  int value,
  int max,
  ValueChanged<int> onChanged,
) => ToolField(
  label: label,
  child: PageDropdownField<int>(
    key: ValueKey('$label-$value'),
    value: value.clamp(1, max),
    values: {for (var i = 1; i <= max; i++) i: '第 $i 周'},
    onChanged: (next) {
      if (next != null) onChanged(next);
    },
  ),
);
