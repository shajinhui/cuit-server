import 'package:chengxin_youyou/features/campus/data/campus_repository.dart';
import 'package:chengxin_youyou/features/campus/models/campus_models.dart';
import 'package:flutter/material.dart';

import '../../../ui/components/page_layout.dart';
import 'campus_widgets.dart';

class ForumPollData {
  const ForumPollData({
    required this.question,
    required this.options,
    this.plainBody = '',
  });

  final String question;
  final List<String> options;
  final String plainBody;
}

/// 兼容当前帖子正文里的投票标记，逐步过渡到结构化投票字段。
ForumPollData? parseForumPoll(String body) {
  final lines = body.split('\n');
  final markerIndex = lines.indexWhere(
    (line) => line.trimLeft().startsWith('投票：'),
  );
  if (markerIndex < 0) return null;

  final marker = lines[markerIndex].trim();
  final question = marker.substring(3).trim();
  final options = <String>[];
  var endIndex = markerIndex + 1;
  while (endIndex < lines.length) {
    final line = lines[endIndex].trim();
    if (!line.startsWith('□')) break;
    final option = line.substring(1).trim();
    if (option.isNotEmpty) options.add(option);
    endIndex++;
  }
  if (question.isEmpty || options.length < 2) return null;

  final plainLines = <String>[
    ...lines.take(markerIndex),
    ...lines.skip(endIndex),
  ];
  return ForumPollData(
    question: question,
    options: List.unmodifiable(options),
    plainBody: plainLines.join('\n').trim(),
  );
}

/// 无正文投票自动沿用“投票：问题”作为帖子标题，卡片内不再重复展示。
String forumDisplayTitle(String title, ForumPollData? poll) {
  if (poll != null && title.trim() == '投票：${poll.question}') return '';
  return title;
}

class ForumPollCard extends StatefulWidget {
  const ForumPollCard({super.key, required this.data, this.onRemove});

  final ForumPollData data;
  final VoidCallback? onRemove;

  @override
  State<ForumPollCard> createState() => _ForumPollCardState();
}

class _ForumPollCardState extends State<ForumPollCard> {
  int? _selectedIndex;
  late List<int> _votes;

  @override
  void initState() {
    super.initState();
    _votes = List<int>.filled(widget.data.options.length, 0);
  }

