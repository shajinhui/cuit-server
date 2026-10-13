enum AppPatchStatus { unavailable, upToDate, outdated, restartRequired }

class AppPatchInfo {
  const AppPatchInfo({this.currentPatch, this.nextPatch});

  final int? currentPatch;
  final int? nextPatch;

  // 回滚到基础版本时 nextPatch 为 null，也需要下次启动才能生效。
  bool get restartRequired => currentPatch != nextPatch;
}

/// 只表达客户端需要的更新能力，页面和状态不依赖具体更新 SDK。
abstract interface class AppUpdateRepository {
  bool get isAvailable;
  Future<AppPatchInfo> readPatches();
  Future<AppPatchStatus> checkForUpdate();
  Future<void> downloadUpdate();
}
