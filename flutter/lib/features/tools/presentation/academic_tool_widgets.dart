import 'package:chengxin_youyou/core/network/api_client.dart';
import 'package:chengxin_youyou/core/network/api_exception.dart';
import 'package:chengxin_youyou/features/schedule/models/semester.dart';
import 'package:flutter/material.dart';

import '../../../ui/components/page_selection.dart';

import 'tool_page_scaffold.dart';

Future<List<Semester>> loadAcademicSemesters(ApiClient? api) async {
  if (api == null) throw const ApiException('服务暂不可用。');
  final raw = await api.request('/api/v1/jwxt/semesters');
  if (raw is! List) throw const ApiException('学期列表格式异常。');
  final result = raw
      .map((item) => Semester.fromJson(item as Map<String, dynamic>))
      .toList();
  result.sort((left, right) {
    final year = right.schoolYear.compareTo(left.schoolYear);
    return year == 0 ? right.term.compareTo(left.term) : year;
  });
  return result;
}

Semester? preferredAcademicSemester(List<Semester> values) {
  for (final item in values) {
    if (item.isCurrent) return item;
  }
  return values.isEmpty ? null : values.first;
}

String academicErrorMessage(Object error) =>
    error is ApiException ? error.message : '读取失败，请检查网络后重试。';

Widget academicSemesterPicker({
  required List<Semester> semesters,
  required String? selected,
  required ValueChanged<String> onChanged,
  String label = '学期',
}) => ToolField(
  label: label,
  child: PageDropdownField<String>(
    key: ValueKey('semester-$selected'),
    value: selected,
    values: {for (final item in semesters) item.id: item.label},
    onChanged: (value) {
      if (value != null) onChanged(value);
    },
  ),
);

class AcademicEmptyCard extends StatelessWidget {
  const AcademicEmptyCard({super.key, required this.text, this.detail});
  final String text;
  final String? detail;
  @override
  Widget build(BuildContext context) => ToolCard(
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 44),
    child: Column(
      children: [
        Text(
          '—',
          style: TextStyle(
            fontSize: 32,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          text,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
        ),
        if (detail != null) ...[
          const SizedBox(height: 6),
          Text(
            detail!,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ],
    ),
  );
}
