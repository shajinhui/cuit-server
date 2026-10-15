import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../ui/components/page_dialog.dart';
import '../models/app_announcement.dart';
import 'announcement_view_model.dart';

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
          if (announcement.actionUrl != null)
            FilledButton(
              key: const Key('announcement-action'),
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(announcement.actionLabel!),
            ),
        ],
      ),
    );
  } finally {
    await viewModel.finishPresentation(announcement);
  }
  if (openLink != true || !context.mounted) return;
  try {
    if (await launchUrl(
      announcement.actionUrl!,
      mode: LaunchMode.externalApplication,
    )) {
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
