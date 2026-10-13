import 'package:chengxin_youyou/core/network/api_client.dart';
import 'package:chengxin_youyou/core/network/api_exception.dart';
import 'package:chengxin_youyou/features/schedule/models/semester.dart';
import 'package:flutter/material.dart';

import 'tool_page_scaffold.dart';

import 'academic_tool_widgets.dart';

class ExamsPage extends StatefulWidget {
  const ExamsPage({super.key, required this.api});
  final ApiClient? api;
  @override
  State<ExamsPage> createState() => _ExamsPageState();
}

class _ExamsPageState extends State<ExamsPage> {
  List<Semester> _semesters = [];
  String? _semesterId;
  String _type = 'final';
  List<Map<String, dynamic>> _exams = [];
  String? _error;
  bool _loading = true;

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
      final selected = semesters.any((item) => item.id == _semesterId)
          ? _semesterId
          : preferredAcademicSemester(semesters)?.id;
      if (selected == null) {
        setState(() {
          _semesters = semesters;
          _loading = false;
        });
        return;
      }
      final exams = await _fetchExams(selected, _type);
      if (mounted) {
        setState(() {
          _semesters = semesters;
          _semesterId = selected;
          _exams = exams;
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

  Future<List<Map<String, dynamic>>> _fetchExams(
    String semester,
    String type,
  ) async {
    final raw = await widget.api!.request(
      '/api/v1/jwxt/exams',
      query: {'semester_id': semester, 'exam_type': type},
    );
    if (raw is! List) throw const ApiException('考试数据格式异常。');
    return raw.cast<Map<String, dynamic>>();
  }

  Future<void> _update({String? semester, String? type}) async {
    final nextSemester = semester ?? _semesterId;
    final nextType = type ?? _type;
    if (nextSemester == null) return;
    setState(() {
      _semesterId = nextSemester;
      _type = nextType;
      _loading = true;
      _error = null;
    });
    try {
      final result = await _fetchExams(nextSemester, nextType);
      if (mounted) {
        setState(() {
          _exams = result;
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

  @override
  Widget build(BuildContext context) {
    final grouped = <String, List<Map<String, dynamic>>>{};
    for (final exam in _exams) {
      final date = '${exam['ExamDate'] ?? ''}'.trim();
      final time = '${exam['ExamTime'] ?? ''}'.trim();
      final pending =
          date.isEmpty ||
          time.isEmpty ||
          RegExp(r'未安排|待安排|暂无').hasMatch('$date $time');
      grouped.putIfAbsent(pending ? '待安排' : date, () => []).add(exam);
    }
    final dates = grouped.keys.where((date) => date != '待安排').toList()..sort();
    if (grouped.containsKey('待安排')) dates.add('待安排');
    final today = DateTime.now();
    final todayKey =
        '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
    final todayExams = grouped[todayKey] ?? [];
    return ToolPageScaffold(
      title: '考场安排',
      actions: [
        IconButton(
          tooltip: '刷新考场安排',
          onPressed: _loading ? null : _initialize,
          icon: const Icon(Icons.refresh_rounded),
        ),
      ],
      child: _loading
          ? const ToolLoading(label: '正在读取考试安排…')
          : _error != null
          ? ToolMessage(message: _error!, onRetry: _initialize)
          : _semesters.isEmpty
          ? const ToolMessage(message: '暂时没有可查询的学期。')
          : RefreshIndicator(
              onRefresh: _initialize,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(22, 12, 22, 34),
                children: [
                  ToolCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        academicSemesterPicker(
                          semesters: _semesters,
                          selected: _semesterId,
                          onChanged: (value) => _update(semester: value),
                        ),
                        const SizedBox(height: 14),
                        const ToolField(
                          label: '考试批次',
                          child: SizedBox.shrink(),
                        ),
                        Wrap(
                          spacing: 7,
                          runSpacing: 7,
                          children: [
                            ToolChoiceButton(
                              label: '期末考试',
                              selected: _type == 'final',
                              onPressed: () => _update(type: 'final'),
                            ),
                            ToolChoiceButton(
                              label: '补考',
                              selected: _type == 'makeup',
                              onPressed: () => _update(type: 'makeup'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  ToolCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ToolSectionHeading(
                          title: '今日考试',
                          subtitle: _examDateLabel(todayKey),
                          subtitleAbove: true,
                          titleSize: 17,
                          trailing: todayExams.isEmpty
                              ? '无安排'
                              : '${todayExams.length} 门',
                        ),
                        const SizedBox(height: 14),
                        if (todayExams.isEmpty)
                          Row(
                            children: [
                              Icon(
                                Icons.check_circle_outline_rounded,
                                color: toolAccent(context),
                                size: 26,
                              ),
                              const SizedBox(width: 12),
                              const Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '今天没有考试',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    Text(
                                      '当前批次今天没有考试安排。',
                                      style: TextStyle(fontSize: 12),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          )
                        else
                          ...todayExams.map((exam) => _ExamCard(exam: exam)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  ToolSectionHeading(
                    title: '考试安排',
                    subtitle: _type == 'final' ? '期末考试' : '补考',
                    trailing: '共 ${_exams.length} 门',
                  ),
                  const SizedBox(height: 14),
                  if (_exams.isEmpty)
                    const AcademicEmptyCard(
                      text: '这个批次暂无考试安排',
                      detail: '可能尚未发布，也可能当前没有需要参加的考试。',
                    )
                  else
                    for (final date in dates) ...[
                      ToolCard(
                        padding: EdgeInsets.zero,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(16),
                              child: ToolSectionHeading(
                                title: _examDateLabel(date),
                                titleSize: 15,
                                trailing: '${grouped[date]!.length} 门',
                              ),
                            ),
                            for (var i = 0; i < grouped[date]!.length; i++) ...[
                              if (i > 0)
                                const Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 16),
                                  child: Divider(height: 1),
                                ),
                              _ExamCard(exam: grouped[date]![i]),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                    ],
                ],
              ),
            ),
    );
  }
}

String _examDateLabel(String value) {
  final date = DateTime.tryParse(value);
  return date == null
      ? value
      : '${date.month}月${date.day}日 周${'一二三四五六日'[date.weekday - 1]}';
}

class _ExamCard extends StatelessWidget {
  const _ExamCard({required this.exam});
  final Map<String, dynamic> exam;
  @override
  Widget build(BuildContext context) {
    final rawTime = '${exam['ExamTime'] ?? ''}'.trim();
    final location = '${exam['Location'] ?? ''}'.trim();
    final parts = rawTime.split(RegExp(r'\s*[~～\-–—]\s*'));
    final start = rawTime.isEmpty || RegExp(r'未安排|待安排|暂无').hasMatch(rawTime)
        ? '待定'
        : parts.first;
    final end = parts.length == 2 ? parts.last : '';
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 72,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  start,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: toolAccent(context),
                  ),
                ),
                if (end.isNotEmpty)
                  Text('至 $end', style: TextStyle(fontSize: 11, color: muted)),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${exam['CourseName'] ?? '未命名考试'}',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.location_on_outlined, size: 15, color: muted),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        location.isEmpty ? '地点未安排' : location,
                        style: TextStyle(fontSize: 12, color: muted),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    for (final key in ['ExamType', 'Credits', 'Status'])
                      if ('${exam[key] ?? ''}'.trim().isNotEmpty)
                        Text(
                          key == 'Credits' ? '${exam[key]} 学分' : '${exam[key]}',
                          style: TextStyle(
                            fontSize: 11,
                            color:
                                key == 'Status' &&
                                    RegExp(
                                      r'取消|异常|缺考|缓考|停考',
                                    ).hasMatch('${exam[key]}')
                                ? Theme.of(context).colorScheme.error
                                : muted,
                          ),
                        ),
                  ],
                ),
                if ('${exam['Remark'] ?? ''}'.trim().isNotEmpty)
                  Text(
                    '备注 ${exam['Remark']}',
                    style: TextStyle(fontSize: 11, color: muted),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
