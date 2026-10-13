import 'dart:async';

import 'package:chengxin_youyou/core/config/app_config.dart';
import 'package:chengxin_youyou/core/config/app_settings.dart';
import 'package:chengxin_youyou/core/network/api_client.dart';
import 'package:chengxin_youyou/core/storage/app_storage.dart';
import 'package:chengxin_youyou/core/storage/cache_storage.dart';
import 'package:chengxin_youyou/core/platform/app_platform.dart';
import 'package:chengxin_youyou/features/schedule/data/schedule_local_store.dart';
import 'package:chengxin_youyou/features/schedule/schedule.dart';
import 'package:chengxin_youyou/features/campus/data/campus_repository.dart';
import 'package:chengxin_youyou/features/campus/data/default_campus_repository.dart';
import 'package:chengxin_youyou/features/session/session.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../features/profile/data/profile_avatar.dart';
import '../features/profile/data/profile_repository.dart';
import '../features/autorun/data/autorun_repository.dart';
import '../features/app_update/data/shorebird_app_update_repository.dart';
import '../features/app_update/data/unavailable_app_update_repository.dart';
import '../features/app_update/presentation/app_update_view_model.dart';
import '../core/platform/desktop_widgets.dart';
import '../features/schedule/models/desktop_widget_snapshot.dart';
import '../features/schedule/presentation/desktop_widget_controller.dart';

/// 依赖只在入口组装，页面无需查找全局单例。
class AppDependencies {
  AppDependencies({
    required this.session,
    required this.calendar,
    required this.settings,
    required this.createScheduleRepository,
    this.api,
    this.campusRepository,
    this.createScheduleLocalStore,
    this.userStorage,
    this.autoRunRepository,
    this.appUpdate,
    this.desktopWidgets,
    ProfileRepository? profileRepository,
  }) : profileRepository =
           profileRepository ?? (api == null ? null : ProfileRepository(api)) {
    session.addListener(_syncSchedule);
    _syncSchedule();
  }
  final SessionViewModel session;
  final AcademicCalendar calendar;
  final AppSettings settings;
  final ScheduleRepository Function(Student student) createScheduleRepository;
  final ApiClient? api;
  final CampusRepository? campusRepository;
  final ScheduleLocalStore Function(Student)? createScheduleLocalStore;
  final AppStorage? userStorage;
  final AutoRunRepository? autoRunRepository;
  final ProfileRepository? profileRepository;
  final AppUpdateViewModel? appUpdate;
  final DesktopWidgets? desktopWidgets;
  DesktopWidgetController? desktopWidget;
  ProfileAvatar? avatar;
  ScheduleViewModel? schedule;
  int _sessionGeneration = -1;
  bool _widgetOpenRequested = false;

  static Future<AppDependencies> create() async {
    const config = AppConfig();
    final calendar = await AcademicCalendar.load();
    final preferences = await SharedPreferences.getInstance();
    // 浏览器由 Cookie 管理会话；不把身份另外写入 localStorage。
    final privateStorage = kIsWeb
        ? MemoryAppStorage()
        : isHarmonyOS
        ? const OhosSecureAppStorage()
        : const SecureAppStorage(FlutterSecureStorage());
    final cacheStorage = await createCacheStorage();
    final api = await ApiClient.create(config.apiBaseUrl, privateStorage);
    final session = SessionViewModel(
      DefaultSessionRepository(
        api,
        privateStorage,
        clearUserData: (account) =>
            DefaultScheduleRepository(api, cacheStorage, account).clear(),
      ),
    );
    final dependencies = AppDependencies(
      session: session,
      calendar: calendar,
      settings: AppSettings(preferences: preferences),
      api: api,
      campusRepository: DefaultCampusRepository(api),
      autoRunRepository: AutoRunRepository(privateStorage),
      appUpdate: AppUpdateViewModel(
        isHarmonyOS
            ? const UnavailableAppUpdateRepository()
            : ShorebirdAppUpdateRepository(),
      ),
      userStorage: cacheStorage,
      desktopWidgets: NativeDesktopWidgets.supported
          ? NativeDesktopWidgets()
          : null,
      createScheduleLocalStore: (student) => ScheduleLocalStore(
        cacheStorage,
        'v1:${api.dio.options.baseUrl}:${student.number}:local',
      ),
      createScheduleRepository: (student) =>
          DefaultScheduleRepository(api, cacheStorage, student.number),
    );
    if (config.startInDemo) {
      session.enterDemo();
    } else {
      await session.restore();
    }
    return dependencies;
  }

