import 'package:native_collator/native_collator.dart';
import 'package:chengxin_youyou/core/platform/app_platform.dart';

import '../models/course.dart';
import '../models/local_course.dart';
import '../models/schedule_order.dart';

typedef ScheduleOrderBuilder =
    Future<ScheduleOrder> Function(List<Course>, List<LocalCourse>);

Future<ScheduleOrder> prepareScheduleOrder(
  List<Course> courses,
  List<LocalCourse> local,
) async {
  final values = ScheduleOrder.values(courses, local).toList();
  if (isHarmonyOS) {
    // native_collator 尚未提供 OHOS 实现；保持稳定顺序，避免登录后因
    // 缺少 MethodChannel 让课表整体不可用。正式 OHOS ICU 适配后再替换。
    final fallback = [...values]..sort();
    return ScheduleOrder(chinese: fallback, standard: fallback);
  }
  final sorted = await Future.wait([
    NativeCollator.sort(values, 'zh-CN'),
    NativeCollator.sort(values, 'en-US'),
  ]);
  return ScheduleOrder(chinese: sorted[0], standard: sorted[1]);
}
