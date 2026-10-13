import 'dart:convert';

import 'package:dio/dio.dart';

import 'fake_api.dart';

/// 二级页预览只替换 HTTP 数据，仍使用正式页面和请求解析。
/// 全部是虚构样例，不读取用户账号，也不会向服务器提交操作。
FakeApi toolPreviewApi() {
  final api = FakeApi();
  final today = DateTime.now().toIso8601String().split('T').first;
  api.handler = (request) async {
    final Object data = switch (request.path) {
      '/api/v1/jwxt/semesters' => [
        {
          'ID': '2026-1',
          'SchoolYear': '2026-2027',
          'Term': '1',
          'Current': true,
        },
        {'ID': '2025-2', 'SchoolYear': '2025-2026', 'Term': '2'},
      ],
      '/api/v1/jwxt/grades' => [
        {
          'CourseName': '高等数学 A',
          'CourseCode': 'MATH101',
          'CourseCategory': '必修',
          'Credits': '5',
          'UsualScore': '92',
          'FinalExamScore': '88',
          'FinalScore': '90',
          'GradePoint': '4.0',
        },
        {
          'CourseName': '大学英语',
          'CourseCode': 'ENG102',
          'CourseCategory': '必修',
          'Credits': '3',
          'UsualScore': '76',
          'FinalExamScore': '45',
          'FinalScore': '55',
          'GradePoint': '0',
        },
        {
          'CourseName': '程序设计基础',
          'CourseCode': 'CS103',
          'CourseCategory': '必修',
          'Credits': '4',
          'FinalScore': '',
          'GradePoint': '',
        },
      ],
      '/api/v1/jwxt/exams' => [
        {
          'CourseName': '高等数学 A',
          'ExamDate': today,
          'ExamTime': '09:00–11:00',
          'Location': '第一教学楼 A203',
          'Credits': '5',
          'ExamType': '笔试',
        },
        {
          'CourseName': '大学英语',
          'ExamDate': '2026-12-25',
          'ExamTime': '14:00–16:00',
          'Location': '第二教学楼 B102',
          'Credits': '3',
        },
        {
          'CourseName': '程序设计基础',
          'ExamDate': '',
          'ExamTime': '',
          'Location': '',
        },
      ],
      '/api/v1/schedule/current-week' => {'CurrentWeek': 3},
      '/api/v1/jwxt/classroom-options' => {
        'Campuses': [
          {'ID': 'airport', 'Name': '航空港'},
          {'ID': 'longquan', 'Name': '龙泉'},
        ],
        'Buildings': [
          {'ID': 'one', 'Name': '第一教学楼'},
          {'ID': 'two', 'Name': '第二教学楼'},
        ],
        'ClassroomTypes': [
          {'ID': 'normal', 'Name': '普通教室'},
        ],
      },
      '/api/v1/jwxt/available-classrooms' => [
        {
          'ID': 'a101',
          'Name': 'A101',
          'Building': '第一教学楼',
          'Type': '多媒体教室',
          'Capacity': 80,
        },
        {
          'ID': 'a203',
          'Name': 'A203',
          'Building': '第一教学楼',
          'Type': '普通教室',
          'Capacity': 60,
        },
        {
          'ID': 'b102',
          'Name': 'B102',
          'Building': '第二教学楼',
          'Type': '普通教室',
          'Capacity': 40,
        },
      ],
      '/api/v1/library/capabilities' => {
        'CaptchaMode': 'none',
        'MemoRequired': true,
        'MemoMaximumLength': 30,
      },
      '/api/v1/library/areas' => [
        {
          'ID': 'reading',
          'Name': '航空港图书馆 · 二楼阅览室',
          'Available': 36,
          'Total': 80,
        },
      ],
      '/api/v1/library/seats' => [
        for (var i = 1; i <= 6; i++)
          {
            'ID': '$i',
            'Name': 'A-${i.toString().padLeft(3, '0')}',
            'Building': '航空港图书馆',
            'Room': '二楼阅览室',
            'Status': i == 3 ? 'occupied' : 'available',
          },
      ],
      '/api/v1/library/reservations' =>
        request.method == 'POST'
            ? {}
            : [
                {
                  'UUID': 'preview',
                  'ReservationID': 'one',
                  'Kind': 'seat',
                  'Name': 'A-001',
                  'Room': '航空港图书馆 · 二楼阅览室',
                  'StatusLabel': '待签到',
                  'Start': '$today 08:00',
                  'End': '$today 12:00',
                  'CanCancel': true,
                  'CanRenew': true,
                },
              ],
      '/api/v1/library/auto-renewals' => [],
      '/api/login' => {'sessionKey': 'preview-only'},
      '/api/run_info' => {
        'runInfo': {'runValidCount': 8, 'runValidDistance': 24000},
      },
      '/api/club_data' => {
        'activities': [
          {
            'clubActivityId': 7,
            'activityName': '羽毛球训练',
            'startTime': '17:00',
            'endTime': '18:00',
            'addressDetail': '体育馆',
            'maxStudent': 30,
            'signInStudent': 8,
            'optionStatus': '0',
          },
        ],
        'joinProgress': {'joinNum': 3, 'totalNum': 12},
        'schedule': {'enabled': false},
      },
      _ => throw StateError('预览未定义此请求：${request.path}'),
    };
    if (!request.path.startsWith('/api/v1/')) {
      return ResponseBody.fromString(
        jsonEncode({'code': 10000, 'msg': '', 'response': data}),
        200,
        headers: {
          Headers.contentTypeHeader: ['application/json'],
        },
      );
    }
    return FakeApi.response(data);
  };
  return api;
}