  @override
  void didUpdateWidget(covariant ForumPollCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.data.question != widget.data.question ||
        oldWidget.data.options.length != widget.data.options.length ||
        !_sameOptions(oldWidget.data.options, widget.data.options)) {
      _selectedIndex = null;
      _votes = List<int>.filled(widget.data.options.length, 0);
    }
  }

  bool _sameOptions(List<String> first, List<String> second) {
    for (var index = 0; index < first.length; index++) {
      if (first[index] != second[index]) return false;
    }
    return true;
  }

  void _selectOption(int index) {
    if (_selectedIndex != null) return;
    setState(() {
      _selectedIndex = index;
      _votes[index] = 1;
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final accent = pageAccent(context);
    final totalVotes = _votes.fold<int>(0, (total, vote) => total + vote);
    final hasResult = _selectedIndex != null;
    return Container(
      decoration: BoxDecoration(
        color: Color.alphaBlend(accent.withValues(alpha: .018), colors.surface),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: colors.outlineVariant.withValues(alpha: .32),
          width: .6,
        ),
        boxShadow: [
          BoxShadow(
            color: colors.shadow.withValues(alpha: .035),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(13, 13, 13, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      widget.data.question,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 16,
                        height: 1.35,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -.1,
                      ),
                    ),
                  ),
                  if (widget.onRemove != null) ...[
                    const SizedBox(width: 4),
                    IconButton(
                      tooltip: '移除投票',
                      onPressed: widget.onRemove,
                      visualDensity: VisualDensity.compact,
                      constraints: const BoxConstraints.tightFor(
                        width: 32,
                        height: 32,
                      ),
                      padding: EdgeInsets.zero,
                      icon: const Icon(Icons.close_rounded, size: 18),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 7),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: .08),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '单选',
                      style: TextStyle(
                        color: accent,
                        fontSize: 10,
                        height: 1.25,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '$totalVotes人参与',
                    key: const ValueKey('forum-poll-participants'),
                    style: TextStyle(
                      color: colors.onSurfaceVariant,
                      fontSize: 12,
                      height: 1.2,
                      fontWeight: FontWeight.w400,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              for (var index = 0; index < widget.data.options.length; index++)
                Padding(
                  padding: EdgeInsets.only(top: index == 0 ? 0 : 8),
                  child: _ForumPollOptionTile(
                    label: widget.data.options[index],
                    votes: _votes[index],
                    totalVotes: totalVotes,
                    selected: _selectedIndex == index,
                    revealed: hasResult,
                    onTap: () => _selectOption(index),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ForumPollOptionTile extends StatelessWidget {
  const _ForumPollOptionTile({
    required this.label,
    required this.votes,
    required this.totalVotes,
    required this.selected,
    required this.revealed,
    required this.onTap,
  });

  final String label;
  final int votes;
  final int totalVotes;
  final bool selected;
  final bool revealed;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final accent = pageAccent(context);
    final percentage = totalVotes == 0 ? 0.0 : votes / totalVotes;
    final percentageLabel = '${(percentage * 100).toStringAsFixed(1)}%';
    final foreground = selected
        ? accent
        : colors.onSurface.withValues(alpha: .82);
    final countForeground = selected
        ? accent
        : colors.onSurfaceVariant.withValues(alpha: .86);
    return Semantics(
      button: !revealed,
      selected: selected,
      label: '$label，$votes人参与，占比$percentageLabel',
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        decoration: BoxDecoration(
          color: colors.onSurface.withValues(alpha: selected ? .025 : .035),
          borderRadius: BorderRadius.circular(13),
          border: Border.all(
            color: selected
                ? accent.withValues(alpha: .2)
                : colors.outlineVariant.withValues(alpha: .2),
            width: .8,
          ),
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: revealed ? null : onTap,
            borderRadius: BorderRadius.circular(13),
            splashColor: accent.withValues(alpha: .07),
            highlightColor: accent.withValues(alpha: .035),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Stack(
                children: [
                  // 结果占比直接用选项底色表达，阅读时不需要在脑中换算长度。
                  Positioned.fill(
                    child: TweenAnimationBuilder<double>(
                      duration: const Duration(milliseconds: 420),
                      curve: Curves.easeOutCubic,
                      tween: Tween<double>(begin: 0, end: percentage),
                      builder: (context, value, child) => Align(
                        alignment: Alignment.centerLeft,
                        child: FractionallySizedBox(
                          widthFactor: value,
                          heightFactor: 1,
                          child: ColoredBox(
                            color: selected
                                ? accent.withValues(alpha: .2)
                                : colors.onSurface.withValues(alpha: .065),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 11, 12, 10),
                    child: Builder(
                      builder: (context) {
                        final largeText =
                            MediaQuery.textScalerOf(context).scale(12) > 18;
                        final labelText = Text(
                          label,
                          maxLines: largeText ? 3 : 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: foreground,
                            fontSize: 14,
                            height: 1.35,
                            fontWeight: selected
                                ? FontWeight.w600
                                : FontWeight.w500,
                          ),
                        );
                        final resultText = Text(
                          '$votes人 | $percentageLabel',
                          key: ValueKey('forum-poll-result-$label'),
                          style: TextStyle(
                            color: countForeground,
                            fontSize: 12.5,
                            height: 1.2,
                            fontWeight: selected
                                ? FontWeight.w700
                                : FontWeight.w500,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        );
                        if (largeText) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              labelText,
                              const SizedBox(height: 7),
                              Align(
                                alignment: Alignment.centerRight,
                                child: resultText,
                              ),
                            ],
                          );
                        }
                        return Row(
                          children: [
                            Expanded(child: labelText),
                            const SizedBox(width: 10),
                            resultText,
                          ],
                        );
                      },
                    ),
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

/// 连续信息流中的一条帖子，校园页论坛栏目和“我的帖子”共用。
///
/// 不使用独立卡片：头像、正文与互动构成主轴，帖与帖之间只保留细分隔线。
class ForumThreadCard extends StatelessWidget {
  const ForumThreadCard({
    super.key,
    required this.thread,
    required this.onTap,
    this.repository,
    this.showCategory = false,
  });

  final ForumThread thread;
  final VoidCallback onTap;
  final CampusRepository? repository;
  final bool showCategory;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final poll = parseForumPoll(thread.body);
    final plainBody = poll?.plainBody ?? thread.body;
    final displayTitle = forumDisplayTitle(thread.title, poll);
    return Material(
      key: ValueKey('forum-thread-card-${thread.id}'),
      color: colors.surface,
      child: InkWell(
        onTap: onTap,
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: colors.outlineVariant.withValues(alpha: .65),
                width: .6,
              ),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(context),
                const SizedBox(height: 7),
                Padding(
                  padding: const EdgeInsets.only(left: 52),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (displayTitle.isNotEmpty)
                        Text(
                          displayTitle,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            height: 1.35,
                          ),
                        ),
                      if (displayTitle.isNotEmpty && plainBody.isNotEmpty)
                        const SizedBox(height: 3),
                      if (plainBody.isNotEmpty)
                        Text(
                          plainBody,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 14,
                            height: 1.45,
                            color: colors.onSurface.withValues(alpha: .82),
                          ),
                        ),
                      if (poll != null) ...[
                        if (displayTitle.isNotEmpty || plainBody.isNotEmpty)
                          const SizedBox(height: 9),
                        ForumPollCard(data: poll),
                      ],
                      if (thread.imageAssetIds.isNotEmpty) ...[
                        const SizedBox(height: 9),
                        _buildImages(),
                      ],
                      const SizedBox(height: 7),
                      _buildFooter(context),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CampusAuthorAvatar(
          author: thread.author,
          radius: 18,
          repository: repository,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 1),
              CampusAuthorName(
                author: thread.author,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 13,
                  height: 1.3,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 3),
              Wrap(
                spacing: 6,
                runSpacing: 2,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    campusFormatTime(thread.lastActivityAt),
                    style: TextStyle(
                      fontSize: 10,
                      height: 1.3,
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                  if (thread.isPinned)
                    _ForumBadge(label: '置顶', color: pageAccent(context)),
                  if (thread.isLocked)
                    _ForumBadge(label: '已锁定', color: colors.onSurfaceVariant),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildImages() {
    final ids = thread.imageAssetIds.take(3).toList();
    if (ids.length == 1) {
      return CampusAssetImage(
        assetId: ids.single,
        repository: repository,
        width: 142,
        height: 120,
        radius: 7,
        adaptive: true,
        fallback: Icons.image_outlined,
      );
    }
    return SizedBox(
      width: double.infinity,
      height: 82,
      child: Row(
        children: [
          for (var index = 0; index < ids.length; index++) ...[
            if (index > 0) const SizedBox(width: 4),
            Expanded(
              child: CampusAssetImage(
                assetId: ids[index],
                repository: repository,
                height: 82,
                radius: 7,
                fallback: Icons.image_outlined,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFooter(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final style = TextStyle(
      fontSize: 11,
      height: 1.3,
      color: colors.onSurfaceVariant,
    );
    final category = showCategory && thread.categoryName.isNotEmpty
        ? Text('# ${thread.categoryName}', style: style)
        : const SizedBox.shrink();
    final metrics = Wrap(
      spacing: 15,
      runSpacing: 5,
      children: [
        _ForumMetric(
          icon: Icons.chat_bubble_outline_rounded,
          value: thread.replyCount,
          label: '条回复',
        ),
        _ForumMetric(
          icon: Icons.thumb_up_alt_outlined,
          value: thread.likeCount,
          label: '个赞',
        ),
        if (thread.imageAssetIds.length > 3)
          Text('+${thread.imageAssetIds.length - 3} 张图', style: style),
      ],
    );
    return SizedBox(
      width: double.infinity,
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        runAlignment: WrapAlignment.center,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 12,
        runSpacing: 5,
        children: [category, metrics],
      ),
    );
  }
}

class _ForumMetric extends StatelessWidget {
  const _ForumMetric({
    required this.icon,
    required this.value,
    required this.label,
  });

  final IconData icon;
  final int value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.onSurfaceVariant;
    return Semantics(
      label: '$value $label',
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: color),
          const SizedBox(width: 4),
          Text(
            '$value',
            style: TextStyle(fontSize: 11, height: 1.3, color: color),
          ),
        ],
      ),
    );
  }
}

class _ForumBadge extends StatelessWidget {
  const _ForumBadge({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
    decoration: BoxDecoration(
      color: color.withValues(alpha: .1),
      borderRadius: BorderRadius.circular(4),
    ),
    child: Text(
      label,
      style: TextStyle(fontSize: 9, height: 1.4, color: color),
    ),
  );
}
