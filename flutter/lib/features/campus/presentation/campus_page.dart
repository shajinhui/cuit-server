import 'dart:async';

import 'package:chengxin_youyou/features/campus/data/campus_repository.dart';
import 'package:chengxin_youyou/features/campus/models/campus_models.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'campus_widgets.dart';
import 'forum_widgets.dart';
import '../../../ui/components/page_layout.dart';

/// 校园入口包含评分广场、二手市场和论坛，详情流程由独立路由承载。
class CampusPage extends StatefulWidget {
  const CampusPage({
    super.key,
    required this.repository,
    this.sessionGeneration = 0,
  });

  final CampusRepository? repository;
  final int sessionGeneration;

  @override
  State<CampusPage> createState() => _CampusPageState();
}

class _CampusPageState extends State<CampusPage> {
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();
  final _boards = <CampusBoard>[];
  final _listings = <CampusListing>[];
  final _threads = <ForumThread>[];
  final _forumCategories = <ForumCategory>[];
  String _area = 'ratings';
  String _sort = 'popular';
  String _listingType = 'sell';
  String _forumSort = 'latest';
  String? _forumCategoryId;
  bool _forumCategoriesLoaded = false;
  String _submittedQuery = '';
  String? _nextCursor;
  String? _error;
  bool _hasMore = false;
  bool _loading = true;
  bool _loadingMore = false;
  int _requestVersion = 0;

  @override
  void initState() {
    super.initState();
    unawaited(_load(reset: true));
  }

