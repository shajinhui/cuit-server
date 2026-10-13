import 'dart:async';
import 'dart:convert';
import 'dart:ui' as ui;

import 'package:chengxin_youyou/core/storage/app_storage.dart';
import 'package:chengxin_youyou/features/profile/data/profile_avatar.dart';
import 'package:chengxin_youyou/features/profile/data/profile_repository.dart';
import 'package:chengxin_youyou/features/profile/presentation/feedback_page.dart';
import 'package:chengxin_youyou/features/profile/presentation/plan_completion_page.dart';
import 'package:chengxin_youyou/features/profile/presentation/profile_avatar_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes/fake_api.dart';

void main() {
  testWidgets('小屏和大字体下头像选择弹窗可以滚动且不溢出', (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 1.5;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final avatar = ProfileAvatar(MemoryAppStorage(), 'one');
    addTearDown(avatar.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(child: ProfileAvatarButton(avatar: avatar)),
        ),
      ),
    );
    await tester.tap(find.byKey(const Key('profile-avatar')));
    await tester.pumpAndSettle();
    expect(find.text('选择头像'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
  test('每个预设头像都对应已打包的原项目资源，非法编号回退第一张', () async {
    for (var id = 1; id <= ProfileAvatar.presetCount; id++) {
      final bytes = await rootBundle.load(
        'assets/avatars/avatar-${id.toString().padLeft(2, '0')}.jpg',
      );
      expect(bytes.lengthInBytes, greaterThan(0));
    }
    final storage = MemoryAppStorage();
    storage.values['one'] = jsonEncode({'preset': 16});
    final avatar = ProfileAvatar(storage, 'one');
    addTearDown(avatar.dispose);
    await avatar.initialize();
    expect(avatar.presetId, 1);
  });
  test('预设头像恢复并按账号隔离', () async {
    final storage = MemoryAppStorage();
    final first = ProfileAvatar(storage, 'account:one:avatar');
    final second = ProfileAvatar(storage, 'account:two:avatar');
    addTearDown(first.dispose);
    addTearDown(second.dispose);
    await first.selectPreset(12);
    await second.selectPreset(3);
    final restored = ProfileAvatar(storage, 'account:one:avatar');
    addTearDown(restored.dispose);
    await restored.initialize();
    expect(restored.presetId, 12);
    expect(restored.assetPath, 'assets/avatars/avatar-12.jpg');
    expect(second.presetId, 3);
  });

  test('迟到的头像读取不能覆盖刚选择的新头像', () async {
    final storage = _DelayedRead();
    final avatar = ProfileAvatar(storage, 'one');
    addTearDown(avatar.dispose);
    final reading = avatar.initialize();
    await avatar.selectPreset(7);
    storage.response.complete(jsonEncode({'preset': 2}));
    await reading;
    expect(avatar.presetId, 7);
  });

  testWidgets('自定义头像居中裁为 512 方形并可恢复', (tester) async {
    await tester.runAsync(() async {
      final recorder = ui.PictureRecorder();
      final canvas = ui.Canvas(recorder);
      canvas.drawColor(const Color(0xFF336699), BlendMode.src);
      final picture = recorder.endRecording();
      final image = await picture.toImage(64, 32);
      final bytes = (await image.toByteData(
        format: ui.ImageByteFormat.png,
      ))!.buffer.asUint8List();
      picture.dispose();
      image.dispose();
      final storage = MemoryAppStorage();
      final avatar = ProfileAvatar(storage, 'one');
      final restored = ProfileAvatar(storage, 'one');
      try {
        await avatar.selectCustom(bytes);
        expect(avatar.error, isNull);
        await restored.initialize();
        final codec = await ui.instantiateImageCodec(restored.customImage!);
        final frame = await codec.getNextFrame();
        expect(frame.image.width, 512);
        expect(frame.image.height, 512);
        frame.image.dispose();
        codec.dispose();
      } finally {
        avatar.dispose();
        restored.dispose();
      }
    });
  });

  testWidgets('反馈校验长度与提交参数，失败保留内容，成功清空', (tester) async {
    _largeViewport(tester);
    final api = FakeApi();
    addTearDown(api.client.dispose);
    api.handler = (_) async => FakeApi.response(null, code: 1, message: '稍后再试');
    await tester.pumpWidget(
      MaterialApp(
        home: FeedbackPage(repository: ProfileRepository(api.client)),
      ),
    );
    final content = find.byKey(const Key('feedback-content'));
    final submit = find.byKey(const Key('feedback-submit'));
    await tester.enterText(content, '太短');
    await tester.pump();
    expect(tester.widget<FilledButton>(submit).onPressed, isNull);
    const body = '工具页面切换时希望保留查询条件';
    await tester.enterText(content, body);
    await tester.tap(find.text('Bug'));
    await tester.tap(find.text('iOS'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(submit);
    await tester.tap(submit);
    await tester.pumpAndSettle();
    expect(api.requests.single.data, {
      'type': 'bug',
      'platform': 'ios',
      'content': body,
    });
    expect(tester.widget<TextField>(content).controller!.text, body);
    api.handler = (_) async =>
        FakeApi.response({'id': 1, 'created_at': '2026-10-06'});
    await tester.tap(submit);
    await tester.pumpAndSettle();
    expect(find.text('已收到，谢谢你的反馈'), findsOneWidget);
    expect(tester.widget<TextField>(content).controller!.text, isEmpty);
  });

  testWidgets('学业完成页展示真实字段，刷新失败保留已有明细', (tester) async {
    final api = FakeApi();
    addTearDown(api.client.dispose);
    api.handler = (_) async => FakeApi.response({
      'Summary': {
        'RequiredCredits': '160',
        'EarnedCredits': '80',
        'GPA': '3.5',
        'AuditResult': '未完成',
      },
      'Items': [
        {'Kind': 'requirement', 'Name': '公共必修'},
        {'Kind': 'course', 'Name': '高等数学', 'Score': '90'},
      ],
    });
    await tester.pumpWidget(
      MaterialApp(
        home: PlanCompletionPage(repository: ProfileRepository(api.client)),
      ),
    );
    await tester.pumpAndSettle();
    expect(api.requests.single.path, '/api/v1/jwxt/plan-completion');
    expect(find.text('50%'), findsOneWidget);
    expect(
      tester
          .widget<LinearProgressIndicator>(find.byType(LinearProgressIndicator))
          .value,
      .5,
    );
    expect(find.text('高等数学'), findsOneWidget);
    api.handler = (_) async =>
        FakeApi.response(null, code: 1, message: '教务暂不可用');
    await tester.tap(find.byTooltip('刷新学业完成情况'));
    await tester.pumpAndSettle();
    expect(find.text('教务暂不可用'), findsOneWidget);
    expect(find.text('高等数学'), findsOneWidget);
  });

  testWidgets('体验账号不能发送真实反馈，学业 401 通知撤销会话', (tester) async {
    _largeViewport(tester);
    await tester.pumpWidget(
      const MaterialApp(home: FeedbackPage(repository: null)),
    );
    await tester.enterText(
      find.byKey(const Key('feedback-content')),
      '这是一条足够长的体验反馈内容',
    );
    await tester.pump();
    expect(
      tester
          .widget<FilledButton>(find.byKey(const Key('feedback-submit')))
          .onPressed,
      isNull,
    );
    final api = FakeApi();
    addTearDown(api.client.dispose);
    api.handler = (_) async => FakeApi.response(null, status: 401);
    var expired = false;
    await tester.pumpWidget(
      MaterialApp(
        home: PlanCompletionPage(
          repository: ProfileRepository(api.client),
          onSessionExpired: () => expired = true,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(expired, isTrue);
  });
}

void _largeViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(390, 1200);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

class _DelayedRead extends MemoryAppStorage {
  final response = Completer<String?>();
  @override
  Future<String?> read(String key) => response.future;
}
