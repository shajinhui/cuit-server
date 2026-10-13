import 'package:flutter/material.dart';

import '../../../core/network/api_exception.dart';
import '../../../ui/components/page_layout.dart';
import '../data/profile_repository.dart';
import '../models/plan_completion.dart';

class PlanCompletionPage extends StatefulWidget {
  const PlanCompletionPage({
    super.key,
    required this.repository,
    this.onSessionExpired,
  });
  final ProfileRepository? repository;
  final VoidCallback? onSessionExpired;
  @override
  State<PlanCompletionPage> createState() => _PlanCompletionPageState();
}

class _PlanCompletionPageState extends State<PlanCompletionPage> {
  PlanCompletion? _data;
  bool _loading = false;
  String? _error;
  int _request = 0;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (_loading) return;
    final request = ++_request;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      if (widget.repository == null) {
        throw const ApiException('体验账号没有真实培养方案数据。');
      }
      final data = await widget.repository!.loadPlanCompletion();
      if (mounted && request == _request) setState(() => _data = data);
    } catch (error) {
      if (!mounted || request != _request) return;
      if (error is ApiException && error.kind == FailureKind.authentication) {
        widget.onSessionExpired?.call();
      }
      setState(
        () =>
            _error = error is ApiException ? error.message : '培养方案读取失败，请稍后重试。',
      );
    } finally {
      if (mounted && request == _request) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = _data;
    return PageScaffold(
      title: '学业完成情况',
      actions: [
        IconButton(
          tooltip: '刷新学业完成情况',
          onPressed: _loading ? null : _load,
          icon: const Icon(Icons.refresh_rounded),
        ),
      ],
      child: _loading && data == null
          ? const PageLoading(label: '正在读取培养方案…')
          : data == null
          ? PageMessage(message: _error ?? '暂无培养方案数据', onRetry: _load)
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(22, 16, 22, 32),
                children: [
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: Text(
                        _error!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ),
                  _summaryCard(context, data),
                  const SizedBox(height: 20),
                  PageSectionHeading(
                    title: '培养方案明细',
                    titleSize: 18,
                    trailing: _loading ? '更新中…' : '${data.groups.length} 个分类',
                  ),
                  const SizedBox(height: 12),
                  if (data.groups.isEmpty)
                    const PageCard(child: Text('暂无培养方案明细')),
                  for (final group in data.groups) ...[
                    _groupCard(context, group),
                    const SizedBox(height: 12),
                  ],
                  const SizedBox(height: 8),
                  Text(
                    '数据来自教务系统培养方案预审，最终结果以学校审核为准。',
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  if ((data.summary['AuditTime'] ?? '').isNotEmpty)
                    Text(
                      '审核时间：${data.summary['AuditTime']}',
                      style: const TextStyle(fontSize: 12),
                    ),
                ],
              ),
            ),
    );
  }

  Widget _summaryCard(BuildContext context, PlanCompletion data) => PageCard(
    radius: 24,
    padding: const EdgeInsets.all(20),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('总体学分', style: TextStyle(fontSize: 13)),
                  const SizedBox(height: 6),
                  Text.rich(
                    TextSpan(
                      children: [
                        const TextSpan(
                          text: '已修 ',
                          style: TextStyle(fontSize: 14),
                        ),
                        TextSpan(
                          text: _value(data.summary['EarnedCredits']),
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        TextSpan(
                          text: ' / ${_value(data.summary['RequiredCredits'])}',
                          style: const TextStyle(fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              data.progress == null
                  ? '—'
                  : '${(data.progress! * 100).round()}%',
              style: const TextStyle(
                fontSize: 34,
                fontWeight: FontWeight.w600,
                height: 1.2,
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        Semantics(
          label: data.progress == null
              ? '完成度暂不可计算'
              : '完成度 ${(data.progress! * 100).round()}%',
          child: LinearProgressIndicator(
            value: data.progress ?? 0,
            minHeight: 8,
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        const SizedBox(height: 18),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('平均绩点', style: TextStyle(fontSize: 13)),
                  const SizedBox(height: 5),
                  Text(
                    _value(data.summary['GPA']),
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('审核结果', style: TextStyle(fontSize: 13)),
                  const SizedBox(height: 5),
                  Text(
                    _value(data.summary['AuditResult'], fallback: '暂未审核'),
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      color: _statusColor(
                        context,
                        data.summary['AuditResult'] ?? '',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        if ((data.summary['Remark'] ?? '').isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(data.summary['Remark']!, style: const TextStyle(fontSize: 12)),
        ],
      ],
    ),
  );

  Widget _groupCard(
    BuildContext context,
    PlanCompletionGroup group,
  ) => PageCard(
    padding: const EdgeInsets.all(16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    group.requirement?.name ?? '其他课程',
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (group.requirement case final requirement?)
                    Text(
                      '实修 ${_value(requirement.earnedCredits)} / 要求 ${_value(requirement.requiredCredits)} 学分',
                      style: const TextStyle(fontSize: 12),
                    ),
                ],
              ),
            ),
            if (group.requirement case final requirement?
                when requirement.status.isNotEmpty) ...[
              const SizedBox(width: 8),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 100),
                child: Text(
                  requirement.status,
                  textAlign: TextAlign.end,
                  style: TextStyle(
                    fontSize: 12,
                    color: _statusColor(context, requirement.status),
                  ),
                ),
              ),
            ],
          ],
        ),
        if (group.courses.isEmpty)
          const Padding(
            padding: EdgeInsets.only(top: 12),
            child: Text('暂无课程明细', style: TextStyle(fontSize: 13)),
          ),
        for (final course in group.courses) ...[
          const Divider(height: 24),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      course.name.isEmpty ? '未命名课程' : course.name,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      [
                        course.courseCode,
                        if (course.earnedCredits.isNotEmpty)
                          '实修 ${course.earnedCredits} 学分',
                        if (course.requiredCredits.isNotEmpty)
                          '要求 ${course.requiredCredits} 学分',
                      ].where((v) => v.isNotEmpty).join(' · '),
                      style: const TextStyle(fontSize: 11),
                    ),
                    if (course.remark.isNotEmpty)
                      Text(course.remark, style: const TextStyle(fontSize: 11)),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    _value(course.score),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    _value(course.status, fallback: '未标记'),
                    style: TextStyle(
                      fontSize: 11,
                      color: _statusColor(context, course.status),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ],
    ),
  );

  Color _statusColor(BuildContext context, String status) =>
      switch (completionStatusTone(status)) {
        -1 => Theme.of(context).colorScheme.error,
        1 => pageAccent(context),
        _ => Theme.of(context).colorScheme.onSurfaceVariant,
      };

  String _value(String? value, {String fallback = '—'}) =>
      value == null || value.trim().isEmpty ? fallback : value;
}
