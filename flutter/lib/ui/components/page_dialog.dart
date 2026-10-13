import 'package:flutter/material.dart';

import 'page_layout.dart';

/// 对话框统一挂在根导航器上，并沿用当前页面的主题。
Future<T?> showPageDialog<T>(
  BuildContext context, {
  required WidgetBuilder builder,
  bool barrierDismissible = true,
}) => showDialog<T>(
  context: context,
  useRootNavigator: true,
  barrierDismissible: barrierDismissible,
  builder: (dialogContext) => Theme(
    data: pageTheme(dialogContext),
    child: Builder(builder: builder),
  ),
);

/// 内容较长时自动滚动，键盘与安全区由 Flutter Dialog 处理。
class PageAlertDialog extends StatelessWidget {
  const PageAlertDialog({
    super.key,
    required this.title,
    required this.content,
    this.actions = const [],
    this.icon,
  });

  final Widget title;
  final Widget content;
  final List<Widget> actions;
  final Widget? icon;

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: title,
    content: content,
    icon: icon,
    actions: actions,
    scrollable: true,
    backgroundColor: Theme.of(context).colorScheme.surface,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
    insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
    constraints: const BoxConstraints(maxWidth: 480),
    actionsOverflowButtonSpacing: 8,
  );
}

/// 自定义表单弹窗仍使用同一容器，不把业务字段搬进公共层。
class PageDialog extends StatelessWidget {
  const PageDialog({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(24),
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) => Dialog(
    backgroundColor: Theme.of(context).colorScheme.surface,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
    insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
    constraints: const BoxConstraints(maxWidth: 480),
    child: SingleChildScrollView(padding: padding, child: child),
  );
}

Future<bool> showPageConfirmation(
  BuildContext context, {
  required String title,
  required Widget content,
  String confirmLabel = '确认',
  String cancelLabel = '取消',
  bool destructive = false,
}) async =>
    await showPageDialog<bool>(
      context,
      builder: (dialogContext) => PageAlertDialog(
        title: Text(title),
        content: content,
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(cancelLabel),
          ),
          FilledButton(
            style: destructive
                ? FilledButton.styleFrom(
                    backgroundColor: Theme.of(dialogContext).colorScheme.error,
                  )
                : null,
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(confirmLabel),
          ),
        ],
      ),
    ) ==
    true;

/// 单选弹窗用于续座时长等短列表，取消时返回 null。
Future<T?> showPageChoice<T>(
  BuildContext context, {
  required String title,
  required Map<T, String> values,
  T? selected,
}) => showPageDialog<T>(
  context,
  builder: (dialogContext) => PageDialog(
    padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Text(
            title,
            style: Theme.of(dialogContext).textTheme.titleLarge,
          ),
        ),
        const SizedBox(height: 12),
        for (final entry in values.entries)
          ListTile(
            title: Text(entry.value),
            selected: selected == entry.key,
            trailing: selected == entry.key
                ? const Icon(Icons.check_rounded)
                : null,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            onTap: () => Navigator.pop(dialogContext, entry.key),
          ),
      ],
    ),
  ),
);
