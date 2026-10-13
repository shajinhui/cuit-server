import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes/navigation_preview.dart';

void main() {
  testWidgets('磨砂降级可以切换四个入口，读屏能识别当前页', (tester) async {
    final semantics = tester.ensureSemantics();
    try {
      await tester.pumpWidget(const NavigationPreview(lightweight: true));
      await tester.pumpAndSettle();
      const labels = ['课表', '工具', '校园', '我的'];
      for (var index = 0; index < labels.length; index++) {
        await tester.tap(find.byKey(ValueKey('nav-$index')));
        await tester.pumpAndSettle();
        expect(find.text('${labels[index]} · 导航预览'), findsOneWidget);
        expect(
          tester.getSemantics(find.byKey(ValueKey('nav-$index'))),
          isSemantics(
            label: labels[index],
            isButton: true,
            isSelected: true,
            hasTapAction: true,
          ),
        );
      }
      // 导航层不能拦截页面本身的触摸和滚动。
      await tester.tap(find.byKey(const ValueKey('preview-card-0')));
      await tester.pumpAndSettle();
      expect(find.text('页面点击次数：1'), findsWidgets);
      await tester.drag(
        find.byKey(const Key('preview-list')),
        const Offset(0, -300),
      );
      await tester.pumpAndSettle();
      expect(find.text('校园生活 1'), findsNothing);
      expect(tester.takeException(), isNull);
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('高对比度和减少动态效果下仍可切页', (tester) async {
    await tester.pumpWidget(
      const NavigationPreview(
        dark: true,
        highContrast: true,
        reduceMotion: true,
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('nav-2')));
    await tester.pump();
    expect(find.text('校园 · 导航预览'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('320 宽屏幕四倍字体时入口仍可点击且没有布局溢出', (tester) async {
    tester.view.physicalSize = const Size(320, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      const NavigationPreview(lightweight: true, textScale: 4),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('nav-3')));
    await tester.pumpAndSettle();
    expect(find.text('我的 · 导航预览'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
