import 'dart:math' as math;

import 'package:flutter/material.dart';

/// 标题栏、设置行中的下拉选择；选项与状态由页面提供。
class PageDropdown<T> extends StatelessWidget {
  const PageDropdown({
    super.key,
    required this.value,
    required this.values,
    required this.onChanged,
    this.expanded = false,
    this.style,
    this.iconSize = 20,
    this.semanticLabel,
  });

  final T? value;
  final Map<T, String> values;
  final ValueChanged<T?>? onChanged;
  final bool expanded;
  final TextStyle? style;
  final double iconSize;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) => Semantics(
    label: semanticLabel,
    child: DropdownButton<T>(
      value: values.containsKey(value) ? value : null,
      items: _menuItems(values),
      selectedItemBuilder: (_) => _selectedItems(values),
      hint: _hint(values, value),
      onChanged: onChanged,
      isExpanded: expanded,
      underline: const SizedBox.shrink(),
      style: style ?? Theme.of(context).textTheme.titleMedium,
      icon: Icon(Icons.keyboard_arrow_down_rounded, size: iconSize),
      dropdownColor: Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.circular(16),
      menuMaxHeight: _menuHeight(context),
      itemHeight: null,
      elevation: 3,
    ),
  );
}

/// 表单中的下拉选择，沿用 Flutter 的校验、焦点和禁用行为。
class PageDropdownField<T> extends StatelessWidget {
  const PageDropdownField({
    super.key,
    required this.value,
    required this.values,
    required this.onChanged,
    this.decoration = const InputDecoration(),
    this.validator,
  });

  final T? value;
  final Map<T, String> values;
  final ValueChanged<T?>? onChanged;
  final InputDecoration decoration;
  final FormFieldValidator<T>? validator;

  @override
  Widget build(BuildContext context) => DropdownButtonFormField<T>(
    // Flutter 会同步新的 initialValue，不另外维护一份选中状态。
    initialValue: values.containsKey(value) ? value : null,
    items: _menuItems(values),
    selectedItemBuilder: (_) => _selectedItems(values),
    hint: _hint(values, value),
    onChanged: onChanged,
    validator: validator,
    decoration: decoration,
    isExpanded: true,
    icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 20),
    dropdownColor: Theme.of(context).colorScheme.surface,
    borderRadius: BorderRadius.circular(16),
    menuMaxHeight: _menuHeight(context),
    itemHeight: null,
    elevation: 3,
  );
}

List<DropdownMenuItem<T>> _menuItems<T>(Map<T, String> values) => [
  for (final entry in values.entries)
    DropdownMenuItem<T>(
      value: entry.key,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 48),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          // 菜单允许换行；收起后的选中项单独使用省略号。
          child: Align(
            alignment: AlignmentDirectional.centerStart,
            child: Text(entry.value),
          ),
        ),
      ),
    ),
];

List<Widget> _selectedItems<T>(Map<T, String> values) => [
  for (final label in values.values)
    Align(
      alignment: AlignmentDirectional.centerStart,
      child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
    ),
];

Widget _hint<T>(Map<T, String> values, T? value) =>
    Text(values[value] ?? '请选择', maxLines: 1, overflow: TextOverflow.ellipsis);

double _menuHeight(BuildContext context) =>
    math.min(400, MediaQuery.sizeOf(context).height * .6);
