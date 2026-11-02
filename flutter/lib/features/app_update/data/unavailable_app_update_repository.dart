import 'app_update_repository.dart';

/// 鸿蒙基础包不包含 Shorebird 引擎，避免初始化不支持的平台运行时。
class UnavailableAppUpdateRepository implements AppUpdateRepository {
  const UnavailableAppUpdateRepository();

  @override
  bool get isAvailable => false;

  @override
  Future<AppPatchInfo> readPatches() async => const AppPatchInfo();

  @override
  Future<void> checkAndDownload() async =>
      throw UnsupportedError('当前平台未提供在线补丁');
}
