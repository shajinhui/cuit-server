import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';

/// 操作只描述显示信息，权限判断和实际执行留在页面。
class PageMenuAction<T> {
  const PageMenuAction({
    required this.value,
    required this.label,
    this.icon,
    this.destructive = false,
    this.enabled = true,
  });

  final T value;
  final String label;
  final IconData? icon;
  final bool destructive;
  final bool enabled;
}

class PageActionMenu<T> extends StatelessWidget {
  const PageActionMenu({
    super.key,
    required this.actions,
    required this.onSelected,
    this.tooltip = '更多操作',
  });

  final List<PageMenuAction<T>> actions;
  final ValueChanged<T>? onSelected;
  final String tooltip;

  @override
  Widget build(BuildContext context) => PopupMenuButton<T>(
    tooltip: tooltip,
    onSelected: onSelected,
    enabled: onSelected != null && actions.any((action) => action.enabled),
    useRootNavigator: true,
    icon: const Icon(Icons.more_horiz_rounded),
    color: Theme.of(context).colorScheme.surface,
    elevation: 3,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    constraints: const BoxConstraints(minWidth: 160, maxWidth: 280),
    itemBuilder: (context) => [
      for (final action in actions)
        PopupMenuItem<T>(
          value: action.value,
          enabled: action.enabled,
          height: 48,
          child: Row(
            children: [
              if (action.icon != null) ...[
                Icon(
                  action.icon,
                  size: 20,
                  color: action.destructive
                      ? Theme.of(context).colorScheme.error
                      : null,
                ),
                const SizedBox(width: 10),
              ],
              Expanded(
                child: Text(
                  action.label,
                  style: TextStyle(
                    color: action.destructive
                        ? Theme.of(context).colorScheme.error
                        : null,
                  ),
                ),
              ),
            ],
          ),
        ),
    ],
  );
}

/// 锚定到按钮的定位菜单；长内容滚动由调用方提供的组件处理。
Future<T?> showPagePopover<T>(
  BuildContext context, {
  required GlobalKey anchor,
  required WidgetBuilder builder,
  double width = 238,
}) {
  final box = anchor.currentContext?.findRenderObject();
  if (box is! RenderBox || !box.hasSize) return Future.value();
  final rect = box.localToGlobal(Offset.zero) & box.size;
  final media = MediaQuery.of(context);
  final menuWidth = math.min(width, media.size.width - 32);
  final left = rect.left.clamp(16.0, media.size.width - menuWidth - 16);
  final bottomLimit =
      media.size.height - media.padding.bottom - media.viewInsets.bottom - 16;
  final below = math.max(0.0, bottomLimit - rect.bottom - 6);
  final above = math.max(0.0, rect.top - media.padding.top - 22);
  final openAbove = below < 112 && above > below;
  final maxHeight = math.min(410.0, openAbove ? above : below);

  return showGeneralDialog<T>(
    context: context,
    useRootNavigator: true,
    barrierDismissible: true,
    barrierLabel: '关闭菜单',
    barrierColor: Colors.transparent,
    transitionDuration: media.disableAnimations
        ? Duration.zero
        : const Duration(milliseconds: 150),
    pageBuilder: (dialog, _, _) => InheritedTheme.captureAll(
      context,
      Stack(
        children: [
          Positioned(
            left: left,
            top: openAbove ? null : rect.bottom + 6,
            bottom: openAbove ? media.size.height - rect.top + 6 : null,
            width: menuWidth,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                child: Material(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? const Color(0xEE242A34)
                      : const Color(0xEEF4F7FC),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxHeight: maxHeight),
                    child: builder(dialog),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    ),
    transitionBuilder: (_, animation, _, child) =>
        FadeTransition(opacity: animation, child: child),
  );
}
