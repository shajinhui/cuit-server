import 'package:flutter/material.dart';

import '../../../ui/components/page_dialog.dart';

/// 版主操作必须留下可理解的理由，拒绝空泛的“违规”以外的空输入。
///
/// 服务端只要求 2–100 字；这里与之一致，避免客户端发送注定失败的请求。
Future<String?> askForumModerationReason(
  BuildContext context, {
  required String title,
  required String hint,
  String confirmLabel = '确定',
}) => showPageDialog<String>(
  context,
  builder: (_) => _ForumModerationReasonDialog(
    title: title,
    hint: hint,
    confirmLabel: confirmLabel,
  ),
);

class _ForumModerationReasonDialog extends StatefulWidget {
  const _ForumModerationReasonDialog({
    required this.title,
    required this.hint,
    required this.confirmLabel,
  });

  final String title;
  final String hint;
  final String confirmLabel;

  @override
  State<_ForumModerationReasonDialog> createState() =>
      _ForumModerationReasonDialogState();
}

class _ForumModerationReasonDialogState
    extends State<_ForumModerationReasonDialog> {
  final _controller = TextEditingController();
  String? _error;

  @override
  void dispose() {
    // 退场动画结束前不能提前释放，交给组件生命周期处理。
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final reason = _controller.text.trim();
    final length = reason.characters.length;
    if (length < 2 || length > 100) {
      setState(() => _error = '请填写 2 到 100 个字的说明。');
      return;
    }
    Navigator.pop(context, reason);
  }

  @override
  Widget build(BuildContext context) => PageAlertDialog(
    title: Text(widget.title),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          widget.hint,
          style: TextStyle(
            fontSize: 13,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          key: const ValueKey('forum-moderation-reason'),
          controller: _controller,
          maxLength: 100,
          minLines: 2,
          maxLines: 4,
          autofocus: true,
          decoration: const InputDecoration(hintText: '例如：人身攻击、广告引流'),
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
        key: const ValueKey('forum-moderation-cancel'),
        onPressed: () => Navigator.pop(context),
        child: const Text('取消'),
      ),
      FilledButton(
        key: const ValueKey('forum-moderation-confirm'),
        onPressed: _submit,
        child: Text(widget.confirmLabel),
      ),
    ],
  );
}

/// 管理日志与管理菜单共用的动作名称，避免两处文案漂移。
String forumModerationActionLabel(String action) => switch (action) {
  'create' => '创建版块',
  'pin' => '置顶帖子',
  'unpin' => '取消置顶',
  'lock' => '锁定帖子',
  'unlock' => '解锁帖子',
  'hide_thread' => '隐藏帖子',
  'restore_thread' => '恢复帖子',
  'remove_member' => '移除成员',
  'update_rules' => '更新版块信息',
  'rename' => '修改版块名称',
  'grant_moderator' => '指定版主',
  'revoke_moderator' => '撤销版主',
  'archive' => '归档版块',
  'restore' => '恢复版块',
  'publish' => '公开版块',
  'unpublish' => '下线版块',
  _ => action,
};
