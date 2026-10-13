import 'dart:async';

import 'package:chengxin_youyou/features/campus/data/campus_repository.dart';
import 'package:chengxin_youyou/features/campus/data/default_campus_repository.dart';
import 'package:chengxin_youyou/features/campus/presentation/campus_widgets.dart';
import 'package:chengxin_youyou/features/campus/presentation/rating_item_page.dart';
import 'package:chengxin_youyou/features/tools/presentation/academic_tool_pages.dart';
import 'package:chengxin_youyou/features/tools/presentation/library_page.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes/fake_api.dart';

void main() {
  test('最终成绩为空时展示总评，价格小数不出现替换占位符', () {
    expect(displayGradeScore({'FinalScore': '', 'OverallScore': '59'}), '59');
    expect(displayGradeScore({'FinalScore': '  ', 'OverallScore': 0}), '0');
    expect(displayGradeScore({'FinalScore': '优秀', 'OverallScore': '90'}), '优秀');
    expect(campusFormatPrice(120), '1.2');
    expect(campusFormatPrice(123), '1.23');
    expect(campusFormatPrice(100), '1');
  });

  test('切换账号后，旧校园 401 不能用新账号凭证重发', () async {
    final main = FakeApi();
    final campus = FakeApi();
    final repository = DefaultCampusRepository(
      main.client,
      dio: campus.client.dio,
    );
    addTearDown(main.client.dispose);
    addTearDown(repository.dispose);
    var token = 'A';
    main.handler = (_) async => FakeApi.response({
      'access_token': token,
      'expires_at': '2099-01-01T00:00:00Z',
    });
    final response = Completer<ResponseBody>();
    final started = Completer<void>();
    campus.handler = (request) async {
      if (request.path.endsWith('/old')) {
        started.complete();
        return response.future;
      }
      return FakeApi.response({'id': 'new', 'title': '新账号'});
    };
    final old = repository.getBoard('old');
    final failure = expectLater(old, throwsA(isA<CampusRepositoryException>()));
    await started.future;
    repository.clearSession();
    token = 'B';
    expect((await repository.getBoard('new')).title, '新账号');
    response.complete(FakeApi.response(null, status: 401));
    await failure;
    expect(campus.requests.where((v) => v.path.endsWith('/old')), hasLength(1));
    expect(campus.requests.last.headers['Authorization'], 'Bearer B');
    expect(main.requests, hasLength(2));
  });

  test('校园图片失败后可以重新读取，成功后仍复用缓存', () async {
    final main = FakeApi();
    final campus = FakeApi();
    final repository = DefaultCampusRepository(
      main.client,
      dio: campus.client.dio,
    );
    addTearDown(main.client.dispose);
    addTearDown(repository.dispose);
    main.handler = (_) async => FakeApi.response({
      'access_token': 'one',
      'expires_at': '2099-01-01T00:00:00Z',
    });
    var failed = true;
    campus.handler = (_) async => failed
        ? ResponseBody.fromString('暂不可用', 503)
        : ResponseBody.fromBytes(
            [1, 2, 3],
            200,
            headers: {
              Headers.contentTypeHeader: ['image/png'],
            },
          );
    expect(await repository.loadAsset('image'), isNull);
    failed = false;
    expect(await repository.loadAsset('image'), [1, 2, 3]);
    expect(await repository.loadAsset('image'), [1, 2, 3]);
    expect(campus.requests, hasLength(2));
  });

  testWidgets('图书馆关闭后，迟到的能力响应不再加载页面', (tester) async {
    final api = FakeApi();
    addTearDown(api.client.dispose);
    final response = Completer<ResponseBody>();
    api.handler = (_) => response.future;
    await tester.pumpWidget(MaterialApp(home: LibraryPage(api: api.client)));
    await tester.pump();
    await tester.pumpWidget(const SizedBox.shrink());
    response.complete(FakeApi.response({'CaptchaMode': 'none'}));
    await tester.pumpAndSettle();
    expect(api.requests, hasLength(1));
    expect(tester.takeException(), isNull);
  });

  testWidgets('图书馆旧座位响应不能覆盖新自修室，并遵守必填备注与长度限制', (tester) async {
    tester.view.physicalSize = const Size(390, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final api = FakeApi();
    addTearDown(api.client.dispose);
    final seatResponse = Completer<ResponseBody>();
    api.handler = (request) async {
      if (request.path.endsWith('/capabilities')) {
        return FakeApi.response({
          'CaptchaMode': 'none',
          'MemoRequired': true,
          'MemoMaximumLength': 6,
        });
      }
      if (request.path.endsWith('/areas')) {
        final study = request.queryParameters['kind'] == 'study';
        return FakeApi.response([
          {
            'ID': study ? 'study-room' : 'seat-room',
            'Name': study ? '新自修室' : '旧座位区域',
          },
        ]);
      }
      if (request.path.endsWith('/seats')) {
        return request.queryParameters['kind'] == 'seat'
            ? seatResponse.future
            : FakeApi.response([
                {'ID': 'one', 'Name': '自修室座位', 'Status': 'available'},
              ]);
      }
      return FakeApi.response({});
    };
    await tester.pumpWidget(MaterialApp(home: LibraryPage(api: api.client)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('查询可预约座位'));
    await tester.pump();
    await tester.tap(find.text('自修室'));
    await tester.pumpAndSettle();
    seatResponse.complete(
      FakeApi.response([
        {'ID': 'old', 'Name': '过期座位', 'Status': 'available'},
      ]),
    );
    await tester.pumpAndSettle();
    expect(find.text('过期座位'), findsNothing);
    expect(find.textContaining('新自修室'), findsOneWidget);
    await tester.tap(find.text('查询可预约座位'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('自修室座位'));
    await tester.pumpAndSettle();
    final confirm = find.widgetWithText(FilledButton, '确认预约');
    expect(tester.widget<FilledButton>(confirm).onPressed, isNull);
    expect(tester.widget<TextField>(find.byType(TextField)).maxLength, 6);
    await tester.enterText(find.byType(TextField), '课程自习');
    await tester.pump();
    await tester.tap(confirm);
    await tester.pumpAndSettle();
    final sent = api.requests.singleWhere((v) => v.method == 'POST');
    expect(sent.data['Kind'], 'study');
    expect(sent.data['RoomID'], 'study-room');
    expect(sent.data['Memo'], '课程自习');
  });

  testWidgets('未展开旧回复时发表新回复，仍会读取完整回复列表', (tester) async {
    tester.view.physicalSize = const Size(390, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final main = FakeApi();
    final campus = FakeApi();
    final repository = DefaultCampusRepository(
      main.client,
      dio: campus.client.dio,
    );
    addTearDown(main.client.dispose);
    addTearDown(repository.dispose);
    main.handler = (_) async => FakeApi.response({
      'access_token': 'one',
      'expires_at': '2099-01-01T00:00:00Z',
    });
    Map<String, Object?> comment(String id, String body, {String? parent}) => {
      'id': id,
      'item_id': 'item',
      'parent_id': parent,
      'body': body,
      'reply_count': parent == null ? 1 : 0,
    };
    campus.handler = (request) async {
      if (request.method == 'POST') {
        return FakeApi.response(comment('new', '新回复', parent: 'root'));
      }
      if (request.path.endsWith('/replies')) {
        return FakeApi.response({
          'items': [
            comment('old', '以前的回复', parent: 'root'),
            comment('new', '新回复', parent: 'root'),
          ],
        });
      }
      if (request.path.endsWith('/comments')) {
        return FakeApi.response({
          'items': [comment('root', '父评论')],
        });
      }
      return FakeApi.response({
        'id': 'item',
        'name': '评分对象',
        'comment_count': 1,
        'rating': {},
      });
    };
    await tester.pumpWidget(
      MaterialApp(
        home: RatingItemPage(repository: repository, itemId: 'item'),
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('回复'));
    await tester.tap(find.text('回复'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '新回复');
    await tester.pump();
    await tester.tap(find.byTooltip('发送评论'));
    await tester.pumpAndSettle();
    expect(
      campus.requests.where((v) => v.path.endsWith('/replies')),
      hasLength(1),
    );
    expect(
      campus.requests.singleWhere((v) => v.method == 'POST').data['parent_id'],
      'root',
    );
    expect(find.textContaining('以前的回复'), findsOneWidget);
    expect(find.textContaining('新回复'), findsOneWidget);
  });
}
