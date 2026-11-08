import 'dart:ui' as ui;

import 'package:chengxin_youyou/app/app.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import '../test/fakes/campus_preview_repository.dart';
import '../test/fakes/test_dependencies.dart';

/// 安卓真机帧耗时采样。
///
/// 只采集、不设硬性阈值：不同机型的 GPU 差异太大，把阈值写死会让测试
/// 在低端机上必然失败。结果通过 `binding.reportData` 回传，`flutter drive`
/// 会写到 `build/integration_response_data.json`。
///
/// ```bash
/// ./tool/flutter.sh drive --profile \
///   --driver=test_driver/integration_test.dart \
///   --target=integration_test/perf_test.dart \
///   -d <设备标识>
/// ```
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('课表与校园滚动、切页的帧耗时采样', (tester) async {
    final phases = <String, List<FrameTiming>>{};
    var recording = false;
    var currentPhase = '';

    void startPhase(String name) {
      currentPhase = name;
      phases.putIfAbsent(name, () => <FrameTiming>[]).clear();
      recording = true;
    }

    void endPhase() => recording = false;

    binding.addTimingsCallback((timings) {
      if (!recording) return;
      phases[currentPhase]!.addAll(timings);
    });

    final dependencies = await testDependencies(
      campusRepository: CampusPreviewRepository(),
    );
    dependencies.session.enterDemo();
    await tester.pumpWidget(ChengxinApp(dependencies: dependencies));

    // 课表来自演示仓库，等它替换掉加载动画。
    await _pumpUntil(
      tester,
      () => find.byKey(const Key('schedule-grid')).evaluate().isNotEmpty,
    );
    await tester.pump(const Duration(milliseconds: 500));

    final view = tester.view;
    final size = view.physicalSize / view.devicePixelRatio;

    // 1. 课表上下滚动：导航收起、课表整张网格重绘。
    startPhase('schedule-scroll');
    await _dragWithFrames(
      tester,
      Offset(size.width / 2, size.height * .72),
      -size.height * .45,
    );
    await _dragWithFrames(
      tester,
      Offset(size.width / 2, size.height * .45),
      size.height * .35,
    );
    endPhase();

    // 2. 校园帖子列表滚动：列表按需构建 + 顶部收起。
    await _showNavigation(tester, size);
    await tester.tapAt(tester.getCenter(find.byKey(const ValueKey('nav-2'))));
    await _pumpUntil(
      tester,
      () => find.byKey(const ValueKey('campus-feed')).evaluate().isNotEmpty,
    );
    await tester.pump(const Duration(milliseconds: 500));

    startPhase('campus-scroll');
    final feed = find.byKey(const ValueKey('campus-feed'));
    await _dragWithFrames(tester, tester.getCenter(feed), -size.height * .5);
    await _dragWithFrames(tester, tester.getCenter(feed), size.height * .4);
    endPhase();

    // 3. 底部四个 Tab 连续切换：液态玻璃选中胶囊与页面切换。
    await _showNavigation(tester, size);
    startPhase('tab-switch');
    for (final index in [0, 1, 2, 3, 0]) {
      await tester.tapAt(tester.getCenter(find.byKey(ValueKey('nav-$index'))));
      for (var frame = 0; frame < 20; frame++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
    }
    endPhase();

    final report = <String, Object?>{
      'refreshRate': view.display.refreshRate,
      'shaderFilter': ui.ImageFilter.isShaderFilterSupported,
      'platform': defaultTargetPlatform.name,
      'phases': {
        for (final entry in phases.entries) entry.key: _summarize(entry.value),
      },
    };
    binding.reportData = report;
    debugPrint('PERF_REPORT $report');
  });
}

Future<void> _pumpUntil(
  WidgetTester tester,
  bool Function() condition, {
  Duration timeout = const Duration(seconds: 15),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (!condition()) {
    if (DateTime.now().isAfter(deadline)) {
      throw TestFailure('等待界面就绪超时。');
    }
    await tester.pump(const Duration(milliseconds: 50));
  }
}

/// 用逐帧移动模拟手指拖动，让每一帧都进入计时回调。
Future<void> _dragWithFrames(
  WidgetTester tester,
  Offset start,
  double dy, {
  int steps = 18,
}) async {
  final gesture = await tester.startGesture(start);
  for (var step = 0; step < steps; step++) {
    await gesture.moveBy(Offset(0, dy / steps));
    await tester.pump(const Duration(milliseconds: 16));
  }
  await gesture.up();
  // 等惯性滚动和导航/顶部的显隐动画走完。
  for (var frame = 0; frame < 25; frame++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
}

/// 上滑后底部导航可能已收起；向下拉一点让它重新出现，再点 Tab。
Future<void> _showNavigation(WidgetTester tester, Size size) async {
  await _dragWithFrames(
    tester,
    Offset(size.width / 2, size.height * .45),
    size.height * .12,
    steps: 6,
  );
  await tester.pump(const Duration(milliseconds: 300));
}

Map<String, Object> _summarize(List<FrameTiming> timings) {
  final build = <double>[];
  final raster = <double>[];
  for (final timing in timings) {
    build.add(timing.buildDuration.inMicroseconds / 1000);
    raster.add(timing.rasterDuration.inMicroseconds / 1000);
  }
  build.sort();
  raster.sort();
  final total = timings.length;
  final budget = 1000 / 60;
  final buildJank = build.where((value) => value > budget).length;
  final rasterJank = raster.where((value) => value > budget).length;
  return <String, Object>{
    'frames': total,
    'buildP50': _percentile(build, .5),
    'buildP90': _percentile(build, .9),
    'buildP99': _percentile(build, .99),
    'rasterP50': _percentile(raster, .5),
    'rasterP90': _percentile(raster, .9),
    'rasterP99': _percentile(raster, .99),
    'buildOverBudget': buildJank,
    'rasterOverBudget': rasterJank,
    'buildOverBudgetPercent': total == 0
        ? 0
        : double.parse((buildJank * 100 / total).toStringAsFixed(1)),
    'rasterOverBudgetPercent': total == 0
        ? 0
        : double.parse((rasterJank * 100 / total).toStringAsFixed(1)),
  };
}

double _percentile(List<double> sorted, double percentile) {
  if (sorted.isEmpty) return 0;
  final index = ((sorted.length - 1) * percentile).round();
  return double.parse(sorted[index].toStringAsFixed(2));
}
