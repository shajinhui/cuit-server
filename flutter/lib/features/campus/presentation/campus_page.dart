import 'dart:async';

import 'package:chengxin_youyou/features/campus/data/campus_repository.dart';
import 'package:chengxin_youyou/features/campus/models/campus_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollCacheExtent, ScrollDirection;
import 'package:go_router/go_router.dart';

import 'campus_widgets.dart';
import 'forum_channels_sheet.dart';
import 'campus_theme.dart';
import 'forum_widgets.dart';
import '../../../ui/components/page_layout.dart';
import '../../community/presentation/community_scope.dart';

class _ForumTopicFilter {
  const _ForumTopicFilter({
    required this.key,
    required this.label,
    required this.icon,
    required this.keywords,
    required this.fallbackQuery,
  });

  final String key;
  final String label;
  final IconData icon;
  final List<String> keywords;
  final String fallbackQuery;
}

const _forumTopicFilters = [
  _ForumTopicFilter(
    key: 'forum-topic-study',
    label: '课程讨论',
    icon: Icons.menu_book_outlined,
    keywords: ['学习', '课程'],
    fallbackQuery: '课程',
  ),
  _ForumTopicFilter(
    key: 'forum-topic-experience',
    label: '经验主题',
    icon: Icons.lightbulb_outline_rounded,
    keywords: ['经验', '分享'],
    fallbackQuery: '经验',
  ),
  _ForumTopicFilter(
    key: 'forum-topic-affairs',
    label: '事务整理',
    icon: Icons.checklist_rounded,
    keywords: ['事务', '整理'],
    fallbackQuery: '事务',
  ),
  _ForumTopicFilter(
    key: 'forum-topic-help',
    label: '本校问答',
    icon: Icons.help_outline_rounded,
    keywords: ['互助', '求助', '问答'],
    fallbackQuery: '求助',
  ),
];

