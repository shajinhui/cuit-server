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
    final failed = _grades.where((item) {
      final score = double.tryParse(displayGradeScore(item));
      return score != null && score < 60;
    }).length;
    final published = _grades
        .where((item) => displayGradeScore(item) != '—')
        .length;
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
                padding: const EdgeInsets.fromLTRB(22, 24, 22, 32),
                children: [
                  academicSemesterPicker(
                    semesters: _semesters,
                    selected: _semesterId,
                    onChanged: _changeSemester,
                    label: '当前学期',
                  ),
                  const SizedBox(height: 18),
                  _SummaryCard(total: published, failed: failed),
                  const SizedBox(height: 27),
                  const ToolSectionHeading(title: '成绩明细', trailing: '已更新'),
                  const SizedBox(height: 14),
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
  const _SummaryCard({required this.total, required this.failed});
  final int total;
  final int failed;
  @override
  Widget build(BuildContext context) => ToolCard(
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 21),
    child: IntrinsicHeight(
      child: Row(
        children: [
          Expanded(
            child: _SummaryValue(label: '已出成绩', value: '$total'),
          ),
          const VerticalDivider(width: 30, thickness: .5),
          Expanded(
            child: _SummaryValue(
              label: '挂科',
              value: '$failed',
              color: failed > 0 ? Theme.of(context).colorScheme.error : null,
            ),
          ),
        ],
      ),
    ),
  );
}

class _SummaryValue extends StatelessWidget {
  const _SummaryValue({required this.label, required this.value, this.color});
  final String label;
  final String value;
  final Color? color;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: TextStyle(
          fontSize: 13,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
      const SizedBox(height: 7),
      Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: value,
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
            const TextSpan(text: ' 门', style: TextStyle(fontSize: 12)),
          ],
        ),
      ),
    ],
  );
}

String _gradeValue(Map<String, dynamic> grade, String key) {
  final value = '${grade[key] ?? ''}'.trim();
  return value.isEmpty ? '—' : value;
}

class _GradeCard extends StatelessWidget {
  const _GradeCard({required this.grade});
  final Map<String, dynamic> grade;
  @override
  Widget build(BuildContext context) {
    final score = displayGradeScore(grade);
    final failed = (double.tryParse(score) ?? 100) < 60;
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return Container(
      color: failed
          ? Theme.of(context).colorScheme.error.withValues(alpha: .04)
          : null,
      padding: const EdgeInsets.symmetric(horizontal: 17, vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${grade['CourseCategory'] ?? '课程'} · ${grade['CourseCode'] ?? ''}',
                  style: TextStyle(fontSize: 10, color: muted),
                ),
                const SizedBox(height: 3),
                Text(
                  '${grade['CourseName'] ?? '未命名课程'}',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 5),
                Wrap(
                  spacing: 11,
                  runSpacing: 5,
                  children: [
                    for (final text in [
                      '${_gradeValue(grade, 'Credits')} 学分',
                      '平时 ${_gradeValue(grade, 'UsualScore')}',
                      '期末 ${_gradeValue(grade, 'FinalExamScore')}',
                      if ('${grade['MakeupScore'] ?? ''}'.isNotEmpty)
                        '补考 ${grade['MakeupScore']}',
                      '绩点 ${_gradeValue(grade, 'GradePoint')}',
                    ])
                      Text(text, style: TextStyle(fontSize: 10, color: muted)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 15),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 90),
            child: Text(
              score,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 29,
                fontWeight: FontWeight.w500,
                color: failed ? Theme.of(context).colorScheme.error : null,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
