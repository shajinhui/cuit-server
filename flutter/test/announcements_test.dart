import 'dart:async';
import 'dart:convert';
import 'package:chengxin_youyou/features/announcements/announcements.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:chengxin_youyou/app/app.dart';
import 'fakes/test_dependencies.dart';

const message = AppAnnouncement(
  id: 'test-notice',
  revision: 1,
  title: '测试公告',
  body: '只用于离线测试的公告正文',
  autoShow: true,
);

class FakeAnnouncements implements AnnouncementRepository {
  AnnouncementSnapshot cache = AnnouncementSnapshot();
  List<AppAnnouncement> remote = [message];
  bool fail = false;
  bool closed = false;
  int fetches = 0;
  Completer<List<AppAnnouncement>>? pending;
  @override
  Future<AnnouncementSnapshot> readCache() async => cache;
  @override
  Future<List<AppAnnouncement>> fetch() async {
    fetches++;
    if (fail) throw StateError('offline');
    return pending?.future ?? remote;
  }

  @override
  Future<void> saveCache(AnnouncementSnapshot snapshot) async {
    cache = snapshot;
  }

  @override
  void dispose() {
    closed = true;
  }
}

void main() {
  test('再次刷新期间不自动弹旧消息，确认下架后删除旧候选', () async {
    final repo = FakeAnnouncements();
    final vm = AnnouncementViewModel(repo);
    await vm.refresh();
    repo.pending = Completer();
    final pending = vm.refresh(force: true);
    await Future<void>.delayed(Duration.zero);
    expect(vm.autoCandidate, isNull);
    repo.pending!.complete([]);
    await pending;
    expect(vm.latest, isNull);
    vm.dispose();
  });
  testWidgets('真实应用工具页接通公告，体验模式不自动打断导航', (tester) async {
    final vm = AnnouncementViewModel(FakeAnnouncements());
    final dependencies = (await tester.runAsync(
      () => testDependencies(announcements: vm),
    ))!;
    dependencies.session.enterDemo();
    await tester.pumpWidget(ChengxinApp(dependencies: dependencies));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('announcement-close')), findsNothing);
    await tester.tap(find.byKey(const Key('nav-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('tools-announcement')));
    await tester.pumpAndSettle();
    expect(find.text(message.body), findsOneWidget);
    await tester.tap(find.byKey(const Key('announcement-close')));
    await tester.pumpAndSettle();
    expect(vm.viewCount(message), 1);
    await tester.pumpWidget(const SizedBox.shrink());
    dependencies.dispose();
  });
  for (final scale in [1.0, 2.0, 3.0]) {
    testWidgets('公告在安卓窄屏 $scale 倍字体和深色下可阅读、可关闭', (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = scale;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final repo = FakeAnnouncements()
        ..remote = [
          AppAnnouncement(
            id: 'long-test',
            revision: 1,
            title: '较长标题的公告用于确认阅读布局和自动换行',
            body: '这是一份很长的虚构公告内容。\n' * 100,
            autoShow: true,
          ),
        ];
      final vm = AnnouncementViewModel(repo);
      await vm.refresh();
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: AnnouncementPresenter(
            viewModel: vm,
            allowed: true,
            child: Scaffold(
              body: AnnouncementTile(viewModel: vm, lightweight: true),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(find.byKey(const Key('announcement-close')));
      await tester.tap(find.byKey(const Key('announcement-close')));
      await tester.pumpAndSettle();
      expect(vm.viewCount(repo.remote.single), 1);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      vm.dispose();
    }, variant: TargetPlatformVariant.only(TargetPlatform.android));
  }
  test('同一内容跨两次启动展示后停止提醒，手动查看和新版本不受限制', () async {
    final repo = FakeAnnouncements();
    for (var i = 0; i < 2; i++) {
      final vm = AnnouncementViewModel(repo);
      await vm.refresh();
      expect(vm.autoCandidate?.id, message.id);
      expect(vm.beginPresentation(message, automatic: true), isTrue);
      expect(vm.beginPresentation(message), isFalse);
      await vm.finishPresentation(message);
      expect(vm.autoCandidate, isNull);
      vm.dispose();
    }
    final vm = AnnouncementViewModel(repo);
    await vm.refresh();
    expect(vm.viewCount(message), 2);
    expect(vm.autoCandidate, isNull);
    expect(vm.beginPresentation(message), isTrue);
    await vm.finishPresentation(message);
    expect(vm.viewCount(message), 2);
    vm.dispose();
    repo.remote = [
      const AppAnnouncement(
        id: 'test-notice',
        revision: 2,
        title: '已更新',
        body: '新内容',
        autoShow: true,
      ),
    ];
    final updated = AnnouncementViewModel(repo);
    await updated.refresh();
    expect(updated.autoCandidate?.revision, 2);
    expect(updated.viewCount(updated.latest!), 0);
    updated.dispose();
  });
  test('断网保留缓存并禁止自动弹旧消息，成功空列表代表全部下架', () async {
    final repo = FakeAnnouncements()
      ..cache = AnnouncementSnapshot(items: [message])
      ..fail = true;
    final vm = AnnouncementViewModel(repo);
    await vm.refresh();
    expect(vm.latest?.title, '测试公告');
    expect(vm.isOffline, isTrue);
    expect(vm.autoCandidate, isNull);
    repo.fail = false;
    repo.remote = [];
    await vm.refresh(force: true);
    expect(vm.items, isEmpty);
    expect(repo.cache.items, isEmpty);
    expect(vm.error, isNull);
    vm.dispose();
  });
  test('关闭自动提醒、未开始与已过期公告不自动弹出', () async {
    final now = DateTime.utc(2026, 10, 14);
    final repo = FakeAnnouncements()
      ..remote = [
        AppAnnouncement(
          id: 'future',
          revision: 1,
          title: '未开始',
          body: '测试',
          autoShow: true,
          startsAt: now.add(const Duration(days: 1)),
        ),
        AppAnnouncement(
          id: 'expired',
          revision: 1,
          title: '已结束',
          body: '测试',
          autoShow: true,
          expiresAt: now,
        ),
        const AppAnnouncement(
          id: 'manual',
          revision: 1,
          title: '仅手动查看',
          body: '测试',
          autoShow: false,
        ),
      ];
    final vm = AnnouncementViewModel(repo, now: () => now);
    await vm.refresh();
    expect(vm.items.map((item) => item.id), ['manual']);
    expect(vm.autoCandidate, isNull);
    vm.dispose();
  });
  test('合并并发刷新、自动检查节流，释放后不接收迟到结果', () async {
    final repo = FakeAnnouncements()..pending = Completer();
    final vm = AnnouncementViewModel(repo);
    final first = vm.refresh();
    expect(identical(first, vm.refresh(force: true)), isTrue);
    await Future<void>.delayed(Duration.zero);
    expect(repo.fetches, 1);
    repo.pending!.complete([message]);
    await first;
    await vm.refresh();
    expect(repo.fetches, 1);
    repo.pending = Completer();
    final second = vm.refresh(force: true);
    await Future<void>.delayed(Duration.zero);
    vm.dispose();
    repo.pending!.complete([]);
    await second;
    expect(vm.latest?.id, message.id);
    expect(repo.closed, isTrue);
  });
  test('模型拒绝脚本、HTTP、携带账号链接以及无效版本', () {
    final base = message.toJson();
    for (final url in [
      'javascript:alert(1)',
      'http://example.invalid',
      'https://user:pass@example.invalid',
      'https://example.invalid/\npath',
    ]) {
      expect(
        () => AppAnnouncement.fromJson({
          ...base,
          'action': {'label': '查看', 'url': url},
        }),
        throwsFormatException,
      );
    }
    expect(
      () => AppAnnouncement.fromJson({...base, 'revision': 0}),
      throwsFormatException,
    );
    expect(
      AppAnnouncement.fromJson({
        ...base,
        'action': {'label': '查看', 'url': 'https://example.invalid'},
      }).actionUrl?.scheme,
      'https',
    );
  });
  test('公开请求只带平台，不携带凭证；缓存损坏可恢复', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final dio = Dio(
      BaseOptions(baseUrl: 'https://announcement.example.invalid'),
    );
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          expect(options.path, '/api/v1/ratings/announcements');
          expect(options.queryParameters, {'platform': 'android'});
          expect(options.headers.containsKey('Authorization'), isFalse);
          expect(options.headers.containsKey('Cookie'), isFalse);
          handler.resolve(
            Response(
              requestOptions: options,
              statusCode: 200,
              data: {
                'code': 0,
                'data': {
                  'items': [message.toJson()],
                },
              },
            ),
          );
        },
      ),
    );
    final repo = DefaultAnnouncementRepository(
      preferences: prefs,
      platform: 'android',
      baseUrl: dio.options.baseUrl,
      dio: dio,
    );
    expect((await repo.fetch()).single.id, message.id);
    await repo.saveCache(
      AnnouncementSnapshot(items: [message], views: {message.viewKey: 2}),
    );
    expect((await repo.readCache()).views[message.viewKey], 2);
    final key = prefs.getKeys().single;
    await prefs.setString(key, jsonEncode({'items': 'broken', 'views': {}}));
    expect((await repo.readCache()).items, isEmpty);
    repo.dispose();
  });
  testWidgets('安卓启动弹窗只显示一次，关闭后工具页仍可手动查看', (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final vm = AnnouncementViewModel(FakeAnnouncements());
    await vm.refresh();
    await tester.pumpWidget(
      MaterialApp(
        home: AnnouncementPresenter(
          viewModel: vm,
          allowed: true,
          child: Scaffold(
            body: AnnouncementTile(viewModel: vm, lightweight: true),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();
    expect(find.text(message.body), findsOneWidget);
    await tester.tap(find.byKey(const Key('announcement-close')));
    await tester.pumpAndSettle();
    expect(find.text(message.body), findsNothing);
    expect(vm.viewCount(message), 1);
    await tester.tap(find.byKey(const Key('tools-announcement')));
    await tester.pumpAndSettle();
    expect(find.text(message.body), findsOneWidget);
    await tester.tap(find.byKey(const Key('announcement-close')));
    await tester.pumpAndSettle();
    expect(vm.viewCount(message), 2);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    vm.dispose();
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));
}
