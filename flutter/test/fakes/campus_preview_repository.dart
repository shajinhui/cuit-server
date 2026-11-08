import 'dart:typed_data';

import 'package:chengxin_youyou/features/campus/data/campus_repository.dart';
import 'package:chengxin_youyou/features/campus/models/campus_models.dart';

/// 只供页面测试与截图使用，所有数据均为虚构样例，不连接真实服务。
class CampusPreviewRepository implements CampusRepository {
  int assetLoads = 0;
  String lastBoardSort = 'popular';
  String lastBoardQuery = '';
  String lastListingType = 'sell';
  String lastListingQuery = '';

  @override
  Future<CampusPageResult<CampusBoard>> listBoards({
    bool mine = false,
    String query = '',
    String sort = 'popular',
    String? cursor,
  }) async {
    lastBoardSort = sort;
    lastBoardQuery = query;
    return const CampusPageResult(
      items: [
        CampusBoard(
          id: 'board-1',
          title: '食堂推荐',
          description: '一起推荐学校周边好吃的。',
          coverAssetId: null,
          creator: CampusAuthor(
            id: 'user-1',
            displayName: '小高',
            avatarPreset: 0,
          ),
          itemCount: 5,
          ratingCount: 20,
          version: 1,
          createdAt: '2026-10-01T00:00:00Z',
          canEdit: false,
        ),
      ],
      nextCursor: null,
      hasMore: false,
    );
  }

  @override
  Future<CampusPageResult<CampusListing>> listListings({
    bool mine = false,
    String query = '',
    String type = 'sell',
    String? cursor,
  }) async {
    lastListingType = type;
    lastListingQuery = query;
    return CampusPageResult(
      items: [
        CampusListing(
          id: 'listing-1',
          title: type == 'wanted' ? '求购校园卡' : '校园二手车',
          description: '状况良好。',
          priceCents: 10000,
          campus: 'airport',
          imageAssetId: null,
          seller: const CampusAuthor(
            id: 'user-1',
            displayName: '小高',
            avatarPreset: 0,
          ),
          listingType: type,
          status: 'on_sale',
          version: 1,
          createdAt: '2026-10-01T00:00:00Z',
          isMine: mine,
        ),
      ],
      nextCursor: null,
      hasMore: false,
    );
  }

  @override
  Future<CampusBoard> getBoard(String boardId) async =>
      (await listBoards()).items.first;

  @override
  Future<CampusPageResult<CampusRatingItem>> listRatingItems({
    required String boardId,
    String query = '',
    String sort = 'popular',
    String? cursor,
  }) async => const CampusPageResult(
    items: [
      CampusRatingItem(
        id: 'rating-item-1',
        boardId: 'board-1',
        name: '麻辣烫窗口',
        description: '一食堂一楼。',
        imageAssetId: null,
        creator: CampusAuthor(id: 'user-1', displayName: '小高', avatarPreset: 0),
        rating: CampusRatingSummary(
          count: 3,
          sum: 12,
          score: 4,
          distribution: {1: 0, 2: 0, 3: 1, 4: 1, 5: 1},
        ),
        version: 1,
        createdAt: '2026-10-01T00:00:00Z',
        canEdit: false,
      ),
    ],
    nextCursor: null,
    hasMore: false,
  );

  @override
  Future<CampusListing> getListing(String itemId) async =>
      (await listListings()).items.first;

  @override
  Future<Uint8List?> loadAsset(
    String assetId, {
    bool refresh = false,
    bool thumbnail = false,
  }) async {
    assetLoads++;
    return null;
  }

  @override
  Future<CampusRatingItemDetail> getRatingItem(String itemId) async =>
      CampusRatingItemDetail(
        item: (await listRatingItems(boardId: 'board-1')).items.first,
        boardTitle: '食堂推荐',
        myRating: null,
        commentCount: 1,
        canRate: true,
        canComment: true,
      );

