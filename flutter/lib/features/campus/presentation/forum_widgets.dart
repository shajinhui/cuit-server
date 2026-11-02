import 'package:chengxin_youyou/features/campus/data/campus_repository.dart';
import 'package:chengxin_youyou/features/campus/models/campus_models.dart';
import 'package:flutter/material.dart';

import '../../../ui/components/page_layout.dart';
import 'campus_widgets.dart';

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
                      if (thread.title.isNotEmpty)
                        Text(
                          thread.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            height: 1.35,
                          ),
                        ),
                      if (thread.title.isNotEmpty && thread.body.isNotEmpty)
                        const SizedBox(height: 3),
                      if (thread.body.isNotEmpty)
                        Text(
                          thread.body,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 14,
                            height: 1.45,
                            color: colors.onSurface.withValues(alpha: .82),
                          ),
                        ),
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
