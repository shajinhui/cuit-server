import 'dart:async';

import 'package:chengxin_youyou/app/app.dart';
import 'package:chengxin_youyou/features/app_update/data/app_update_repository.dart';
import 'package:chengxin_youyou/features/app_update/presentation/app_update_tile.dart';
import 'package:chengxin_youyou/features/app_update/presentation/app_update_view_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes/fake_app_update_repository.dart';
import 'fakes/test_dependencies.dart';

void main() {
  test('普通安装包和不支持的运行环境跳过网络检查', () async {
    final repository = FakeAppUpdateRepository()..isAvailable = false;
    final model = AppUpdateViewModel(repository);
    addTearDown(model.dispose);

    await model.checkAndDownload();

    expect(model.state, AppUpdateState.unavailable);
    expect(repository.reads, 0);
    expect(repository.checks, 0);
    expect(repository.downloads, 0);
  });

  test('没有新补丁时保留当前补丁号，不启动下载', () async {
    final repository = FakeAppUpdateRepository()
      ..patches = const AppPatchInfo(currentPatch: 3, nextPatch: 3);
    final model = AppUpdateViewModel(repository);
    addTearDown(model.dispose);

    await model.checkAndDownload();

    expect(model.state, AppUpdateState.upToDate);
    expect(model.currentPatch, 3);
    expect(repository.downloads, 0);
  });

  test('后台下载新补丁后提示下次启动，当前执行的补丁号不变', () async {
    final repository = FakeAppUpdateRepository()
      ..status = AppPatchStatus.outdated
      ..patches = const AppPatchInfo(currentPatch: 3, nextPatch: 3);
    final model = AppUpdateViewModel(repository);
    addTearDown(model.dispose);
    final states = <AppUpdateState>[];
    model.addListener(() => states.add(model.state));

    await model.checkAndDownload();

    expect(states, [
      AppUpdateState.checking,
      AppUpdateState.downloading,
      AppUpdateState.restartRequired,
    ]);
    expect(model.currentPatch, 3);
    expect(repository.downloads, 1);
  });

  for (final nextPatch in <int?>[4, null]) {
    test('本机待生效的补丁或回滚不依赖网络（next=$nextPatch）', () async {
      final repository = FakeAppUpdateRepository()
        ..patches = AppPatchInfo(currentPatch: 3, nextPatch: nextPatch)
        ..checkError = StateError('offline');
      final model = AppUpdateViewModel(repository);
      addTearDown(model.dispose);

      await model.checkAndDownload();

      expect(model.state, AppUpdateState.restartRequired);
      expect(model.currentPatch, 3);
      expect(repository.checks, 0);
      expect(repository.downloads, 0);
    });
  }

  test('启动检查和连续手动检查复用正在执行的检查与下载', () async {
    final checking = Completer<AppPatchStatus>();
    final downloading = Completer<void>();
    final repository = FakeAppUpdateRepository()
      ..onCheck = (() => checking.future)
      ..onDownload = (() => downloading.future);
    final model = AppUpdateViewModel(repository);
    addTearDown(model.dispose);

    final first = model.checkAndDownload();
    expect(identical(first, model.checkAndDownload()), isTrue);
    await Future<void>.delayed(Duration.zero);
    expect(repository.checks, 1);

    checking.complete(AppPatchStatus.outdated);
    await Future<void>.delayed(Duration.zero);
    expect(model.state, AppUpdateState.downloading);
    expect(identical(first, model.checkAndDownload()), isTrue);
    expect(repository.downloads, 1);

    downloading.complete();
    await first;
    expect(model.state, AppUpdateState.restartRequired);
  });

  test('检查失败保留当前补丁，允许重新检查', () async {
    final repository = FakeAppUpdateRepository()
      ..patches = const AppPatchInfo(currentPatch: 3, nextPatch: 3)
      ..checkError = StateError('offline');
    final model = AppUpdateViewModel(repository);
    addTearDown(model.dispose);

    await model.checkAndDownload();
    expect(model.state, AppUpdateState.failed);
    expect(model.error, '检查更新失败，请检查网络后重试');
    expect(model.currentPatch, 3);
    expect(repository.downloads, 0);

    repository.checkError = null;
    await model.checkAndDownload();
    expect(model.state, AppUpdateState.upToDate);
    expect(model.error, isNull);
    expect(repository.checks, 2);
  });

  test('下载失败不会误报已完成，重试成功后等待重新启动', () async {
    final repository = FakeAppUpdateRepository()
      ..status = AppPatchStatus.outdated
      ..downloadError = StateError('download failed');
    final model = AppUpdateViewModel(repository);
    addTearDown(model.dispose);

    await model.checkAndDownload();
    expect(model.state, AppUpdateState.failed);
    expect(model.error, '更新下载失败，请检查网络后重试');
    expect(repository.patches.nextPatch, isNull);

    repository.downloadError = null;
    await model.checkAndDownload();
    expect(model.state, AppUpdateState.restartRequired);
    expect(repository.downloads, 2);
  });

  test('检查过程中释放对象后，迟到结果不能启动下载或通知页面', () async {
    final checking = Completer<AppPatchStatus>();
    final repository = FakeAppUpdateRepository()
      ..onCheck = () => checking.future;
    final model = AppUpdateViewModel(repository);
    var notifications = 0;
    model.addListener(() => notifications++);
    final pending = model.checkAndDownload();
    await Future<void>.delayed(Duration.zero);
    model.dispose();
    final before = notifications;

    checking.complete(AppPatchStatus.outdated);
    await pending;
    await model.checkAndDownload();

    expect(notifications, before);
    expect(repository.downloads, 0);
    expect(repository.checks, 1);
  });

  testWidgets('手动检查显示加载与下载结果，不强制退出应用', (tester) async {
    final checking = Completer<AppPatchStatus>();
    final repository = FakeAppUpdateRepository()
      ..onCheck = () => checking.future;
    final model = AppUpdateViewModel(repository);
    addTearDown(model.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: AppUpdateTile(viewModel: model)),
      ),
    );

    await tester.tap(find.byKey(const Key('profile-check-update')));
    await tester.pump();
    expect(find.text('正在检查更新…'), findsOneWidget);
    expect(tester.widget<ListTile>(find.byType(ListTile)).onTap, isNull);

    checking.complete(AppPatchStatus.outdated);
    await tester.pumpAndSettle();
    expect(find.text('更新已准备好，下次启动生效'), findsOneWidget);
    expect(find.byType(AppUpdateTile), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('后台更新不会阻塞登录页，个人中心接入检查更新入口', (tester) async {
    final checking = Completer<AppPatchStatus>();
    final repository = FakeAppUpdateRepository()
      ..onCheck = () => checking.future;
    final model = AppUpdateViewModel(repository);
    final dependencies = (await tester.runAsync(
      () => testDependencies(appUpdate: model),
    ))!;
    await tester.pumpWidget(ChengxinApp(dependencies: dependencies));
    await tester.pumpAndSettle();
    expect(find.text('登录教务账号'), findsOneWidget);
    expect(repository.checks, 1);

    checking.complete(AppPatchStatus.outdated);
    await tester.pumpAndSettle();
    dependencies.session.enterDemo();
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('nav-3')));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const Key('profile-check-update')),
      200,
    );
    expect(find.text('更新已准备好，下次启动生效'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    dependencies.dispose();
  });
}