  @override
  Future<CampusPageResult<CampusComment>> listComments({
    required String itemId,
    String sort = 'newest',
    String? cursor,
  }) async => const CampusPageResult(
    items: [
      CampusComment(
        id: 'comment-1',
        itemId: 'rating-item-1',
        parentId: null,
        author: CampusAuthor(
          id: 'user-2',
          displayName: '体验同学',
          avatarPreset: 0,
        ),
        body: '味道不错，午饭时间记得提前去。',
        starsSnapshot: 4,
        replyCount: 0,
        version: 1,
        createdAt: '2026-10-01T00:00:00Z',
        canDelete: false,
      ),
    ],
    nextCursor: null,
    hasMore: false,
  );

  @override
  Future<CampusPageResult<CampusMineEntry>> listMyRatingContent({
    required String kind,
    String? cursor,
  }) async => CampusPageResult(
    items: [
      switch (kind) {
        'boards' => CampusMineEntry(board: await getBoard('board-1')),
        'comments' => CampusMineEntry(
          comment: (await listComments(itemId: 'rating-item-1')).items.first,
        ),
        _ => CampusMineEntry(
          item: (await listRatingItems(boardId: 'board-1')).items.first,
        ),
      },
    ],
    nextCursor: null,
    hasMore: false,
  );

  final forumCategories = <ForumCategory>[
    const ForumCategory(
      id: 'cat-general',
      name: '日常',
      description: '校园生活、见闻和日常闲聊。',
      sortOrder: 1,
    ),
    const ForumCategory(
      id: 'cat-study',
      name: '学习',
      description: '课程、考试、资料与学习经验。',
      sortOrder: 2,
    ),
    const ForumCategory(
      id: 'cat-mutual',
      name: '互助',
      description: '校内互帮互助和资源交换。',
      sortOrder: 3,
    ),
    const ForumCategory(
      id: 'cat-lost',
      name: '失物',
      description: '失物招领与寻物启事。',
      sortOrder: 4,
    ),
    const ForumCategory(
      id: 'cat-partner',
      name: '搭子',
      description: '自习、运动、吃饭和出行搭子。',
      sortOrder: 5,
    ),
    const ForumCategory(
      id: 'cat-activity',
      name: '社团活动',
      description: '社团、组织、讲座与校园活动。',
      sortOrder: 6,
    ),
    const ForumCategory(
      id: 'cat-treehole',
      name: '树洞',
      description: '匿名树洞与心情记录。',
      sortOrder: 7,
    ),
  ];
  List<String> forumHomeCategoryIds = [];
  int _createdCategoryCount = 0;

  @override
  Future<List<ForumCategory>> listForumCategories() async =>
      List.of(forumCategories);

  @override
  Future<ForumCategory> createForumCategory({
    required String name,
    required String description,
  }) async {
    final category = ForumCategory(
      id: 'cat-custom-${++_createdCategoryCount}',
      name: name,
      description: description,
      sortOrder: forumCategories.length + 1,
      isOfficial: false,
      isMine: true,
    );
    forumCategories.add(category);
    return category;
  }

  @override
  Future<List<String>> getForumHomeCategories() async =>
      List.of(forumHomeCategoryIds);

  @override
  Future<List<String>> setForumHomeCategories(List<String> categoryIds) async {
    final available = forumCategories.map((category) => category.id).toSet();
    forumHomeCategoryIds = categoryIds
        .where(available.contains)
        .toSet()
        .toList();
    return List.of(forumHomeCategoryIds);
  }

