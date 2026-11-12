import 'package:flutter/material.dart';

import 'full_app_update_view_model.dart';

class FullAppUpdateTile extends StatelessWidget {
  const FullAppUpdateTile({super.key, required this.viewModel});

  final FullAppUpdateViewModel viewModel;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: viewModel,
    builder: (context, _) {
      final update = viewModel.update;
      final subtitle = switch (viewModel.state) {
        FullAppUpdateState.idle => '从服务器检查完整安装包',
        FullAppUpdateState.unavailable => '当前平台暂不支持完整更新',
        FullAppUpdateState.checking => '正在检查完整安装包…',
        FullAppUpdateState.upToDate => '当前已是最新安装包',
        FullAppUpdateState.available =>
          '发现版本 ${update?.versionName ?? ''}，点击安装',
        FullAppUpdateState.downloading => '正在下载完整安装包…',
        FullAppUpdateState.failed => viewModel.error!,
      };
      return ListTile(
        key: const Key('profile-full-update'),
        contentPadding: const EdgeInsets.symmetric(horizontal: 18),
        leading: const Icon(Icons.download_for_offline_outlined),
        title: const Text('完整安装包更新'),
        subtitle: Text(subtitle),
        trailing: viewModel.isBusy
            ? const SizedBox.square(
                dimension: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.chevron_right_rounded),
        onTap: viewModel.isBusy
            ? null
            : viewModel.state == FullAppUpdateState.available
            ? viewModel.install
            : viewModel.check,
      );
    },
  );
}
