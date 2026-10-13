import 'package:flutter/material.dart';

/// 沿用原 Vue 页面的灰底、居中标题和圆形按钮。
/// 页面按需使用局部主题，不改变课表网格和原生导航的样式。
class PageScaffold extends StatelessWidget {
  const PageScaffold({
    super.key,
    required this.title,
    required this.child,
    this.subtitle,
    this.actions = const [],
    this.onBack,
    this.hideTitle = false,
    this.backgroundColor,
    this.maxWidth = 480,
    this.header,
    this.bottomNavigationBar,
    this.floatingActionButton,
    this.backLabel = '返回',
  });

  final String title;
  final String? subtitle;
  final Widget child;
  final List<Widget> actions;
  final VoidCallback? onBack;
  final bool hideTitle;
  final Color? backgroundColor;
  final double maxWidth;
  final Widget? header;
  final Widget? bottomNavigationBar;
  final Widget? floatingActionButton;
  final String backLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final background = backgroundColor ?? pageBackground(context);
    final localTheme = pageTheme(context, backgroundColor: backgroundColor);
    return Theme(
      data: localTheme,
      child: Scaffold(
        backgroundColor: background,
        bottomNavigationBar: bottomNavigationBar,
        floatingActionButton: floatingActionButton,
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxWidth),
              child: Column(
                children: [
                  header ??
                      Padding(
                        padding: const EdgeInsets.fromLTRB(22, 8, 22, 8),
                        child: Row(
                          children: [
                            IconButton(
                              tooltip: backLabel,
                              onPressed:
                                  onBack ??
                                  () => Navigator.of(context).maybePop(),
                              icon: const Icon(
                                Icons.chevron_left_rounded,
                                size: 28,
                              ),
                            ),
                            Expanded(
                              child: hideTitle
                                  ? const SizedBox.shrink()
                                  : Column(
                                      children: [
                                        Text(
                                          title,
                                          textAlign: TextAlign.center,
                                          style: const TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        if (subtitle != null)
                                          Text(
                                            subtitle!,
                                            textAlign: TextAlign.center,
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: theme
                                                  .colorScheme
                                                  .onSurfaceVariant,
                                            ),
                                          ),
                                      ],
                                    ),
                            ),
                            if (actions.isEmpty)
                              const SizedBox(width: 44)
                            else
                              ...actions,
                          ],
                        ),
                      ),
                  Expanded(child: child),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 公共视觉规则由页面显式采用，避免全局主题影响业务页面。
ThemeData pageTheme(BuildContext context, {Color? backgroundColor}) {
  final theme = Theme.of(context);
  final dark = theme.brightness == Brightness.dark;
  final surface = dark ? const Color(0xFF2C2C2E) : Colors.white;
  final background = backgroundColor ?? pageBackground(context);
  return theme.copyWith(
    colorScheme: theme.colorScheme.copyWith(
      primary: pageAccent(context),
      surface: surface,
      onSurface: dark ? const Color(0xFFF2F2F7) : const Color(0xFF1C1C1E),
    ),
    scaffoldBackgroundColor: background,
    cardTheme: CardThemeData(
      color: surface,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(
        minimumSize: const Size(44, 44),
        maximumSize: const Size(44, 44),
        padding: EdgeInsets.zero,
        iconSize: 21,
        backgroundColor: surface.withValues(alpha: .8),
        foregroundColor: theme.colorScheme.onSurface,
        shape: const CircleBorder(),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: pageAccent(context),
        foregroundColor: Colors.white,
        minimumSize: const Size(44, 52),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(44, 48),
        backgroundColor: background,
        foregroundColor: theme.colorScheme.onSurface,
        side: BorderSide.none,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: background,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: pageAccent(context)),
      ),
    ),
  );
}

Color pageBackground(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark
    ? const Color(0xFF1C1C1E)
    : const Color(0xFFF2F2F7);

Color pageAccent(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark
    ? const Color(0xFF409CFF)
    : const Color(0xFF0088FF);

/// 原版共用的圆角分组容器；不为每一行单独增加阴影或模糊。
class PageCard extends StatelessWidget {
  const PageCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.radius = 22,
  });
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;

  @override
  Widget build(BuildContext context) => Material(
    color: Theme.of(context).colorScheme.surface,
    borderRadius: BorderRadius.circular(radius),
    clipBehavior: Clip.antiAlias,
    child: Padding(padding: padding, child: child),
  );
}

class PageSectionHeading extends StatelessWidget {
  const PageSectionHeading({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
    this.subtitleAbove = false,
    this.titleSize = 20,
  });
  final String title;
  final String? subtitle;
  final String? trailing;
  final bool subtitleAbove;
  final double titleSize;
  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.center,
    children: [
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (subtitleAbove && subtitle != null)
              Text(
                subtitle!,
                style: TextStyle(
                  fontSize: 11,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            Text(
              title,
              style: TextStyle(
                fontSize: titleSize,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (!subtitleAbove && subtitle != null)
              Text(
                subtitle!,
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
          ],
        ),
      ),
      if (trailing != null) ...[
        const SizedBox(width: 8),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 150),
          child: Text(
            trailing!,
            textAlign: TextAlign.end,
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    ],
  );
}

class PageField extends StatelessWidget {
  const PageField({super.key, required this.label, required this.child});
  final String label;
  final Widget child;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: TextStyle(
          fontSize: 13,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
      const SizedBox(height: 8),
      child,
    ],
  );
}

class PageChoiceButton extends StatelessWidget {
  const PageChoiceButton({
    super.key,
    required this.label,
    required this.selected,
    required this.onPressed,
  });
  final String label;
  final bool selected;
  final VoidCallback? onPressed;
  @override
  Widget build(BuildContext context) => Semantics(
    selected: selected,
    child: TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        minimumSize: const Size(44, 44),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        backgroundColor: selected
            ? pageAccent(context)
            : pageBackground(context),
        foregroundColor: selected
            ? Colors.white
            : Theme.of(context).colorScheme.onSurfaceVariant,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
      ),
      child: Text(label, textAlign: TextAlign.center),
    ),
  );
}

/// 校区、预约类型沿用原版胶囊切换；标签允许换行以适配大字体。
class PageSegmentedControl<T> extends StatelessWidget {
  const PageSegmentedControl({
    super.key,
    required this.values,
    required this.selected,
    required this.onChanged,
  });
  final Map<T, String> values;
  final T selected;
  final ValueChanged<T>? onChanged;
  @override
  Widget build(BuildContext context) => PageCard(
    radius: 24,
    padding: const EdgeInsets.all(4),
    child: Row(
      children: [
        for (final item in values.entries)
          Expanded(
            child: Semantics(
              selected: selected == item.key,
              child: TextButton(
                onPressed: onChanged == null
                    ? null
                    : () => onChanged!(item.key),
                style: TextButton.styleFrom(
                  minimumSize: const Size(44, 44),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 10,
                  ),
                  foregroundColor: Theme.of(context).colorScheme.onSurface,
                  backgroundColor: selected == item.key
                      ? pageBackground(context)
                      : Colors.transparent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                child: Text(
                  item.value,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
      ],
    ),
  );
}

class PageGroupedList extends StatelessWidget {
  const PageGroupedList({super.key, required this.children});
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => PageCard(
    padding: EdgeInsets.zero,
    child: Column(
      children: [
        for (var i = 0; i < children.length; i++) ...[
          if (i > 0)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 17),
              child: Divider(height: 1, thickness: .5),
            ),
          children[i],
        ],
      ],
    ),
  );
}

class PageMessage extends StatelessWidget {
  const PageMessage({super.key, required this.message, this.onRetry});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            onRetry == null
                ? Icons.info_outline_rounded
                : Icons.cloud_off_rounded,
            size: 42,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 12),
          Text(message, textAlign: TextAlign.center),
          if (onRetry != null) ...[
            const SizedBox(height: 16),
            OutlinedButton(onPressed: onRetry, child: const Text('重新加载')),
          ],
        ],
      ),
    ),
  );
}

class PageLoading extends StatelessWidget {
  const PageLoading({super.key, this.label = '正在读取…'});
  final String label;

  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(strokeWidth: 2.4),
        ),
        const SizedBox(height: 14),
        Text(label, style: Theme.of(context).textTheme.bodyMedium),
      ],
    ),
  );
}
