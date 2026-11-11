import 'package:chengxin_youyou/features/campus/presentation/marketplace_editor_page.dart';
import 'package:chengxin_youyou/ui/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes/campus_preview_repository.dart';

Widget _app(Widget page) =>
    MaterialApp(theme: AppTheme.build(Brightness.light), home: page);

void main() {
  testWidgets('发布页选项胶囊可就地点选，底部发布栏始终可见', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      _app(MarketplaceEditorPage(repository: CampusPreviewRepository())),
    );
    await tester.pumpAndSettle();

    // 校区是原生胶囊而不是下拉框，首屏即可点选。
    expect(find.text('航空港校区'), findsOneWidget);
    expect(find.text('龙泉校区'), findsOneWidget);
    await tester.tap(find.text('龙泉校区'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    // 发布按钮固定在底部，不随列表滚动。
    final button = find.widgetWithText(FilledButton, '确认上架');
    expect(button, findsOneWidget);
    expect(tester.getRect(button).bottom, lessThanOrEqualTo(844));

    // 空表单提交的提示也出现在底部栏里，同样不需要滚动。
    await tester.tap(button);
    await tester.pumpAndSettle();
    expect(find.text('请检查必填内容、价格和联系方式。'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('切换求购时标题与字段文案同步变化', (tester) async {
    await tester.pumpWidget(
      _app(MarketplaceEditorPage(repository: CampusPreviewRepository())),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('我想求购'));
    await tester.pumpAndSettle();
    expect(find.text('发布求购'), findsWidgets);
    expect(find.text('求购信息'), findsOneWidget);
    expect(find.text('求购标题'), findsOneWidget);
    expect(find.text('需求说明'), findsOneWidget);
    expect(find.text('预算（元）'), findsOneWidget);
    expect(find.text('参考图片（选填）'), findsOneWidget);
    // 列表懒构建，先滚动到联系方式分组再断言。
    await tester.drag(find.byType(ListView), const Offset(0, -500));
    await tester.pumpAndSettle();
    expect(find.text('我的联系方式'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
