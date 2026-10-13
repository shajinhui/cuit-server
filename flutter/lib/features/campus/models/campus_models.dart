import 'dart:math';

/// 分页接口的统一返回值。
class CampusPageResult<T> {
  const CampusPageResult({
    required this.items,
    required this.nextCursor,
    required this.hasMore,
  });

  final List<T> items;
  final String? nextCursor;
  final bool hasMore;

  factory CampusPageResult.fromJson(
    Map<String, dynamic> json,
    T Function(Map<String, dynamic>) parseItem,
  ) {
    final rawItems = json['items'];
    final items = rawItems is List
        ? rawItems.whereType<Map<String, dynamic>>().map(parseItem).toList()
        : <T>[];
    final cursor = json['next_cursor'];
    return CampusPageResult(
      items: items,
      nextCursor: cursor is String && cursor.isNotEmpty ? cursor : null,
      hasMore: json['has_more'] == true,
    );
  }
}

class CampusAuthor {
  const CampusAuthor({
    required this.id,
    required this.displayName,
    required this.avatarPreset,
  });

  final String id;
  final String displayName;
  final int avatarPreset;

  factory CampusAuthor.fromJson(Map<String, dynamic>? json) => CampusAuthor(
    id: _string(json?['id']),
    displayName: _string(json?['display_name'], fallback: '校园同学'),
    avatarPreset: _integer(json?['avatar_preset']),
  );
}

class CampusRatingSummary {
  const CampusRatingSummary({
    required this.count,
    required this.sum,
    required this.score,
    required this.distribution,
  });

  final int count;
  final int sum;
  final double? score;
  final Map<int, int> distribution;

  factory CampusRatingSummary.fromJson(Map<String, dynamic>? json) {
    final rawDistribution = _map(json?['distribution']);
    final distribution = <int, int>{};
    for (var stars = 1; stars <= 5; stars++) {
      distribution[stars] = _integer(rawDistribution?['$stars']);
    }
    final score = json?['score'];
    return CampusRatingSummary(
      count: _integer(json?['count']),
      sum: _integer(json?['sum']),
      score: score is num ? score.toDouble() : null,
      distribution: distribution,
    );
  }
}

class CampusUserRating {
  const CampusUserRating({
    required this.stars,
    required this.version,
    required this.status,
  });

  final int stars;
  final int version;
  final String status;

  factory CampusUserRating.fromJson(Map<String, dynamic>? json) =>
      CampusUserRating(
        stars: _integer(json?['stars']),
        version: _integer(json?['version']),
        status: _string(json?['status']),
      );
}

class CampusBoard {
  const CampusBoard({
    required this.id,
    required this.title,
    required this.description,
    required this.coverAssetId,
    required this.creator,
    required this.itemCount,
    required this.ratingCount,
    required this.version,
    required this.createdAt,
    required this.canEdit,
  });

  final String id;
  final String title;
  final String description;
  final String? coverAssetId;
  final CampusAuthor creator;
  final int itemCount;
  final int ratingCount;
  final int version;
  final String createdAt;
  final bool canEdit;

  String get creatorName => creator.displayName;
  int get avatarPreset => creator.avatarPreset;

  factory CampusBoard.fromJson(Map<String, dynamic> json) {
    final cover = _map(json['cover_asset']);
    final capabilities = _map(json['capabilities']);
    return CampusBoard(
      id: _string(json['id']),
      title: _string(json['title']),
      description: _string(json['description']),
      coverAssetId: _optionalString(cover?['id']),
      creator: CampusAuthor.fromJson(_map(json['creator'])),
      itemCount: _integer(json['item_count']),
      ratingCount: _integer(json['rating_count']),
      version: _integer(json['version']),
      createdAt: _string(json['created_at']),
      canEdit: capabilities?['can_edit'] == true,
    );
  }
}

class CampusRatingItem {
  const CampusRatingItem({
    required this.id,
    required this.boardId,
    required this.name,
    required this.description,
    required this.imageAssetId,
    required this.creator,
    required this.rating,
    required this.version,
    required this.createdAt,
    required this.canEdit,
  });

  final String id;
  final String boardId;
  final String name;
  final String description;
  final String? imageAssetId;
  final CampusAuthor creator;
  final CampusRatingSummary rating;
  final int version;
  final String createdAt;
  final bool canEdit;

  factory CampusRatingItem.fromJson(Map<String, dynamic> json) {
    final image = _map(json['image_asset']);
    final capabilities = _map(json['capabilities']);
    return CampusRatingItem(
      id: _string(json['id']),
      boardId: _string(
        json['board_id'],
        fallback: _string(_map(json['board'])?['id']),
      ),
      name: _string(json['name']),
      description: _string(json['description']),
      imageAssetId: _optionalString(image?['id']),
      creator: CampusAuthor.fromJson(_map(json['creator'])),
      rating: CampusRatingSummary.fromJson(_map(json['rating'])),
      version: _integer(json['version']),
      createdAt: _string(json['created_at']),
      canEdit: capabilities?['can_edit'] == true,
    );
  }
}

