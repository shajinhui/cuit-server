import 'package:flutter/material.dart';

import '../../../ui/components/page_dialog.dart';

/// 举报字数属于校园业务；公共弹窗只负责容器与弹出方式。
Future<String?> askCampusReportReason(BuildContext context) =>
    showPageDialog<String>(
      context,
      builder: (_) => const _CampusReportDialog(),
    );

class _CampusReportDialog extends StatefulWidget {
  const _CampusReportDialog();

  @override
  State<_CampusReportDialog> createState() => _CampusReportDialogState();
}

class _CampusReportDialogState extends State<_CampusReportDialog> {
  final _controller = TextEditingController();
  String? _error;

  @override
  void dispose() {
    // 控制器随弹窗组件释放，不能在 pop 后、退场动画完成前提前释放。
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final reason = _controller.text.trim();
    final length = reason.characters.length;
    if (length < 5 || length > 300) {
      setState(() => _error = '请填写 5 到 300 个字的原因。');
      return;
    }
    Navigator.pop(context, reason);
  }

  @override
  Widget build(BuildContext context) => PageAlertDialog(
    title: const Text('举报内容'),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('请说明内容存在的问题，管理员会根据实际情况处理。'),
        const SizedBox(height: 12),
        TextField(
          controller: _controller,
          maxLength: 300,
          minLines: 3,
          maxLines: 5,
          decoration: const InputDecoration(hintText: '至少填写 5 个字'),
        ),
        if (_error != null)
          Text(
            _error!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
      ],
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('取消'),
      ),
      FilledButton(onPressed: _submit, child: const Text('提交')),
    ],
  );
}
