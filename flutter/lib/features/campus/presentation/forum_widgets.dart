import 'dart:async';

import 'package:chengxin_youyou/features/campus/data/campus_repository.dart';
import 'package:chengxin_youyou/features/campus/models/campus_models.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../../../ui/components/page_layout.dart';
import 'campus_theme.dart';
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
/// 纯投票帖的标题由问题派生，卡片和详情里不再重复展示同一句话。
String forumThreadDisplayTitle(ForumThread thread, ForumPollData? legacyPoll) {
  final poll = thread.poll;
  if (poll != null && legacyPoll == null && thread.body.isEmpty) {
    final derived = poll.question.characters.take(50).toString();
    if (thread.title == derived || thread.title == poll.question) return '';
  }
  return forumDisplayTitle(thread.title, legacyPoll);
}

String forumDisplayTitle(String title, ForumPollData? poll) {
  if (poll != null && title.trim() == '投票：${poll.question}') return '';
  return title;
}

class ForumPollCard extends StatefulWidget {
  const ForumPollCard({
    super.key,
    this.data,
    this.poll,
    this.repository,
    this.threadId,
    this.onRemove,
  }) : assert(data != null || poll != null, '投票卡片需要预览数据或服务端投票');

  /// 旧版正文投票或编辑预览：只在本地展示，不写入服务端。
  final ForumPollData? data;

  /// 结构化投票：人数、占比和当前用户选择都来自服务端。
  final ForumPoll? poll;
  final CampusRepository? repository;
  final String? threadId;
  final VoidCallback? onRemove;

  @override
  State<ForumPollCard> createState() => _ForumPollCardState();
}

class _ForumPollCardState extends State<ForumPollCard> {
  int? _selectedIndex;
  late List<int> _votes;
  ForumPoll? _poll;
  bool _voting = false;

  @override
  void initState() {
    super.initState();
    _poll = widget.poll;
    _votes = List<int>.filled(widget.data?.options.length ?? 0, 0);
  }

