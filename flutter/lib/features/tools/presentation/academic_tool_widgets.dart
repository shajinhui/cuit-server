import 'dart:math' as math;

import 'package:chengxin_youyou/core/network/api_client.dart';
import 'package:chengxin_youyou/core/network/api_exception.dart';
import 'package:chengxin_youyou/features/schedule/models/semester.dart';
import 'package:flutter/material.dart';

import '../../../ui/components/page_layout.dart';

import 'tool_page_scaffold.dart';

Future<List<Semester>> loadAcademicSemesters(ApiClient? api) async {
  if (api == null) throw const ApiException('服务暂不可用。');
  final raw = await api.request('/api/v1/jwxt/semesters');
  if (raw is! List) throw const ApiException('学期列表格式异常。');
  final result = raw
      .map((item) => Semester.fromJson(item as Map<String, dynamic>))
      .toList();
  result.sort((left, right) {
    final year = right.schoolYear.compareTo(left.schoolYear);
    return year == 0 ? right.term.compareTo(left.term) : year;
  });
  return result;
}

Semester? preferredAcademicSemester(List<Semester> values) {
  for (final item in values) {
    if (item.isCurrent) return item;
  }
  return values.isEmpty ? null : values.first;
}

String academicErrorMessage(Object error) =>
    error is ApiException ? error.message : '读取失败，请检查网络后重试。';

Widget academicSemesterPicker({
  required List<Semester> semesters,
  required String? selected,
  required ValueChanged<String> onChanged,
  String label = '学期',
}) => ToolField(
  label: label,
  child: _SemesterPicker(
    semesters: semesters,
    selected: selected,
    onChanged: onChanged,
  ),
);

/// 学期文本单独排版，避免「第2学期」挤在没有空格的短横线后面。
String _semesterLabel(Semester item) =>
    '${item.schoolYear} · 第 ${item.term} 学期';

/// 收起态是一行描边胶囊，展开交给底部弹层，长学期列表不再撑满整屏。
class _SemesterPicker extends StatelessWidget {
  const _SemesterPicker({
    required this.semesters,
    required this.selected,
    required this.onChanged,
  });

  final List<Semester> semesters;
  final String? selected;
  final ValueChanged<String> onChanged;

  Semester? get _current {
    for (final item in semesters) {
      if (item.id == selected) return item;
    }
    return semesters.isEmpty ? null : semesters.first;
  }

