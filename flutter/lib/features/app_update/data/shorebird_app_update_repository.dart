import 'package:shorebird_code_push/shorebird_code_push.dart';

import 'app_update_repository.dart';

class ShorebirdAppUpdateRepository implements AppUpdateRepository {
  ShorebirdAppUpdateRepository({ShorebirdUpdater? updater})
    : _updater = updater ?? ShorebirdUpdater();

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
  // checkForUpdate 的 native bool 返回值会将网络失败折叠为没有更新。
  // update 会检查并下载，并通过结果接口将网络错误转为 UpdateException。
  Future<void> checkAndDownload() => _updater.update();
}