  @override
  Future<CampusPageResult<ForumThread>> listForumThreads({
    bool mine = false,
    String? categoryId,
    String query = '',
    String sort = 'latest',
    String? cursor,
  }) async {
    lastForumSort = sort;
    lastForumQuery = query;
    final threads = [
      ForumThread(
        id: 'thread-1',
        categoryId: 'cat-general',
        categoryName: '日常',
        title: '图书馆晚上能不能延长闭馆时间',
        body: '期末复习人很多，十点闭馆有点早，大家觉得呢？',
        author: const CampusAuthor(
          id: 'user-1',
          displayName: '小高',
          avatarPreset: 0,
        ),
        imageAssetIds: [],
        replyCount: deletedReplyIds.contains('reply-1')
            ? 0
            : 2 - deletedReplyIds.toSet().length,
        likeCount: 5,
        reactions: forumReactionState('thread-1').reactions,
        myReaction: forumReactionState('thread-1').myReaction,
        isPinned: true,
        isLocked: false,
        status: 'normal',
        version: 1,
        createdAt: '2026-10-01T00:00:00Z',
        lastActivityAt: '2026-10-02T00:00:00Z',
        canEdit: true,
        canDelete: true,
      ),
      ForumThread(
        id: 'thread-2',
        categoryId: 'cat-study',
        categoryName: '学习',
        title: '操作系统实验报告模板分享',
        body: '整理了一份实验报告模板，需要的同学自取。',
        author: CampusAuthor(
          id: 'user-2',
          displayName: '体验同学',
          avatarPreset: 0,
        ),
        imageAssetIds: ['asset-template-1'],
        replyCount: 0,
        likeCount: 12,
        reactions: forumReactionState('thread-2').reactions,
        myReaction: forumReactionState('thread-2').myReaction,
        isPinned: false,
        isLocked: false,
        status: 'normal',
        version: 1,
        createdAt: '2026-09-28T00:00:00Z',
        lastActivityAt: '2026-09-28T00:00:00Z',
        canEdit: false,
        canDelete: false,
      ),
    ];
    final filtered = threads
        .where(
          (thread) =>
              (categoryId == null || thread.categoryId == categoryId) &&
              (query.isEmpty ||
                  thread.title.contains(query) ||
                  thread.body.contains(query)),
        )
        .map((thread) => _threadOverrides[thread.id] ?? thread)
        .where((thread) => !deletedThreadIds.contains(thread.id))
        .toList();
    return CampusPageResult(items: filtered, nextCursor: null, hasMore: false);
  }

  String lastForumSort = 'latest';
  String lastForumQuery = '';

  /// 按帖子模拟服务端表情聚合，供界面测试观察回显与取消。
  final _reactionStates = <String, ForumThreadReaction>{};

  /// 新建帖子与投票的服务端副本，供详情页重新读取。
  final _createdThreads = <String, ForumThread>{};
  final _polls = <String, ForumPoll>{};
  ForumThread? lastCreatedThread;

  /// 测试预置：模拟其他用户已经投出的票数。
  void seedForumPoll(String threadId, ForumPoll poll) {
    _polls[threadId] = poll;
  }

  ForumThreadReaction forumReactionState(String threadId) =>
      _reactionStates[threadId] ??
      const ForumThreadReaction(reactions: [], myReaction: null);

  @override
  Future<ForumThreadReaction> setForumThreadReaction({
    required String threadId,
    required String? emoji,
  }) async {
    final current = forumReactionState(threadId);
    final counts = {
      for (final reaction in current.reactions) reaction.emoji: reaction.count,
    };
    final previous = current.myReaction;
    if (previous != null) {
      final remaining = (counts[previous] ?? 1) - 1;
      if (remaining <= 0) {
        counts.remove(previous);
      } else {
        counts[previous] = remaining;
      }
    }
    if (emoji != null) counts[emoji] = (counts[emoji] ?? 0) + 1;
    final reactions =
        [
          for (final entry in counts.entries)
            if (entry.value > 0)
              ForumReaction(emoji: entry.key, count: entry.value),
        ]..sort((left, right) {
          final byCount = right.count.compareTo(left.count);
          return byCount != 0 ? byCount : left.emoji.compareTo(right.emoji);
        });
    final state = ForumThreadReaction(reactions: reactions, myReaction: emoji);
    _reactionStates[threadId] = state;
    return state;
  }

