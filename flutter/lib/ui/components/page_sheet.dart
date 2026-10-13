import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';

/// 所有底部弹层共用层级、最大宽度、键盘避让和底部安全区。
Future<T?> showPageSheet<T>(
  BuildContext context, {
  required WidgetBuilder builder,
  bool floating = false,
  bool showHandle = true,
  bool blurBackdrop = false,
}) => showModalBottomSheet<T>(
  context: context,
  useRootNavigator: true,
  isScrollControlled: true,
  useSafeArea: true,
  showDragHandle: false,
  enableDrag: !floating,
  backgroundColor: Colors.transparent,
  barrierColor: Colors.black.withValues(alpha: .18),
  constraints: const BoxConstraints(maxWidth: 480),
  builder: (sheetContext) => LayoutBuilder(
    builder: (context, constraints) {
      final media = MediaQuery.of(context);
      final bottom =
          media.viewInsets.bottom + media.padding.bottom + (floating ? 12 : 0);
      final maxHeight = math.max(
        0.0,
        constraints.maxHeight - bottom - (floating ? 36 : 12),
      );
      final dark = Theme.of(context).brightness == Brightness.dark;
      Widget sheet = Padding(
        padding: EdgeInsets.fromLTRB(
          floating ? 12 : 0,
          0,
          floating ? 12 : 0,
          bottom,
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxHeight),
          child: Material(
            color: dark ? const Color(0xFF2C2C2E) : const Color(0xF5FFFFFF),
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(floating ? 26 : 24),
              bottom: Radius.circular(floating ? 26 : 0),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (showHandle) const PageSheetHandle(),
                Flexible(
                  // 容器已经避让键盘和安全区，内部不再重复叠加。
                  child: MediaQuery.removePadding(
                    context: context,
                    removeBottom: true,
                    child: MediaQuery.removeViewInsets(
                      context: context,
                      removeBottom: true,
                      child: Builder(builder: builder),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      if (blurBackdrop) {
        sheet = BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 3, sigmaY: 3),
          child: sheet,
        );
      }
      return sheet;
    },
  ),
);

class PageSheetHandle extends StatelessWidget {
  const PageSheetHandle({super.key});

  @override
  Widget build(BuildContext context) => Center(
    child: Container(
      margin: const EdgeInsets.only(top: 8, bottom: 2),
      width: 36,
      height: 5,
      decoration: BoxDecoration(
        color: Colors.grey.withValues(alpha: .3),
        borderRadius: BorderRadius.circular(4),
      ),
    ),
  );
}