class CampusRatingItemDetail {
  const CampusRatingItemDetail({
    required this.item,
    required this.boardTitle,
    required this.myRating,
    required this.commentCount,
    required this.canRate,
    required this.canComment,
  });

  final CampusRatingItem item;
  final String boardTitle;
  final CampusUserRating? myRating;
  final int commentCount;
  final bool canRate;
  final bool canComment;

  factory CampusRatingItemDetail.fromJson(Map<String, dynamic> json) {
    final board = _map(json['board']);
    final myRating = _map(json['my_rating']);
    final capabilities = _map(json['capabilities']);
    return CampusRatingItemDetail(
      item: CampusRatingItem.fromJson(json),
      boardTitle: _string(board?['title']),
      myRating: myRating == null ? null : CampusUserRating.fromJson(myRating),
      commentCount: _integer(json['comment_count']),
      canRate: capabilities?['can_rate'] != false,
      canComment: capabilities?['can_comment'] != false,
    );
  }
}

class CampusRatingMutation {
  const CampusRatingMutation({required this.rating, required this.myRating});
  final CampusRatingSummary rating;
  final CampusUserRating? myRating;
}

class CampusComment {
  const CampusComment({
    required this.id,
    required this.itemId,
    required this.parentId,
    required this.author,
    required this.body,
    required this.starsSnapshot,
    required this.replyCount,
    required this.version,
    required this.createdAt,
    required this.canDelete,
  });

  final String id;
  final String itemId;
  final String? parentId;
  final CampusAuthor author;
  final String body;
  final int? starsSnapshot;
  final int replyCount;
  final int version;
  final String createdAt;
  final bool canDelete;

  factory CampusComment.fromJson(Map<String, dynamic> json) {
    final capabilities = _map(json['capabilities']);
    final stars = json['stars_snapshot'];
    return CampusComment(
      id: _string(json['id']),
      itemId: _string(json['item_id']),
      parentId: _optionalString(json['parent_id']),
      author: CampusAuthor.fromJson(_map(json['author'])),
      body: _string(json['body']),
      starsSnapshot: stars is num ? stars.toInt() : null,
      replyCount: _integer(json['reply_count']),
      version: _integer(json['version']),
      createdAt: _string(json['created_at']),
      canDelete: capabilities?['can_delete'] == true,
    );
  }
}

/// “我的内容”接口按类别返回不同对象，在页面层保留共同字段并按类别解析。
class CampusMineEntry {
  const CampusMineEntry({this.board, this.item, this.comment});
  final CampusBoard? board;
  final CampusRatingItem? item;
  final CampusComment? comment;

  factory CampusMineEntry.fromJson(
    Map<String, dynamic> json, {
    required String kind,
  }) => switch (kind) {
    'boards' => CampusMineEntry(board: CampusBoard.fromJson(json)),
    'comments' => CampusMineEntry(comment: CampusComment.fromJson(json)),
    _ => CampusMineEntry(item: CampusRatingItem.fromJson(json)),
  };
}

class CampusListing {
  const CampusListing({
    required this.id,
    required this.title,
    required this.description,
    required this.priceCents,
    required this.campus,
    required this.imageAssetId,
    required this.seller,
    required this.listingType,
    required this.status,
    required this.version,
    required this.createdAt,
    required this.isMine,
  });

  final String id;
  final String title;
  final String description;
  final int priceCents;
  final String campus;
  final String? imageAssetId;
  final CampusAuthor seller;
  final String listingType;
  final String status;
  final int version;
  final String createdAt;
  final bool isMine;

  String get sellerName => seller.displayName;

  factory CampusListing.fromJson(Map<String, dynamic> json) {
    final seller = _map(json['seller']);
    final image = _map(json['image_asset']);
    return CampusListing(
      id: _string(json['id']),
      title: _string(json['title']),
      description: _string(json['description']),
      priceCents: _integer(json['price_cents']),
      campus: _string(json['campus'], fallback: 'airport'),
      imageAssetId: _optionalString(image?['id']),
      seller: CampusAuthor.fromJson(seller),
      listingType: _string(json['listing_type'], fallback: 'sell'),
      status: _string(json['status'], fallback: 'on_sale'),
      version: _integer(json['version']),
      createdAt: _string(json['created_at']),
      isMine: json['is_mine'] == true,
    );
  }
}

class CampusContact {
  const CampusContact({required this.type, required this.value});

  final String type;
  final String value;
}

/// 请求重试使用随机 UUID，避免网络超时后重复创建内容。
String createCampusRequestId() {
  final bytes = List<int>.generate(16, (_) => Random.secure().nextInt(256));
  bytes[6] = (bytes[6] & 0x0f) | 0x40;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;
  final hex = bytes
      .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
      .join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
      '${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
}

/// 论坛版块。数量固定且较少，由后端返回，客户端不做本地缓存。
class ForumCategory {
  const ForumCategory({
    required this.id,
    required this.name,
    required this.description,
    required this.sortOrder,
  });

  final String id;
  final String name;
  final String description;
  final int sortOrder;

  factory ForumCategory.fromJson(Map<String, dynamic> json) => ForumCategory(
    id: _string(json['id']),
    name: _string(json['name']),
    description: _string(json['description']),
    sortOrder: _integer(json['sort_order']),
  );
}

