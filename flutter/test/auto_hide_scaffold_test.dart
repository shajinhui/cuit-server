import 'package:chengxin_youyou/ui/components/auto_hide_scaffold.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('主页面向上滚动隐藏底部导航，回滑后恢复', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: AutoHideScaffold(
          body: ListView.builder(
            key: const ValueKey('auto-hide-list'),
            itemCount: 30,
            itemExtent: 72,
            padding: const EdgeInsets.only(bottom: 120),
            itemBuilder: (context, index) => Text('条目 $index'),
          ),
          bottomNavigationBar: const SizedBox(
            height: 64,
            child: Center(child: Text('底部导航')),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    AnimatedSlide slide() => tester.widget<AnimatedSlide>(
      find.byKey(const ValueKey('auto-hide-navigation')),
    );

    expect(slide().offset, Offset.zero);
    expect(
      tester
          .widget<IgnorePointer>(
            find.byKey(const ValueKey('auto-hide-navigation-pointer')),
          )
          .ignoring,
      isFalse,
    );

    await tester.drag(
      find.byKey(const ValueKey('auto-hide-list')),
      const Offset(0, -320),
    );
    await tester.pumpAndSettle();
    expect(slide().offset, const Offset(0, 1.15));
    expect(
      tester
          .widget<IgnorePointer>(
            find.byKey(const ValueKey('auto-hide-navigation-pointer')),
          )
          .ignoring,
      isTrue,
    );

    await tester.drag(
      find.byKey(const ValueKey('auto-hide-list')),
      const Offset(0, 120),
    );
    await tester.pumpAndSettle();
    expect(slide().offset, Offset.zero);
    expect(find.text('底部导航'), findsOneWidget);
  });

  testWidgets('向页面暴露导航可见状态和实际高度', (tester) async {
    AutoHideNavigationScope? scope;
    await tester.pumpWidget(
      MaterialApp(
        home: AutoHideScaffold(
          body: Builder(
            builder: (context) {
              scope = AutoHideNavigationScope.maybeOf(context);
              return ListView.builder(
                key: const ValueKey('scope-list'),
                itemCount: 30,
                itemExtent: 72,
                itemBuilder: (context, index) => Text('条目 $index'),
              );
            },
          ),
          bottomNavigationBar: const SizedBox(
            key: ValueKey('measured-bar'),
            height: 64,
            child: Center(child: Text('底部导航')),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(scope?.visible, isTrue);
    expect(scope?.bottomBarHeight, closeTo(64, .1));

    await tester.drag(
      find.byKey(const ValueKey('scope-list')),
      const Offset(0, -320),
    );
    await tester.pumpAndSettle();
    expect(scope?.visible, isFalse);
    expect(scope?.bottomBarHeight, closeTo(64, .1));
  });

  testWidgets('底部导航切换和高度变化不会破坏渲染树', (tester) async {
    var showBar = true;
    var barHeight = 64.0;
    late StateSetter updateScaffold;
    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) {
            updateScaffold = setState;
            return AutoHideScaffold(
              body: const SizedBox.expand(),
              bottomNavigationBar: showBar
                  ? SizedBox(
                      height: barHeight,
                      child: const Center(child: Text('底部导航')),
                    )
                  : null,
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    updateScaffold(() => showBar = false);
    await tester.pumpAndSettle();

    updateScaffold(() {
      showBar = true;
      barHeight = 82;
    });
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('底部导航'), findsOneWidget);
  });

  testWidgets('切换主页面时底部导航重新显示', (tester) async {
    Widget build(int token) => MaterialApp(
      home: AutoHideScaffold(
        resetToken: token,
        body: ListView.builder(
          key: ValueKey('reset-list-$token'),
          itemCount: 30,
          itemExtent: 72,
          itemBuilder: (context, index) => Text('页面 $token 条目 $index'),
        ),
        bottomNavigationBar: const SizedBox(
          height: 64,
          child: Center(child: Text('底部导航')),
        ),
      ),
    );

    await tester.pumpWidget(build(0));
    await tester.pumpAndSettle();
    await tester.drag(
      find.byKey(const ValueKey('reset-list-0')),
      const Offset(0, -320),
    );
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<AnimatedSlide>(
            find.byKey(const ValueKey('auto-hide-navigation')),
          )
          .offset,
      const Offset(0, 1.15),
    );

    await tester.pumpWidget(build(1));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<AnimatedSlide>(
            find.byKey(const ValueKey('auto-hide-navigation')),
          )
          .offset,
      Offset.zero,
    );
  });
}
