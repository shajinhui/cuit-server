import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../../core/platform/app_platform.dart';

import 'community_link.dart';

import '../../../core/network/api_exception.dart';
import '../data/profile_repository.dart';
import '../../../ui/components/page_layout.dart';

class FeedbackPage extends StatefulWidget {
  const FeedbackPage({
    super.key,
    required this.repository,
    this.onSessionExpired,
  });
  final ProfileRepository? repository;
  final VoidCallback? onSessionExpired;
  @override
  State<FeedbackPage> createState() => _FeedbackPageState();
}

class _FeedbackPageState extends State<FeedbackPage> {
  final _content = TextEditingController();
  String _type = 'suggestion';
  String _platform = isHarmonyOS
      ? 'ohos'
      : defaultTargetPlatform == TargetPlatform.iOS
      ? 'ios'
      : 'android';
  String? _error;
  bool _submitting = false;
  bool _submitted = false;
  int get _length => _content.text.trim().characters.length;
  bool get _canSubmit =>
      !_submitting &&
      _length >= 10 &&
      _length <= 2000 &&
      widget.repository != null;
  @override
  void dispose() {
    _content.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_canSubmit) return;
    final type = _type;
    final platform = _platform;
    final content = _content.text.trim();
    setState(() {
      _submitting = true;
      _error = null;
      _submitted = false;
    });
    try {
      await widget.repository!.submitFeedback(
        type: type,
        platform: platform,
        content: content,
      );
      if (!mounted) return;
      _content.clear();
      setState(() => _submitted = true);
    } catch (error) {
      if (!mounted) return;
      if (error is ApiException && error.kind == FailureKind.authentication) {
        widget.onSessionExpired?.call();
      }
      setState(
        () => _error = error is ApiException ? error.message : '暂时无法提交，请稍后重试。',
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) => PageScaffold(
    title: '问题反馈',
    child: ListView(
      padding: const EdgeInsets.fromLTRB(22, 18, 22, 32),
      children: [
        PageCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.forum_outlined,
                    color: pageAccent(context),
                    size: 28,
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '建议优先加群反馈',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          '这里的反馈开发者可能无法及时看到；需要尽快回复时，请加入交流群。',
                          style: TextStyle(fontSize: 12, height: 1.5),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () => openCommunityGroup(context),
                child: const Text('加入群 151247227'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _selection(
          '反馈类型',
          {'suggestion': '建议', 'bug': 'Bug'},
          _type,
          (value) => setState(() => _type = value),
        ),
        const SizedBox(height: 16),
        _selection(
          '问题平台',
          {'android': 'Android', 'ios': 'iOS'},
          _platform,
          (value) => setState(() => _platform = value),
        ),
        const SizedBox(height: 16),
        PageCard(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              PageSectionHeading(
                title: '详细描述',
                titleSize: 15,
                trailing: '$_length/2000',
              ),
              const SizedBox(height: 14),
              TextField(
                key: const Key('feedback-content'),
                controller: _content,
                enabled: !_submitting,
                maxLength: 2000,
                minLines: 7,
                maxLines: 12,
                buildCounter:
                    (
                      _, {
                      required currentLength,
                      required isFocused,
                      maxLength,
                    }) => null,
                onChanged: (_) => setState(() {
                  _error = null;
                  _submitted = false;
                }),
                decoration: const InputDecoration(
                  hintText: '请描述你的建议，或说明问题出现的页面、操作步骤和实际表现（至少 10 个字）',
                ),
              ),
              const SizedBox(height: 12),
              Text(
                '反馈不会上传密码或教务系统 Cookie。',
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        if (widget.repository == null)
          const Padding(
            padding: EdgeInsets.only(top: 12),
            child: Text('体验账号不能提交真实反馈，请先登录。'),
          ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        if (_submitted)
          const Padding(
            padding: EdgeInsets.only(top: 12),
            child: Text('已收到，谢谢你的反馈'),
          ),
        const SizedBox(height: 16),
        FilledButton(
          key: const Key('feedback-submit'),
          onPressed: _canSubmit ? _submit : null,
          child: Text(_submitting ? '正在提交…' : '提交反馈'),
        ),
      ],
    ),
  );

  Widget _selection(
    String title,
    Map<String, String> values,
    String selected,
    ValueChanged<String> onChanged,
  ) => PageCard(
    padding: const EdgeInsets.all(18),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PageSectionHeading(title: title, titleSize: 15, trailing: '必选'),
        const SizedBox(height: 14),
        PageSegmentedControl<String>(
          values: values,
          selected: selected,
          onChanged: _submitting ? null : onChanged,
        ),
      ],
    ),
  );
}
