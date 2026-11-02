import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:chengxin_youyou/features/campus/data/campus_repository.dart';
import 'package:chengxin_youyou/features/campus/models/campus_models.dart';
import 'package:chengxin_youyou/features/campus/presentation/campus_page.dart';
import 'package:chengxin_youyou/features/campus/presentation/campus_widgets.dart';
import 'package:chengxin_youyou/features/community/models/community_models.dart';
import 'package:chengxin_youyou/features/community/presentation/community_pages.dart';
import 'package:chengxin_youyou/features/community/presentation/community_scope.dart';
import 'package:chengxin_youyou/features/community/presentation/community_view_model.dart';
import 'package:chengxin_youyou/ui/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:chengxin_youyou/features/session/session.dart';
import 'package:chengxin_youyou/app/app.dart';
import 'fakes/fake_community_repository.dart';
import 'fakes/test_dependencies.dart';

void main() {
  testWidgets('真实应用路由从我的打开资料、消息、收藏并正确返回', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repo = FakeCommunityRepository();
    final dependencies = (await tester.runAsync(
      () => testDependencies(
        campusRepository: repo,
        sessionRepository: _SwitchingSession(),
      ),
    ))!;
    await tester.runAsync(() async {
      await dependencies.session.login('test-account', 'test-only');
      // Finish the asynchronous platform-channel fixture before entering the
      // widget test's fake clock; this is not a production startup wait.
      await dependencies.schedule!.initialize();
    });
    await tester.pumpWidget(ChengxinApp(dependencies: dependencies));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('nav-3')));
    await tester.pumpAndSettle();
    expect(find.text('公开昵称'), findsOneWidget);
    expect(find.text('学校姓名（仅自己可见）'), findsOneWidget);
    for (final entry in [
      'profile-public-info',
      'profile-community-messages',
      'profile-community-favorites',
      'profile-community-home',
    ]) {
      await tester.scrollUntilVisible(
        find.byKey(Key(entry)),
        180,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.byKey(Key(entry)));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('nav-3')), findsNothing);
      expect(find.byTooltip('返回'), findsOneWidget);
      await tester.tap(find.byTooltip('返回'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('profile-public-info')), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
    await tester.pumpWidget(const SizedBox.shrink());
    dependencies.dispose();
  });

  testWidgets('同一代登录完成时身份变化仍重新绑定社区，旧资料不串到新账号', (tester) async {
    final repo = FakeCommunityRepository();
    final dependencies = (await tester.runAsync(
      () => testDependencies(
        campusRepository: repo,
        sessionRepository: _SwitchingSession(),
      ),
    ))!;
    await tester.runAsync(() async {
      await dependencies.session.login('account-a', 'test-only');
      final old = dependencies.community!;
      await old.loadProfile();
      repo.profile = const CampusAuthor(
        id: 'account-b',
        displayName: '第二位同学',
        avatarPreset: 3,
      );
      await dependencies.session.login('account-b', 'test-only');
      expect(dependencies.community, isNot(same(old)));
      await dependencies.community!.loadProfile();
      expect(old.profile, isNull);
      expect(dependencies.community!.profile!.id, 'account-b');
      expect(
        dependencies.schedule!.isLoading ||
            dependencies.schedule!.semesters.isNotEmpty,
        isTrue,
      );
    });
    dependencies.dispose();
  });

  test('旧作者字段兼容，新公开资料按版本覆盖已加载的自己', () async {
    final legacy = CampusAuthor.fromJson({
      'id': 'community-me',
      'display_name': '旧昵称',
      'avatar_preset': 2,
    });
    expect(legacy.profileVersion, 1);
    expect(legacy.avatarAssetId, isNull);
    final repo = FakeCommunityRepository();
    final model = CommunityViewModel(repo, repo);
    await model.loadProfile();
    await model.saveProfile(displayName: '新的公开昵称', avatarPreset: 4);
    expect(model.resolveAuthor(legacy).displayName, '新的公开昵称');
    expect(model.profile!.profileVersion, 2);
    model.dispose();
  });

  test('退出后的迟到资料响应不能写回；下一账号保持独立', () async {
    final first = FakeCommunityRepository()
      ..pendingProfile = Completer<CampusAuthor>();
    final old = CommunityViewModel(first, first);
    final task = old.loadProfile();
    old.dispose();
    final second = FakeCommunityRepository()
      ..profile = const CampusAuthor(
        id: 'second',
        displayName: '第二个账号',
        avatarPreset: 3,
      );
    final current = CommunityViewModel(second, second);
    await current.loadProfile();
    first.pendingProfile!.complete(first.profile);
    await task;
    expect(old.profile, isNull);
    expect(current.profile!.id, 'second');
    current.dispose();
  });

  test('旧服务端或断网不会因依赖重建无限重试，手动刷新可以恢复', () async {
    final repo = FakeCommunityRepository()
      ..profileError = const CampusRepositoryException('尚未上线', statusCode: 404);
    final model = CommunityViewModel(repo, repo);
    await model.loadProfile();
    await model.loadProfile();
    expect(repo.profileLoads, 1);
    expect(model.supported, isFalse);
    repo.profileError = null;
    await model.loadProfile(refresh: true);
    expect(model.supported, isTrue);
    expect(repo.profileLoads, 2);
    model.dispose();
  });

  testWidgets('公开资料必须确认公开范围后才保存；取消不会写入', (tester) async {
    final repo = FakeCommunityRepository();
    final model = CommunityViewModel(repo, repo);
    await tester.pumpWidget(_app(model, const CommunityProfileEditorPage()));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('community-nickname')), '新昵称');
    await tester.scrollUntilVisible(
      find.byKey(const Key('community-profile-save')),
      240,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byKey(const Key('community-profile-save')));
    await tester.pumpAndSettle();
    expect(find.text('保存公开资料？'), findsOneWidget);
    expect(repo.updates, 0);
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    expect(repo.updates, 0);
    await tester.pumpWidget(const SizedBox.shrink());
    model.dispose();
  });

  testWidgets('全部已读保留快照之后的新消息；消息列表仅使用服务端水位', (tester) async {
    final repo = FakeCommunityRepository();
    repo.inbox = CommunityInbox(
      page: CampusPageResult(
        items: [_message('2'), _message('1')],
        nextCursor: null,
        hasMore: false,
      ),
      readWatermark: '1',
      unreadCount: 2,
    );
    final model = CommunityViewModel(repo, repo);
    await tester.pumpWidget(_app(model, const CommunityListPage()));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.check_circle_outline_rounded), findsNWidgets(2));
    await tester.tap(find.text('全部已读'));
    await tester.pumpAndSettle();
    expect(repo.lastWatermark, '1');
    expect(model.unreadCount, 1);
    expect(find.byIcon(Icons.check_circle_outline_rounded), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    model.dispose();
  });

  testWidgets('确认保存公开资料后成功返回，未向服务端传学籍姓名', (tester) async {
    final repo = FakeCommunityRepository();
    final model = CommunityViewModel(repo, repo);
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => Scaffold(
            body: TextButton(
              onPressed: () => context.push('/edit'),
              child: const Text('编辑公开资料'),
            ),
          ),
          routes: [
            GoRoute(
              path: 'edit',
              builder: (_, _) => const CommunityProfileEditorPage(),
            ),
          ],
        ),
      ],
    );
    await tester.pumpWidget(
      MaterialApp.router(
        routerConfig: router,
        theme: AppTheme.build(Brightness.light),
        builder: (_, child) => CommunityScope(model: model, child: child!),
      ),
    );
    await tester.tap(find.text('编辑公开资料'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('community-nickname')),
      '我选择的昵称',
    );
    await tester.scrollUntilVisible(
      find.byKey(const Key('community-profile-save')),
      240,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byKey(const Key('community-profile-save')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('保存并公开'));
    await tester.pumpAndSettle();
    expect(repo.updates, 1);
    expect(model.profile!.displayName, '我选择的昵称');
    expect(find.text('编辑公开资料'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    router.dispose();
    model.dispose();
  });

  testWidgets('收藏取消失败保留原条目，重试成功再移除', (tester) async {
    final repo = FakeCommunityRepository()
      ..favoriteError = const CampusRepositoryException('网络错误');
    repo.favorites = const CampusPageResult(
      items: [
        CommunityFavorite(
          targetId: 'post',
          title: '已收藏的帖子',
          excerpt: '摘要',
          createdAt: '',
          available: false,
        ),
      ],
      nextCursor: null,
      hasMore: false,
    );
    final model = CommunityViewModel(repo, repo);
    await tester.pumpWidget(
      _app(model, const CommunityListPage(favorites: true)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('取消收藏'));
    await tester.pumpAndSettle();
    expect(find.text('已收藏的帖子'), findsOneWidget);
    repo.favoriteError = null;
    await tester.tap(find.byTooltip('取消收藏'));
    await tester.pumpAndSettle();
    expect(find.text('已收藏的帖子'), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
    model.dispose();
  });

  for (final scale in [1.0, 2.0, 3.0]) {
    testWidgets('社区入口 320 宽、$scale 倍字体无溢出且不重复加载资料', (tester) async {
      tester.view.physicalSize = const Size(320, 800);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = scale;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final repo = FakeCommunityRepository();
      final model = CommunityViewModel(repo, repo);
      await tester.pumpWidget(
        _app(model, Scaffold(body: CampusPage(repository: repo))),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('campus-notifications')),
        findsOneWidget,
      );
      expect(repo.profileLoads, 1);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      model.dispose();
    });
  }

  testWidgets('统一作者组件在资料变更后刷新昵称', (tester) async {
    final repo = FakeCommunityRepository();
    final model = CommunityViewModel(repo, repo);
    await model.loadProfile();
    await tester.pumpWidget(
      _app(
        model,
        const Scaffold(
          body: CampusAuthorName(
            author: CampusAuthor(
              id: 'community-me',
              displayName: '旧昵称',
              avatarPreset: 1,
            ),
          ),
        ),
      ),
    );
    expect(find.text('公开昵称'), findsOneWidget);
    await model.saveProfile(displayName: '统一新昵称', avatarPreset: 2);
    await tester.pump();
    expect(find.text('统一新昵称'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    model.dispose();
  });

  // Optional local visual QA; ordinary CI does not need fonts or write files.
  final capture = Platform.environment['COMMUNITY_CAPTURE_DIR'];
  final font = Platform.environment['COMMUNITY_PREVIEW_FONT'];
  if (capture != null && font != null) {
    for (final brightness in Brightness.values) {
      for (final screen in ['profile', 'inbox']) {
        testWidgets('导出社区 $screen ${brightness.name} 界面预览', (tester) async {
          tester.view.physicalSize = const Size(390, 844);
          tester.view.devicePixelRatio = 1;
          tester.view.padding = const FakeViewPadding(top: 24, bottom: 34);
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          addTearDown(tester.view.resetPadding);
          await tester.runAsync(() async {
            final bytes = await File(font).readAsBytes();
            for (final family in ['Roboto', 'Ahem', 'CommunityPreview']) {
              await (FontLoader(
                family,
              )..addFont(Future.value(ByteData.sublistView(bytes)))).load();
            }
            await (FontLoader('MaterialIcons')
                  ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf')))
                .load();
          });
          final repo = FakeCommunityRepository();
          repo.inbox = CommunityInbox(
            page: CampusPageResult(
              items: [_message('2'), _message('1')],
              nextCursor: null,
              hasMore: false,
            ),
            readWatermark: '2',
            unreadCount: 2,
          );
          final model = CommunityViewModel(repo, repo);
          final key = GlobalKey();
          final theme = AppTheme.build(brightness);
          await tester.pumpWidget(
            RepaintBoundary(
              key: key,
              child: MaterialApp(
                debugShowCheckedModeBanner: false,
                theme: theme.copyWith(
                  textTheme: theme.textTheme.apply(
                    fontFamily: 'CommunityPreview',
                  ),
                ),
                home: CommunityScope(
                  model: model,
                  child: screen == 'profile'
                      ? const CommunityProfileEditorPage()
                      : const CommunityListPage(),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          await tester.runAsync(() async {
            await Directory(capture).create(recursive: true);
            final boundary =
                key.currentContext!.findRenderObject()!
                    as RenderRepaintBoundary;
            final image = await boundary.toImage(pixelRatio: 2);
            final bytes = await image.toByteData(
              format: ui.ImageByteFormat.png,
            );
            await File(
              '$capture/$screen-${brightness.name}.png',
            ).writeAsBytes(bytes!.buffer.asUint8List());
            image.dispose();
          });
          await tester.pumpWidget(const SizedBox.shrink());
          model.dispose();
        });
      }
    }
  }
}

Widget _app(CommunityViewModel model, Widget child) => MaterialApp(
  theme: AppTheme.build(Brightness.light),
  home: CommunityScope(model: model, child: child),
);
CommunityNotification _message(String id) => CommunityNotification(
  id: id,
  kind: 'thread_reply',
  title: '公开帖子',
  excerpt: '回复正文',
  createdAt: '2026-10-20T10:00:00Z',
  isRead: false,
  available: true,
  threadId: 'thread-1',
  replyId: 'reply-$id',
  actor: const CampusAuthor(id: 'other', displayName: '另一位同学', avatarPreset: 1),
);

class _SwitchingSession implements SessionRepository {
  @override
  Future<RestoredSession?> restore() async => null;
  @override
  Future<Student> login(String number, String password) async =>
      Student(number: number, name: '仅自己可见的学校姓名', campus: '航空港校区');
  @override
  Future<void> logout() async {}
}
