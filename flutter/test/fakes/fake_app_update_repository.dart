import 'package:chengxin_youyou/features/app_update/data/app_update_repository.dart';

class FakeAppUpdateRepository implements AppUpdateRepository {
  @override
  bool isAvailable = true;
  AppPatchInfo patches = const AppPatchInfo();
  AppPatchStatus status = AppPatchStatus.upToDate;
  Future<AppPatchStatus> Function()? onCheck;
  Future<void> Function()? onDownload;
  Object? checkError;
  Object? downloadError;
  int reads = 0;
  int checks = 0;
  int downloads = 0;

  @override
  Future<AppPatchInfo> readPatches() async {
    reads++;
    return patches;
  }

  @override
  Future<AppPatchStatus> checkForUpdate() async {
    checks++;
    if (checkError != null) throw checkError!;
    return onCheck == null ? status : await onCheck!();
  }

  @override
  Future<void> downloadUpdate() async {
    downloads++;
    if (downloadError != null) throw downloadError!;
    await onDownload?.call();
    patches = AppPatchInfo(currentPatch: patches.currentPatch, nextPatch: 4);
  }
}