  @override
  void didUpdateWidget(covariant ForumPollCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_voting && !_samePoll(oldWidget.poll, widget.poll)) {
      _poll = widget.poll;
    }
    final oldOptions = oldWidget.data?.options ?? const <String>[];
    final newOptions = widget.data?.options ?? const <String>[];
    if (oldWidget.data?.question != widget.data?.question ||
        !_sameOptions(oldOptions, newOptions)) {
      _selectedIndex = null;
      _votes = List<int>.filled(newOptions.length, 0);
    }
  }

  static bool _sameOptions(List<String> first, List<String> second) {
    if (first.length != second.length) return false;
    for (var index = 0; index < first.length; index++) {
      if (first[index] != second[index]) return false;
    }
    return true;
  }

  static bool _samePoll(ForumPoll? left, ForumPoll? right) {
    if (left == null || right == null) return identical(left, right);
    if (left.question != right.question ||
        left.totalVotes != right.totalVotes ||
        left.myOptionId != right.myOptionId ||
        left.options.length != right.options.length) {
      return false;
    }
    for (var index = 0; index < left.options.length; index++) {
      final leftOption = left.options[index];
      final rightOption = right.options[index];
      if (leftOption.id != rightOption.id ||
          leftOption.count != rightOption.count) {
        return false;
      }
    }
    return true;
  }

  void _selectOption(int index) {
    if (_voting) return;
    final poll = _poll;
    if (poll == null) {
      // 旧版正文投票没有服务端记录，保留本地演示行为。
      if (_selectedIndex != null) return;
      setState(() {
        _selectedIndex = index;
        _votes[index] = 1;
      });
      return;
    }
    if (index >= poll.options.length) return;
    final option = poll.options[index];
    if (option.id == poll.myOptionId) return;
    unawaited(_vote(poll, option));
  }

  Future<void> _vote(ForumPoll poll, ForumPollOption option) async {
    final repository = widget.repository;
    final threadId = widget.threadId;
    if (repository == null || threadId == null) return;
    final previous = _poll ?? poll;
    // 先移动自己那一票，失败再回滚；服务端结果会覆盖合计与占比。
    setState(() {
      _poll = _applyVote(poll, option.id);
      _voting = true;
    });
    try {
      final updated = await repository.voteForumPoll(
        threadId: threadId,
        optionId: option.id,
      );
      if (!mounted) return;
      setState(() {
        _poll = updated;
        _voting = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _poll = previous;
        _voting = false;
      });
      ScaffoldMessenger.maybeOf(
        context,
      )?.showSnackBar(const SnackBar(content: Text('投票失败，请稍后重试')));
    }
  }

  static ForumPoll _applyVote(ForumPoll poll, String optionId) {
    final counts = {for (final option in poll.options) option.id: option.count};
    var total = poll.totalVotes;
    final previous = poll.myOptionId;
    if (previous != null) {
      counts[previous] = (counts[previous] ?? 1) - 1;
      total -= 1;
    }
    counts[optionId] = (counts[optionId] ?? 0) + 1;
    total += 1;
    final safeTotal = total < 0 ? 0 : total;
    return ForumPoll(
      question: poll.question,
      totalVotes: safeTotal,
      myOptionId: optionId,
      options: [
        for (final option in poll.options)
          ForumPollOption(
            id: option.id,
            label: option.label,
            count: (counts[option.id] ?? 0) < 0 ? 0 : counts[option.id] ?? 0,
            percent: safeTotal == 0
                ? 0
                : ((counts[option.id] ?? 0) / safeTotal * 1000).round() / 10,
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final accent = pageAccent(context);
    final poll = _poll;
    final preview = widget.data;
    final structured = widget.poll != null && poll != null;
    final labels = structured
        ? [for (final option in poll.options) option.label]
        : (preview?.options ?? const <String>[]);
    final counts = structured
        ? [for (final option in poll.options) option.count]
        : _votes;
    final percentages = <double?>[
      if (structured)
        for (final option in poll.options) option.percent
      else
        for (var index = 0; index < labels.length; index++) null,
    ];
    final totalVotes = structured
        ? poll.totalVotes
        : _votes.fold<int>(0, (total, vote) => total + vote);
    final hasResult = structured || _selectedIndex != null;
    final question = structured ? poll.question : preview?.question ?? '';
    final selectedIndex = structured && poll.myOptionId != null
        ? poll.options.indexWhere((option) => option.id == poll.myOptionId)
        : _selectedIndex;
    return Container(
      key: const ValueKey('forum-poll-card'),
      decoration: BoxDecoration(
        // 投票区用比页面更深一层的中性灰，确保在白底帖子中能形成清楚边界。
        color: colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: colors.outlineVariant.withValues(alpha: .9),
          width: .8,
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
                      question,
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
              for (var index = 0; index < labels.length; index++)
                Padding(
                  padding: EdgeInsets.only(top: index == 0 ? 0 : 8),
                  child: _ForumPollOptionTile(
                    label: labels[index],
                    votes: index < counts.length ? counts[index] : 0,
                    totalVotes: totalVotes,
                    percent: index < percentages.length
                        ? percentages[index]
                        : null,
                    selected: selectedIndex == index,
                    revealed: hasResult,
                    enabled: structured ? !_voting : _selectedIndex == null,
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
    required this.enabled,
    required this.onTap,
    this.percent,
  });

  final String label;
  final int votes;
  final int totalVotes;
  final bool selected;
  final bool revealed;
  final bool enabled;

  /// 服务端百分比；旧版正文投票和草稿没有该值，退回本地计算。
  final double? percent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final accent = pageAccent(context);
    final percentage = percent != null
        ? (percent! / 100).clamp(0.0, 1.0).toDouble()
        : (totalVotes == 0 ? 0.0 : votes / totalVotes);
    final percentageLabel = '${(percentage * 100).toStringAsFixed(1)}%';
    final foreground = selected
        ? accent
        : colors.onSurface.withValues(alpha: .82);
    final countForeground = selected
        ? accent
        : colors.onSurfaceVariant.withValues(alpha: .86);
    return Semantics(
      button: enabled,
      selected: selected,
      label: '$label，$votes人参与，占比$percentageLabel',
      child: AnimatedContainer(
        key: ValueKey('forum-poll-option-$label'),
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        decoration: BoxDecoration(
          // 选项悬浮在灰色投票底板上，使用白色表面拉开层级。
          color: colors.surface,
          borderRadius: BorderRadius.circular(13),
          border: Border.all(
            color: selected
                ? accent.withValues(alpha: .32)
                : colors.outlineVariant.withValues(alpha: .7),
            width: selected ? 1 : .8,
          ),
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: enabled ? onTap : null,
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

const _forumReactionEmojis = [
  // 常用表情
  '😀', '😃', '😄', '😁', '😆', '😅', '😂', '🤣',
  '😊', '😇', '🙂', '😉', '😍', '🥰', '😘', '😋',
  '😛', '😜', '🤪', '😎', '🤩', '🥳', '😏', '😒',
  '😞', '😔', '😟', '😕', '🙁', '😣', '😖', '😫',
  '😩', '🥺', '😢', '😭', '😤', '😠', '😡', '🤬',
  '🤯', '😳', '🥵', '🥶', '😱', '😨', '😰', '😥',
  '😓', '🤗', '🤔', '🤭', '🤫', '🤥', '😶', '😐',
  '😑', '😬', '🙄', '😯', '😦', '😧', '😮', '😲',
  '🥱', '😴', '🤤', '😪', '😵', '🤐', '🥴', '🤢',
  '🤮', '🤧', '😷', '🤒', '🤕', '🤑', '🤠', '😈',
  '👿', '👻', '💀', '👽', '🤖', '💩', '😺', '😸',
  '😹', '😻', '😼', '😽', '🙀', '😿', '😾',
  // 手势与人物
  '👍', '👎', '👌', '✌️', '🤞', '🤟', '🤘', '🤙',
  '👈', '👉', '👆', '👇', '☝️', '👋', '🤚', '🖐️',
  '✋', '🖖', '👏', '🙌', '🤝', '🙏', '💪', '👀',
  '🧠',
  // 爱心与符号
  '❤️', '🧡', '💛', '💚', '💙', '💜', '🖤', '🤍',
  '🤎', '💔', '❣️', '💕', '💞', '💓', '💗', '💖',
  '💘', '💝', '💟', '🔥', '✨', '🎉', '🎊', '🎈',
  '💯', '✅', '❌', '⭐', '🌟', '🌈', '☀️', '🌙',
  // 校园生活常用
  '🍻', '🍺', '☕', '🍜', '🍔', '🍕', '🎂', '🎁',
  '🏆', '⚽', '🏀', '🎮', '📚', '💻', '📱', '🐹',
  '🐧', '🐱', '🐶', '🐼', '🦊', '🐰',
];

Future<String?> _pickForumReaction(BuildContext context, String? selected) {
  final screenHeight = MediaQuery.sizeOf(context).height;
  return showModalBottomSheet<String>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: Theme.of(context).colorScheme.surface,
    constraints: BoxConstraints(maxHeight: screenHeight * .75),
    builder: (sheetContext) => Theme(
      data: campusTheme(sheetContext),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 2, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '选择一个表情',
                style: Theme.of(sheetContext).textTheme.titleMedium,
              ),
              const SizedBox(height: 4),
              Text(
                '选中后会显示在这条帖子下方',
                style: TextStyle(
                  fontSize: 11,
                  color: Theme.of(sheetContext).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: (screenHeight * .45).clamp(180.0, 420.0),
                child: Scrollbar(
                  child: SingleChildScrollView(
                    key: const ValueKey('forum-reaction-scroll'),
                    child: Wrap(
                      spacing: 9,
                      runSpacing: 9,
                      children: [
                        for (final emoji in _forumReactionEmojis)
                          _ForumReactionOption(
                            emoji: emoji,
                            selected: emoji == selected,
                            onTap: () => Navigator.of(sheetContext).pop(emoji),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _ForumReactionOption extends StatelessWidget {
  const _ForumReactionOption({
    required this.emoji,
    required this.selected,
    required this.onTap,
  });

  final String emoji;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final accent = pageAccent(context);
    return Semantics(
      button: true,
      selected: selected,
      label: '表情 $emoji',
      child: Material(
        color: selected ? accent.withValues(alpha: .1) : colors.surface,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          key: ValueKey('forum-reaction-option-$emoji'),
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            width: 50,
            height: 50,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: selected
                    ? accent.withValues(alpha: .5)
                    : colors.outlineVariant,
                width: selected ? 1 : .7,
              ),
            ),
            child: Text(emoji, style: const TextStyle(fontSize: 25)),
          ),
        ),
      ),
    );
  }
}

/// 帖子的表情回应和底部操作区。
///
/// 选择的表情会显示在正文下方；底部的笑脸按钮始终保留，作为表情入口。
class ForumPostFooter extends StatefulWidget {
  const ForumPostFooter({
    super.key,
    required this.thread,
    required this.onComment,
    this.repository,
    this.showCategory = true,
    this.trailing,
    this.compact = true,
  });

  final ForumThread thread;
  final VoidCallback? onComment;

  /// 表情回应写入服务端；为空时仅做本地预览（用于纯组件测试）。
  final CampusRepository? repository;
  final bool showCategory;
  final Widget? trailing;
  final bool compact;

  @override
  State<ForumPostFooter> createState() => _ForumPostFooterState();
}

class _ForumPostFooterState extends State<ForumPostFooter> {
  late List<ForumReaction> _reactions;
  String? _myReaction;
  bool _submitting = false;

  int get _reactionCount =>
      _reactions.fold(0, (total, reaction) => total + reaction.count);

  @override
  void initState() {
    super.initState();
    _adoptServerState();
  }

  @override
  void didUpdateWidget(covariant ForumPostFooter oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 只在新数据真的变化时覆盖本地状态，避免父级点赞等重建冲掉乐观结果。
    if (_submitting) return;
    if (oldWidget.thread.id != widget.thread.id ||
        !_sameReactions(oldWidget.thread, widget.thread)) {
      _adoptServerState();
    }
  }

  void _adoptServerState() {
    _reactions = List<ForumReaction>.of(widget.thread.reactions);
    _myReaction = widget.thread.myReaction;
  }

  static bool _sameReactions(ForumThread left, ForumThread right) {
    if (left.myReaction != right.myReaction ||
        left.reactions.length != right.reactions.length) {
      return false;
    }
    for (var index = 0; index < left.reactions.length; index++) {
      final leftReaction = left.reactions[index];
      final rightReaction = right.reactions[index];
      if (leftReaction.emoji != rightReaction.emoji ||
          leftReaction.count != rightReaction.count) {
        return false;
      }
    }
    return true;
  }

  Future<void> _chooseReaction([String? emoji]) async {
    if (_submitting) return;
    final picked = emoji ?? await _pickForumReaction(context, _myReaction);
    if (!mounted || picked == null) return;
    await _submitReaction(picked == _myReaction ? null : picked);
  }

  Future<void> _submitReaction(String? next) async {
    final previousReactions = _reactions;
    final previousMine = _myReaction;
    // 先按用户预期更新，网络失败再整体回滚。
    setState(() {
      _reactions = _applyReaction(_reactions, previousMine, next);
      _myReaction = next;
      _submitting = true;
    });
    final repository = widget.repository;
    if (repository == null) {
      setState(() => _submitting = false);
      return;
    }
    try {
      final state = await repository.setForumThreadReaction(
        threadId: widget.thread.id,
        emoji: next,
      );
      if (!mounted) return;
      setState(() {
        _reactions = state.reactions;
        _myReaction = state.myReaction;
        _submitting = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _reactions = previousReactions;
        _myReaction = previousMine;
        _submitting = false;
      });
      ScaffoldMessenger.maybeOf(
        context,
      )?.showSnackBar(const SnackBar(content: Text('表情回应失败，请稍后重试')));
    }
  }

  static List<ForumReaction> _applyReaction(
    List<ForumReaction> reactions,
    String? previous,
    String? next,
  ) {
    final counts = {
      for (final reaction in reactions) reaction.emoji: reaction.count,
    };
    if (previous != null) {
      final remaining = (counts[previous] ?? 1) - 1;
      if (remaining <= 0) {
        counts.remove(previous);
      } else {
        counts[previous] = remaining;
      }
    }
    if (next != null) {
      counts[next] = (counts[next] ?? 0) + 1;
    }
    final updated =
        [
          for (final entry in counts.entries)
            if (entry.value > 0)
              ForumReaction(emoji: entry.key, count: entry.value),
        ]..sort((left, right) {
          final byCount = right.count.compareTo(left.count);
          return byCount != 0 ? byCount : left.emoji.compareTo(right.emoji);
        });
    return updated;
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final style = TextStyle(
      fontSize: 11,
      height: 1.3,
      color: colors.onSurfaceVariant,
    );
    final horizontalPadding = widget.compact ? 6.0 : 8.0;
    final actionStyle = TextButton.styleFrom(
      minimumSize: Size(44, widget.compact ? 30 : 40),
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      padding: EdgeInsets.symmetric(
        horizontal: horizontalPadding,
        vertical: widget.compact ? 3 : 6,
      ),
      foregroundColor: colors.onSurfaceVariant,
    );
    final actionLabelStyle = TextStyle(
      fontSize: widget.compact ? 11 : 12,
      height: 1.2,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_reactions.isNotEmpty) ...[
          Align(
            alignment: Alignment.centerLeft,
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final reaction in _reactions)
                  _ForumReactionChip(
                    key: ValueKey(
                      'forum-reaction-chip-${widget.thread.id}-${reaction.emoji}',
                    ),
                    emoji: reaction.emoji,
                    count: reaction.count,
                    selected: reaction.emoji == _myReaction,
                    onTap: () => _chooseReaction(reaction.emoji),
                  ),
              ],
            ),
          ),
          SizedBox(height: widget.compact ? 4 : 7),
        ],
        Wrap(
          alignment:
              widget.showCategory && widget.thread.categoryName.isNotEmpty
              ? WrapAlignment.spaceBetween
              : WrapAlignment.end,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 8,
          runSpacing: 2,
          children: [
            if (widget.showCategory && widget.thread.categoryName.isNotEmpty)
              Text(
                '# ${widget.thread.categoryName}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: style,
              ),
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 2,
              children: [
                TextButton.icon(
                  key: ValueKey('forum-reaction-${widget.thread.id}'),
                  onPressed: _submitting ? null : () => _chooseReaction(),
                  style: actionStyle,
                  icon: const Icon(Icons.add_reaction_outlined, size: 19),
                  label: Text('$_reactionCount', style: actionLabelStyle),
                ),
                TextButton.icon(
                  key: ValueKey('forum-comment-${widget.thread.id}'),
                  onPressed: widget.onComment,
                  style: actionStyle,
                  icon: const Icon(Icons.chat_bubble_outline_rounded, size: 18),
                  label: Text(
                    '${widget.thread.replyCount}',
                    style: actionLabelStyle,
                  ),
                ),
                ForumShareButton(thread: widget.thread),
                if (widget.trailing != null) widget.trailing!,
              ],
            ),
          ],
        ),
      ],
    );
  }
}

class _ForumReactionChip extends StatelessWidget {
  const _ForumReactionChip({
    super.key,
    required this.emoji,
    required this.count,
    required this.selected,
    required this.onTap,
  });

  final String emoji;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final accent = pageAccent(context);
    return Semantics(
      button: true,
      selected: selected,
      label: '表情 $emoji，$count 人',
      child: Material(
        color: selected ? accent.withValues(alpha: .08) : campusControlSurface,
        borderRadius: BorderRadius.circular(999),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(999),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: selected
                    ? accent.withValues(alpha: .45)
                    : campusLine.withValues(alpha: .42),
                width: .6,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(emoji, style: const TextStyle(fontSize: 16)),
                const SizedBox(width: 4),
                Text(
                  '$count',
                  style: TextStyle(
                    fontSize: 11,
                    height: 1.2,
                    fontWeight: FontWeight.w600,
                    color: colors.onSurface,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class ForumShareButton extends StatelessWidget {
  const ForumShareButton({super.key, required this.thread});

  final ForumThread thread;

  Future<void> _share(BuildContext context) async {
    try {
      await SharePlus.instance.share(
        ShareParams(
          title: thread.title,
          text: '${thread.title}\n\n${thread.body}',
        ),
      );
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.maybeOf(
        context,
      )?.showSnackBar(const SnackBar(content: Text('转发失败，请稍后重试')));
    }
  }

  @override
  Widget build(BuildContext context) => IconButton(
    key: ValueKey('forum-share-${thread.id}'),
    tooltip: '转发',
    onPressed: () => _share(context),
    constraints: const BoxConstraints.tightFor(width: 40, height: 30),
    padding: EdgeInsets.zero,
    icon: const Icon(Icons.reply_rounded, size: 19),
    color: Theme.of(context).colorScheme.onSurfaceVariant,
  );
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
    // 结构化投票不再写进正文；只有旧帖子才回退到正文解析。
    final legacyPoll = thread.poll == null ? parseForumPoll(thread.body) : null;
    final plainBody = legacyPoll?.plainBody ?? thread.body;
    final displayTitle = forumThreadDisplayTitle(thread, legacyPoll);
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
                      if (thread.poll != null) ...[
                        if (displayTitle.isNotEmpty || plainBody.isNotEmpty)
                          const SizedBox(height: 9),
                        ForumPollCard(
                          poll: thread.poll,
                          repository: repository,
                          threadId: thread.id,
                        ),
                      ] else if (legacyPoll != null) ...[
                        if (displayTitle.isNotEmpty || plainBody.isNotEmpty)
                          const SizedBox(height: 9),
                        ForumPollCard(data: legacyPoll),
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

  Widget _buildFooter(BuildContext context) => ForumPostFooter(
    thread: thread,
    repository: repository,
    showCategory: showCategory,
    onComment: onTap,
    compact: true,
  );
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
