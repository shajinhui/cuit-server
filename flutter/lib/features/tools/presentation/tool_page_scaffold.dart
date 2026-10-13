import 'package:flutter/material.dart';

import '../../../ui/components/page_layout.dart';

// 保留已有工具页的命名和导入入口；样式由全应用共用的页面组件维护。
class ToolPageScaffold extends PageScaffold {
  const ToolPageScaffold({
    super.key,
    required super.title,
    required super.child,
    super.subtitle,
    super.actions,
    super.onBack,
    super.hideTitle,
    super.backgroundColor,
    super.maxWidth,
    super.header,
    super.bottomNavigationBar,
  }) : super(backLabel: '返回工具页');
}

typedef ToolCard = PageCard;
typedef ToolSectionHeading = PageSectionHeading;
typedef ToolField = PageField;
typedef ToolChoiceButton = PageChoiceButton;
typedef ToolSegmentedControl<T> = PageSegmentedControl<T>;
typedef ToolGroupedList = PageGroupedList;
typedef ToolMessage = PageMessage;
typedef ToolLoading = PageLoading;

Color toolBackground(BuildContext context) => pageBackground(context);
Color toolAccent(BuildContext context) => pageAccent(context);
