import 'package:chengxin_youyou/features/app_update/data/shorebird_app_update_repository.dart';
import 'package:chengxin_youyou/features/app_update/presentation/app_update_view_model.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shorebird_code_push/shorebird_code_push.dart';

void main() {
  test('SDK 检查网络失败时显示失败，避免 bool 检查接口误报最新', () async {
    final updater = _FakeUpdater()
      ..updateError = UpdateException(
        message: 'offline',
        reason: UpdateFailureReason.downloadFailed,
      );
    final model = AppUpdateViewModel(
      ShorebirdAppUpdateRepository(updater: updater),
    );
    addTearDown(model.dispose);

    await model.checkAndDownload();

    expect(model.state, AppUpdateState.failed);
    expect(model.error, '更新失败，请检查网络后重试');
    expect(model.currentPatch, 7);
    expect(updater.legacyChecks, 0);
    expect(updater.updates, 1);

    updater.updateError = null;
    await model.checkAndDownload();
    expect(model.state, AppUpdateState.upToDate);
    expect(model.error, isNull);
  });

  test('SDK 确认没有更新后保留当前补丁号', () async {
    final updater = _FakeUpdater();
    final model = AppUpdateViewModel(
      ShorebirdAppUpdateRepository(updater: updater),
    );
    addTearDown(model.dispose);

    await model.checkAndDownload();

    expect(model.state, AppUpdateState.upToDate);
    expect(model.currentPatch, 7);
    expect(updater.updates, 1);
    expect(updater.legacyChecks, 0);
  });
}

class _FakeUpdater implements ShorebirdUpdater {
  Object? updateError;
  int updates = 0;
  int legacyChecks = 0;

  @override
  bool get isAvailable => true;

  @override
  Future<Patch?> readCurrentPatch() async => const Patch(number: 7);

  @override
  Future<Patch?> readNextPatch() async => const Patch(number: 7);

  @override
  Future<UpdateStatus> checkForUpdate({UpdateTrack? track}) async {
    legacyChecks++;
    return UpdateStatus.upToDate;
  }

  @override
  Future<void> update({UpdateTrack? track}) async {
    updates++;
    if (updateError case final failure?) throw failure;
  }
}
