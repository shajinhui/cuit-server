import 'package:chengxin_youyou/features/campus/data/campus_repository.dart';
import 'package:chengxin_youyou/features/campus/models/campus_models.dart';
import 'package:flutter/material.dart';

import '../../../ui/components/page_layout.dart';
import 'campus_widgets.dart';

/// 帖子列表卡片，校园页论坛栏目和“我的帖子”共用。
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
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            if (thread.isPinned) ...[
                              const _ForumBadge(label: '置顶', highlighted: true),
                              const SizedBox(width: 6),
                            ],
                            if (thread.isLocked) ...[
                              const _ForumBadge(label: '已锁定'),
                              const SizedBox(width: 6),
                            ],
                            if (showCategory &&
                                thread.categoryName.isNotEmpty) ...[
                              _ForumBadge(label: thread.categoryName),
                              const SizedBox(width: 6),
                            ],
                            Expanded(
                              child: Text(
                                thread.title,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  height: 1.4,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          thread.body,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            height: 1.5,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // 有附图时在右侧显示首图缩略图，无图帖子不占位。
                  if (thread.imageAssetIds.isNotEmpty) ...[
                    const SizedBox(width: 10),
                    CampusAssetImage(
                      assetId: thread.imageAssetIds.first,
                      repository: repository,
                      height: 64,
                      width: 64,
                      radius: 10,
                      fallback: Icons.image_outlined,
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  CampusAuthorAvatar(author: thread.author, radius: 11),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      thread.author.displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelSmall,
                    ),
                  ),
                  Text(
                    campusFormatTime(thread.lastActivityAt),
                    style: theme.textTheme.labelSmall,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(
                    Icons.chat_bubble_outline_rounded,
                    size: 15,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 3),
                  Text(
                    '${thread.replyCount}',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Icon(
                    Icons.thumb_up_alt_outlined,
                    size: 15,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 3),
                  Text(
                    '${thread.likeCount}',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  if (thread.imageAssetIds.length > 1) ...[
                    const SizedBox(width: 14),
                    Icon(
                      Icons.photo_library_outlined,
                      size: 15,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 3),
                    Text(
                      '${thread.imageAssetIds.length}',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ForumBadge extends StatelessWidget {
  const _ForumBadge({required this.label, this.highlighted = false});

  final String label;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: highlighted
            ? pageAccent(context).withValues(alpha: .14)
            : colors.onSurfaceVariant.withValues(alpha: .1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          color: highlighted ? pageAccent(context) : colors.onSurfaceVariant,
        ),
      ),
    );
  }
}
