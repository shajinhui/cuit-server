import 'dart:async';

import 'package:chengxin_youyou/app/app_dependencies.dart';
import 'package:chengxin_youyou/core/config/app_settings.dart';
import 'package:chengxin_youyou/core/network/api_exception.dart';
import 'package:chengxin_youyou/features/schedule/schedule.dart';
import 'package:chengxin_youyou/features/session/session.dart';
import 'package:chengxin_youyou/main.dart';
import 'package:chengxin_youyou/ui/components/brand_mark.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes/test_dependencies.dart';

void main() {
  for (final failure in [FailureKind.network, FailureKind.authentication]) {
    testWidgets('先显示缓存课表，后台刷新遇到 $failure 按原规则处理', (tester) async {
      final calendar = (await tester.runAsync(() async {
        await DemoScheduleRepository.prepare();
        return AcademicCalendar.load();
      }))!;
      final repository = _CachedScheduleRepository();
      final session = SessionViewModel(_OfflineSessionRepository());
      await session.restore();
      final dependencies = AppDependencies(
        session: session,
        calendar: calendar,
        settings: AppSettings(),
        createScheduleRepository: (_) => repository,
      );
      await tester.pumpWidget(
        AppBootstrap(createDependencies: () async => dependencies),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('schedule-grid')), findsOneWidget);
      expect(repository.refreshRequests, 1);
      expect(dependencies.schedule!.snapshot!.fromCache, isTrue);
      expect(find.byType(BrandMark), findsNothing);

      repository.refreshResult.completeError(
        ApiException('test-only failure', kind: failure),
      );
      await tester.pumpAndSettle();
      if (failure == FailureKind.authentication) {
        expect(session.student, isNull);
        expect(find.byKey(const Key('student-number')), findsOneWidget);
        expect(repository.invalidated, isTrue);
      } else {
        expect(session.student, isNotNull);
        expect(find.byKey(const Key('schedule-grid')), findsOneWidget);
        expect(dependencies.schedule!.error, contains('继续显示离线课表'));
      }
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  testWidgets('本机初始化结束后直接进入登录页，不展示品牌转圈页面', (tester) async {
    final initialization = Completer<AppDependencies>();
    var initialized = 0;
    await tester.pumpWidget(
      AppBootstrap(
        createDependencies: () => initialization.future,
        onInitialized: () => initialized++,
      ),
    );
    expect(find.byType(BrandMark), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(initialized, 0);

    final dependencies = (await tester.runAsync(testDependencies))!;
    initialization.complete(dependencies);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('student-number')), findsOneWidget);
    expect(find.byType(BrandMark), findsNothing);
    expect(initialized, 1);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('有本机身份时第一张实际页面就是课表，不闪现登录页', (tester) async {
    final dependencies = (await tester.runAsync(testDependencies))!;
    dependencies.session.enterDemo();
    await tester.pumpWidget(
      AppBootstrap(createDependencies: () async => dependencies),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('schedule-grid')), findsOneWidget);
    expect(find.byKey(const Key('student-number')), findsNothing);
    expect(find.byType(BrandMark), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('本机初始化失败仍可重试，重复点击不会并发创建依赖', (tester) async {
    var attempts = 0;
    var initialized = 0;
    final retry = Completer<AppDependencies>();
    await tester.pumpWidget(
      AppBootstrap(
        createDependencies: () {
          attempts++;
          if (attempts == 1) {
            return Future.error(StateError('test-only failure'));
          }
          return retry.future;
        },
        onInitialized: () => initialized++,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('启动未完成，请重试。'), findsOneWidget);
    expect(initialized, 1);
    await tester.tap(find.text('重新打开'));
    await tester.pump();
    await tester.tap(find.text('正在重试…'));
    await tester.pump();
    expect(attempts, 2);
    expect(find.byType(CircularProgressIndicator), findsNothing);

    retry.complete((await tester.runAsync(testDependencies))!);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('student-number')), findsOneWidget);
    expect(initialized, 1);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('启动组件已销毁时释放迟到的依赖，不再通知首帧', (tester) async {
    final initialization = Completer<AppDependencies>();
    var initialized = 0;
    await tester.pumpWidget(
      AppBootstrap(
        createDependencies: () => initialization.future,
        onInitialized: () => initialized++,
      ),
    );
    final dependencies = (await tester.runAsync(testDependencies))!;
    var notifications = 0;
    dependencies.session.addListener(() => notifications++);
    await tester.pumpWidget(const SizedBox.shrink());
    initialization.complete(dependencies);
    await tester.pump();
    dependencies.session.enterDemo();

    expect(notifications, 0);
    expect(initialized, 0);
    expect(tester.takeException(), isNull);
  });
}

class _OfflineSessionRepository implements SessionRepository {
  @override
  Future<RestoredSession?> restore() async =>
      const RestoredSession(Student.demo, offline: true);

  @override
  Future<Student> login(String number, String password) async =>
      throw StateError('not used');

  @override
  Future<void> logout() async {}
}

class _CachedScheduleRepository extends DemoScheduleRepository {
  final refreshResult = Completer<ScheduleSnapshot>();
  int refreshRequests = 0;
  bool invalidated = false;

  @override
  Future<ScheduleSnapshot> load(String id, {bool refresh = false}) async {
    if (refresh) {
      refreshRequests++;
      return refreshResult.future;
    }
    final result = await super.load(id);
    return ScheduleSnapshot(result.table, result.updatedAt, fromCache: true);
  }

  @override
  void invalidate() => invalidated = true;
}
