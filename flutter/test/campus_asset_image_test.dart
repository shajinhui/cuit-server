import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:chengxin_youyou/features/campus/presentation/campus_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes/campus_preview_repository.dart';

void main() {
  testWidgets('封面打开可缩放大图，关闭后保留列表，点击不误入父级卡片', (tester) async {
    final bytes = (await tester.runAsync(() => _png()))!;
    final repository = _Images()..response = (_) async => bytes;
    var cardTaps = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: InkWell(
            onTap: () => cardTaps++,
            child: Row(children: [_thumbnail(repository), const Text('评分对象')]),
          ),
        ),
      ),
    );
    await _settleImages(tester);
    expect(find.byType(Image), findsOneWidget);
    await tester.tap(find.byType(CampusAssetImage));
    await tester.pumpAndSettle();
    expect(find.byType(InteractiveViewer), findsOneWidget);
    expect(cardTaps, 0);
    expect(repository.calls, [false, false]);
    expect(repository.variants, [true, false]);
    await tester.tap(find.byTooltip('关闭大图'));
    await tester.pumpAndSettle();
    expect(find.byType(InteractiveViewer), findsNothing);
    expect(find.byType(Image), findsOneWidget);
    await tester.tap(find.text('评分对象'));
    expect(cardTaps, 1);
  });

  testWidgets('预览先显示小图，原图失败可单独重试并保持可缩放', (tester) async {
    final thumbnail = (await tester.runAsync(() => _png()))!;
    final original = (await tester.runAsync(() => _png(color: Colors.green)))!;
    final pending = Completer<Uint8List?>();
    final repository = _Images();
    repository.response = (_) async => thumbnail;
    repository.originalResponse = () => pending.future;
    await tester.pumpWidget(
      MaterialApp(home: Scaffold(body: _thumbnail(repository))),
    );
    await _settleImages(tester);
    expect(repository.variants, [true]);
    await tester.tap(find.byType(CampusAssetImage));
    await tester.pumpAndSettle();
    expect(find.text('正在加载原图…'), findsOneWidget);
    expect(find.byType(InteractiveViewer), findsOneWidget);
    pending.complete(null);
    await tester.pumpAndSettle();
    expect(find.text('原图加载失败，点击重试'), findsOneWidget);
    repository.originalResponse = () async => original;
    await tester.tap(find.text('原图加载失败，点击重试'));
    await _settleImages(tester);
    expect(find.text('原图加载失败，点击重试'), findsNothing);
    final preview = tester.widget<Image>(
      find.byWidgetPredicate(
        (widget) => widget is Image && widget.semanticLabel == '图片预览，可双指缩放',
      ),
    );
    expect(
      ((preview.image as ResizeImage).imageProvider as MemoryImage).bytes,
      original,
    );
    expect(repository.calls, [false, false, true]);
    expect(repository.variants, [true, false, false]);
    await tester.tap(find.byTooltip('关闭大图'));
    await tester.pumpAndSettle();
    expect(find.byType(CampusAssetImage), findsOneWidget);
  });

  testWidgets('原图无法解码时保留小图且允许重新下载原图', (tester) async {
    final bytes = (await tester.runAsync(() => _png()))!;
    final repository = _Images();
    repository.response = (_) async => bytes;
    repository.originalResponse = () async => Uint8List.fromList([1, 2, 3]);
    await tester.pumpWidget(
      MaterialApp(home: Scaffold(body: _thumbnail(repository))),
    );
    await _settleImages(tester);
    await tester.tap(find.byType(CampusAssetImage));
    await _settleImages(tester);
    expect(find.text('原图加载失败，点击重试'), findsOneWidget);
    expect(tester.takeException(), isNull);
    repository.originalResponse = () async => bytes;
    await tester.tap(find.text('原图加载失败，点击重试'));
    await _settleImages(tester);
    expect(find.text('原图加载失败，点击重试'), findsNothing);
    expect(repository.calls, [false, false, true]);
    expect(tester.takeException(), isNull);
  });

  testWidgets('加载失败可点击重试，并强制重新下载，不继续复用失败状态', (tester) async {
    final bytes = (await tester.runAsync(() => _png()))!;
    final repository = _Images();
    repository.response = (_) async => null;
    await tester.pumpWidget(
      MaterialApp(home: Scaffold(body: _thumbnail(repository))),
    );
    await tester.pumpAndSettle();
    expect(find.text('重试'), findsOneWidget);
    repository.response = (_) async => bytes;
    await tester.tap(find.text('重试'));
    await _settleImages(tester);
    expect(find.text('重试'), findsNothing);
    expect(find.byType(Image), findsOneWidget);
    expect(repository.calls, [false, true]);
  });

  testWidgets('已下载但无法解码的坏图也可重试，页面不抛出图片异常', (tester) async {
    final repository = _Images()
      ..response = (_) async => Uint8List.fromList([1, 2, 3]);
    await tester.pumpWidget(
      MaterialApp(home: Scaffold(body: _thumbnail(repository))),
    );
    await _settleImages(tester);
    expect(find.text('重试'), findsOneWidget);
    expect(tester.takeException(), isNull);
    final bytes = (await tester.runAsync(() => _png()))!;
    repository.response = (_) async => bytes;
    await tester.tap(find.text('重试'));
    await _settleImages(tester);
    expect(find.text('重试'), findsNothing);
    expect(repository.calls, [false, true]);
  });

  testWidgets('替换图片时迟到的旧响应不显示，重复重建不再请求', (tester) async {
    final old = Completer<Uint8List?>();
    final latest = (await tester.runAsync(() => _png()))!;
    final repository = _Images()
      ..response = (id) => id == 'old' ? old.future : Future.value(latest);
    Widget page(String id) => MaterialApp(
      home: Scaffold(body: _thumbnail(repository, id: id)),
    );
    await tester.pumpWidget(page('old'));
    await tester.pumpWidget(page('new'));
    await _settleImages(tester);
    old.complete(Uint8List.fromList([1, 2, 3]));
    await tester.pumpAndSettle();
    await tester.pumpWidget(page('new'));
    await tester.pumpAndSettle();
    expect(repository.calls, [false, false]);
    expect(find.text('重试'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('自适应缩略图按原图比例完整显示，不裁切方图和竖图', (tester) async {
    final square = (await tester.runAsync(() => _png(width: 40, height: 40)))!;
    final portrait = (await tester.runAsync(
      () => _png(width: 20, height: 40),
    ))!;
    final repository = _Images()
      ..response = (id) async => id == 'square' ? square : portrait;

    Widget thumbnail(String id) => MaterialApp(
      home: Scaffold(
        body: Align(
          alignment: Alignment.topLeft,
          child: CampusAssetImage(
            key: ValueKey(id),
            assetId: id,
            repository: repository,
            fallback: Icons.image_outlined,
            width: 120,
            height: 180,
            adaptive: true,
          ),
        ),
      ),
    );

    await tester.pumpWidget(thumbnail('square'));
    await _settleImages(tester);
    expect(tester.getSize(find.byType(CampusAssetImage)), const Size(120, 120));
    expect(tester.widget<Image>(find.byType(Image)).fit, BoxFit.contain);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(thumbnail('portrait'));
    await _settleImages(tester);
    expect(tester.getSize(find.byType(CampusAssetImage)), const Size(90, 180));
    expect(tester.widget<Image>(find.byType(Image)).fit, BoxFit.contain);
    expect(tester.takeException(), isNull);
  });

  testWidgets('未设置封面时不发空地址请求，显示正常占位图', (tester) async {
    final repository = _Images();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: _thumbnail(repository, id: '')),
      ),
    );
    await tester.pumpAndSettle();
    expect(repository.calls, isEmpty);
    expect(find.byIcon(Icons.image_outlined), findsOneWidget);
    expect(find.text('重试'), findsNothing);
  });
}