const _officialForumCategories = <ForumCategory>[
  ForumCategory(
    id: 'general',
    name: '日常',
    description: '校园生活、见闻和日常闲聊。',
    sortOrder: 1,
  ),
  ForumCategory(
    id: 'study',
    name: '学习',
    description: '课程、考试、资料与学习经验。',
    sortOrder: 2,
  ),
  ForumCategory(
    id: 'mutual',
    name: '互助',
    description: '校内互帮互助和资源交换。',
    sortOrder: 3,
  ),
  ForumCategory(
    id: 'lost',
    name: '失物',
    description: '失物招领与寻物启事。',
    sortOrder: 4,
  ),
  ForumCategory(
    id: 'partner',
    name: '搭子',
    description: '自习、运动、吃饭和出行搭子。',
    sortOrder: 5,
  ),
  ForumCategory(
    id: 'activity',
    name: '社团活动',
    description: '社团、组织、讲座与校园活动。',
    sortOrder: 6,
  ),
  ForumCategory(
    id: 'treehole',
    name: '树洞',
    description: '匿名树洞与心情记录。',
    sortOrder: 7,
  ),
];

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
  final _searchFocusNode = FocusNode();
  final _scrollController = ScrollController();
  final _boards = <CampusBoard>[];
  final _listings = <CampusListing>[];
  final _threads = <ForumThread>[];
  final _forumCategories = <ForumCategory>[];
  final _forumHomeCategoryIds = <String>[];
  String _area = 'ratings';
  String _sort = 'popular';
  String _listingType = 'sell';
  String _forumSort = 'latest';
  String? _forumCategoryId;
  _ForumTopicFilter? _forumTopic;
  bool _forumCategoriesLoaded = false;
  String _submittedQuery = '';
  bool _searchOpen = false;
  String? _nextCursor;
  String? _error;
  bool _hasMore = false;
  bool _loading = true;
  bool _loadingMore = false;
  bool _headerVisible = true;
  int _requestVersion = 0;

  @override
  void initState() {
    super.initState();
    unawaited(_load(reset: true));
    if (_area == 'forum') unawaited(_ensureForumCategories());
  }

  void _setHeaderVisible(bool visible) {
    if (visible == _headerVisible) return;
    setState(() => _headerVisible = visible);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final community = CommunityScope.maybeOf(context);
    if (community != null) {
      scheduleMicrotask(() {
        unawaited(community.loadProfile());
        unawaited(community.refreshUnread());
      });
    }
  }

  @override
  void didUpdateWidget(covariant CampusPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.sessionGeneration != widget.sessionGeneration) {
      _requestVersion++;
      _boards.clear();
      _listings.clear();
      _threads.clear();
      _forumCategories.clear();
      _forumHomeCategoryIds.clear();
      _forumCategoriesLoaded = false;
      _forumCategoryId = null;
      _forumSort = 'latest';
      _forumTopic = null;
      _submittedQuery = '';
      _searchOpen = false;
      _searchFocusNode.unfocus();
      _searchController.clear();
      _nextCursor = null;
      unawaited(_load(reset: true));
      if (_area == 'forum') unawaited(_ensureForumCategories());
    }
  }

  @override
  void reassemble() {
    super.reassemble();
    // Flutter 热重载会保留 State；清掉旧版块目录，让当前代码重新应用默认版块。
    _forumCategoriesLoaded = false;
    _forumCategories.clear();
    _forumHomeCategoryIds.clear();
    if (_area == 'forum') {
      unawaited(_ensureForumCategories());
      unawaited(_load(reset: true));
    }
  }

  @override
  void dispose() {
    _requestVersion++;
    _searchController.dispose();
    _searchFocusNode.dispose();
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
    _searchFocusNode.unfocus();
    setState(() {
      _area = value;
      _headerVisible = true;
      _submittedQuery = '';
      _searchOpen = false;
      _forumTopic = null;
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

  /// 版块目录与首页偏好只拉取一次；失败时下次进入论坛栏目再重试。
  Future<void> _ensureForumCategories() async {
    final repository = widget.repository;
    if (_forumCategoriesLoaded || repository == null) return;
    try {
      final listedCategories = await repository.listForumCategories();
      final categories = listedCategories.isEmpty
          ? _officialForumCategories
          : listedCategories;
      List<String> homeCategoryIds;
      try {
        homeCategoryIds = await repository.getForumHomeCategories();
      } catch (_) {
        homeCategoryIds = const [];
      }
      if (!mounted) return;
      final availableIds = categories.map((category) => category.id).toSet();
      final validHomeCategoryIds = homeCategoryIds
          .where(availableIds.contains)
          .toSet()
          .toList();
      final effectiveHomeCategoryIds = validHomeCategoryIds.isNotEmpty
          ? validHomeCategoryIds
          : _defaultForumHomeCategoryIds(categories);
      setState(() {
        _forumCategories
          ..clear()
          ..addAll(categories);
        _forumHomeCategoryIds
          ..clear()
          ..addAll(effectiveHomeCategoryIds);
        _forumCategoriesLoaded = true;
        // 选中的版块不在最新目录中时回到“全部”，避免带着过期筛选请求。
        if (_forumCategoryId != null &&
            !categories.any((category) => category.id == _forumCategoryId)) {
          _forumCategoryId = null;
        }
      });
    } catch (_) {
      // 版块加载失败不阻塞帖子流，筛选栏仍保留固定的“全部”和“热门”。
    }
  }

  List<String> _defaultForumHomeCategoryIds(List<ForumCategory> categories) {
    final official =
        categories.where((category) => category.isOfficial).toList()
          ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    final candidates = official.isNotEmpty ? official : [...categories]
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    return candidates.take(8).map((category) => category.id).toList();
  }

  void _changeForumCategory(String value) {
    final categoryId = value.isEmpty ? null : value;
    if (_forumCategoryId == categoryId && _forumTopic == null) return;
    setState(() {
      _forumCategoryId = categoryId;
      // 手动点版块即视为放弃主题筛选，避免两个条件互相矛盾。
      _forumTopic = null;
      _nextCursor = null;
    });
    unawaited(_load(reset: true));
  }

  void _selectForumAll() {
    if (_forumCategoryId == null &&
        _forumSort == 'latest' &&
        _forumTopic == null &&
        _submittedQuery.isEmpty) {
      return;
    }
    setState(() {
      _forumCategoryId = null;
      _forumSort = 'latest';
      _forumTopic = null;
      _submittedQuery = '';
      _searchController.clear();
      _nextCursor = null;
    });
    unawaited(_load(reset: true));
  }

  void _selectForumHot() {
    if (_forumCategoryId == null &&
        _forumSort == 'active' &&
        _forumTopic == null &&
        _submittedQuery.isEmpty) {
      return;
    }
    setState(() {
      _forumCategoryId = null;
      _forumSort = 'active';
      _forumTopic = null;
      _submittedQuery = '';
      _searchController.clear();
      _nextCursor = null;
    });
    unawaited(_load(reset: true));
  }

  Future<void> _openForumChannels() async {
    final result = await showModalBottomSheet<ForumChannelsSheetResult>(
      context: context,
      useRootNavigator: true,
      showDragHandle: true,
      isScrollControlled: true,
      backgroundColor: campusSurface,
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * .86,
      ),
      builder: (_) => Theme(
        data: campusTheme(context),
        child: FractionallySizedBox(
          heightFactor: .82,
          child: ForumChannelsSheet(
            repository: widget.repository,
            categories: List.unmodifiable(_forumCategories),
            homeCategoryIds: List.unmodifiable(_forumHomeCategoryIds),
            selectedCategoryId: _forumCategoryId,
          ),
        ),
      ),
    );
    if (!mounted || result == null) return;
    setState(() {
      if (result.changed || result.categories.isNotEmpty) {
        _forumCategories
          ..clear()
          ..addAll(result.categories);
      }
      _forumHomeCategoryIds
        ..clear()
        ..addAll(result.homeCategoryIds);
      _forumCategoriesLoaded = true;
    });
    final selectedCategoryId = result.selectedCategoryId;
    if (selectedCategoryId != null) {
      _changeForumCategory(selectedCategoryId);
    }
  }

  void _changeForumSort(String value) {
    if (_forumSort == value) return;
    setState(() {
      _forumSort = value;
      _nextCursor = null;
    });
    unawaited(_load(reset: true));
  }

  /// 主题筛选优先匹配同名版块，匹配不到时退回关键词搜索。
  void _applyForumTopic(_ForumTopicFilter? topic) {
    if (topic?.key == _forumTopic?.key) return;
    String? categoryId;
    var query = '';
    if (topic != null) {
      for (final category in _forumCategories) {
        if (topic.keywords.any(category.name.contains)) {
          categoryId = category.id;
          break;
        }
      }
      if (categoryId == null) query = topic.fallbackQuery;
    }
    setState(() {
      _forumTopic = topic;
      _forumCategoryId = categoryId;
      _submittedQuery = query;
      _searchController.text = query;
      _nextCursor = null;
    });
    unawaited(_load(reset: true));
  }

  String get _searchScopeName => switch (_area) {
    'ratings' => '评分',
    'marketplace' => '二手',
    _ => '论坛',
  };

  String get _searchHint => switch (_area) {
    'ratings' => '搜索评分板块',
    'marketplace' => _listingType == 'wanted' ? '搜索求购需求' : '搜索想要的闲置',
    _ => '搜索帖子',
  };

  void _openSearch() {
    if (!_searchOpen) {
      setState(() => _searchOpen = true);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _searchFocusNode.requestFocus();
    });
  }

  void _closeSearch() {
    if (!_searchOpen) return;
    final hadSubmittedQuery = _submittedQuery.isNotEmpty;
    _searchFocusNode.unfocus();
    setState(() {
      _searchOpen = false;
      _searchController.clear();
      _submittedQuery = '';
      _nextCursor = null;
    });
    if (hadSubmittedQuery) unawaited(_load(reset: true));
  }

  void _clearSearchInput() {
    _searchController.clear();
    if (_submittedQuery.isNotEmpty) {
      _submitSearch('');
    } else {
      setState(() {});
    }
  }

  void _submitSearch(String value) {
    _searchFocusNode.unfocus();
    setState(() {
      _submittedQuery = value.trim();
      // 新搜索覆盖旧主题条件。
      _forumTopic = null;
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

  Future<void> _createThread() async {
    await context.pushNamed('forum-create');
    if (mounted) await _load(reset: true);
  }

  Future<void> _openThread(ForumThread thread) async {
    await context.pushNamed(
      'forum-thread',
      pathParameters: {'threadId': thread.id},
    );
    if (mounted) await _load(reset: true);
  }

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
  Widget build(BuildContext context) => CampusThemeBuilder(
    builder: (context) => DefaultTextStyle.merge(
      style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
      child: ColoredBox(
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
          ClipRect(
            child: AnimatedAlign(
              key: const ValueKey('campus-collapsible-header'),
              alignment: Alignment.topCenter,
              heightFactor: _headerVisible ? 1 : 0,
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOutCubic,
              child: _buildHeader(context),
            ),
          ),
          if (_searchOpen) _buildSearchBar(),
          Expanded(
            child: ColoredBox(
              color: _area == 'forum' ? scheme.surface : campusCanvas,
              child: NotificationListener<ScrollNotification>(
                onNotification: (notification) {
                  if (notification.metrics.axis != Axis.vertical) {
                    return false;
                  }
                  if (notification.metrics.pixels <= 0) {
                    _setHeaderVisible(true);
                  } else if (notification is ScrollUpdateNotification &&
                      notification.scrollDelta != null &&
                      notification.scrollDelta!.abs() > .5) {
                    _setHeaderVisible(notification.scrollDelta! < 0);
                  } else if (notification is UserScrollNotification &&
                      notification.direction != ScrollDirection.idle) {
                    _setHeaderVisible(
                      notification.direction == ScrollDirection.reverse,
                    );
                  }
                  return false;
                },
                child: RefreshIndicator(
                  onRefresh: () => _load(reset: true),
                  child: _area == 'marketplace'
                      ? _buildMarketplaceList()
                      : ListView(
                          controller: _scrollController,
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: _area == 'forum'
                              ? const EdgeInsets.only(bottom: 120)
                              : const EdgeInsets.fromLTRB(16, 4, 16, 120),
                          children: [
                            if (_area == 'ratings') _buildRatingIntro(scheme),
                            if (_area == 'ratings') ...[
                              _buildRatingHeading(context),
                              ..._buildRatingContent(),
                            ] else if (_area == 'forum') ...[
                              _buildForumFilters(context),
                              ..._buildForumContent(),
                            ],
                          ],
                        ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final community = CommunityScope.maybeOf(context);
    final tabs = PageSegmentedControl<String>(
      key: const ValueKey('campus-area-segment'),
      compact: true,
      values: const {'ratings': '评分', 'marketplace': '二手', 'forum': '论坛'},
      selected: _area,
      onChanged: _changeArea,
      trackColor: campusControlSurface,
      selectedColor: campusInk,
      selectedForegroundColor: campusOnInk,
    );
    const title = Text(
      '校园',
      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
    );
    final search = IconButton(
      key: const ValueKey('campus-search-toggle'),
      tooltip: '搜索$_searchScopeName',
      onPressed: _openSearch,
      style: IconButton.styleFrom(
        foregroundColor: _searchOpen ? pageAccent(context) : null,
        backgroundColor: _searchOpen
            ? pageAccent(context).withValues(alpha: .1)
            : null,
      ),
      icon: const Icon(Icons.search_rounded, size: 20),
    );
    final mine = IconButton(
      key: const ValueKey('campus-mine'),
      tooltip: _area == 'ratings'
          ? '我的评分内容'
          : _area == 'forum'
          ? '我的帖子'
          : '我的二手发布',
      onPressed: _openMine,
      icon: const Icon(Icons.person_outline_rounded, size: 20),
    );
    final controls = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        search,
        if (community != null && community.supported != false)
          IconButton(
            key: const ValueKey('campus-notifications'),
            tooltip: community.unreadCount > 0
                ? '互动消息，${community.unreadCount}条未读'
                : '互动消息',
            onPressed: () => context.pushNamed('community-notifications'),
            icon: Badge(
              isLabelVisible: community.unreadCount > 0,
              label: Text(
                community.unreadCount > 99 ? '99+' : '${community.unreadCount}',
              ),
              child: const Icon(Icons.campaign_outlined, size: 20),
            ),
          ),
        mine,
      ],
    );
    // 常规尺寸下，三个栏目夹在标题和右侧搜索入口之间；只有大字体
    // 导致单行确实放不下时才响应式折行，避免压缩系统字号或点击区域。
    final largeText = MediaQuery.textScalerOf(context).scale(13) > 20;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
      child: largeText
          ? Column(
              children: [
                Row(
                  children: [
                    const Expanded(child: title),
                    controls,
                  ],
                ),
                const SizedBox(height: 2),
                tabs,
              ],
            )
          : Row(
              children: [
                title,
                const SizedBox(width: 8),
                Expanded(child: tabs),
                const SizedBox(width: 4),
                controls,
              ],
            ),
    );
  }

  Widget _buildRatingIntro(ColorScheme scheme) => Container(
    key: const ValueKey('campus-rating-intro'),
    margin: const EdgeInsets.only(bottom: 12),
    decoration: BoxDecoration(
      color: campusInk,
      borderRadius: BorderRadius.circular(18),
      boxShadow: [
        BoxShadow(
          color: campusInk.withValues(alpha: .12),
          blurRadius: 18,
          offset: const Offset(0, 6),
        ),
      ],
    ),
    clipBehavior: Clip.antiAlias,
    child: Stack(
      children: [
        Positioned(
          right: -12,
          top: -22,
          child: Icon(
            Icons.star_rounded,
            size: 108,
            color: Colors.white.withValues(alpha: .045),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final copy = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.auto_awesome_rounded,
                        size: 12,
                        color: Colors.white.withValues(alpha: .7),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        '校园评分',
                        style: TextStyle(
                          fontSize: 10,
                          letterSpacing: .6,
                          fontWeight: FontWeight.w600,
                          color: Colors.white.withValues(alpha: .68),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Text(
                    '发现值得讨论的校园事物',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 18,
                      height: 1.25,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -.2,
                      color: scheme.onPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '创建主题，邀请同学留下真实评分。',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11.5,
                      height: 1.35,
                      color: Colors.white.withValues(alpha: .6),
                    ),
                  ),
                ],
              );
              final button = FilledButton(
                key: const ValueKey('campus-create-board'),
                onPressed: _createBoard,
                style: FilledButton.styleFrom(
                  backgroundColor: campusSurface,
                  foregroundColor: campusInk,
                  minimumSize: const Size(44, 40),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  shape: const StadiumBorder(),
                  textStyle: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                child: const Text('创建板块'),
              );
              if (constraints.maxWidth < 300 ||
                  MediaQuery.textScalerOf(context).scale(14) > 18) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [copy, const SizedBox(height: 10), button],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(child: copy),
                  const SizedBox(width: 10),
                  button,
                ],
              );
            },
          ),
        ),
      ],
    ),
  );

  Widget _buildSearchBar() {
    final forum = _area == 'forum';
    return Padding(
      key: const ValueKey('campus-search-panel'),
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              key: const ValueKey('campus-search'),
              controller: _searchController,
              focusNode: _searchFocusNode,
              autofocus: true,
              style: forum ? const TextStyle(fontSize: 14, height: 1.3) : null,
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
                // 统一由校园主题提供中性浅灰输入框底色。
                fillColor: null,
                hintText: _searchHint,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                constraints: const BoxConstraints(minHeight: 44),
                prefixIconConstraints: const BoxConstraints(
                  minWidth: 40,
                  minHeight: 44,
                ),
                suffixIconConstraints: const BoxConstraints(
                  minWidth: 44,
                  minHeight: 44,
                ),
                prefixIcon: Icon(Icons.search_rounded, size: forum ? 20 : 24),
                suffixIcon: _searchController.text.isEmpty
                    ? null
                    : IconButton(
                        key: const ValueKey('campus-search-clear'),
                        tooltip: '清空搜索',
                        onPressed: _clearSearchInput,
                        icon: const Icon(Icons.close_rounded),
                      ),
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),
          const SizedBox(width: 4),
          TextButton(
            key: const ValueKey('campus-search-cancel'),
            onPressed: _closeSearch,
            style: TextButton.styleFrom(
              minimumSize: const Size(52, 44),
              padding: const EdgeInsets.symmetric(horizontal: 8),
            ),
            child: const Text('取消'),
          ),
        ],
      ),
    );
  }

  Widget _buildRatingHeading(BuildContext context) {
    final copy = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _submittedQuery.isEmpty ? '评分广场' : '搜索结果',
          style: TextStyle(
            fontSize: 11,
            height: 1.2,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        Text(
          _submittedQuery.isEmpty ? '大家都在评' : _submittedQuery,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 17,
            height: 1.2,
            fontWeight: FontWeight.w600,
            letterSpacing: -.15,
          ),
        ),
      ],
    );
    final sort = PageSegmentedControl<String>(
      key: const ValueKey('campus-sort-segment'),
      compact: true,
      values: const {'popular': '热门', 'newest': '最新'},
      selected: _sort,
      onChanged: _changeSort,
      trackColor: campusControlSurface,
      selectedColor: campusInk,
      selectedForegroundColor: campusOnInk,
    );
    final largeText = MediaQuery.textScalerOf(context).scale(13) > 20;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: largeText
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [copy, const SizedBox(height: 6), sort],
            )
          : Row(
              children: [
                Expanded(child: copy),
                SizedBox(width: 108, child: sort),
              ],
            ),
    );
  }

  Widget _buildMarketplaceHeading(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final wanted = _listingType == 'wanted';
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
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
                    Text(
                      wanted ? '求购需求' : '校园闲置',
                      style: const TextStyle(
                        fontSize: 24,
                        height: 1.2,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -.45,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      wanted ? '说出你正在找的东西，让有闲置的同学联系你。' : '把闲置交给下一位同学，也让宿舍轻一点。',
                      style: TextStyle(
                        fontSize: 12.5,
                        height: 1.45,
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              FilledButton.icon(
                key: const ValueKey('campus-create-listing'),
                onPressed: _createListing,
                style: FilledButton.styleFrom(
                  backgroundColor: campusInk,
                  foregroundColor: campusOnInk,
                  minimumSize: const Size(44, 42),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 13,
                    vertical: 9,
                  ),
                  shape: const StadiumBorder(),
                  textStyle: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('发布'),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              SizedBox(
                width: 152,
                child: PageSegmentedControl<String>(
                  key: const ValueKey('campus-listing-type'),
                  values: const {'sell': '出售', 'wanted': '求购'},
                  selected: _listingType,
                  onChanged: (value) => _changeListingType(value),
                  trackColor: campusControlSurface,
                  selectedColor: campusInk,
                  selectedForegroundColor: campusOnInk,
                ),
              ),
              const Spacer(),
              Text(
                '${_listings.length} 件',
                style: TextStyle(fontSize: 11, color: colors.onSurfaceVariant),
              ),
              const SizedBox(width: 6),
              IconButton(
                tooltip: '刷新二手',
                onPressed: _loading ? null : () => _load(reset: true),
                constraints: const BoxConstraints.tightFor(
                  width: 38,
                  height: 38,
                ),
                padding: EdgeInsets.zero,
                style: IconButton.styleFrom(
                  foregroundColor: campusInk,
                  backgroundColor: campusSurface,
                  side: const BorderSide(color: campusCardLine, width: .8),
                  shape: const CircleBorder(),
                ),
                icon: const Icon(Icons.refresh_rounded, size: 18),
              ),
            ],
          ),
        ],
      ),
    );
  }

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

  Widget _buildMarketplaceList() {
    final headers = <Widget>[
      _buildMarketplaceHeading(context),
      if (_listings.isEmpty)
        _buildMarketplaceEmptyState()
      else if (_error != null)
        _InlineError(message: _error!, onRetry: () => _load(reset: true)),
    ];
    // 每行按需创建，避免 Wrap 把屏幕外的商品图片也同时下载，抢占首屏带宽。
    // 普通字号仍为两列；大字体改为单列，卡片高度由内容决定。
    final columns = MediaQuery.textScalerOf(context).scale(15) > 20 ? 1 : 2;
    final rowCount = (_listings.length + columns - 1) ~/ columns;
    return ListView.builder(
      key: const ValueKey('campus-listings'),
      controller: _scrollController,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 120),
      scrollCacheExtent: const ScrollCacheExtent.pixels(200),
      itemCount: headers.length + rowCount + (_hasMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index < headers.length) return headers[index];
        final row = index - headers.length;
        if (row == rowCount) {
          return _LoadMoreButton(
            loading: _loadingMore,
            onPressed: () => _load(reset: false),
          );
        }
        final first = row * columns;
        return Padding(
          key: ValueKey(_listings[first].id),
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var column = 0; column < columns; column++) ...[
                if (column > 0) const SizedBox(width: 8),
                Expanded(
                  child: first + column < _listings.length
                      ? _buildMarketplaceCard(_listings[first + column])
                      : const SizedBox.shrink(),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildMarketplaceCard(CampusListing listing) => _MarketplaceCard(
    listing: listing,
    repository: widget.repository,
    onTap: () => _openListing(listing),
  );

  Widget _buildMarketplaceEmptyState() {
    if (_loading) {
      return CampusPageState(
        title: _listingType == 'wanted' ? '正在加载求购' : '正在加载商品',
        loading: true,
      );
    }
    if (_error != null) {
      return CampusPageState(
        title: '暂时无法加载校园二手',
        description: _error,
        actionLabel: '重新加载',
        onAction: () => _load(reset: true),
      );
    }
    final wanted = _listingType == 'wanted';
    return CampusPageState(
      title: wanted ? '暂时没有求购' : '二手小铺等待开张',
      description: wanted ? '写下想要的物品，让有闲置的同学联系你。' : '整理一下闲置，让它们继续派上用场。',
      actionLabel: wanted ? '发布第一条求购' : '发布第一件闲置',
      onAction: _createListing,
    );
  }

  /// 首页固定「全部」「热门」，后面只放用户选择的版块。
  ///
  /// 用户从「更多板块」临时进入一个未固定版块时，也把它临时放进这一行，
  /// 保证当前筛选状态始终可见。
  Widget _buildForumCategoryChips(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final accent = pageAccent(context);
    final filterIsPristine = _forumTopic == null && _submittedQuery.isEmpty;
    final allActive =
        _forumCategoryId == null && _forumSort == 'latest' && filterIsPristine;
    final hotActive =
        _forumCategoryId == null && _forumSort == 'active' && filterIsPristine;

    Widget chip({
      required String keyValue,
      required String label,
      required bool active,
      required VoidCallback onPressed,
      IconData? icon,
    }) {
      return Padding(
        padding: const EdgeInsets.only(right: 4),
        child: Semantics(
          selected: active,
          button: true,
          child: TextButton(
            key: ValueKey(keyValue),
            onPressed: onPressed,
            style: TextButton.styleFrom(
              minimumSize: const Size(44, 44),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              padding: const EdgeInsets.symmetric(horizontal: 2),
            ),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: active
                    ? accent.withValues(alpha: .1)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (icon != null) ...[
                    Icon(
                      icon,
                      size: 14,
                      color: active ? accent : colors.onSurfaceVariant,
                    ),
                    const SizedBox(width: 3),
                  ],
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.3,
                      fontWeight: active ? FontWeight.w600 : FontWeight.w400,
                      color: active ? accent : colors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    final byId = {
      for (final category in _forumCategories) category.id: category,
    };
    final visibleCategories = <ForumCategory>[
      for (final id in _forumHomeCategoryIds)
        if (byId[id] != null) byId[id]!,
    ];
    final selectedId = _forumCategoryId;
    if (selectedId != null &&
        !visibleCategories.any((category) => category.id == selectedId) &&
        byId[selectedId] != null) {
      visibleCategories.insert(0, byId[selectedId]!);
    }

    return SizedBox(
      height: (MediaQuery.textScalerOf(context).scale(12) * 1.3 + 12).clamp(
        44,
        double.infinity,
      ),
      child: ListView(
        key: const ValueKey('campus-forum-categories'),
        scrollDirection: Axis.horizontal,
        children: [
          chip(
            keyValue: 'forum-channel-all',
            label: '全部',
            active: allActive,
            onPressed: _selectForumAll,
          ),
          chip(
            keyValue: 'forum-channel-hot',
            label: '热门',
            active: hotActive,
            onPressed: _selectForumHot,
          ),
          for (final category in visibleCategories)
            chip(
              keyValue: 'forum-channel-${category.id}',
              label: category.name,
              active: _forumCategoryId == category.id,
              onPressed: () => _changeForumCategory(category.id),
            ),
        ],
      ),
    );
  }

  /// 首页只保留一排主分类；主题与排序收进右侧的筛选面板。
  Widget _buildForumFilters(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 0, 8, 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            key: const ValueKey('campus-forum-filter-row'),
            children: [
              Expanded(child: _buildForumCategoryChips(context)),
              _buildForumCreateButton(context),
              _buildForumMoreButton(context),
              _buildForumFilterButton(context),
            ],
          ),
          _buildForumConditions(context),
        ],
      ),
    );
  }

  Widget _buildForumFilterButton(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final accent = pageAccent(context);
    final active = _forumTopic != null;
    return SizedBox(
      width: 44,
      height: 44,
      child: IconButton(
        key: const ValueKey('campus-forum-filter'),
        tooltip: active ? '筛选：${_forumTopic!.label}' : '筛选与排序',
        onPressed: _openForumFilterSheet,
        padding: EdgeInsets.zero,
        visualDensity: VisualDensity.compact,
        icon: Badge(
          isLabelVisible: active,
          smallSize: 7,
          backgroundColor: accent,
          child: Icon(
            Icons.tune_rounded,
            size: 19,
            color: active ? accent : colors.onSurfaceVariant,
          ),
        ),
      ),
    );
  }

  Widget _buildForumCreateButton(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final accent = pageAccent(context);
    return IconButton(
      key: const ValueKey('campus-create-thread'),
      tooltip: '发帖',
      onPressed: _createThread,
      constraints: const BoxConstraints.tightFor(width: 44, height: 44),
      padding: EdgeInsets.zero,
      style: IconButton.styleFrom(
        foregroundColor: accent,
        backgroundColor: _area == 'forum'
            ? campusControlSurface
            : colors.primaryContainer,
      ),
      icon: const Icon(Icons.add_rounded, size: 20),
    );
  }

  Widget _buildForumMoreButton(BuildContext context) => SizedBox(
    width: 58,
    height: 44,
    child: TextButton.icon(
      key: const ValueKey('forum-channel-more'),
      onPressed: _openForumChannels,
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 2),
        foregroundColor: Theme.of(context).colorScheme.onSurfaceVariant,
        textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
      ),
      icon: const Icon(Icons.grid_view_rounded, size: 16),
      label: const Text('更多'),
    ),
  );

  /// 条件只在生效时出现，一行内可点掉，不额外占常规空间。
  Widget _buildForumConditions(BuildContext context) {
    final topic = _forumTopic;
    final colors = Theme.of(context).colorScheme;
    if (topic == null && _submittedQuery.isEmpty) {
      return const SizedBox.shrink();
    }
    final accent = pageAccent(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 0, 2, 2),
      child: Row(
        children: [
          if (topic != null) ...[
            Material(
              color: accent.withValues(alpha: .1),
              borderRadius: BorderRadius.circular(9),
              child: InkWell(
                key: const ValueKey('campus-forum-topic-chip'),
                borderRadius: BorderRadius.circular(9),
                onTap: () => _applyForumTopic(null),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(8, 4, 6, 4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        topic.label,
                        style: TextStyle(
                          fontSize: 11,
                          height: 1.2,
                          fontWeight: FontWeight.w600,
                          color: accent,
                        ),
                      ),
                      const SizedBox(width: 2),
                      Icon(Icons.close_rounded, size: 13, color: accent),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
          ],
          if (_submittedQuery.isNotEmpty)
            Expanded(
              child: Text(
                '搜索：$_submittedQuery',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 11, color: colors.onSurfaceVariant),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTopicChoice(
    BuildContext context, {
    required String key,
    required String label,
    required IconData icon,
    required bool selected,
    required VoidCallback onTap,
  }) {
    final colors = Theme.of(context).colorScheme;
    final accent = pageAccent(context);
    return TextButton.icon(
      key: ValueKey(key),
      onPressed: onTap,
      style: TextButton.styleFrom(
        minimumSize: const Size(0, 40),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        foregroundColor: selected ? accent : colors.onSurfaceVariant,
        backgroundColor: selected ? accent.withValues(alpha: .1) : null,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: const TextStyle(
          fontSize: 13,
          height: 1.2,
          fontWeight: FontWeight.w500,
        ),
      ),
      icon: Icon(icon, size: 16),
      label: Text(label),
    );
  }

  Future<void> _openForumFilterSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      showDragHandle: true,
      isScrollControlled: true,
      backgroundColor: campusSurface,
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * .8,
      ),
      builder: (sheetContext) {
        return Theme(
          data: campusTheme(context),
          child: StatefulBuilder(
            builder: (context, setSheetState) {
              final colors = Theme.of(context).colorScheme;
              Widget heading(String text) => Padding(
                padding: const EdgeInsets.fromLTRB(20, 6, 20, 4),
                child: Text(
                  text,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: colors.onSurfaceVariant,
                  ),
                ),
              );
              final content = Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  heading('帖子主题'),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    child: Wrap(
                      spacing: 4,
                      runSpacing: 2,
                      children: [
                        _buildTopicChoice(
                          context,
                          key: 'forum-topic-all',
                          label: '全部',
                          icon: Icons.apps_rounded,
                          selected: _forumTopic == null,
                          onTap: () {
                            _applyForumTopic(null);
                            setSheetState(() {});
                          },
                        ),
                        for (final topic in _forumTopicFilters)
                          _buildTopicChoice(
                            context,
                            key: topic.key,
                            label: topic.label,
                            icon: topic.icon,
                            selected: _forumTopic?.key == topic.key,
                            onTap: () {
                              _applyForumTopic(topic);
                              setSheetState(() {});
                            },
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 2),
                  heading('排序'),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: PageSegmentedControl<String>(
                      key: const ValueKey('campus-forum-sort-segment'),
                      values: const {'latest': '最新', 'active': '热门'},
                      selected: _forumSort,
                      onChanged: (value) {
                        _changeForumSort(value);
                        setSheetState(() {});
                      },
                      trackColor: campusControlSurface,
                      selectedColor: campusInk,
                      selectedForegroundColor: campusOnInk,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: FilledButton(
                      key: const ValueKey('campus-forum-filter-done'),
                      onPressed: () => Navigator.of(sheetContext).pop(),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(44),
                      ),
                      child: const Text('完成'),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
              );
              return SafeArea(
                top: false,
                child: SingleChildScrollView(child: content),
              );
            },
          ),
        );
      },
    );
  }

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
          showCategory: true,
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
    final colors = Theme.of(context).colorScheme;
    final image = CampusAssetImage(
      assetId: board.coverAssetId,
      repository: repository,
      height: 64,
      width: 64,
      radius: 12,
      fallback: Icons.forum_outlined,
    );
    final title = Text(
      board.title,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(
        fontSize: 15,
        height: 1.25,
        fontWeight: FontWeight.w600,
        letterSpacing: -.1,
      ),
    );
    final description = Text(
      board.description.isEmpty ? '这个评分板块还没有介绍' : board.description,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        fontSize: 12,
        height: 1.35,
        color: colors.onSurfaceVariant,
      ),
    );
    final author = Row(
      children: [
        CampusAuthorAvatar(
          author: board.creator,
          radius: 8,
          repository: repository,
        ),
        const SizedBox(width: 5),
        Expanded(
          child: CampusAuthorName(
            author: board.creator,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 10, color: colors.onSurfaceVariant),
          ),
        ),
      ],
    );
    final statistics = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          '${board.itemCount}',
          style: const TextStyle(
            fontSize: 18,
            height: 1,
            fontWeight: FontWeight.w700,
            color: campusInk,
            fontFeatures: [FontFeature.tabularFigures()],
          ),
        ),
        const SizedBox(height: 1),
        Text(
          '个对象',
          style: TextStyle(fontSize: 9, color: colors.onSurfaceVariant),
        ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
          decoration: BoxDecoration(
            color: campusControlSurface,
            borderRadius: BorderRadius.circular(99),
          ),
          child: Text(
            '${board.ratingCount} 人次',
            style: TextStyle(
              fontSize: 9,
              height: 1.2,
              color: colors.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
    final largeText = MediaQuery.textScalerOf(context).scale(13) > 20;
    final content = largeText
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  image,
                  const SizedBox(width: 11),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [title, const SizedBox(height: 3), description],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // 大字体下把作者和统计信息换到第二行，避免右侧固定信息
              // 把标题区域挤成一条窄缝。
              Wrap(
                spacing: 12,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CampusAuthorAvatar(
                        author: board.creator,
                        radius: 8,
                        repository: repository,
                      ),
                      const SizedBox(width: 5),
                      CampusAuthorName(
                        author: board.creator,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 10,
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    '${board.itemCount} 个对象 · ${board.ratingCount} 人次',
                    style: TextStyle(
                      fontSize: 10,
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ],
          )
        : Row(
            children: [
              image,
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    title,
                    const SizedBox(height: 3),
                    description,
                    const SizedBox(height: 6),
                    author,
                  ],
                ),
              ),
              const SizedBox(width: 10),
              statistics,
            ],
          );
    return Container(
      key: ValueKey('rating-board-card-${board.id}'),
      margin: const EdgeInsets.only(bottom: 8),
      decoration: campusCardDecoration(radius: 16),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(padding: const EdgeInsets.all(10), child: content),
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
    final colors = theme.colorScheme;
    final wanted = listing.listingType == 'wanted';
    final image = listing.imageAssetId;
    final media = image != null || !wanted
        ? Stack(
            fit: StackFit.expand,
            children: [
              CampusAssetImage(
                assetId: image,
                repository: repository,
                fallback: Icons.shopping_bag_outlined,
                radius: 0,
              ),
              Positioned(
                left: 8,
                top: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: campusSurface.withValues(alpha: .92),
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: Text(
                    listingStatusLabel(listing),
                    style: const TextStyle(
                      fontSize: 9.5,
                      height: 1.2,
                      fontWeight: FontWeight.w600,
                      color: campusInk,
                    ),
                  ),
                ),
              ),
            ],
          )
        : Container(
            color: campusControlSurface,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.search_rounded, size: 20, color: campusMuted),
                const SizedBox(width: 6),
                Text(
                  '求购需求',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          );
    return Container(
      decoration: campusCardDecoration(radius: 16),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AspectRatio(aspectRatio: 4 / 3, child: media),
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 9, 10, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${wanted ? '预算 ' : ''}¥${campusFormatPrice(listing.priceCents)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 20,
                        height: 1.2,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -.45,
                        color: campusInk,
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      listing.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        height: 1.4,
                      ),
                    ),
                    if (wanted) ...[
                      const SizedBox(height: 4),
                      Text(
                        listing.description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11.5,
                          height: 1.45,
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ],
                    const SizedBox(height: 7),
                    Row(
                      children: [
                        Icon(
                          Icons.location_on_outlined,
                          size: 11,
                          color: colors.onSurfaceVariant,
                        ),
                        const SizedBox(width: 2),
                        Expanded(
                          child: Text(
                            '${campusLabel(listing.campus)} · ${campusFormatTime(listing.createdAt)}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 9.5,
                              height: 1.2,
                              color: colors.onSurfaceVariant,
                            ),
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
      ),
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
