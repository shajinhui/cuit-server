import 'package:chengxin_youyou/core/network/api_client.dart';
import 'package:chengxin_youyou/core/network/api_exception.dart';
import 'package:chengxin_youyou/features/schedule/models/semester.dart';
import 'package:flutter/material.dart';

import 'tool_page_scaffold.dart';

import 'academic_tool_widgets.dart';

/// 教务接口会用空字符串表示尚无最终成绩，此时仍应展示总评成绩。
String displayGradeScore(Map<String, dynamic> grade) {
  final finalScore = (grade['FinalScore'] ?? '').toString().trim();
  final overall = (grade['OverallScore'] ?? '').toString().trim();
  return finalScore.isNotEmpty
      ? finalScore
      : overall.isNotEmpty
      ? overall
      : '—';
}

class GradesPage extends StatefulWidget {
  const GradesPage({super.key, required this.api});
  final ApiClient? api;

  @override
  State<GradesPage> createState() => _GradesPageState();
}

class _GradesPageState extends State<GradesPage> {
  List<Semester> _semesters = [];
  String? _semesterId;
  List<Map<String, dynamic>> _grades = [];
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
      final selected = semesters.any((value) => value.id == _semesterId)
          ? _semesterId
          : preferredAcademicSemester(semesters)?.id;
      if (selected == null) {
        setState(() {
          _semesters = semesters;
          _semesterId = null;
          _grades = [];
          _loading = false;
        });
        return;
      }
      final raw = await widget.api!.request(
        '/api/v1/jwxt/grades',
        query: {'semester_id': selected},
      );
      if (raw is! List) throw const ApiException('成绩数据格式异常。');
      if (!mounted) return;
      setState(() {
        _semesters = semesters;
        _semesterId = selected;
        _grades = raw.cast<Map<String, dynamic>>();
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

  Future<void> _changeSemester(String value) async {
    setState(() {
      _semesterId = value;
      _loading = true;
      _error = null;
    });
    try {
      final raw = await widget.api!.request(
        '/api/v1/jwxt/grades',
        query: {'semester_id': value},
      );
      if (raw is! List) throw const ApiException('成绩数据格式异常。');
      if (mounted) {
        setState(() {
          _grades = raw.cast<Map<String, dynamic>>();
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
    final published = _grades
        .where((item) => displayGradeScore(item) != '—')
        .toList();
    final failed = published.where((item) {
      final score = double.tryParse(displayGradeScore(item));
      return score != null && score < 60;
    }).length;
    double creditSum = 0;
    double weightedSum = 0;
    double weightSum = 0;
    for (final item in published) {
      final credits = double.tryParse('${item['Credits'] ?? ''}'.trim()) ?? 0;
      creditSum += credits;
      final score = double.tryParse(displayGradeScore(item));
      if (score != null) {
        // 无学分信息时按 1 学分计权，保证均分仍可计算。
        final weight = credits > 0 ? credits : 1;
        weightedSum += score * weight;
        weightSum += weight;
      }
    }
    return ToolPageScaffold(
      title: '查成绩',
      hideTitle: _semesters.isNotEmpty,
      backgroundColor: Theme.of(context).brightness == Brightness.dark
          ? null
          : const Color(0xFFF6F6F8),
      actions: [
        IconButton(
          tooltip: '刷新成绩',
          onPressed: _loading ? null : _initialize,
          icon: const Icon(Icons.refresh_rounded),
        ),
      ],
      child: _loading
          ? const ToolLoading(label: '正在读取成绩…')
          : _error != null
          ? ToolMessage(message: _error!, onRetry: _initialize)
          : _semesters.isEmpty
          ? const ToolMessage(message: '暂时没有可查询的学期。')
          : RefreshIndicator(
              onRefresh: _initialize,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                children: [
                  academicSemesterPicker(
                    semesters: _semesters,
                    selected: _semesterId,
                    onChanged: _changeSemester,
                    label: '当前学期',
                  ),
                  const SizedBox(height: 10),
                  _SummaryCard(
                    total: published.length,
                    failed: failed,
                    credits: creditSum,
                    average: weightSum > 0 ? weightedSum / weightSum : null,
                  ),
                  const SizedBox(height: 14),
                  const ToolSectionHeading(title: '成绩明细'),
                  const SizedBox(height: 10),
                  if (_grades.isEmpty)
                    const AcademicEmptyCard(
                      text: '本学期暂无成绩',
                      detail: '教务系统发布后会显示在这里。',
                    )
                  else
                    ToolGroupedList(
                      children: _grades
                          .map((grade) => _GradeCard(grade: grade))
                          .toList(),
                    ),
                ],
              ),
            ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.total,
    required this.failed,
    required this.credits,
    required this.average,
  });
  final int total;
  final int failed;
  final double credits;
  final double? average;

  String _format(double value) => value == value.roundToDouble()
      ? '${value.toInt()}'
      : value.toStringAsFixed(1);

  @override
  Widget build(BuildContext context) {
    final errorColor = Theme.of(context).colorScheme.error;
    final average = this.average;
    final averageText = average == null ? '—' : average.toStringAsFixed(1);
    return ToolCard(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      child: IntrinsicHeight(
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '平均分 · 学分加权',
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    averageText,
                    style: TextStyle(fontSize: 30, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
            const VerticalDivider(width: 26, thickness: .5),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _SummaryStat(label: '已出', value: '$total 门'),
                  const SizedBox(height: 5),
                  _SummaryStat(
                    label: '挂科',
                    value: '$failed 门',
                    valueColor: failed > 0 ? errorColor : null,
                  ),
                  const SizedBox(height: 5),
                  _SummaryStat(label: '总学分', value: _format(credits)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryStat extends StatelessWidget {
  const _SummaryStat({
    required this.label,
    required this.value,
    this.valueColor,
  });
  final String label;
  final String value;
  final Color? valueColor;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      SizedBox(
        width: 40,
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ),
      Text(
        value,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: valueColor,
        ),
      ),
    ],
  );
}

String _gradeValue(Map<String, dynamic> grade, String key) {
  final value = '${grade[key] ?? ''}'.trim();
  return value.isEmpty ? '—' : value;
}

/// 成绩行：收起时只露课程名与主分数，点击展开平时/期末等分项。
class _GradeCard extends StatefulWidget {
  const _GradeCard({required this.grade});
  final Map<String, dynamic> grade;
  @override
  State<_GradeCard> createState() => _GradeCardState();
}

class _GradeCardState extends State<_GradeCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final grade = widget.grade;
    final score = displayGradeScore(grade);
    final failed = (double.tryParse(score) ?? 100) < 60;
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return InkWell(
      onTap: () => setState(() => _expanded = !_expanded),
      child: Container(
        color: failed
            ? Theme.of(context).colorScheme.error.withValues(alpha: .04)
            : null,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${grade['CourseName'] ?? '未命名课程'}',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${grade['CourseCategory'] ?? '课程'} · '
                        '${_gradeValue(grade, 'Credits')} 学分 · '
                        '绩点 ${_gradeValue(grade, 'GradePoint')}',
                        style: TextStyle(fontSize: 11, color: muted),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 72),
                  child: Text(
                    score,
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w600,
                      color: failed
                          ? Theme.of(context).colorScheme.error
                          : null,
                    ),
                  ),
                ),
                AnimatedRotation(
                  turns: _expanded ? .5 : 0,
                  duration: const Duration(milliseconds: 180),
                  child: Icon(
                    Icons.expand_more_rounded,
                    size: 18,
                    color: muted,
                  ),
                ),
              ],
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOutCubic,
              alignment: Alignment.topLeft,
              child: _expanded
                  ? Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Wrap(
                        spacing: 14,
                        runSpacing: 4,
                        children: [
                          for (final text in [
                            '平时 ${_gradeValue(grade, 'UsualScore')}',
                            '期末 ${_gradeValue(grade, 'FinalExamScore')}',
                            '总评 ${_gradeValue(grade, 'OverallScore')}',
                            '代码 ${_gradeValue(grade, 'CourseCode')}',
                          ])
                            Text(
                              text,
                              style: TextStyle(fontSize: 11, color: muted),
                            ),
                        ],
                      ),
                    )
                  : const SizedBox(width: double.infinity),
            ),
          ],
        ),
      ),
    );
  }
}