/// 论坛帖子。列表与详情共用同一结构，字段对齐后端 snake_case 契约。
class ForumThread {
  const ForumThread({
    required this.id,
    required this.categoryId,
    required this.categoryName,
    required this.title,
    required this.body,
    required this.author,
    required this.imageAssetIds,
    required this.replyCount,
    required this.likeCount,
    required this.isPinned,
    required this.isLocked,
    required this.status,
    required this.version,
    required this.createdAt,
    required this.lastActivityAt,
    required this.canEdit,
    required this.canDelete,
  });

  final String id;
  final String categoryId;
  final String categoryName;
  final String title;
  final String body;
  final CampusAuthor author;

  /// 帖子附图资产 id，通过受保护的资产接口加载，随会话清理。
  final List<String> imageAssetIds;
  final int replyCount;
  final int likeCount;
  final bool isPinned;
  final bool isLocked;
  final String status;
  final int version;
  final String createdAt;
  final String lastActivityAt;
  final bool canEdit;
  final bool canDelete;

  bool get isHidden => status != 'normal';

  factory ForumThread.fromJson(Map<String, dynamic> json) {
    final category = _map(json['category']);
    final capabilities = _map(json['capabilities']);
    return ForumThread(
      id: _string(json['id']),
      categoryId: _string(
        json['category_id'],
        fallback: _string(category?['id']),
      ),
      categoryName: _string(category?['name']),
      title: _string(json['title']),
      body: _string(json['body']),
      author: CampusAuthor.fromJson(_map(json['author'])),
      imageAssetIds: _stringList(json['image_asset_ids']),
      replyCount: _integer(json['reply_count']),
      likeCount: _integer(json['like_count']),
      isPinned: json['is_pinned'] == true,
      isLocked: json['is_locked'] == true,
      status: _string(json['status'], fallback: 'normal'),
      version: _integer(json['version']),
      createdAt: _string(json['created_at']),
      lastActivityAt: _string(
        json['last_activity_at'],
        fallback: _string(json['created_at']),
      ),
      canEdit: capabilities?['can_edit'] == true,
      canDelete: capabilities?['can_delete'] == true,
    );
  }
}

/// 帖子详情附带当前用户状态；帖子和回复使用同一套独立校园凭证。
class ForumThreadDetail {
  const ForumThreadDetail({
    required this.thread,
    required this.liked,
    required this.canReply,
  });

  final ForumThread thread;
  final bool liked;
  final bool canReply;

  factory ForumThreadDetail.fromJson(Map<String, dynamic> json) {
    final capabilities = _map(json['capabilities']);
    return ForumThreadDetail(
      thread: ForumThread.fromJson(json),
      liked: json['my_like'] == true,
      canReply: capabilities?['can_reply'] != false,
    );
  }
}

/// 帖子回复。parentId 为空表示主楼回复，非空表示楼中楼第二层。
class ForumReply {
  const ForumReply({
    required this.id,
    required this.threadId,
    required this.parentId,
    required this.author,
    required this.body,
    required this.likeCount,
    required this.liked,
    required this.replyCount,
    required this.version,
    required this.createdAt,
    required this.canDelete,
  });

  final String id;
  final String threadId;
  final String? parentId;
  final CampusAuthor author;
  final String body;
  final int likeCount;

  /// 当前用户是否已点赞，用于回显点赞按钮状态。
  final bool liked;
  final int replyCount;
  final int version;
  final String createdAt;
  final bool canDelete;

  factory ForumReply.fromJson(Map<String, dynamic> json) {
    final capabilities = _map(json['capabilities']);
    return ForumReply(
      id: _string(json['id']),
      threadId: _string(json['thread_id']),
      parentId: _optionalString(json['parent_id']),
      author: CampusAuthor.fromJson(_map(json['author'])),
      body: _string(json['body']),
      likeCount: _integer(json['like_count']),
      liked: json['my_like'] == true,
      replyCount: _integer(json['reply_count']),
      version: _integer(json['version']),
      createdAt: _string(json['created_at']),
      canDelete: capabilities?['can_delete'] == true,
    );
  }
}

/// 点赞或取消点赞后的服务端最新状态，客户端据此覆盖本地计数。
class ForumThreadLike {
  const ForumThreadLike({required this.liked, required this.likeCount});

  final bool liked;
  final int likeCount;

  factory ForumThreadLike.fromJson(Map<String, dynamic> json) =>
      ForumThreadLike(
        liked: json['liked'] == true,
        likeCount: _integer(json['like_count']),
      );
}

Map<String, dynamic>? _map(Object? value) =>
    value is Map<String, dynamic> ? value : null;

String _string(Object? value, {String fallback = ''}) =>
    value is String ? value : fallback;

String? _optionalString(Object? value) =>
    value is String && value.isNotEmpty ? value : null;

List<String> _stringList(Object? value) => value is List
    ? value.whereType<String>().where((item) => item.isNotEmpty).toList()
    : const [];

int _integer(Object? value) => value is num ? value.toInt() : 0;
