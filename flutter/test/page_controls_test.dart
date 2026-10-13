import 'package:chengxin_youyou/features/campus/presentation/campus_report_dialog.dart';
import 'package:chengxin_youyou/ui/components/page_dialog.dart';
import 'package:chengxin_youyou/ui/components/page_menu.dart';
import 'package:chengxin_youyou/ui/components/page_selection.dart';
import 'package:chengxin_youyou/ui/components/page_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  void smallScreen(WidgetTester tester) {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  testWidgets('下拉框同步外部重置，空值选项可恢复，长标签在小屏大字体下可选择', (tester) async {
    smallScreen(tester);
    var selected = 'first';
    int? capacity = 20;
    var changes = 0;
    late StateSetter update;
    await tester.pumpWidget(
      _app(
        StatefulBuilder(
          builder: (context, setState) {
            update = setState;
            return Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  PageDropdownField<String>(
                    key: const Key('long-dropdown'),
                    value: selected,
                    values: const {
                      'first': '第一学期：这是一个用于检查换行的较长学期名称',
                      'second': '第二学期：这是另一个用于检查换行的较长学期名称',
                    },
                    onChanged: (value) => setState(() {
                      selected = value!;
                      changes++;
                    }),
                  ),
                  PageDropdownField<int?>(
                    key: const Key('capacity-dropdown'),
                    value: capacity,
                    values: const {null: '不限', 20: '20 人以上'},
                    onChanged: (value) => setState(() => capacity = value),
                  ),
                ],
              ),
            );
          },
        ),
        textScale: 1.5,
      ),
    );
    update(() => selected = 'second');
    await tester.pump();
    final field = tester.state<FormFieldState<String>>(
      find.byType(DropdownButtonFormField<String>),
    );
    expect(field.value, 'second');
    expect(changes, 0);
    await tester.tap(find.byKey(const Key('long-dropdown')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('第一学期：这是一个用于检查换行的较长学期名称').last);
    await tester.pumpAndSettle();
    expect(selected, 'first');
    expect(changes, 1);
    await tester.tap(find.byKey(const Key('capacity-dropdown')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('不限').last);
    await tester.pumpAndSettle();
    expect(capacity, isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('操作菜单的禁用动作不会执行，选择有效动作只回调一次', (tester) async {
    var selections = <String>[];
    await tester.pumpWidget(
      _app(
        PageActionMenu<String>(
          actions: const [
            PageMenuAction(value: 'report', label: '举报'),
            PageMenuAction(
              value: 'delete',
              label: '删除',
              destructive: true,
              enabled: false,
            ),
          ],
          onSelected: selections.add,
        ),
      ),
    );
    await tester.tap(find.byTooltip('更多操作'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('删除'));
    await tester.pumpAndSettle();
    expect(selections, isEmpty);
    await tester.tap(find.text('举报'));
    await tester.pumpAndSettle();
    expect(selections, ['report']);
  });

  testWidgets('确认弹窗适配小屏大字体和键盘，取消与确认返回不同结果', (tester) async {
    smallScreen(tester);
    tester.view.viewInsets = const FakeViewPadding(bottom: 200);
    addTearDown(tester.view.resetViewInsets);
    bool? result;
    await tester.pumpWidget(
      _app(
        Builder(
          builder: (context) => FilledButton(
            onPressed: () async => result = await showPageConfirmation(
              context,
              title: '确认操作',
              content: Text(List.filled(20, '较长的说明文字应当能够滚动阅读。').join()),
            ),
            child: const Text('打开确认'),
          ),
        ),
        textScale: 1.5,
      ),
    );
    await tester.tap(find.text('打开确认'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    expect(result, isFalse);
    await tester.tap(find.text('打开确认'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('确认'));
    await tester.pumpAndSettle();
    expect(result, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('底部弹层挂在根导航器并避让键盘，内部不重复叠加安全区', (tester) async {
    smallScreen(tester);
    tester.view.viewInsets = const FakeViewPadding(bottom: 180);
    addTearDown(tester.view.resetViewInsets);
    final root = _RouteObserver();
    final branch = _RouteObserver();
    String? result;
    EdgeInsets? childInsets;
    await tester.pumpWidget(
      MaterialApp(
        navigatorObservers: [root],
        home: Scaffold(
          bottomNavigationBar: const SizedBox(height: 60, child: Text('根导航')),
          body: Navigator(
            observers: [branch],
            onGenerateRoute: (_) => MaterialPageRoute<void>(
              builder: (context) => Scaffold(
                body: Center(
                  child: FilledButton(
                    onPressed: () async => result = await showPageSheet<String>(
                      context,
                      builder: (context) {
                        childInsets = MediaQuery.viewInsetsOf(context);
                        return SizedBox(
                          key: const Key('sheet-content'),
                          height: 160,
                          width: double.infinity,
                          child: Center(
                            child: FilledButton(
                              onPressed: () =>
                                  Navigator.pop(context, 'selected'),
                              child: const Text('完成选择'),
                            ),
                          ),
                        );
                      },
                    ),
                    child: const Text('打开弹层'),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('打开弹层'));
    await tester.pumpAndSettle();
    expect(root.pushes, 2);
    expect(branch.pushes, 1);
    expect(childInsets?.bottom, 0);
    expect(
      tester.getBottomLeft(find.byKey(const Key('sheet-content'))).dy,
      lessThanOrEqualTo(388),
    );
    await tester.tap(find.text('完成选择'));
    await tester.pumpAndSettle();
    expect(result, 'selected');
    expect(tester.takeException(), isNull);
  });

  testWidgets('定位菜单在右下角和窄屏上向上展开，不超出屏幕边缘', (tester) async {
    smallScreen(tester);
    final anchor = GlobalKey();
    int? result;
    await tester.pumpWidget(
      _app(
        Builder(
          builder: (context) => Align(
            alignment: Alignment.bottomRight,
            child: TextButton(
              key: anchor,
              onPressed: () async => result = await showPagePopover<int>(
                context,
                anchor: anchor,
                width: 500,
                builder: (context) => ListView(
                  key: const Key('popover-options'),
                  shrinkWrap: true,
                  children: [
                    for (var i = 1; i <= 30; i++)
                      ListTile(
                        title: Text('选项 $i'),
                        onTap: () => Navigator.pop(context, i),
                      ),
                  ],
                ),
              ),
              child: const Text('定位菜单'),
            ),
          ),
        ),
        textScale: 1.5,
      ),
    );
    await tester.tap(find.text('定位菜单'));
    await tester.pumpAndSettle();
    final menu = tester.getRect(find.byKey(const Key('popover-options')));
    expect(menu.left, greaterThanOrEqualTo(16));
    expect(menu.right, lessThanOrEqualTo(304));
    expect(menu.bottom, lessThan(tester.getTopLeft(find.byKey(anchor)).dy));
    await tester.tap(find.text('选项 2'));
    await tester.pumpAndSettle();
    expect(result, 2);
    expect(tester.takeException(), isNull);
  });

  testWidgets('举报弹窗保留字数校验，关闭动画不会提前释放输入控制器', (tester) async {
    String? result;
    await tester.pumpWidget(
      _app(
        Builder(
          builder: (context) => FilledButton(
            onPressed: () async =>
                result = await askCampusReportReason(context),
            child: const Text('打开举报'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('打开举报'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '理由');
    await tester.tap(find.text('提交'));
    await tester.pump();
    expect(find.text('请填写 5 到 300 个字的原因。'), findsOneWidget);
    expect(result, isNull);
    await tester.enterText(find.byType(TextField), '内容包含虚假信息');
    await tester.tap(find.text('提交'));
    await tester.pumpAndSettle();
    expect(result, '内容包含虚假信息');
    expect(tester.takeException(), isNull);
  });
}

Widget _app(Widget child, {double textScale = 1}) => MaterialApp(
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(
      context,
    ).copyWith(textScaler: TextScaler.linear(textScale)),
    child: child!,
  ),
  home: Scaffold(body: child),
);

class _RouteObserver extends NavigatorObserver {
  int pushes = 0;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    pushes++;
    super.didPush(route, previousRoute);
  }
}
