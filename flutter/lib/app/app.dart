import 'dart:async';

import '../features/profile/presentation/plan_completion_page.dart';
import '../features/profile/presentation/feedback_page.dart';
import '../features/profile/presentation/about_page.dart';
import '../features/app_update/presentation/app_update_tile.dart';

import 'package:chengxin_youyou/features/schedule/presentation/schedule_page.dart';
import 'package:chengxin_youyou/features/session/presentation/login_page.dart';
import 'package:chengxin_youyou/features/session/presentation/profile_page.dart';
import 'package:chengxin_youyou/features/session/session.dart';
import 'package:chengxin_youyou/features/campus/models/campus_models.dart';
import 'package:chengxin_youyou/features/campus/presentation/campus_page.dart';
import 'package:chengxin_youyou/features/campus/presentation/rating_board_page.dart';
import 'package:chengxin_youyou/features/campus/presentation/rating_item_page.dart';
import 'package:chengxin_youyou/features/campus/presentation/rating_editor_page.dart';
import 'package:chengxin_youyou/features/campus/presentation/ratings_mine_page.dart';
import 'package:chengxin_youyou/features/campus/presentation/marketplace_item_page.dart';
import 'package:chengxin_youyou/features/campus/presentation/marketplace_editor_page.dart';
import 'package:chengxin_youyou/features/campus/presentation/marketplace_mine_page.dart';
import 'package:chengxin_youyou/features/campus/presentation/forum_thread_page.dart';
import 'package:chengxin_youyou/features/campus/presentation/forum_editor_page.dart';
import 'package:chengxin_youyou/features/campus/presentation/forum_mine_page.dart';
import 'package:chengxin_youyou/ui/theme/app_theme.dart';
import 'package:chengxin_youyou/features/tools/presentation/tools_page.dart';
import 'package:chengxin_youyou/features/tools/presentation/academic_tool_pages.dart';
import 'package:chengxin_youyou/features/tools/presentation/calendar_page.dart';
import 'package:chengxin_youyou/features/tools/presentation/campus_map_page.dart';
import 'package:chengxin_youyou/features/tools/presentation/library_page.dart';
import 'package:chengxin_youyou/features/tools/presentation/past_exams_page.dart';
import 'package:chengxin_youyou/features/tools/presentation/autorun_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'app_dependencies.dart';
import 'app_shell.dart';
import '../features/schedule/presentation/desktop_widget_page.dart';

class ChengxinApp extends StatefulWidget {
  const ChengxinApp({super.key, required this.dependencies});
  final AppDependencies dependencies;
  @override
  State<ChengxinApp> createState() => _ChengxinAppState();
}

class _ChengxinAppState extends State<ChengxinApp> {
  @override
  void initState() {
    super.initState();
    // 热更新独立于账号和业务初始化，不等待网络检查才展示页面。
    unawaited(widget.dependencies.appUpdate?.checkAndDownload());
    unawaited(widget.dependencies.announcements?.refresh());
    widget.dependencies.desktopWidgets?.onOpenSchedule = _openWidgetSchedule;
    unawaited(_consumeWidgetLaunch());
  }

  Future<void> _consumeWidgetLaunch() async {
    try {
      if (await widget.dependencies.desktopWidgets?.consumeLaunch() == true &&
          mounted) {
        _openWidgetSchedule();
      }
    } catch (_) {
      // 桌面能力不可用时仍正常启动主应用。
    }
  }

  void _openWidgetSchedule() {
    if (!mounted) return;
    _router.go('/schedule');
    widget.dependencies.openWidgetSchedule();
  }