Widget _thumbnail(_Images repository, {String id = 'one'}) => CampusAssetImage(
  assetId: id,
  repository: repository,
  fallback: Icons.image_outlined,
  width: 72,
  height: 72,
);

class _Images extends CampusPreviewRepository {
  final calls = <bool>[];
  final variants = <bool>[];
  Future<Uint8List?> Function(String)? response;
  Future<Uint8List?> Function()? originalResponse;

  @override
  Future<Uint8List?> loadAsset(
    String assetId, {
    bool refresh = false,
    bool thumbnail = false,
  }) async {
    calls.add(refresh);
    variants.add(thumbnail);
    if (!thumbnail && originalResponse != null) return originalResponse!();
    return response?.call(assetId);
  }
}

Future<void> _settleImages(WidgetTester tester) async {
  await tester.pumpAndSettle();
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 30)),
  );
  await tester.pumpAndSettle();
}

Future<Uint8List> _png({
  Color color = Colors.blue,
  int width = 40,
  int height = 20,
}) async {
  final recorder = ui.PictureRecorder();
  ui.Canvas(recorder).drawColor(color, BlendMode.src);
  final picture = recorder.endRecording();
  final image = await picture.toImage(width, height);
  final bytes = (await image.toByteData(
    format: ui.ImageByteFormat.png,
  ))!.buffer.asUint8List();
  picture.dispose();
  image.dispose();
  return bytes;
}
