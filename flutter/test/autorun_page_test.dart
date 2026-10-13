import 'dart:convert';

import 'package:chengxin_youyou/core/storage/app_storage.dart';
import 'package:chengxin_youyou/features/autorun/data/autorun_repository.dart';
import 'package:chengxin_youyou/features/tools/presentation/autorun_page.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes/fake_api.dart';

void main() {
  testWidgets('校园跑从独立登录到提交、俱乐部报名、签到、定时与退出', (tester) async {
    tester.view.physicalSize = const Size(390, 1100);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final api = FakeApi();
    final storage = MemoryAppStorage();
    final repository = AutoRunRepository(storage, dio: api.client.dio);
    addTearDown(repository.dispose);
    var submitted = false;
    var joined = false;
    var signed = false;
    var scheduled = false;
    api.handler = (request) async {
      final Map<String, Object?> data;
      switch (request.path) {
        case '/api/login':
          data = {'sessionKey': 'test-session'};
        case '/api/run_info':
          data = {
            'runInfo': {
              'runValidCount': submitted ? 5 : 4,
              'runValidDistance': 12000,
            },
          };
        case '/api/run_prepare':
          data = {
            'userId': 42,
            'schoolId': 1,
            'runStandard': {'semesterYear': '2026-2027-1'},
            'bounds': [],
          };
        case '/api/run':
          submitted = true;
          data = {'success': true};
        case '/api/club_join':
          joined = true;
          data = {'success': true};
        case '/api/club_sign':
          signed = true;
          data = {'success': true};
        case '/api/club_schedule_set':
          scheduled = request.data['enabled'] as bool;
          data = {
            'success': true,
            'schedule': {'enabled': scheduled},
          };
        case '/api/club_data':
          data = {
            'activities': [
              {
                'clubActivityId': 7,
                'activityName': '羽毛球训练',
                'startTime': '17:00',
                'endTime': '18:00',
                'optionStatus': joined ? '1' : '0',
                'maxStudent': 30,
                'signInStudent': 2,
              },
            ],
            'signTask': {
              'activityId': 7,
              'activityName': '羽毛球训练',
              'startTime': '17:00',
              'endTime': '18:00',
              'signStatus': '1',
              'signInStatus': signed ? '1' : '0',
              'latitude': '30.5',
              'longitude': '104.0',
            },
            'joinProgress': {'joinNum': 3, 'totalNum': 12},
            'schedule': {'enabled': scheduled},
          };
        default:
          throw StateError('未预期的请求 ${request.path}');
      }
      return ResponseBody.fromString(
        jsonEncode({'code': 10000, 'msg': '', 'response': data}),
        200,
        headers: {
          Headers.contentTypeHeader: ['application/json'],
        },
      );
    };
    await tester.pumpWidget(
      MaterialApp(home: AutoRunPage(repository: repository)),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('autorun-phone')),
      '13800138000',
    );
    await tester.enterText(
      find.byKey(const Key('autorun-password')),
      'test-only',
    );
    await tester.tap(find.byKey(const Key('autorun-login')));
    await tester.pumpAndSettle();
    expect(find.textContaining('4 / 20'), findsOneWidget);
    await tester.tap(find.byKey(const Key('autorun-submit-run')));
    await tester.pumpAndSettle();
    expect(submitted, isTrue);
    expect(find.textContaining('5 / 20'), findsOneWidget);
    final record =
        api.requests.singleWhere((v) => v.path == '/api/run').data['record']
            as Map;
    expect(record['yearSemester'], '2026-2027-1');
    expect(record['userId'], 42);
    expect(jsonDecode(record['trackPoints'] as String), isNotEmpty);
    await tester.tap(find.text('俱乐部'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('报名'));
    await tester.tap(find.text('报名'));
    await tester.pumpAndSettle();
    expect(joined, isTrue);
    expect(find.text('取消报名'), findsOneWidget);
    await tester.ensureVisible(find.byKey(const Key('autorun-club-sign')));
    await tester.tap(find.byKey(const Key('autorun-club-sign')));
    await tester.pumpAndSettle();
    expect(signed, isTrue);
    expect(
      tester
          .widget<FilledButton>(find.byKey(const Key('autorun-club-sign')))
          .onPressed,
      isNull,
    );
    await tester.ensureVisible(find.byKey(const Key('autorun-club-schedule')));
    await tester.tap(find.byKey(const Key('autorun-club-schedule')));
    await tester.pumpAndSettle();
    expect(scheduled, isTrue);
    await tester.tap(find.text('我的'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('autorun-logout')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('autorun-login')), findsOneWidget);
    expect(storage.values, isEmpty);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
