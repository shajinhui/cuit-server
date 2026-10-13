import 'package:flutter/material.dart';

import '../../../../ui/components/page_sheet.dart';

/// 保留课表的调用入口；公共层统一处理层级、宽度与键盘。
Future<T?> showScheduleSheet<T>(
  BuildContext context,
  Widget child, {
  bool floating = false,
}) => showPageSheet<T>(
  context,
  builder: (_) => child,
  floating: floating,
  showHandle: false,
  blurBackdrop: true,
);

typedef SheetHandle = PageSheetHandle;