  /// 测试预置：模拟其他用户已经留下的表情聚合。
  void seedForumReactions(
    String threadId,
    Map<String, int> counts, {
    String? mine,
  }) {
    final reactions =
        [
          for (final entry in counts.entries)
            if (entry.value > 0)
              ForumReaction(emoji: entry.key, count: entry.value),
        ]..sort((left, right) {
          final byCount = right.count.compareTo(left.count);
          return byCount != 0 ? byCount : left.emoji.compareTo(right.emoji);
        });
    _reactionStates[threadId] = ForumThreadReaction(
      reactions: reactions,
      myReaction: mine,
    );
  }

  /// 供测试断言：被删除的帖子与回复、最近一次编辑结果。
  final deletedThreadIds = <String>[];
  final deletedReplyIds = <String>[];
  String? lastUpdatedThreadId;
  String? lastUpdatedThreadTitle;
  final _threadOverrides = <String, ForumThread>{};

  @override
  Future<ForumThreadDetail> getForumThread(String threadId) async {
    ForumThread? thread;
    for (final item in (await listForumThreads()).items) {
      if (item.id == threadId) {
        thread = item;
        break;
      }
    }
    thread ??= _createdThreads[threadId];
    if (thread == null) {
      throw const CampusRepositoryException('帖子不存在。');
    }
    return ForumThreadDetail(thread: thread, liked: false, canReply: true);
  }

  @override
  Future<ForumThread> createForumThread({
    required String categoryId,
    required String title,
    required String body,
    List<String> imageAssetIds = const [],
    ForumPollDraft? poll,
    String? requestId,
  }) async {
    final structured = poll == null
        ? null
        : ForumPoll(
            question: poll.question,
            totalVotes: 0,
            myOptionId: null,
            options: [
              for (var index = 0; index < poll.options.length; index++)
                ForumPollOption(
                  id: 'poll-option-${index + 1}',
                  label: poll.options[index],
                  count: 0,
                  percent: 0,
                ),
            ],
          );
    final thread = ForumThread(
      id: 'thread-new',
      categoryId: categoryId,
      categoryName: forumCategories
          .firstWhere(
            (category) => category.id == categoryId,
            orElse: () => const ForumCategory(
              id: '',
              name: '日常',
              description: '',
              sortOrder: 0,
            ),
          )
          .name,
      title: title,
      body: body,
      author: const CampusAuthor(
        id: 'user-1',
        displayName: '小高',
        avatarPreset: 0,
      ),
      imageAssetIds: imageAssetIds,
      replyCount: 0,
      likeCount: 0,
      poll: structured,
      isPinned: false,
      isLocked: false,
      status: 'normal',
      version: 1,
      createdAt: '2026-10-13T00:00:00Z',
      lastActivityAt: '2026-10-13T00:00:00Z',
      canEdit: true,
      canDelete: true,
    );
    _createdThreads[thread.id] = thread;
    lastCreatedThread = thread;
    if (structured != null) _polls[thread.id] = structured;
    return thread;
  }

  @override
  Future<ForumPoll> voteForumPoll({
    required String threadId,
    required String optionId,
  }) async {
    final poll = _polls[threadId];
    if (poll == null) throw const CampusRepositoryException('投票不存在。');
    final counts = {for (final option in poll.options) option.id: option.count};
    if (!counts.containsKey(optionId)) {
      throw const CampusRepositoryException('投票选项无效。');
    }
    final previous = poll.myOptionId;
    if (previous != null) {
      counts[previous] = (counts[previous] ?? 1) - 1;
    }
    counts[optionId] = (counts[optionId] ?? 0) + 1;
    final total = counts.values.fold<int>(
      0,
      (sum, count) => sum + (count > 0 ? count : 0),
    );
    final updated = ForumPoll(
      question: poll.question,
      totalVotes: total,
      myOptionId: optionId,
      options: [
        for (final option in poll.options)
          ForumPollOption(
            id: option.id,
            label: option.label,
            count: (counts[option.id] ?? 0) < 0 ? 0 : counts[option.id] ?? 0,
            percent: total == 0
                ? 0
                : ((counts[option.id] ?? 0) / total * 1000).round() / 10,
          ),
      ],
    );
    _polls[threadId] = updated;
    return updated;
  }

