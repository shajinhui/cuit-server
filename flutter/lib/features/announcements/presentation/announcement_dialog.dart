import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../ui/components/page_dialog.dart';
import '../models/app_announcement.dart';
import 'announcement_view_model.dart';

const _groupName = '成信友友二群';
const _groupUrl = 'https://qm.qq.com/q/oY2MdsQgco';

Future<void> showAnnouncement(
  BuildContext context,
  AnnouncementViewModel viewModel,
  AppAnnouncement announcement, {
  bool automatic = false,
}) async {
  if (!viewModel.beginPresentation(announcement, automatic: automatic)) return;
  bool? openLink;
  try {
    openLink = await showPageDialog<bool>(
      context,
      builder: (dialogContext) => PageAlertDialog(
        icon: const Icon(Icons.campaign_outlined),
        title: Text(announcement.title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(announcement.body),
            const SizedBox(height: 12),
            const Text(_groupName),
            if (viewModel.isOffline) ...[
              const SizedBox(height: 12),
              const Text('离线内容，联网后可获取最新公告'),
            ],
          ],
        ),
        actions: [
          TextButton(
            key: const Key('announcement-close'),
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('我知道了'),
          ),
          FilledButton(
            key: const Key('announcement-action'),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(announcement.actionLabel ?? '立即入群'),
          ),
        ],
      ),
    );
  } finally {
    await viewModel.finishPresentation(announcement);
  }
  if (openLink != true || !context.mounted) return;
  // 公告专属按钮沿用服务端链接；没有专属按钮时，默认进入成信友友二群。
  final uri = announcement.actionUrl ?? Uri.parse(_groupUrl);
  try {
    if (await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      return;
    }
  } catch (_) {
    /* 平台没有处理程序时显示可重试反馈。 */
  }
  if (context.mounted) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('暂时无法打开公告链接，请稍后重试')));
  }
}
