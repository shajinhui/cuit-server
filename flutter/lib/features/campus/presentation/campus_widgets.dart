import 'dart:typed_data';

import 'package:chengxin_youyou/features/campus/data/campus_repository.dart';
import 'package:chengxin_youyou/features/campus/models/campus_models.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../ui/components/page_layout.dart';
import 'campus_image_preview.dart';
import 'campus_theme.dart';
import '../../community/presentation/community_scope.dart';

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
  Widget build(BuildContext context) => Container(
    decoration: campusCardDecoration(context, radius: 16),
    child: PageCard(
      radius: 16,
      padding: const EdgeInsets.all(11),
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
                height: 60,
                width: 60,
                radius: 11,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        height: 1.25,
                        letterSpacing: -.25,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        CampusAuthorAvatar(
                          author: author,
                          radius: 7,
                          repository: repository,
                          linkToProfile: false,
                        ),
                        const SizedBox(width: 5),
                        Expanded(
                          child: CampusAuthorName(
                            author: author,
                            suffix: ' $authorSuffix',
                            style: const TextStyle(fontSize: 10.5),
                          ),
                        ),
                      ],
                    ),
                    if (stats != null) ...[
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: context.campusColors.controlSurface,
                          borderRadius: BorderRadius.circular(99),
                        ),
                        child: Text(
                          stats!,
                          style: TextStyle(
                            fontSize: 9.5,
                            height: 1.2,
                            color: context.campusColors.muted,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          if (description.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              description,
              style: TextStyle(
                fontSize: 12,
                height: 1.4,
                color: context.campusColors.muted,
              ),
            ),
          ],
        ],
      ),
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
    this.adaptive = false,
  });

  final String? assetId;
  final CampusRepository? repository;
  final IconData fallback;
  final double? height;
  final double? width;
  final double radius;
  final BoxFit fit;

  /// 按图片实际宽高比布局；此时 [width] 和 [height] 是最大边界。
  final bool adaptive;

  @override
  State<CampusAssetImage> createState() => _CampusAssetImageState();
}

