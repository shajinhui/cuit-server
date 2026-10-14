import 'dart:typed_data';

import 'package:chengxin_youyou/features/campus/data/campus_repository.dart';
import 'package:chengxin_youyou/features/campus/models/campus_models.dart';

/// 只供页面测试与截图使用，所有数据均为虚构样例，不连接真实服务。
class CampusPreviewRepository implements CampusRepository {
  int assetLoads = 0;
  String lastBoardSort = 'popular';
  String lastListingType = 'sell';

  @override
  Future<CampusPageResult<CampusBoard>> listBoards({
    bool mine = false,
    String query = '',
    String sort = 'popular',
    String? cursor,
  }) async {
    lastBoardSort = sort;
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
  Future<Uint8List?> loadAsset(String assetId) async {
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

  @override
  Future<List<ForumCategory>> listForumCategories() async => const [
    ForumCategory(
      id: 'cat-general',
      name: '综合讨论',
      description: '校园大小事都可以聊。',
      sortOrder: 1,
    ),
    ForumCategory(
      id: 'cat-study',
      name: '学习交流',
      description: '课程、考试与学习资料。',
      sortOrder: 2,
    ),
  ];

  @override
  Future<CampusPageResult<ForumThread>> listForumThreads({
    bool mine = false,
    String? categoryId,
    String query = '',
    String sort = 'latest',
    String? cursor,
  }) async {
    lastForumSort = sort;
    final threads = [
      ForumThread(
        id: 'thread-1',
        categoryId: 'cat-general',
        categoryName: '综合讨论',
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
        isPinned: true,
        isLocked: false,
        status: 'normal',
        version: 1,
        createdAt: '2026-10-01T00:00:00Z',
        lastActivityAt: '2026-10-02T00:00:00Z',
        canEdit: true,
        canDelete: true,
      ),
      const ForumThread(
        id: 'thread-2',
        categoryId: 'cat-study',
        categoryName: '学习交流',
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

  /// 供测试断言：被删除的帖子与回复、最近一次编辑结果。
  final deletedThreadIds = <String>[];
  final deletedReplyIds = <String>[];
  String? lastUpdatedThreadId;
  String? lastUpdatedThreadTitle;
  final _threadOverrides = <String, ForumThread>{};

  @override
  Future<ForumThreadDetail> getForumThread(String threadId) async {
    final thread = (await listForumThreads()).items.firstWhere(
      (item) => item.id == threadId,
      orElse: () => throw const CampusRepositoryException('帖子不存在。'),
    );
    return ForumThreadDetail(thread: thread, liked: false, canReply: true);
  }

  @override
  Future<ForumThread> createForumThread({
    required String categoryId,
    required String title,
    required String body,
    List<String> imageAssetIds = const [],
    String? requestId,
  }) async => ForumThread(
    id: 'thread-new',
    categoryId: categoryId,
    categoryName: '综合讨论',
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
    isPinned: false,
    isLocked: false,
    status: 'normal',
    version: 1,
    createdAt: '2026-10-13T00:00:00Z',
    lastActivityAt: '2026-10-13T00:00:00Z',
    canEdit: true,
    canDelete: true,
  );

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
