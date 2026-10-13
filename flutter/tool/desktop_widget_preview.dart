import 'package:chengxin_youyou/app/app.dart';
import 'package:chengxin_youyou/app/app_dependencies.dart';
import 'package:chengxin_youyou/core/config/app_settings.dart';
import 'package:chengxin_youyou/core/platform/desktop_widgets.dart';
import 'package:chengxin_youyou/features/session/session.dart';
import 'package:flutter/material.dart';

import '../test/fakes/desktop_widget_fakes.dart';

/// 仅用于本地原生小组件验收，使用假账号与虚构课程，不访问真实教务服务。
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final session = SessionViewModel(WidgetSessionRepository());
  await session.restore();
  final dependencies = AppDependencies(
    session: session,
    calendar: widgetCalendar(),
    settings: AppSettings(),
    desktopWidgets: NativeDesktopWidgets(),
    createScheduleRepository: (_) => WidgetScheduleRepository(),
  );
  runApp(ChengxinApp(dependencies: dependencies));
}