  @override
  Future<ForumThread> updateForumThread({
    required String threadId,
    required String categoryId,
    required String title,
    required String body,
    required List<String> imageAssetIds,
    required int expectedVersion,
  }) async {
    lastUpdatedThreadId = threadId;
    lastUpdatedThreadTitle = title;
    final original = (await listForumThreads()).items.firstWhere(
      (item) => item.id == threadId,
      orElse: () => throw const CampusRepositoryException('帖子不存在。'),
    );
    final updated = ForumThread(
      id: original.id,
      categoryId: categoryId,
      categoryName: original.categoryName,
      title: title,
      body: body,
      author: original.author,
      imageAssetIds: imageAssetIds,
      replyCount: original.replyCount,
      likeCount: original.likeCount,
      isPinned: original.isPinned,
      isLocked: original.isLocked,
      status: original.status,
      version: expectedVersion + 1,
      createdAt: original.createdAt,
      lastActivityAt: original.lastActivityAt,
      canEdit: original.canEdit,
      canDelete: original.canDelete,
    );
    _threadOverrides[original.id] = updated;
    return updated;
  }

  @override
  Future<void> deleteForumThread({
    required String threadId,
    required int expectedVersion,
  }) async {
    deletedThreadIds.add(threadId);
  }

  @override
  Future<void> deleteForumReply({
    required String replyId,
    required int expectedVersion,
  }) async {
    deletedReplyIds.add(replyId);
  }

  @override
  Future<CampusPageResult<ForumReply>> listForumReplies({
    required String threadId,
    String? cursor,
  }) async => CampusPageResult(
    items: [
      if (!deletedReplyIds.contains('reply-1'))
        const ForumReply(
          id: 'reply-1',
          threadId: 'thread-1',
          parentId: null,
          author: CampusAuthor(
            id: 'user-2',
            displayName: '体验同学',
            avatarPreset: 0,
          ),
          body: '支持，上次十点被赶出来书还没看完。',
          likeCount: 3,
          liked: false,
          replyCount: 1,
          version: 1,
          createdAt: '2026-10-01T01:00:00Z',
          canDelete: true,
        ),
    ],
    nextCursor: null,
    hasMore: false,
  );

  @override
  Future<CampusPageResult<ForumReply>> listForumReplyChildren({
    required String replyId,
    String? cursor,
  }) async => const CampusPageResult(
    items: [
      ForumReply(
        id: 'reply-1-1',
        threadId: 'thread-1',
        parentId: 'reply-1',
        author: CampusAuthor(id: 'user-1', displayName: '小高', avatarPreset: 0),
        body: '我也是，准备去反馈一下。',
        likeCount: 1,
        liked: false,
        replyCount: 0,
        version: 1,
        createdAt: '2026-10-01T02:00:00Z',
        canDelete: false,
      ),
    ],
    nextCursor: null,
    hasMore: false,
  );

  @override
  Future<ForumReply> createForumReply({
    required String threadId,
    required String body,
    String? parentId,
    String? requestId,
  }) async => ForumReply(
    id: 'reply-new',
    threadId: threadId,
    parentId: parentId,
    author: const CampusAuthor(
      id: 'user-1',
      displayName: '小高',
      avatarPreset: 0,
    ),
    body: body,
    likeCount: 0,
    liked: false,
    replyCount: 0,
    version: 1,
    createdAt: '2026-10-13T00:00:00Z',
    canDelete: true,
  );

  @override
  Future<ForumThreadLike> toggleForumThreadLike({
    required String threadId,
    required bool like,
  }) async => ForumThreadLike(liked: like, likeCount: like ? 6 : 5);

  @override
  Future<ForumThreadLike> toggleForumReplyLike({
    required String replyId,
    required bool like,
  }) async => ForumThreadLike(liked: like, likeCount: like ? 4 : 3);

  @override
  void clearSession() {}

  @override
  void dispose() {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
