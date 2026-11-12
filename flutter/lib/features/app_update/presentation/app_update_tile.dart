import 'dart:async';

import 'package:flutter/material.dart';

import 'app_update_view_model.dart';
import 'full_app_update_view_model.dart';

class AppUpdateTile extends StatelessWidget {
  const AppUpdateTile({super.key, required this.viewModel, this.fullViewModel});

  final AppUpdateViewModel viewModel;
  final FullAppUpdateViewModel? fullViewModel;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([viewModel, ?fullViewModel]),
    builder: (context, _) {
      final theme = Theme.of(context);
      final full = fullViewModel;
      final fullAvailable =
          full?.state == FullAppUpdateState.available && full?.update != null;
      final busy = viewModel.isBusy || full?.isBusy == true;
      final subtitle = _subtitle(full);
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
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(subtitle),
            if (viewModel.hasPatchInfo)
              Text(
                viewModel.currentPatch == null
                    ? '当前为基础版本'
                    : '当前补丁：${viewModel.currentPatch}',
                key: const Key('app-current-patch'),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
          ],
        ),
        trailing: busy
            ? const SizedBox.square(
                dimension: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.chevron_right_rounded),
        onTap: busy
            ? null
            : fullAvailable
            ? full!.install
            : viewModel.state == AppUpdateState.restartRequired
            ? null
            : () {
                unawaited(viewModel.checkAndDownload());
                final full = fullViewModel;
                if (full != null) unawaited(full.check());
              },
      );
    },
  );

  String _subtitle(FullAppUpdateViewModel? full) {
    final update = full?.update;
    if (full?.state == FullAppUpdateState.available && update != null) {
      return '发现新版本 ${update.versionName}，点击更新';
    }
    if (viewModel.state == AppUpdateState.restartRequired) {
      return '热更新已准备好，下次启动生效';
    }
    if (full?.state == FullAppUpdateState.downloading) {
      return '正在下载完整安装包…';
    }
    if (viewModel.isBusy || full?.isBusy == true) return '正在检查更新…';
    if (viewModel.state == AppUpdateState.failed) return viewModel.error!;
    if (full?.state == FullAppUpdateState.failed) return full!.error!;
    if (viewModel.state == AppUpdateState.upToDate ||
        (viewModel.state == AppUpdateState.unavailable &&
            full?.state == FullAppUpdateState.upToDate)) {
      return '当前已是最新版本';
    }
    if (viewModel.state == AppUpdateState.idle &&
        (full == null || full.state == FullAppUpdateState.idle)) {
      return '检查可用更新';
    }
    return '点击重新检查';
  }
}
