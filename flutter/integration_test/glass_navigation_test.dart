import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import '../test/fakes/navigation_preview.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('实时折射导航、拖动切换与无障碍降级', (tester) async {
    // 该测试需要支持实时着色器的设备；不把 Skia 降级当成折射验收。
    expect(ui.ImageFilter.isShaderFilterSupported, isTrue);
    final semantics = tester.ensureSemantics();
    try {
      if (defaultTargetPlatform == TargetPlatform.android) {
        // Android 截图需要 Flutter surface；iOS 不需要这一步。
        await binding.convertFlutterSurfaceToImage();
      }
      await tester.pumpWidget(const NavigationPreview());
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('navigation-liquid')), findsOneWidget);
      // 刚进入液态分支时，原 PNG 必须已经解码，不能等切页才出现。
      for (final element in find.byType(Image).evaluate()) {
        final render = tester.renderObject<RenderImage>(
          find.byWidget(element.widget),
        );
        expect(render.image, isNotNull);
      }

      // 语义定位层让指针穿透，实际触摸交给下方库的手势层。
      await tester.tapAt(tester.getCenter(find.byKey(const ValueKey('nav-1'))));
      await tester.pumpAndSettle();
      expect(find.text('工具 · 导航预览'), findsOneWidget);
      expect(
        tester.getSemantics(find.byKey(const ValueKey('nav-1'))),
        isSemantics(
          label: '工具',
          isButton: true,
          isSelected: true,
          hasTapAction: true,
        ),
      );
      // 库以短长按启动拖动；释放后只能选中一次目标页。
      final start = tester.getCenter(find.byKey(const ValueKey('nav-1')));
      final end = tester.getCenter(find.byKey(const ValueKey('nav-3')));
      final gesture = await tester.startGesture(start);
      await tester.pump(const Duration(milliseconds: 150));
      await gesture.moveTo(end);
      await tester.pump(const Duration(milliseconds: 100));
      await gesture.up();
      await tester.pumpAndSettle();
      expect(find.text('我的 · 导航预览'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('preview-card-0')));
      await tester.pumpAndSettle();
      expect(find.text('页面点击次数：1'), findsWidgets);
      await tester.drag(
        find.byKey(const Key('preview-list')),
        const Offset(0, -300),
      );
      await tester.pumpAndSettle();
      expect(find.text('校园生活 1'), findsNothing);
      await binding.takeScreenshot('flutter-glass-navigation-light');

      await tester.pumpWidget(const NavigationPreview(dark: true));
      await tester.pumpAndSettle();
      await binding.takeScreenshot('flutter-glass-navigation-dark');
      await tester.pumpWidget(const NavigationPreview(lightweight: true));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('navigation-liquid')), findsNothing);
      await binding.takeScreenshot('flutter-glass-navigation-frosted');
      await tester.pumpWidget(
        const NavigationPreview(highContrast: true, reduceMotion: true),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('nav-0')));
      await tester.pump();
      expect(find.text('课表 · 导航预览'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    } finally {
      semantics.dispose();
    }
  });
}