  @override
  void didUpdateWidget(covariant CampusPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.sessionGeneration != widget.sessionGeneration) {
      _requestVersion++;
      _boards.clear();
      _listings.clear();
      _threads.clear();
      _submittedQuery = '';
      _searchController.clear();
      _nextCursor = null;
      unawaited(_load(reset: true));
    }
  }

  @override
  void dispose() {
    _requestVersion++;
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _load({required bool reset}) async {
    final repository = widget.repository;
    final version = ++_requestVersion;
    setState(() {
      _error = null;
      _loading = reset;
      _loadingMore = !reset;
    });
    try {
      if (repository == null) {
        throw const CampusRepositoryException('校园服务暂时不可用。');
      }

      if (_area == 'ratings') {
        final page = await repository.listBoards(
          query: _submittedQuery,
          sort: _sort,
          cursor: reset ? null : _nextCursor,
        );
        if (!mounted || version != _requestVersion) return;
        _replaceOrAppend(_boards, page.items, reset, (board) => board.id);
        _nextCursor = page.nextCursor;
        _hasMore = page.hasMore;
      } else if (_area == 'forum') {
        final page = await repository.listForumThreads(
          categoryId: _forumCategoryId,
          query: _submittedQuery,
          sort: _forumSort,
          cursor: reset ? null : _nextCursor,
        );
        if (!mounted || version != _requestVersion) return;
        _replaceOrAppend(_threads, page.items, reset, (thread) => thread.id);
        _nextCursor = page.nextCursor;
        _hasMore = page.hasMore;
      } else {
        final page = await repository.listListings(
          query: _submittedQuery,
          type: _listingType,
          cursor: reset ? null : _nextCursor,
        );
        if (!mounted || version != _requestVersion) return;
        _replaceOrAppend(_listings, page.items, reset, (listing) => listing.id);
        _nextCursor = page.nextCursor;
        _hasMore = page.hasMore;
      }
    } catch (error) {
      if (!mounted || version != _requestVersion) return;
      _error = error.toString();
    } finally {
      if (mounted && version == _requestVersion) {
        setState(() {
          _loading = false;
          _loadingMore = false;
        });
      }
    }
  }

  void _replaceOrAppend<T>(
    List<T> current,
    List<T> incoming,
    bool reset,
    String Function(T) getId,
  ) {
    final values = <String, T>{};
    if (!reset) {
      for (final item in current) {
        values[getId(item)] = item;
      }
    }
    for (final item in incoming) {
      values[getId(item)] = item;
    }
    current
      ..clear()
      ..addAll(values.values);
  }

  void _changeArea(String value) {
    if (_area == value) return;
    setState(() {
      _area = value;
      _submittedQuery = '';
      _searchController.clear();
      _nextCursor = null;
    });
    // 两个栏目内容长度不同，切换后回到顶部，确保筛选和发布入口可见。
    if (_scrollController.hasClients) _scrollController.jumpTo(0);
    if (value == 'forum') {
      unawaited(_ensureForumCategories());
    }
    unawaited(_load(reset: true));
  }

  /// 版块目录只拉取一次；失败时不标记完成，下次进入论坛栏目再重试。
  Future<void> _ensureForumCategories() async {
    final repository = widget.repository;
    if (_forumCategoriesLoaded || repository == null) return;
    try {
      final categories = await repository.listForumCategories();
      if (!mounted) return;
      setState(() {
        _forumCategories
          ..clear()
          ..addAll(categories);
        _forumCategoriesLoaded = true;
        // 选中的版块不在最新目录中时回到“全部”，避免带着过期筛选请求。
        if (_forumCategoryId != null &&
            !categories.any((category) => category.id == _forumCategoryId)) {
          _forumCategoryId = null;
        }
      });
    } catch (_) {
      // 版块加载失败不阻塞帖子流，筛选栏此时只显示“全部”。
    }
  }

  void _changeForumCategory(String value) {
    final categoryId = value.isEmpty ? null : value;
    if (_forumCategoryId == categoryId) return;
    setState(() {
      _forumCategoryId = categoryId;
      _nextCursor = null;
    });
    unawaited(_load(reset: true));
  }

  void _changeForumSort(String value) {
    if (_forumSort == value) return;
    setState(() {
      _forumSort = value;
      _nextCursor = null;
    });
    unawaited(_load(reset: true));
  }

  void _submitSearch(String value) {
    setState(() {
      _submittedQuery = value.trim();
      _nextCursor = null;
    });
    unawaited(_load(reset: true));
  }

  void _changeSort(String value) {
    if (_sort == value) return;
    setState(() {
      _sort = value;
      _nextCursor = null;
    });
    unawaited(_load(reset: true));
  }

  void _changeListingType(String value) {
    if (_listingType == value) return;
    setState(() {
      _listingType = value;
      _nextCursor = null;
    });
    unawaited(_load(reset: true));
  }

  void _openMine() {
    if (_area == 'ratings') {
      context.pushNamed('ratings-mine');
    } else if (_area == 'forum') {
      context.pushNamed('forum-mine');
    } else {
      context.pushNamed(
        'marketplace-mine',
        queryParameters: {'type': _listingType},
      );
    }
  }

  void _createBoard() => context.pushNamed('rating-create-board');

  void _createThread() => context.pushNamed('forum-create');

  void _openThread(ForumThread thread) => context.pushNamed(
    'forum-thread',
    pathParameters: {'threadId': thread.id},
  );

  void _createListing() => context.pushNamed(
    'marketplace-create',
    queryParameters: {'type': _listingType},
  );

  void _openBoard(CampusBoard board) =>
      context.pushNamed('rating-board', pathParameters: {'boardId': board.id});

  void _openListing(CampusListing listing) => context.pushNamed(
    'marketplace-item',
    pathParameters: {'itemId': listing.id},
    queryParameters: {'type': listing.listingType},
  );

  @override
  Widget build(BuildContext context) => Theme(
    data: pageTheme(context),
    child: Builder(
      builder: (context) => ColoredBox(
        color: pageBackground(context),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: _buildPage(context),
          ),
        ),
      ),
    ),
  );

  Widget _buildPage(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SafeArea(
      bottom: false,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    '校园',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                  ),
                ),
                SizedBox(
                  width: (MediaQuery.sizeOf(context).width * .52).clamp(
                    198,
                    216,
                  ),
                  child: PageSegmentedControl<String>(
                    key: const ValueKey('campus-area-segment'),
                    values: const {
                      'ratings': '评分',
                      'marketplace': '二手',
                      'forum': '论坛',
                    },
                    selected: _area,
                    onChanged: _changeArea,
                  ),
                ),
                Expanded(
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: IconButton(
                      key: const ValueKey('campus-mine'),
                      tooltip: _area == 'ratings'
                          ? '我的评分内容'
                          : _area == 'forum'
                          ? '我的帖子'
                          : '我的二手发布',
                      onPressed: _openMine,
                      icon: const Icon(Icons.person_outline_rounded),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => _load(reset: true),
              child: ListView(
                controller: _scrollController,
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 120),
                children: [
                  if (_area == 'ratings') _buildRatingIntro(scheme),
                  _buildSearch(),
                  if (_area == 'ratings') ...[
                    _buildRatingHeading(),
                    ..._buildRatingContent(),
                  ] else if (_area == 'forum') ...[
                    _buildForumCategoryChips(),
                    _buildForumHeading(),
                    ..._buildForumContent(),
                  ] else ...[
                    _buildMarketplaceHeading(),
                    ..._buildMarketplaceContent(),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRatingIntro(ColorScheme scheme) => Container(
    margin: const EdgeInsets.only(bottom: 12),
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: const Color(0xFF0065D0),
      borderRadius: BorderRadius.circular(18),
    ),
    child: LayoutBuilder(
      builder: (context, constraints) {
        final copy = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '发现值得讨论的校园事物',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '创建一个主题，邀请大家添加对象并留下真实评分。',
              style: TextStyle(
                fontSize: 13,
                color: Colors.white.withValues(alpha: .85),
              ),
            ),
          ],
        );
        final button = FilledButton(
          key: const ValueKey('campus-create-board'),
          onPressed: _createBoard,
          style: FilledButton.styleFrom(
            backgroundColor: scheme.surface,
            foregroundColor: scheme.primary,
            minimumSize: const Size(44, 44),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            shape: const StadiumBorder(),
            textStyle: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          child: const Text('创建板块'),
        );
        if (constraints.maxWidth < 300 ||
            MediaQuery.textScalerOf(context).scale(14) > 18) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [copy, const SizedBox(height: 12), button],
          );
        }
        return Row(
          children: [
            Expanded(child: copy),
            const SizedBox(width: 12),
            button,
          ],
        );
      },
    ),
  );

  Widget _buildSearch() {
    final marketplace = _area == 'marketplace';
    final forum = _area == 'forum';
    final hint = marketplace
        ? (_listingType == 'wanted' ? '搜索求购需求' : '搜索想要的闲置')
        : forum
        ? '搜索帖子'
        : '搜索评分板块';
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              key: const ValueKey('campus-search'),
              controller: _searchController,
              maxLength: 50,
              buildCounter:
                  (
                    _, {
                    required currentLength,
                    required isFocused,
                    maxLength,
                  }) => null,
              textInputAction: TextInputAction.search,
              onSubmitted: _submitSearch,
              decoration: InputDecoration(
                fillColor: Theme.of(context).colorScheme.surface,
                hintText: hint,
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: _searchController.text.isEmpty
                    ? null
                    : IconButton(
                        tooltip: '清空搜索',
                        onPressed: () {
                          _searchController.clear();
                          _submitSearch('');
                        },
                        icon: const Icon(Icons.close_rounded),
                      ),
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),
          if (marketplace) ...[
            const SizedBox(width: 8),
            FilledButton.tonalIcon(
              key: const ValueKey('campus-create-listing'),
              onPressed: _createListing,
              icon: const Icon(Icons.add_rounded),
              label: const Text('发布'),
            ),
          ],
          if (forum) ...[
            const SizedBox(width: 8),
            FilledButton.tonalIcon(
              key: const ValueKey('campus-create-thread'),
              onPressed: _createThread,
              icon: const Icon(Icons.add_rounded),
              label: const Text('发帖'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildRatingHeading() => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _submittedQuery.isEmpty ? '评分广场' : '搜索结果',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              Text(
                _submittedQuery.isEmpty ? '大家都在评' : _submittedQuery,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ],
          ),
        ),
        SizedBox(
          width: 132,
          child: PageSegmentedControl<String>(
            key: const ValueKey('campus-sort-segment'),
            values: const {'popular': '热门', 'newest': '最新'},
            selected: _sort,
            onChanged: _changeSort,
          ),
        ),
      ],
    ),
  );

  Widget _buildMarketplaceHeading() => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Row(
      children: [
        _TypeChoice(
          value: 'sell',
          selected: _listingType,
          label: '出售',
          onSelected: _changeListingType,
        ),
        _TypeChoice(
          value: 'wanted',
          selected: _listingType,
          label: '求购',
          onSelected: _changeListingType,
        ),
        const Spacer(),
        TextButton.icon(
          onPressed: _loading ? null : () => _load(reset: true),
          icon: const Icon(Icons.refresh_rounded, size: 18),
          label: const Text('刷新'),
        ),
      ],
    ),
  );

  List<Widget> _buildRatingContent() {
    if (_loading && _boards.isEmpty) {
      return [const CampusPageState(title: '正在加载评分板块', loading: true)];
    }
    if (_error != null && _boards.isEmpty) {
      return [
        CampusPageState(
          title: '暂时无法打开评分广场',
          description: _error,
          actionLabel: '重新加载',
          onAction: () => _load(reset: true),
        ),
      ];
    }
    if (_boards.isEmpty) {
      return [
        CampusPageState(
          title: _submittedQuery.isEmpty ? '还没有评分板块' : '没有找到相关板块',
          description: _submittedQuery.isEmpty
              ? '创建第一个主题，邀请大家参与评分。'
              : '换个关键词试试。',
          actionLabel: _submittedQuery.isEmpty ? '创建板块' : '清空搜索',
          onAction: _submittedQuery.isEmpty
              ? _createBoard
              : () {
                  _searchController.clear();
                  _submitSearch('');
                },
        ),
      ];
    }
    return [
      if (_error != null)
        _InlineError(message: _error!, onRetry: () => _load(reset: true)),
      for (final board in _boards)
        _RatingBoardCard(
          board: board,
          repository: widget.repository,
          onTap: () => _openBoard(board),
        ),
      if (_hasMore)
        _LoadMoreButton(
          loading: _loadingMore,
          onPressed: () => _load(reset: false),
        ),
    ];
  }

  List<Widget> _buildMarketplaceContent() {
    if (_loading && _listings.isEmpty) {
      return [
        CampusPageState(
          title: _listingType == 'wanted' ? '正在加载求购' : '正在加载商品',
          loading: true,
        ),
      ];
    }
    if (_error != null && _listings.isEmpty) {
      return [
        CampusPageState(
          title: '暂时无法加载校园二手',
          description: _error,
          actionLabel: '重新加载',
          onAction: () => _load(reset: true),
        ),
      ];
    }
    if (_listings.isEmpty) {
      final wanted = _listingType == 'wanted';
      return [
        CampusPageState(
          title: wanted ? '暂时没有求购' : '二手小铺等待开张',
          description: wanted ? '写下想要的物品，让有闲置的同学联系你。' : '整理一下闲置，让它们继续派上用场。',
          actionLabel: wanted ? '发布第一条求购' : '发布第一件闲置',
          onAction: _createListing,
        ),
      ];
    }
    return [
      if (_error != null)
        _InlineError(message: _error!, onRetry: () => _load(reset: true)),
      LayoutBuilder(
        builder: (context, constraints) {
          // 正常字号保留两列；大字体改为单列，卡片按内容自然增高。
          final columns = MediaQuery.textScalerOf(context).scale(15) > 20
              ? 1
              : 2;
          final cardWidth =
              (constraints.maxWidth - 8 * (columns - 1)) / columns;
          return Wrap(
            key: const ValueKey('campus-listings'),
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final listing in _listings)
                SizedBox(
                  width: cardWidth,
                  child: _MarketplaceCard(
                    listing: listing,
                    repository: widget.repository,
                    onTap: () => _openListing(listing),
                  ),
                ),
            ],
          );
        },
      ),
      if (_hasMore)
        _LoadMoreButton(
          loading: _loadingMore,
          onPressed: () => _load(reset: false),
        ),
    ];
  }

  /// 版块筛选条：内容可能较多，用横向滚动避免挤压列表空间。
  Widget _buildForumCategoryChips() {
    final colors = Theme.of(context).colorScheme;
    Widget chip(String value, String label) {
      final active = _forumCategoryId == (value.isEmpty ? null : value);
      return Padding(
        padding: const EdgeInsets.only(right: 8),
        child: ChoiceChip(
          label: Text(label),
          selected: active,
          onSelected: (_) => _changeForumCategory(value),
          showCheckmark: false,
          selectedColor: colors.primaryContainer,
          labelStyle: TextStyle(
            color: active ? colors.onPrimaryContainer : colors.onSurfaceVariant,
          ),
        ),
      );
    }

    return SizedBox(
      height: 40,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          chip('', '全部'),
          for (final category in _forumCategories)
            chip(category.id, category.name),
        ],
      ),
    );
  }

  Widget _buildForumHeading() => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _submittedQuery.isEmpty ? '校园论坛' : '搜索结果',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              Text(
                _submittedQuery.isEmpty ? '大家都在聊' : _submittedQuery,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ],
          ),
        ),
        SizedBox(
          width: 132,
          child: PageSegmentedControl<String>(
            key: const ValueKey('campus-forum-sort-segment'),
            values: const {'latest': '最新', 'active': '活跃'},
            selected: _forumSort,
            onChanged: _changeForumSort,
          ),
        ),
      ],
    ),
  );

  List<Widget> _buildForumContent() {
    if (_loading && _threads.isEmpty) {
      return [const CampusPageState(title: '正在加载帖子', loading: true)];
    }
    if (_error != null && _threads.isEmpty) {
      return [
        CampusPageState(
          title: '暂时无法打开论坛',
          description: _error,
          actionLabel: '重新加载',
          onAction: () => _load(reset: true),
        ),
      ];
    }
    if (_threads.isEmpty) {
      return [
        CampusPageState(
          title: _submittedQuery.isEmpty ? '还没有帖子' : '没有找到相关帖子',
          description: _submittedQuery.isEmpty ? '发出第一帖，和同学们聊聊。' : '换个关键词试试。',
          actionLabel: _submittedQuery.isEmpty ? '发帖' : '清空搜索',
          onAction: _submittedQuery.isEmpty
              ? _createThread
              : () {
                  _searchController.clear();
                  _submitSearch('');
                },
        ),
      ];
    }
    return [
      if (_error != null)
        _InlineError(message: _error!, onRetry: () => _load(reset: true)),
      for (final thread in _threads)
        ForumThreadCard(
          thread: thread,
          repository: widget.repository,
          onTap: () => _openThread(thread),
        ),
      if (_hasMore)
        _LoadMoreButton(
          loading: _loadingMore,
          onPressed: () => _load(reset: false),
        ),
    ];
  }
}

