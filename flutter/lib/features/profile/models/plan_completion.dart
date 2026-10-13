class PlanCompletion {
  const PlanCompletion({required this.summary, required this.groups});
  final Map<String, String> summary;
  final List<PlanCompletionGroup> groups;

  factory PlanCompletion.fromJson(Map<String, dynamic> json) {
    if (json['Summary'] is! Map || json['Items'] is! List) {
      throw const FormatException('培养方案数据格式异常');
    }
    final groups = <PlanCompletionGroup>[];
    PlanCompletionGroup? current;
    for (final raw in json['Items'] as List) {
      final item = PlanCompletionItem.fromJson(
        Map<String, dynamic>.from(raw as Map),
      );
      if (item.kind == 'requirement') {
        current = PlanCompletionGroup(requirement: item, courses: []);
        groups.add(current);
      } else {
        if (current == null) {
          current = PlanCompletionGroup(courses: []);
          groups.add(current);
        }
        current.courses.add(item);
      }
    }
    return PlanCompletion(
      summary: (json['Summary'] as Map).map(
        (key, value) => MapEntry('$key', value?.toString() ?? ''),
      ),
      groups: groups,
    );
  }

  double? get progress {
    final required = _credits(summary['RequiredCredits'] ?? '');
    final earned = _credits(summary['EarnedCredits'] ?? '');
    if (required == null ||
        earned == null ||
        !required.isFinite ||
        !earned.isFinite ||
        required <= 0 ||
        earned < 0) {
      return null;
    }
    return (earned / required).clamp(0, 1);
  }

  // 与 Vue 的 parseFloat 一致，允许教务字段在数字后附带“学分”等文字。
  double? _credits(String value) {
    final prefix = RegExp(
      r'^[+-]?(?:\d+\.?\d*|\.\d+)(?:[eE][+-]?\d+)?',
    ).firstMatch(value.trim());
    return prefix == null ? null : double.tryParse(prefix.group(0)!);
  }
}

class PlanCompletionGroup {
  const PlanCompletionGroup({this.requirement, required this.courses});
  final PlanCompletionItem? requirement;
  final List<PlanCompletionItem> courses;
}

class PlanCompletionItem {
  const PlanCompletionItem({
    required this.kind,
    required this.name,
    required this.courseCode,
    required this.requiredCredits,
    required this.earnedCredits,
    required this.score,
    required this.status,
    required this.remark,
  });
  final String kind,
      name,
      courseCode,
      requiredCredits,
      earnedCredits,
      score,
      status,
      remark;
  factory PlanCompletionItem.fromJson(Map<String, dynamic> json) =>
      PlanCompletionItem(
        kind: '${json['Kind'] ?? ''}',
        name: '${json['Name'] ?? ''}',
        courseCode: '${json['CourseCode'] ?? ''}',
        requiredCredits: '${json['RequiredCredits'] ?? ''}',
        earnedCredits: '${json['EarnedCredits'] ?? ''}',
        score: '${json['Score'] ?? ''}',
        status: '${json['Status'] ?? ''}',
        remark: '${json['Remark'] ?? ''}',
      );
}

/// 先判断“未完成”等否定词，避免被其中的“完成”误判为已完成。
int completionStatusTone(String status) {
  if (RegExp('缺|否|未通过|不通过|未完成').hasMatch(status)) return -1;
  if (status.trim() == '是' || RegExp('通过|完成|满足').hasMatch(status)) return 1;
  return 0;
}