class _CampusAssetImageState extends State<CampusAssetImage> {
  Future<Uint8List?>? _image;
  Uint8List? _sizeBytes;
  ImageStream? _sizeStream;
  ImageStreamListener? _sizeListener;
  double? _aspectRatio;

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
    } else if (oldWidget.adaptive != widget.adaptive) {
      _resetIntrinsicSize();
    }
  }

  @override
  void dispose() {
    _removeIntrinsicSizeListener();
    super.dispose();
  }

  void _load({bool refresh = false}) {
    _resetIntrinsicSize();
    // 输入或筛选触发重建时沿用已有 Future，避免封面重复请求和闪回占位图。
    _image =
        widget.assetId == null ||
            widget.assetId!.isEmpty ||
            widget.repository == null
        ? null
        : widget.repository!.loadAsset(
            widget.assetId!,
            refresh: refresh,
            thumbnail: true,
          );
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(widget.radius),
      child: widget.adaptive
          ? LayoutBuilder(
              builder: (context, constraints) {
                final maxWidth = widget.width == null
                    ? constraints.maxWidth
                    : widget.width!.clamp(0, constraints.maxWidth).toDouble();
                final maxHeight = widget.height ?? 240;
                final ratio = _aspectRatio ?? 4 / 3;
                final width = maxWidth.clamp(0, maxHeight * ratio).toDouble();
                return Align(
                  alignment: Alignment.centerLeft,
                  widthFactor: 1,
                  heightFactor: 1,
                  child: SizedBox(
                    width: width,
                    height: width / ratio,
                    child: _buildImage(context),
                  ),
                );
              },
            )
          : SizedBox(
              height: widget.height,
              width: widget.width,
              child: _buildImage(context),
            ),
    );
  }

  Widget _buildImage(BuildContext context) {
    return _image == null
        ? _placeholder(context)
        : FutureBuilder<Uint8List?>(
            key: ValueKey(_image),
            future: _image,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return ColoredBox(
                  color: Theme.of(
                    context,
                  ).colorScheme.primary.withValues(alpha: .08),
                  child: const Center(
                    child: SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                );
              }
              final bytes = snapshot.data;
              if (snapshot.hasError || bytes == null || bytes.isEmpty) {
                return _retry(context);
              }
              return LayoutBuilder(
                builder: (context, constraints) {
                  // 列表只解码缩略图所需的像素，大图预览仍使用完整图片。
                  final width = widget.adaptive
                      ? constraints.maxWidth
                      : widget.width ?? constraints.maxWidth;
                  final cacheWidth = width.isFinite && width > 0
                      ? (width * MediaQuery.devicePixelRatioOf(context))
                            .ceil()
                            .clamp(1, 2048)
                      : null;
                  final provider = ResizeImage.resizeIfNeeded(
                    cacheWidth,
                    null,
                    MemoryImage(bytes),
                  );
                  if (widget.adaptive) _resolveIntrinsicSize(bytes, provider);
                  return Semantics(
                    button: true,
                    label: '查看大图',
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () {
                        final repository = widget.repository!;
                        final assetId = widget.assetId!;
                        showCampusImagePreview(
                          context,
                          bytes,
                          loadOriginal: (refresh) =>
                              repository.loadAsset(assetId, refresh: refresh),
                          downloadName: assetId,
                        );
                      },
                      child: Image(
                        image: provider,
                        fit: widget.adaptive ? BoxFit.contain : widget.fit,
                        errorBuilder: (_, _, _) => _retry(context),
                      ),
                    ),
                  );
                },
              );
            },
          );
  }

  void _resolveIntrinsicSize(Uint8List bytes, ImageProvider<Object> provider) {
    if (identical(_sizeBytes, bytes)) return;
    _removeIntrinsicSizeListener();
    _sizeBytes = bytes;
    final stream = provider.resolve(ImageConfiguration.empty);
    final listener = ImageStreamListener((info, _) {
      final ratio = info.image.width / info.image.height;
      info.image.dispose();
      if (!ratio.isFinite) return;
      // 图片命中缓存时监听可能在 build 中同步回调，统一延后更新布局。
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !identical(_sizeBytes, bytes)) return;
        if (_aspectRatio != ratio) setState(() => _aspectRatio = ratio);
      });
    }, onError: (_, _) {});
    _sizeStream = stream;
    _sizeListener = listener;
    stream.addListener(listener);
  }

  void _resetIntrinsicSize() {
    _removeIntrinsicSizeListener();
    _sizeBytes = null;
    _aspectRatio = null;
  }

  void _removeIntrinsicSizeListener() {
    final stream = _sizeStream;
    final listener = _sizeListener;
    if (stream != null && listener != null) stream.removeListener(listener);
    _sizeStream = null;
    _sizeListener = null;
  }

  Widget _retry(BuildContext context) => Semantics(
    button: true,
    label: '图片加载失败，点击重试',
    child: InkWell(
      onTap: () => setState(() => _load(refresh: true)),
      child: ColoredBox(
        color: Theme.of(context).colorScheme.primary.withValues(alpha: .08),
        child: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.refresh_rounded, size: 22),
              Text('重试', style: TextStyle(fontSize: 10)),
            ],
          ),
        ),
      ),
    ),
  );

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
  const CampusAuthorAvatar({
    super.key,
    required this.author,
    this.radius = 16,
    this.repository,
    this.linkToProfile = true,
  });
  final CampusAuthor author;
  final double radius;
  final CampusRepository? repository;
  final bool linkToProfile;

  @override
  Widget build(BuildContext context) {
    final model = CommunityScope.maybeOf(context);
    final resolved = model?.resolveAuthor(author) ?? author;
    final colors = Theme.of(context).colorScheme;
    final initial = resolved.displayName.isEmpty
        ? '?'
        : resolved.displayName.characters.first;
    final hasPreset = resolved.avatarPreset >= 1 && resolved.avatarPreset <= 15;
    // 头像最大只有 44 逻辑像素。预设图是 200KB 级别的 JPG，按原始尺寸解码
    // 会给列表滚动带来额外的解码和内存压力，这里按实际显示像素解码。
    final decodeSize = (radius * 2 * MediaQuery.devicePixelRatioOf(context))
        .ceil()
        .clamp(1, 256);
    final fallback = CircleAvatar(
      radius: radius,
      backgroundColor: colors.primary.withValues(alpha: .12),
      foregroundColor: colors.primary,
      backgroundImage: hasPreset
          ? ResizeImage.resizeIfNeeded(
              decodeSize,
              decodeSize,
              AssetImage(
                'assets/avatars/avatar-${resolved.avatarPreset.toString().padLeft(2, '0')}.jpg',
              ),
            )
          : null,
      child: hasPreset
          ? null
          : Text(initial, style: TextStyle(fontSize: radius * .9)),
    );
    final source = repository ?? model?.campus;
    final image = resolved.avatarAssetId == null || source == null
        ? fallback
        : ClipOval(
            child: FutureBuilder<Uint8List?>(
              future: source.loadAsset(
                resolved.avatarAssetId!,
                thumbnail: true,
              ),
              builder: (context, snapshot) => snapshot.data == null
                  ? fallback
                  : Image.memory(
                      snapshot.data!,
                      width: radius * 2,
                      height: radius * 2,
                      cacheWidth: decodeSize,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => fallback,
                    ),
            ),
          );
    if (!linkToProfile || resolved.id.isEmpty || model == null) return image;
    return Semantics(
      label: '查看${resolved.displayName}的个人主页',
      button: true,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: () => context.pushNamed(
          'community-profile',
          pathParameters: {'profileId': resolved.id},
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 44, minWidth: 44),
          child: Center(widthFactor: 1, heightFactor: 1, child: image),
        ),
      ),
    );
  }
}

