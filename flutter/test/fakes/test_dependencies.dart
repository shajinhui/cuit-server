import 'package:chengxin_youyou/app/app_dependencies.dart';
import 'package:chengxin_youyou/features/campus/data/campus_repository.dart';
import 'package:chengxin_youyou/core/config/app_settings.dart';
import 'package:chengxin_youyou/core/network/api_exception.dart';
import 'package:chengxin_youyou/features/session/session.dart';
import 'package:chengxin_youyou/features/schedule/schedule.dart';
import 'package:chengxin_youyou/features/app_update/presentation/app_update_view_model.dart';

class RejectedSession implements SessionRepository {
  @override
  Future<Student> login(String number, String password) async =>
      throw const ApiException('学号或密码错误');
  @override
  Future<void> logout() async {}
  @override
  Future<RestoredSession?> restore() async => null;
}

Future<AppDependencies> testDependencies({
  AppUpdateViewModel? appUpdate,
  CampusRepository? campusRepository,
}) async {
  await DemoScheduleRepository.prepare();
  final session = SessionViewModel(RejectedSession());
  await session.restore();
  return AppDependencies(
    session: session,
    calendar: await AcademicCalendar.load(),
    settings: AppSettings(),
    createScheduleRepository: (_) => DemoScheduleRepository(),
    appUpdate: appUpdate,
    campusRepository: campusRepository,
  );
}
