import 'package:chengxin_youyou/features/app_update/data/full_app_update_repository.dart';
import 'package:chengxin_youyou/features/app_update/presentation/full_app_update_view_model.dart';
import 'package:chengxin_youyou/app/app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes/test_dependencies.dart';

void main() {
  test('完整更新检查发现新版本后等待用户安装', () async {
    final repository = _FakeFullUpdateRepository(
      update: const FullAppUpdate(
        platform: 'android',
        versionName: '0.1.2',
        versionCode: 4,
        minimumVersionCode: 3,
        downloadPath: '/download.apk',
        storeUrl: null,
        sha256:
            'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
        size: 4,
        forceUpdate: false,
        releaseNotes: ['修复更新问题'],
      ),
    );
    final model = FullAppUpdateViewModel(repository);
    addTearDown(model.dispose);

    await model.check();

    expect(model.state, FullAppUpdateState.available);
    expect(model.update?.versionCode, 4);
    expect(repository.installCount, 0);
  });

  test('完整更新安装失败后保留可安装状态', () async {
    final repository = _FakeFullUpdateRepository(
      update: const FullAppUpdate(
        platform: 'android',
        versionName: '0.1.2',
        versionCode: 4,
        minimumVersionCode: 3,
        downloadPath: '/download.apk',
        storeUrl: null,
        sha256: null,
        size: null,
        forceUpdate: false,
        releaseNotes: [],
      ),
    )..installError = StateError('offline');
    final model = FullAppUpdateViewModel(repository);
    addTearDown(model.dispose);

    await model.check();
    await model.install();

    expect(model.state, FullAppUpdateState.available);
    expect(model.error, '完整更新失败，请稍后重试');
  });

  testWidgets('发现新版本后应用自动提示，稍后仅关闭本次提醒', (tester) async {
    final repository = _FakeFullUpdateRepository(
      update: const FullAppUpdate(
        platform: 'android',
        versionName: '0.1.4',
        versionCode: 6,
        minimumVersionCode: 5,
        downloadPath: '/download.apk',
        storeUrl: null,
        sha256: null,
        size: null,
        forceUpdate: false,
        releaseNotes: ['修复更新问题'],
      ),
    );
    final model = FullAppUpdateViewModel(repository);
    final dependencies = (await tester.runAsync(
      () => testDependencies(fullAppUpdate: model),
    ))!;
    addTearDown(dependencies.dispose);

    await tester.pumpWidget(ChengxinApp(dependencies: dependencies));
    await tester.pumpAndSettle();

    expect(find.text('发现新版本 0.1.4'), findsOneWidget);
    expect(find.textContaining('修复更新问题'), findsOneWidget);
    await tester.tap(find.byKey(const Key('full-update-later')));
    await tester.pumpAndSettle();
    expect(find.text('发现新版本 0.1.4'), findsNothing);
  });
}

class _FakeFullUpdateRepository implements FullAppUpdateRepository {
  _FakeFullUpdateRepository({this.update});

  final FullAppUpdate? update;
  Object? installError;
  int installCount = 0;

  @override
  bool get isAvailable => true;

  @override
  Future<FullAppUpdate?> check() async => update;

  @override
  Future<void> install(FullAppUpdate update) async {
    installCount++;
    if (installError != null) throw installError!;
  }
}