class CampusAuthorName extends StatelessWidget {
  const CampusAuthorName({
    super.key,
    required this.author,
    this.suffix = '',
    this.style,
    this.maxLines = 1,
    this.overflow = TextOverflow.ellipsis,
  });
  final CampusAuthor author;
  final String suffix;
  final TextStyle? style;
  final int? maxLines;
  final TextOverflow overflow;
  @override
  Widget build(BuildContext context) => Text(
    '${(CommunityScope.maybeOf(context)?.resolveAuthor(author) ?? author).displayName}$suffix',
    style: style,
    maxLines: maxLines,
    overflow: overflow,
  );
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
    return Container(
      key: const ValueKey('campus-rating-summary-card'),
      decoration: campusCardDecoration(context, radius: 16),
      child: PageCard(
        radius: 16,
        padding: const EdgeInsets.all(11),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final stacked =
                constraints.maxWidth < 300 ||
                MediaQuery.textScalerOf(context).scale(12) > 17;
            final scorePanel = Container(
              width: stacked ? double.infinity : 96,
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
              decoration: BoxDecoration(
                color: context.campusColors.canvas,
                borderRadius: BorderRadius.circular(11),
                border: Border.all(
                  color: context.campusColors.cardLine,
                  width: .5,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            score == null ? '—' : score.toStringAsFixed(1),
                            maxLines: 1,
                            style: TextStyle(
                              fontSize: 28,
                              height: 1,
                              color: context.campusColors.ink,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -.8,
                              fontFeatures: const [
                                FontFeature.tabularFigures(),
                              ],
                            ),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(left: 2, bottom: 3),
                        child: Text(
                          '/ 5',
                          style: TextStyle(
                            fontSize: 10,
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    summary.count == 0 ? '等待第一份评分' : '${summary.count} 人评分',
                    style: TextStyle(
                      fontSize: 9.5,
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            );
            final distribution = Column(
              children: [
                for (var stars = 5; stars >= 1; stars--)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 1.2),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 28,
                          child: Text(
                            '$stars★',
                            style: TextStyle(
                              fontSize: 9,
                              color: colors.onSurfaceVariant,
                            ),
                          ),
                        ),
                        Expanded(
                          child: LinearProgressIndicator(
                            value: summary.count == 0
                                ? 0
                                : (summary.distribution[stars] ?? 0) /
                                      summary.count,
                            minHeight: 4,
                            borderRadius: BorderRadius.circular(4),
                            backgroundColor:
                                context.campusColors.controlSurface,
                          ),
                        ),
                        const SizedBox(width: 6),
                        SizedBox(
                          width: 18,
                          child: Text(
                            '${summary.distribution[stars] ?? 0}',
                            textAlign: TextAlign.end,
                            style: TextStyle(
                              fontSize: 9.5,
                              color: colors.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            );
            if (stacked) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [scorePanel, const SizedBox(height: 8), distribution],
              );
            }
            return Row(
              children: [
                scorePanel,
                const SizedBox(width: 10),
                Expanded(child: distribution),
              ],
            );
          },
        ),
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
