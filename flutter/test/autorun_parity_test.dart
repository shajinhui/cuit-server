import 'dart:convert';
import 'dart:io';

import 'package:chengxin_youyou/features/autorun/models/autorun_models.dart';
import 'package:chengxin_youyou/features/autorun/models/run_record.dart';
import 'package:chengxin_youyou/features/profile/models/plan_completion.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final fixture =
      jsonDecode(
            File('test/fixtures/autorun_reference.json').readAsStringSync(),
          )
          as Map;
  for (final item in fixture['campuses'] as List) {
    test('校区识别与 Vue 一致：${item['standard']} ${item['bounds']}', () {
      expect(
        detectAutoRunCampus(
          item['bounds'] as List,
          autoRunMap(item['standard']),
        ),
        item['expected'],
      );
    });
  }
  for (var i = 0; i < (fixture['progress'] as List).length; i++) {
    test('校园跑进度与 Vue 一致：$i', () {
      final item = fixture['progress'][i];
      final actual = AutoRunProgress.fromJson(autoRunMap(item['input']));
      expect(
        actual
            .map(
              (v) => {'current': v.current, 'target': v.target, 'unit': v.unit},
            )
            .toList(),
        item['expected'],
      );
    });
  }
  for (final item in fixture['activities'] as List) {
    test('活动报名状态与 Vue 一致：${item['input']['clubActivityId']}', () {
      final actual = AutoRunActivity.fromJson(autoRunMap(item['input']));
      final expected = item['expected'] as Map;
      expect(actual.isJoined, expected['isJoined']);
      expect(actual.isFull, expected['isFull']);
      expect(actual.isUnavailable, expected['isUnavailable']);
      expect(
        actual.canJoin,
        actual.isJoined || (!actual.isFull && !actual.isUnavailable),
      );
    });
  }
  for (var i = 1; i < (fixture['signs'] as List).length; i++) {
    test('签到与签退窗口与 Vue 一致：$i', () {
      final item = fixture['signs'][i];
      final actual = AutoRunSignTask(autoRunMap(item['input']));
      final action = item['action'] as Map?;
      expect(actual.signType, action?['signType']);
      expect(actual.canSign, action != null && action['disabled'] == false);
      expect(actual.description, item['description']);
    });
  }
  for (final item in fixture['records'] as List) {
    test('完整校园跑提交与 Vue 逐字段一致：${item['campus']}', () {
      final filename = item['campus'] == 'longquan'
          ? 'map-longquan.json'
          : 'map.json';
      final locations = parseTrackMap(
        jsonDecode(File('assets/data/autorun/$filename').readAsStringSync()),
      );
      expect(
        buildAutoRunRecord(
          autoRunMap(item['preparation']),
          locations,
          now: DateTime.parse(item['now'] as String),
          random: () => item['random'] as double,
          distance: item['distance'] as int,
          duration: item['duration'] as int,
        ),
        item['expected'],
      );
    });
  }
  for (final item in fixture['credits'] as List) {
    test('学分完成度与 Vue 一致：${item['required']} / ${item['earned']}', () {
      final data = PlanCompletion.fromJson({
        'Summary': {
          'RequiredCredits': item['required'],
          'EarnedCredits': item['earned'],
        },
        'Items': [],
      });
      final expected = item['expected'] as num?;
      expect(data.progress, expected == null ? null : expected / 100);
    });
  }
  test('学业明细按原顺序归类，先判断否定状态', () {
    final data = PlanCompletion.fromJson({
      'Summary': {},
      'Items': [
        {'Kind': 'course', 'Name': '其他课程'},
        {'Kind': 'requirement', 'Name': '公共必修'},
        {'Kind': 'course', 'Name': '高等数学'},
        {'Kind': 'requirement', 'Name': '专业必修'},
      ],
    });
    expect(data.groups, hasLength(3));
    expect(data.groups[0].requirement, isNull);
    expect(data.groups[1].courses.single.name, '高等数学');
    expect(completionStatusTone('未完成'), -1);
    expect(completionStatusTone('已完成'), 1);
    expect(completionStatusTone('待审核'), 0);
  });
  test('上游事件时间与记录日期使用北京时间', () {
    expect(
      autoRunEventTime('2026-10-06', '18:00')!.toUtc(),
      DateTime.utc(2026, 10, 6, 10),
    );
    expect(
      autoRunEventTime('2026-10-06', '2026/10/07 18:00')!.toUtc(),
      DateTime.utc(2026, 10, 7, 10),
    );
    expect(autoRunBusinessDate(DateTime.utc(2026, 10, 6, 17)), '2026-10-07');
  });
}
