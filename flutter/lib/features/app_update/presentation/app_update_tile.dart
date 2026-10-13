import 'package:flutter/material.dart';

import 'app_update_view_model.dart';

class AppUpdateTile extends StatelessWidget {
  const AppUpdateTile({super.key, required this.viewModel});

  final AppUpdateViewModel viewModel;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: viewModel,
    builder: (context, _) {
      final theme = Theme.of(context);
      final subtitle = switch (viewModel.state) {
        AppUpdateState.idle => '检查并下载可用更新',
        AppUpdateState.unavailable => '当前安装包暂不支持在线更新',
        AppUpdateState.checking => '正在检查更新…',
        AppUpdateState.upToDate => '暂无可用的在线更新',
        AppUpdateState.downloading => '正在后台下载更新…',
        AppUpdateState.restartRequired => '更新已准备好，下次启动生效',
        AppUpdateState.failed => viewModel.error!,
      };
      return ListTile(
        key: const Key('profile-check-update'),
        contentPadding: const EdgeInsets.symmetric(horizontal: 18),
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: theme.colorScheme.primary.withValues(alpha: .09),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            Icons.system_update_alt,
            color: theme.colorScheme.primary,
          ),
        ),
        title: const Text('检查更新'),
        subtitle: Text(subtitle),
        trailing: viewModel.isBusy
            ? const SizedBox.square(
                dimension: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.chevron_right_rounded),
        onTap:
            viewModel.isBusy ||
                viewModel.state == AppUpdateState.unavailable ||
                viewModel.state == AppUpdateState.restartRequired
            ? null
            : viewModel.checkAndDownload,
      );
    },
  );
}
