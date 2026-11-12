import 'package:flutter/material.dart';

import '../../../ui/components/page_dialog.dart';
import '../data/full_app_update_repository.dart';
import 'full_app_update_view_model.dart';

Future<void> showFullAppUpdatePrompt(
  BuildContext context,
  FullAppUpdateViewModel viewModel,
  FullAppUpdate update,
) async {
  await showDialog<void>(
    context: context,
    barrierDismissible: !update.forceUpdate,
    builder: (dialogContext) => PopScope(
      canPop: !update.forceUpdate,
      child: ListenableBuilder(
        listenable: viewModel,
        builder: (context, _) => PageAlertDialog(
          icon: const Icon(Icons.system_update_alt_rounded),
          title: Text('发现新版本 ${update.versionName}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (update.releaseNotes.isEmpty)
                const Text('建议更新到最新版本，获得最新功能和修复。')
              else
                ...update.releaseNotes.map(
                  (note) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text('• $note'),
                  ),
                ),
              if (viewModel.error != null) ...[
                const SizedBox(height: 10),
                Text(
                  viewModel.error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
            ],
          ),
          actions: [
            if (!update.forceUpdate)
              TextButton(
                key: const Key('full-update-later'),
                onPressed: viewModel.isBusy
                    ? null
                    : () => Navigator.pop(dialogContext),
                child: const Text('稍后'),
              ),
            FilledButton(
              key: const Key('full-update-now'),
              onPressed: viewModel.isBusy
                  ? null
                  : () async {
                      await viewModel.install();
                      if (dialogContext.mounted && viewModel.error == null) {
                        Navigator.pop(dialogContext);
                      }
                    },
              child: viewModel.isBusy
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('立即更新'),
            ),
          ],
        ),
      ),
    ),
  );
}
