import 'dart:typed_data';

import 'package:chengxin_youyou/features/campus/data/campus_repository.dart';
import 'package:chengxin_youyou/features/campus/models/campus_models.dart';
import 'package:flutter/material.dart';

import '../../../ui/components/page_layout.dart';

/// 板块与评分对象使用原版的小封面、标题、作者和下方介绍。
class CampusHero extends StatelessWidget {
  const CampusHero({
    super.key,
    required this.name,
    required this.description,
    required this.assetId,
    required this.author,
    required this.authorSuffix,
    required this.repository,
    required this.fallback,
    this.stats,
  });
  final String name;
  final String description;
  final String? assetId;
  final CampusAuthor author;
  final String authorSuffix;
  final CampusRepository? repository;
  final IconData fallback;
  final String? stats;

  @override
  Widget build(BuildContext context) => PageCard(
    radius: 16,
    padding: const EdgeInsets.all(14),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CampusAssetImage(
              assetId: assetId,
              repository: repository,
              fallback: fallback,
              height: 80,
              width: 80,
              radius: 10,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      CampusAuthorAvatar(author: author, radius: 10),
                      const SizedBox(width: 7),
                      Expanded(
                        child: Text(
                          '${author.displayName} $authorSuffix',
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                  if (stats != null) ...[
                    const SizedBox(height: 6),
                    Text(stats!, style: const TextStyle(fontSize: 12)),
                  ],
                ],
              ),
            ),
          ],
        ),
        if (description.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(
            description,
            style: TextStyle(
              fontSize: 13,
              height: 1.5,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ],
    ),
  );
}

class CampusAssetImage extends StatefulWidget {
  const CampusAssetImage({
    super.key,
    required this.assetId,
    required this.repository,
    required this.fallback,
    this.height,
    this.width,
    this.radius = 16,
    this.fit = BoxFit.cover,
  });

  final String? assetId;
  final CampusRepository? repository;
  final IconData fallback;
  final double? height;
  final double? width;
  final double radius;
  final BoxFit fit;

  @override
  State<CampusAssetImage> createState() => _CampusAssetImageState();
}

class _CampusAssetImageState extends State<CampusAssetImage> {
  Future<Uint8List?>? _image;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant CampusAssetImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.assetId != widget.assetId ||
        oldWidget.repository != widget.repository) {
      _load();
    }
  }

  void _load() {
    // 输入或筛选触发重建时沿用已有 Future，避免封面重复请求和闪回占位图。
    _image = widget.assetId == null || widget.repository == null
        ? null
        : widget.repository!.loadAsset(widget.assetId!);
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(widget.radius),
      child: SizedBox(
        height: widget.height,
        width: widget.width,
        child: _image == null
            ? _placeholder(context)
            : FutureBuilder<Uint8List?>(
                key: ValueKey(widget.assetId),
                future: _image,
                builder: (context, snapshot) => snapshot.data == null
                    ? _placeholder(context)
                    : Image.memory(snapshot.data!, fit: widget.fit),
              ),
      ),
    );
  }

  Widget _placeholder(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return ColoredBox(
      color: colors.primary.withValues(alpha: .08),
      child: Center(
        child: Icon(widget.fallback, color: colors.primary, size: 34),
      ),
    );
  }
}

class CampusAuthorAvatar extends StatelessWidget {
  const CampusAuthorAvatar({super.key, required this.author, this.radius = 16});
  final CampusAuthor author;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final initial = author.displayName.isEmpty
        ? '?'
        : author.displayName.characters.first;
    return CircleAvatar(
      radius: radius,
      backgroundColor: colors.primary.withValues(alpha: .12),
      foregroundColor: colors.primary,
      backgroundImage: author.avatarPreset >= 1 && author.avatarPreset <= 15
          ? AssetImage(
              'assets/avatars/avatar-${author.avatarPreset.toString().padLeft(2, '0')}.jpg',
            )
          : null,
      child: author.avatarPreset >= 1 && author.avatarPreset <= 15
          ? null
          : Text(initial, style: TextStyle(fontSize: radius * .9)),
    );
  }
}

class CampusPageState extends StatelessWidget {
  const CampusPageState({
    super.key,
    required this.title,
    this.description,
    this.actionLabel,
    this.onAction,
    this.loading = false,
  });

  final String title;
  final String? description;
  final String? actionLabel;
  final VoidCallback? onAction;
  final bool loading;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (loading)
            const CircularProgressIndicator()
          else
            Icon(
              Icons.info_outline_rounded,
              size: 36,
              color: Theme.of(context).colorScheme.primary,
            ),
          const SizedBox(height: 14),
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          if (description != null) ...[
            const SizedBox(height: 6),
            Text(description!, textAlign: TextAlign.center),
          ],
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 14),
            FilledButton(onPressed: onAction, child: Text(actionLabel!)),
          ],
        ],
      ),
    ),
  );
}

class CampusRatingSummaryCard extends StatelessWidget {
  const CampusRatingSummaryCard({super.key, required this.summary});
  final CampusRatingSummary summary;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final score = summary.score;
    return PageCard(
      radius: 12,
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          SizedBox(
            width: 96,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  score == null ? '—' : score.toStringAsFixed(1),
                  style: TextStyle(
                    fontSize: 38,
                    height: 1.1,
                    color: colors.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  summary.count == 0 ? '等待第一份评分' : '${summary.count} 人评分',
                  style: const TextStyle(fontSize: 11),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              children: [
                for (var stars = 5; stars >= 1; stars--)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 25,
                          child: Text(
                            '$stars★',
                            style: const TextStyle(fontSize: 10),
                          ),
                        ),
                        Expanded(
                          child: LinearProgressIndicator(
                            value: summary.count == 0
                                ? 0
                                : (summary.distribution[stars] ?? 0) /
                                      summary.count,
                            minHeight: 5,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '${summary.distribution[stars] ?? 0}',
                          style: const TextStyle(fontSize: 10),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

String campusFormatPrice(int cents) {
  final value = (cents / 100).toStringAsFixed(2);
  return value
      .replaceFirst(RegExp(r'\.00$'), '')
      .replaceFirstMapped(RegExp(r'(\.\d)0$'), (match) => match.group(1)!);
}

String campusLabel(String campus) => switch (campus) {
  'longquan' => '龙泉校区',
  _ => '航空港校区',
};

String contactLabel(String type) => switch (type) {
  'qq' => 'QQ',
  'phone' => '手机号',
  _ => '微信',
};

String listingStatusLabel(CampusListing item) {
  if (item.listingType == 'wanted') {
    return switch (item.status) {
      'sold' => '已求到',
      'withdrawn' => '已关闭',
      _ => '求购中',
    };
  }
  return switch (item.status) {
    'sold' => '已售出',
    'withdrawn' => '已下架',
    _ => '在售',
  };
}

String campusFormatTime(String value) {
  final date = DateTime.tryParse(value)?.toLocal();
  if (date == null) return '';
  final now = DateTime.now();
  final difference = now.difference(date);
  if (difference.inSeconds < 60) return '刚刚';
  if (difference.inMinutes < 60) return '${difference.inMinutes} 分钟前';
  if (difference.inHours < 24) return '${difference.inHours} 小时前';
  return '${date.year == now.year ? '' : '${date.year}年'}${date.month}月${date.day}日';
}
