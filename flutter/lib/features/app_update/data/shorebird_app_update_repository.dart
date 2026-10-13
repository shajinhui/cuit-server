import 'package:shorebird_code_push/shorebird_code_push.dart';

import 'app_update_repository.dart';

class ShorebirdAppUpdateRepository implements AppUpdateRepository {
  ShorebirdAppUpdateRepository() : _updater = ShorebirdUpdater();

  final ShorebirdUpdater _updater;

  @override
  bool get isAvailable => _updater.isAvailable;

  @override
  Future<AppPatchInfo> readPatches() async {
    final current = await _updater.readCurrentPatch();
    final next = await _updater.readNextPatch();
    return AppPatchInfo(currentPatch: current?.number, nextPatch: next?.number);
  }

  @override
  Future<AppPatchStatus> checkForUpdate() async =>
      switch (await _updater.checkForUpdate()) {
        UpdateStatus.unavailable => AppPatchStatus.unavailable,
        UpdateStatus.upToDate => AppPatchStatus.upToDate,
        UpdateStatus.outdated => AppPatchStatus.outdated,
        UpdateStatus.restartRequired => AppPatchStatus.restartRequired,
      };

  @override
  Future<void> downloadUpdate() => _updater.update();
}