  late final GoRouter _router = GoRouter(
    initialLocation: '/schedule',
    refreshListenable: widget.dependencies.session,
    redirect: (context, state) {
      final loggedIn = widget.dependencies.session.student != null;
      if (!loggedIn && state.matchedLocation != '/login') return '/login';
      if (loggedIn && state.matchedLocation == '/login') return '/schedule';
      return null;
    },
    routes: [
      GoRoute(path: '/login', builder: (context, state) => const LoginPage()),
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => AppShell(
          navigationShell: shell,
          hideBottomBar: ![
            '/schedule',
            '/tools',
            '/campus',
            '/profile',
          ].contains(state.uri.path),
          onScheduleActivated: () =>
              widget.dependencies.schedule?.resetWeekSelection(),
          announcements: widget.dependencies.announcements,
          allowAnnouncements: !widget.dependencies.session.isDemo,
        ),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/schedule',
                builder: (context, state) {
                  final session = context.watch<SessionViewModel>();
                  final schedule = widget.dependencies.schedule;
                  if (schedule == null || session.student == null) {
                    return const SizedBox.shrink();
                  }
                  return SchedulePage(
                    viewModel: schedule,
                    student: session.student!,
                    isDemo: session.isDemo,
                    isOffline: session.isOffline,
                  );
                },
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/tools',
                builder: (context, state) =>
                    ToolsPage(announcements: widget.dependencies.announcements),
              ),
              GoRoute(
                path: '/classrooms',
                name: 'classrooms',
                builder: (context, state) =>
                    ClassroomsPage(api: widget.dependencies.api),
              ),
              GoRoute(
                path: '/grades',
                name: 'grades',
                builder: (context, state) =>
                    GradesPage(api: widget.dependencies.api),
              ),
              GoRoute(
                path: '/calendar',
                name: 'calendar',
                builder: (context, state) => const AcademicCalendarPage(),
              ),
              GoRoute(
                path: '/exams',
                name: 'exams',
                builder: (context, state) =>
                    ExamsPage(api: widget.dependencies.api),
              ),
              GoRoute(
                path: '/campus-map',
                name: 'campus-map',
                builder: (context, state) => const CampusMapPage(),
              ),
              GoRoute(
                path: '/campus-run',
                name: 'autorun',
                builder: (context, state) => AutoRunPage(
                  repository: widget.dependencies.autoRunRepository,
                ),
              ),
              GoRoute(
                path: '/past-exams',
                name: 'past-exams',
                builder: (context, state) => const PastExamsPage(),
              ),
              GoRoute(
                path: '/library',
                name: 'library',
                builder: (context, state) =>
                    LibraryPage(api: widget.dependencies.api),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/campus',
                name: 'campus',
                builder: (context, state) {
                  final session = context.watch<SessionViewModel>();
                  return CampusPage(
                    repository: widget.dependencies.campusRepository,
                    sessionGeneration: session.generation,
                  );
                },
                routes: [
                  GoRoute(
                    path: 'ratings/new',
                    name: 'rating-create-board',
                    builder: (context, state) => RatingEditorPage(
                      repository: widget.dependencies.campusRepository,
                    ),
                  ),
                  GoRoute(
                    path: 'ratings/mine',
                    name: 'ratings-mine',
                    builder: (context, state) => RatingsMinePage(
                      repository: widget.dependencies.campusRepository,
                    ),
                  ),
                  GoRoute(
                    path: 'ratings/boards/:boardId',
                    name: 'rating-board',
                    builder: (context, state) => RatingBoardPage(
                      repository: widget.dependencies.campusRepository,
                      boardId: state.pathParameters['boardId']!,
                    ),
                    routes: [
                      GoRoute(
                        path: 'items/new',
                        name: 'rating-create-item',
                        builder: (context, state) => RatingEditorPage(
                          repository: widget.dependencies.campusRepository,
                          boardId: state.pathParameters['boardId'],
                        ),
                      ),
                    ],
                  ),
                  GoRoute(
                    path: 'ratings/items/:itemId',
                    name: 'rating-item',
                    builder: (context, state) => RatingItemPage(
                      repository: widget.dependencies.campusRepository,
                      itemId: state.pathParameters['itemId']!,
                    ),
                  ),
                  GoRoute(
                    path: 'marketplace/new',
                    name: 'marketplace-create',
                    builder: (context, state) => MarketplaceEditorPage(
                      repository: widget.dependencies.campusRepository,
                      initialType: state.uri.queryParameters['type'] ?? 'sell',
                    ),
                  ),
                  GoRoute(
                    path: 'marketplace/mine',
                    name: 'marketplace-mine',
                    builder: (context, state) => MarketplaceMinePage(
                      repository: widget.dependencies.campusRepository,
                      initialType: state.uri.queryParameters['type'] ?? 'sell',
                    ),
                  ),
                  GoRoute(
                    path: 'marketplace/items/:itemId',
                    name: 'marketplace-item',
                    builder: (context, state) => MarketplaceItemPage(
                      repository: widget.dependencies.campusRepository,
                      itemId: state.pathParameters['itemId']!,
                    ),
                  ),
                  GoRoute(
                    path: 'forum/new',
                    name: 'forum-create',
                    builder: (context, state) => ForumEditorPage(
                      repository: widget.dependencies.campusRepository,
                    ),
                  ),
                  GoRoute(
                    path: 'forum/mine',
                    name: 'forum-mine',
                    builder: (context, state) => ForumMinePage(
                      repository: widget.dependencies.campusRepository,
                    ),
                  ),
                  GoRoute(
                    path: 'forum/threads/:threadId',
                    name: 'forum-thread',
                    builder: (context, state) => ForumThreadPage(
                      repository: widget.dependencies.campusRepository,
                      threadId: state.pathParameters['threadId']!,
                    ),
                  ),
                  GoRoute(
                    path: 'forum/threads/:threadId/edit',
                    name: 'forum-edit',
                    builder: (context, state) {
                      final extra = state.extra;
                      if (extra is ForumThread) {
                        return ForumEditorPage(
                          repository: widget.dependencies.campusRepository,
                          editingThread: extra,
                        );
                      }
                      // 直接打开编辑链接而没有原帖数据时，退回帖子详情。
                      return ForumThreadPage(
                        repository: widget.dependencies.campusRepository,
                        threadId: state.pathParameters['threadId']!,
                      );
                    },
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/profile',
                builder: (context, state) {
                  context.watch<SessionViewModel>();
                  final appUpdate = widget.dependencies.appUpdate;
                  return ProfilePage(
                    avatar: widget.dependencies.avatar,
                    updateTile: appUpdate == null
                        ? null
                        : AppUpdateTile(viewModel: appUpdate),
                    desktopWidgetTile:
                        widget.dependencies.desktopWidgets == null
                        ? null
                        : ListTile(
                            leading: const Icon(Icons.widgets_outlined),
                            title: const Text('桌面小组件'),
                            subtitle: const Text('今日课程 · 下一节课'),
                            trailing: const Icon(Icons.chevron_right_rounded),
                            onTap: () => context.pushNamed('desktop-widget'),
                          ),
                  );
                },
                routes: [
                  if (widget.dependencies.desktopWidgets != null)
                    GoRoute(
                      path: 'desktop-widget',
                      name: 'desktop-widget',
                      builder: (context, state) => DesktopWidgetPage(
                        platform: widget.dependencies.desktopWidgets!,
                        controller: widget.dependencies.desktopWidget,
                      ),
                    ),
                  GoRoute(
                    path: 'plan-completion',
                    name: 'plan-completion',
                    builder: (context, state) => PlanCompletionPage(
                      repository: widget.dependencies.session.isDemo
                          ? null
                          : widget.dependencies.profileRepository,
                      onSessionExpired: () => unawaited(
                        widget.dependencies.session.logout(expired: true),
                      ),
                    ),
                  ),
                  GoRoute(
                    path: 'about',
                    name: 'about',
                    builder: (context, state) => const AboutPage(),
                  ),
                  GoRoute(
                    path: 'feedback',
                    name: 'feedback',
                    builder: (context, state) => FeedbackPage(
                      repository: widget.dependencies.session.isDemo
                          ? null
                          : widget.dependencies.profileRepository,
                      onSessionExpired: () => unawaited(
                        widget.dependencies.session.logout(expired: true),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    ],
  );
  @override
  void dispose() {
    widget.dependencies.desktopWidgets?.onOpenSchedule = null;
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MultiProvider(
    providers: [
      ChangeNotifierProvider.value(value: widget.dependencies.session),
      ChangeNotifierProvider.value(value: widget.dependencies.settings),
    ],
    child: ListenableBuilder(
      listenable: widget.dependencies.settings,
      builder: (context, _) => MaterialApp.router(
        title: '成信友友',
        debugShowCheckedModeBanner: false,
        routerConfig: _router,
        theme: AppTheme.build(Brightness.light),
        darkTheme: AppTheme.build(Brightness.dark),
        themeMode: widget.dependencies.settings.themeMode,
        locale: const Locale('zh', 'CN'),
        supportedLocales: const [Locale('zh', 'CN')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
      ),
    ),
  );
}