class _RatingBoardCard extends StatelessWidget {
  const _RatingBoardCard({
    required this.board,
    required this.repository,
    required this.onTap,
  });
  final CampusBoard board;
  final CampusRepository? repository;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              CampusAssetImage(
                assetId: board.coverAssetId,
                repository: repository,
                height: 72,
                width: 72,
                fallback: Icons.forum_outlined,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      board.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      board.description.isEmpty
                          ? '这个评分板块还没有介绍'
                          : board.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Row(
                      children: [
                        CampusAuthorAvatar(author: board.creator, radius: 9),
                        const SizedBox(width: 5),
                        Expanded(
                          child: Text(
                            board.creatorName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.labelSmall,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${board.itemCount}',
                    style: theme.textTheme.titleLarge?.copyWith(
                      color: theme.colorScheme.primary,
                      height: 1,
                    ),
                  ),
                  Text('个对象', style: theme.textTheme.labelSmall),
                  const SizedBox(height: 7),
                  Text(
                    '${board.ratingCount} 人次',
                    style: theme.textTheme.labelSmall,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MarketplaceCard extends StatelessWidget {
  const _MarketplaceCard({
    required this.listing,
    required this.repository,
    required this.onTap,
  });
  final CampusListing listing;
  final CampusRepository? repository;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final wanted = listing.listingType == 'wanted';
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!wanted || listing.imageAssetId != null)
              AspectRatio(
                aspectRatio: 4 / 3,
                child: CampusAssetImage(
                  assetId: listing.imageAssetId,
                  repository: repository,
                  fallback: Icons.shopping_bag_outlined,
                  radius: 0,
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    listing.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      height: 1.4,
                    ),
                  ),
                  if (wanted) ...[
                    const SizedBox(height: 6),
                    Text(
                      listing.description,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.5,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        '${wanted ? '预算 ' : ''}¥${campusFormatPrice(listing.priceCents)}',
                        style: TextStyle(
                          fontSize: wanted ? 20 : 22,
                          fontWeight: FontWeight.w700,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                      Text(
                        campusLabel(listing.campus),
                        style: TextStyle(
                          fontSize: 12,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TypeChoice extends StatelessWidget {
  const _TypeChoice({
    required this.value,
    required this.selected,
    required this.label,
    required this.onSelected,
  });
  final String value;
  final String selected;
  final String label;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final active = value == selected;
    final colors = Theme.of(context).colorScheme;
    return TextButton(
      onPressed: () => onSelected(value),
      style: TextButton.styleFrom(
        foregroundColor: active ? colors.primary : colors.onSurfaceVariant,
        backgroundColor: active ? colors.surface : Colors.transparent,
      ),
      child: Text(label),
    );
  }
}

class _LoadMoreButton extends StatelessWidget {
  const _LoadMoreButton({required this.loading, required this.onPressed});
  final bool loading;
  final VoidCallback onPressed;
  @override
  Widget build(BuildContext context) => Center(
    child: OutlinedButton(
      onPressed: loading ? null : onPressed,
      child: Text(loading ? '正在加载…' : '加载更多'),
    ),
  );
}

class _InlineError extends StatelessWidget {
  const _InlineError({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => ListTile(
    leading: const Icon(Icons.cloud_off_outlined),
    title: Text(message, maxLines: 2, overflow: TextOverflow.ellipsis),
    trailing: TextButton(onPressed: onRetry, child: const Text('重试')),
  );
}
