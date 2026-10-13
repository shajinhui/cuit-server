import 'package:flutter_test/flutter_test.dart';
import 'package:chengxin_youyou/core/storage/app_storage.dart';
import 'package:chengxin_youyou/core/network/api_exception.dart';
import 'package:chengxin_youyou/features/schedule/data/schedule_local_store.dart';
import 'package:chengxin_youyou/features/schedule/schedule.dart';
import 'package:chengxin_youyou/features/schedule/models/local_course.dart';
import 'package:chengxin_youyou/features/schedule/models/semester.dart';

class FailingRefresh extends DemoScheduleRepository {
  bool fail = false;
  @override
  Future<ScheduleSnapshot> load(String id, {bool refresh = false}) {
    if (fail) throw const ApiException('离线', kind: FailureKind.network);
    return super.load(id, refresh: refresh);
  }
}

class FailingStorage extends MemoryAppStorage {
  bool fail = false;
  @override
  Future<void> write(String key, String value) async {
    if (fail) throw StateError('存储不可用');
    await super.write(key, value);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('手动课程、覆盖、配色和透明度持久化，刷新不丢失，历史学期隔离', () async {
    final calendar = await AcademicCalendar.load(),
        storage = MemoryAppStorage();
    final local = ScheduleLocalStore(storage, 'one:local');
    ScheduleViewModel create() => ScheduleViewModel(
      DemoScheduleRepository(),
      calendar,
      localStore: local,
      now: () => DateTime(2026, 9, 30),
      onSessionExpired: () {},
    );
    final vm = create();
    await vm.initialize();
    final semester = vm.selectedSemester!.id;
    await vm.saveCourse(
      LocalCourse(
        id: 'manual',
        semesterId: semester,
        name: '自习',
        room: '图书馆',
        day: 7,
        start: 3,
        end: 4,
        weeks: [1, 3, 8],
      ),
    );
    final school = vm.entriesFor(1).firstWhere((b) => !b.isManual);
    await vm.saveCourse(
      LocalCourse(
        id: school.id,
        targetId: school.id,
        semesterId: semester,
        name: '本机改名',
        room: 'H999',
        day: 6,
        start: 2,
        end: 3,
        weeks: [2, 4],
      ),
    );
    await vm.setColor(school.colorKey, 14);
    await vm.setOpacity(.2);
    await vm.refresh();
    expect(vm.manualCourses.single.weeks, [1, 3, 8]);
    expect(vm.overrides.single.name, '本机改名');
    vm.dispose();
    final restored = create();
    await restored.initialize();
    expect(restored.local.opacity, .2);
    expect(restored.entriesFor(2).first.tone, 14);
    expect(restored.entriesFor(2).first.name, '本机改名');
    await restored.selectSemester(restored.semesters[1]);
    expect(restored.manualCourses, isEmpty);
    expect(restored.overrides, isEmpty);
    restored.dispose();
  });
  test('刷新或切学期失败保留可用课表和用户选周', () async {
    final repo = FailingRefresh();
    final vm = ScheduleViewModel(
      repo,
      await AcademicCalendar.load(),
      now: () => DateTime(2026, 9, 30),
      onSessionExpired: () {},
    );
    await vm.initialize();
    vm.selectWeek(5);
    final table = vm.snapshot;
    repo.fail = true;
    await vm.refresh();
    expect(vm.snapshot, same(table));
    expect(vm.selectedWeek, 5);
    expect(vm.error, contains('离线课表'));
    await vm.selectSemester(vm.semesters[1]);
    expect(vm.selectedSemester!.id, DemoScheduleRepository.semester.id);
    expect(vm.snapshot, same(table));
    vm.dispose();
  });
  test('保存失败不显示为成功，也不删除现有本机课程', () async {
    final storage = FailingStorage();
    final vm = ScheduleViewModel(
      DemoScheduleRepository(),
      await AcademicCalendar.load(),
      localStore: ScheduleLocalStore(storage, 'test'),
      onSessionExpired: () {},
    );
    await vm.initialize();
    storage.fail = true;
    await expectLater(
      vm.saveCourse(
        LocalCourse(
          id: 'manual',
          semesterId: vm.selectedSemester!.id,
          name: '失败课程',
          room: '',
          day: 1,
          start: 1,
          end: 2,
          weeks: [1],
        ),
      ),
      throwsStateError,
    );
    expect(vm.manualCourses, isEmpty);
    vm.dispose();
  });
  test('校历和周次与原版一致：全局当前周、历史学期、手选日期及重新激活', () async {
    final vm = ScheduleViewModel(
      DemoScheduleRepository(),
      await AcademicCalendar.load(),
      now: () => DateTime(2026, 9, 30),
      onSessionExpired: () {},
    );
    await vm.initialize();
    expect(vm.currentWeek, 4);
    expect(vm.selectedWeek, 1);
    expect(vm.weekStatus, '历史学期');
    expect(vm.dateTitle, '2026/3/4');
    vm.selectDay(7);
    vm.selectWeek(3);
    expect(vm.dateTitle, '2026/3/22');
    vm.resetWeekSelection();
    expect(vm.dateTitle, '2026/3/4');
    await vm.selectSemester(
      const Semester(id: 'future', schoolYear: '2099-2100', term: '1'),
    );
    expect(vm.selectedSemester!.id, DemoScheduleRepository.semester.id);
    expect(
      vm.calendar.firstMonday(
        const Semester(id: 'future', schoolYear: '2099-2100', term: '1'),
      ),
      isNull,
    );
    vm.dispose();
  });
}