  Future<void> _open(BuildContext context) async {
    final picked = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      // 沿用全局弹层的圆角、下拉手柄与背景，只限制最大高度。
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * .72,
      ),
      builder: (_) => _SemesterSheet(
        semesters: semesters,
        selected: selected ?? _current?.id,
      ),
    );
    if (picked != null && picked != selected) onChanged(picked);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final accent = pageAccent(context);
    final current = _current;
    final label = current == null ? '暂无学期' : _semesterLabel(current);
    return Semantics(
      button: true,
      label: '选择学期，当前$label',
      child: Material(
        color: colors.surface,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: colors.outlineVariant.withValues(alpha: .9)),
        ),
        child: InkWell(
          onTap: semesters.isEmpty ? null : () => _open(context),
          child: SizedBox(
            height: 48,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(13, 0, 10, 0),
              child: Row(
                children: [
                  Icon(Icons.event_note_rounded, size: 17, color: accent),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  if (current?.isCurrent ?? false) ...[
                    const SizedBox(width: 8),
                    _CurrentBadge(color: accent),
                  ],
                  const SizedBox(width: 3),
                  Icon(
                    Icons.expand_more_rounded,
                    size: 20,
                    color: colors.onSurfaceVariant,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CurrentBadge extends StatelessWidget {
  const _CurrentBadge({required this.color});
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    decoration: BoxDecoration(
      color: color.withValues(alpha: .1),
      borderRadius: BorderRadius.circular(6),
    ),
    child: Text(
      '当前',
      style: TextStyle(
        fontSize: 10,
        height: 1.35,
        fontWeight: FontWeight.w600,
        color: color,
      ),
    ),
  );
}

class _SemesterSheet extends StatefulWidget {
  const _SemesterSheet({required this.semesters, required this.selected});

  final List<Semester> semesters;
  final String? selected;

  @override
  State<_SemesterSheet> createState() => _SemesterSheetState();
}

class _SemesterSheetState extends State<_SemesterSheet> {
  static const _rowHeight = 46.0;
  static const _listTopPadding = 4.0;
  static const _listBottomPadding = 12.0;
  late final ScrollController _scroll;

  int get _selectedIndex {
    final index = widget.semesters.indexWhere(
      (item) => item.id == widget.selected,
    );
    return index < 0 ? 0 : index;
  }

  @override
  void initState() {
    super.initState();
    // 学期多时默认把当前选中项带进可视区，省去首次滑动。
    _scroll = ScrollController(
      initialScrollOffset: math.max(
        0,
        _selectedIndex * _rowHeight - _rowHeight,
      ),
    );
    // 初始偏移被滚动范围截断后会停在半行上，第一帧结束后对齐到整行。
    WidgetsBinding.instance.addPostFrameCallback((_) => _snapToRows());
  }

  void _snapToRows() {
    if (!mounted || !_scroll.hasClients) return;
    final position = _scroll.position;
    if (!position.hasContentDimensions) return;
    final snapped = (_scroll.offset / _rowHeight).roundToDouble() * _rowHeight;
    final target = snapped
        .clamp(position.minScrollExtent, position.maxScrollExtent)
        .toDouble();
    if ((target - _scroll.offset).abs() > .5) _scroll.jumpTo(target);
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final accent = pageAccent(context);
    return SafeArea(
      top: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 2, 18, 6),
            child: Row(
              children: [
                const Text(
                  '选择学期',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                const Spacer(),
                Text(
                  '共 ${widget.semesters.length} 个',
                  style: TextStyle(
                    fontSize: 12,
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Flexible(
            child: LayoutBuilder(
              builder: (context, constraints) {
                // 底部补白对齐到整行，滚动条停在哪一行都不会切出半行文字。
                final content =
                    _listTopPadding +
                    widget.semesters.length * _rowHeight +
                    _listBottomPadding;
                final overflow = content - constraints.maxHeight;
                final remain = overflow <= 0 ? 0.0 : overflow % _rowHeight;
                final filler = remain < .01 ? 0.0 : _rowHeight - remain;
                return ListView.builder(
                  controller: _scroll,
                  shrinkWrap: true,
                  padding: EdgeInsets.fromLTRB(
                    8,
                    _listTopPadding,
                    8,
                    _listBottomPadding + filler,
                  ),
                  itemCount: widget.semesters.length,
                  itemExtent: _rowHeight,
                  itemBuilder: (context, index) {
                    final item = widget.semesters[index];
                    final active = item.id == widget.selected;
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: Material(
                        color: active
                            ? accent.withValues(alpha: .08)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                        clipBehavior: Clip.antiAlias,
                        child: InkWell(
                          onTap: () => Navigator.of(context).pop(item.id),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            child: Row(
                              children: [
                                Icon(
                                  active
                                      ? Icons.check_circle_rounded
                                      : Icons.circle_outlined,
                                  size: 18,
                                  color: active
                                      ? accent
                                      : colors.onSurfaceVariant.withValues(
                                          alpha: .35,
                                        ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    _semesterLabel(item),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: active
                                          ? FontWeight.w600
                                          : FontWeight.w400,
                                      color: active ? accent : null,
                                    ),
                                  ),
                                ),
                                if (item.isCurrent && !active) ...[
                                  const SizedBox(width: 8),
                                  _CurrentBadge(color: accent),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class AcademicEmptyCard extends StatelessWidget {
  const AcademicEmptyCard({super.key, required this.text, this.detail});
  final String text;
  final String? detail;
  @override
  Widget build(BuildContext context) => ToolCard(
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 44),
    child: Column(
      children: [
        Text(
          '—',
          style: TextStyle(
            fontSize: 32,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          text,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
        ),
        if (detail != null) ...[
          const SizedBox(height: 6),
          Text(
            detail!,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ],
    ),
  );
}
