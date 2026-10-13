import 'package:chengxin_youyou/app/app.dart';
import 'package:chengxin_youyou/features/app_update/data/shorebird_app_update_repository.dart';
import 'package:chengxin_youyou/features/app_update/presentation/app_update_view_model.dart';
import 'package:chengxin_youyou/ui/platform/native_tab_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import '../test/fakes/test_dependencies.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('普通 Debug 安装包安全跳过热更新，并展示个人中心入口', (tester) async {
    // 使用真实 SDK 检测运行时，业务会话保持虚构且不访问学校接口。
    final updates = AppUpdateViewModel(ShorebirdAppUpdateRepository());
    final dependencies = await testDependencies(appUpdate: updates);
    dependencies.session.enterDemo();
    await tester.pumpWidget(ChengxinApp(dependencies: dependencies));
    await tester.pumpAndSettle();
    expect(updates.state, AppUpdateState.unavailable);
    expect(find.byKey(const Key('schedule-grid')), findsOneWidget);

    final nativeNavigation = find.byType(NativeTabBar);
    if (nativeNavigation.evaluate().isNotEmpty) {
      tester.widget<NativeTabBar>(nativeNavigation).onSelected(3);
    } else {
      await tester.tap(find.byKey(const Key('nav-3')));
    }
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const Key('profile-check-update')),
      200,
    );
    await tester.pumpAndSettle();
    expect(find.text('当前安装包暂不支持在线更新'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await binding.takeScreenshot('ios-app-update-debug');
    await tester.pumpWidget(const SizedBox.shrink());
    dependencies.dispose();
  });
}