  void _syncSchedule() {
    // 登录开始和成功属于同一代请求，只有拿到身份后才能创建课表。
    final student = session.student;
    if (student == null && !session.isRestoring) {
      _publishWidgetMessage('loggedOut', '登录后查看今日课程');
    }
    if (_sessionGeneration == session.generation &&
        (student == null || schedule != null)) {
      return;
    }
    if (_sessionGeneration != session.generation) {
      campusRepository?.clearSession();
    }
    _sessionGeneration = session.generation;
    avatar?.dispose();
    avatar = null;
    desktopWidget?.dispose();
    desktopWidget = null;
    schedule?.removeListener(_openWidgetScheduleIfReady);
    schedule?.dispose();
    schedule = null;
    if (student == null) return;
    avatar = ProfileAvatar(
      session.isDemo ? MemoryAppStorage() : userStorage ?? MemoryAppStorage(),
      'v1:${api?.dio.options.baseUrl ?? 'demo'}:${student.number}:avatar',
    );
    unawaited(avatar!.initialize());
    final repository = session.isDemo
        ? DemoScheduleRepository()
        : createScheduleRepository(student);
    schedule = ScheduleViewModel(
      repository,
      calendar,
      localStore: session.isDemo
          ? null
          : createScheduleLocalStore?.call(student),
      onOnline: session.markOnline,
      onSessionExpired: () => unawaited(session.logout(expired: true)),
    );
    schedule!.addListener(_openWidgetScheduleIfReady);
    if (desktopWidgets != null) {
      _publishWidgetMessage(
        session.isDemo ? 'demo' : 'loading',
        session.isDemo ? '登录真实账号后添加课表小组件' : '打开应用同步课表',
      );
      if (!session.isDemo) {
        desktopWidget = DesktopWidgetController(
          platform: desktopWidgets!,
          schedule: schedule!,
          campus: student.campus,
        );
      }
    }
    unawaited(schedule!.initialize());
  }

  void _publishWidgetMessage(String status, String message) {
    unawaited(
      desktopWidgets
          ?.publish(desktopWidgetMessage(status, message))
          .catchError((Object _) {}),
    );
  }

  /// 点击桌面卡片后回到今天；登录或课表初始化尚未完成时保留请求。
  void openWidgetSchedule() {
    _widgetOpenRequested = true;
    _openWidgetScheduleIfReady();
  }

  void _openWidgetScheduleIfReady() {
    final vm = schedule;
    if (!_widgetOpenRequested ||
        vm == null ||
        vm.isLoading ||
        vm.isRefreshing) {
      return;
    }
    if (vm.semesters.isEmpty) return;
    _widgetOpenRequested = false;
    final current = calendar.semesterForDate(DateTime.now());
    final semester = vm.semesters
        .where(
          (semester) =>
              semester.schoolYear == current.schoolYear &&
              semester.term == current.term,
        )
        .firstOrNull;
    if (semester != null && semester.id != vm.selectedSemester?.id) {
      unawaited(
        vm.selectSemester(semester).then((_) {
          if (identical(vm, schedule)) vm.resetWeekSelection();
        }),
      );
    } else {
      vm.resetWeekSelection();
    }
  }

  void dispose() {
    session.removeListener(_syncSchedule);
    desktopWidgets?.onOpenSchedule = null;
    desktopWidget?.dispose();
    schedule?.removeListener(_openWidgetScheduleIfReady);
    schedule?.dispose();
    campusRepository?.dispose();
    autoRunRepository?.dispose();
    avatar?.dispose();
    session.dispose();
    settings.dispose();
    appUpdate?.dispose();
    api?.dispose();
  }
}
