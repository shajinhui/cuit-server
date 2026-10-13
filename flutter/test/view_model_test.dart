import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:chengxin_youyou/core/network/api_exception.dart';
import 'package:chengxin_youyou/features/session/session.dart';
import 'package:chengxin_youyou/features/schedule/schedule.dart';
import 'package:chengxin_youyou/features/schedule/models/semester.dart';

class PendingSession implements SessionRepository {
  final loginResult = Completer<Student>();
  final logoutResult = Completer<void>();
  int loginCount = 0;
  @override
  Future<Student> login(String number, String password) {
    loginCount++;
    return loginResult.future;
  }

  @override
  Future<void> logout() => logoutResult.future;
  @override
  Future<RestoredSession?> restore() async => null;
}

class PendingSchedule extends ScheduleRepository {
  final results = <String, Completer<ScheduleSnapshot>>{};
  int calls = 0;
  @override
  Future<List<Semester>> semesters({bool refresh = false}) =>
      DemoScheduleRepository().semesters();
  @override
  Future<ScheduleSnapshot> load(String id, {bool refresh = false}) {
    calls++;
    return results.putIfAbsent(id, () => Completer<ScheduleSnapshot>()).future;
  }

  @override
  Future<void> clear() async {}
  @override
  void invalidate() {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('重复提交登录被拦截，退出清理期间不能登录或进入演示', () async {
    final repository = PendingSession();
    final vm = SessionViewModel(repository);
    final login = vm.login('1', 'test');
    expect(await vm.login('1', 'test'), isFalse);
    repository.loginResult.complete(Student.demo);
    expect(await login, isTrue);
    final logout = vm.logout();
    expect(vm.student, isNull);
    vm.enterDemo();
    expect(vm.student, isNull);
    expect(await vm.login('2', 'test'), isFalse);
    repository.logoutResult.complete();
    await logout;
    expect(vm.isSubmitting, isFalse);
    expect(repository.loginCount, 1);
    vm.dispose();
  });
  test('登录失败保留中文错误，销毁后的响应不通知页面', () async {
    final repository = PendingSession();
    final vm = SessionViewModel(repository);
    final request = vm.login('1', 'test');
    repository.loginResult.completeError(const ApiException('学号或密码错误'));
    expect(await request, isFalse);
    expect(vm.error, '学号或密码错误');
    vm.dispose();
    final second = PendingSession();
    final disposedVm = SessionViewModel(second);
    final lateRequest = disposedVm.login('1', 'test');
    disposedVm.dispose();
    second.loginResult.complete(Student.demo);
    expect(await lateRequest, isFalse);
  });
  test('快速切换学期时只有最后一次结果生效；切周不请求接口', () async {
    final repository = PendingSchedule();
    final vm = ScheduleViewModel(
      repository,
      await AcademicCalendar.load(),
      onSessionExpired: () {},
    );
    const first = DemoScheduleRepository.semester;
    const second = Semester(id: 'second', schoolYear: '2025-2026', term: '2');
    final firstRequest = vm.selectSemester(first);
    final secondRequest = vm.selectSemester(second);
    repository.results['second']!.complete(
      await DemoScheduleRepository().load('second'),
    );
    await secondRequest;
    repository.results[first.id]!.complete(
      await DemoScheduleRepository().load(first.id),
    );
    await firstRequest;
    expect(vm.snapshot?.table.semesterId, 'second');
    vm.selectWeek(2);
    vm.selectWeek(99);
    expect(vm.selectedWeek, 99);
    expect(repository.calls, 2);
    vm.dispose();
  });
}
