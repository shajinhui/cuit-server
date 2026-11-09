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
  bool glass = false,
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
        : const Duration(milliseconds: 190),
    pageBuilder: (dialog, _, _) => InheritedTheme.captureAll(
      context,
      Stack(
        children: [
          Positioned(
            left: left,
            top: openAbove ? null : rect.bottom + 6,
            bottom: openAbove ? media.size.height - rect.top + 6 : null,
            width: menuWidth,
            child: _PopoverSurface(
              glass: glass,
              maxHeight: maxHeight,
              child: builder(dialog),
            ),
          ),
        ],
      ),
    ),
    transitionBuilder: (_, animation, _, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      );
      return FadeTransition(
        opacity: curved,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: Offset(0, openAbove ? .018 : -.018),
            end: Offset.zero,
          ).animate(curved),
          child: ScaleTransition(
            scale: Tween<double>(begin: .985, end: 1).animate(curved),
            child: child,
          ),
        ),
      );
    },
  );
}

class _PopoverSurface extends StatelessWidget {
  const _PopoverSurface({
    required this.glass,
    required this.maxHeight,
    required this.child,
  });

  final bool glass;
  final double maxHeight;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final surface = ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: BackdropFilter(
        filter: ImageFilter.blur(
          sigmaX: glass ? 22 : 20,
          sigmaY: glass ? 22 : 20,
        ),
        child: glass
            ? DecoratedBox(
                decoration: BoxDecoration(
                  color: dark
                      ? const Color(0xE6232933)
                      : const Color(0xE6F7FAFE),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: dark ? .16 : .62),
                    width: .8,
                  ),
                ),
                child: Material(
                  type: MaterialType.transparency,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxHeight: maxHeight),
                    child: child,
                  ),
                ),
              )
            : Material(
                color: dark ? const Color(0xEE242A34) : const Color(0xEEF4F7FC),
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxHeight: maxHeight),
                  child: child,
                ),
              ),
      ),
    );
    return glass
        ? DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: dark ? .28 : .12),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: surface,
          )
        : surface;
  }
}
