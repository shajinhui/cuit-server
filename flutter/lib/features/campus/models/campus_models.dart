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
    this.avatarAssetId,
    this.profileVersion = 1,
  });

  final String id;
  final String displayName;
  final int avatarPreset;
  final String? avatarAssetId;
  final int profileVersion;

  factory CampusAuthor.fromJson(Map<String, dynamic>? json) => CampusAuthor(
    id: _string(json?['id']),
    displayName: _string(json?['display_name'], fallback: '校园同学'),
    avatarPreset: _integer(json?['avatar_preset']),
    avatarAssetId: json?['avatar_asset_id'] as String?,
    profileVersion: json?['profile_version'] is num
        ? (json!['profile_version'] as num).toInt()
        : 1,
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

/// 论坛版块。官方版块由后端预置，用户也可以创建自己的版块。
///
/// 用户版块默认「未列出」：知道版块 ID 的登录用户可以阅读，但不会出现在
/// 公共目录、首页默认和热门里；加入后才能发帖。管理权限只由服务端的
/// `capabilities` 决定，客户端不根据 `isMine` 推断。
class ForumCategory {
  const ForumCategory({
    required this.id,
    required this.name,
    required this.description,
    required this.sortOrder,
    this.isOfficial = true,
    this.isMine = false,
    this.isMember = false,
    this.isModerator = false,
    this.visibility = 'public',
    this.status = 'active',
    this.rules = '',
    this.memberCount = 0,
    this.version = 1,
    this.createdAt,
    this.canManage = false,
    this.canPost = true,
    this.canJoin = false,
    this.canReviewReports = false,
    this.moderators = const [],
  });

  final String id;
  final String name;
  final String description;
  final int sortOrder;

  /// 官方预置版块排在用户版块之前，并带有稳定的初始排序。
  final bool isOfficial;

  /// 当前登录用户创建的版块。
  final bool isMine;

  /// 当前登录用户是否已加入该用户版块。
  final bool isMember;

  /// 当前登录用户是否是版主（含 owner）。
  final bool isModerator;

  /// `unlisted` 表示不进入公共目录；官方版块始终为 `public`。
  final String visibility;

  /// `archived` 为只读状态，由管理员恢复。
  final String status;
  final String rules;
  final int memberCount;
  final int version;
  final String? createdAt;

  final bool canManage;
  final bool canPost;
  final bool canJoin;
  final bool canReviewReports;

  /// 仅在版块详情接口返回；列表接口为空。
  final List<ForumCategoryModerator> moderators;

  bool get isUnlisted => visibility != 'public';
  bool get isArchived => status == 'archived';

  ForumCategory copyWith({
    String? name,
    String? description,
    bool? isMember,
    bool? isModerator,
    String? visibility,
    String? status,
    String? rules,
    int? memberCount,
    int? version,
    bool? canManage,
    bool? canPost,
    bool? canJoin,
    bool? canReviewReports,
    List<ForumCategoryModerator>? moderators,
  }) => ForumCategory(
    id: id,
    name: name ?? this.name,
    description: description ?? this.description,
    sortOrder: sortOrder,
    isOfficial: isOfficial,
    isMine: isMine,
    isMember: isMember ?? this.isMember,
    isModerator: isModerator ?? this.isModerator,
    visibility: visibility ?? this.visibility,
    status: status ?? this.status,
    rules: rules ?? this.rules,
    memberCount: memberCount ?? this.memberCount,
    version: version ?? this.version,
    createdAt: createdAt,
    canManage: canManage ?? this.canManage,
    canPost: canPost ?? this.canPost,
    canJoin: canJoin ?? this.canJoin,
    canReviewReports: canReviewReports ?? this.canReviewReports,
    moderators: moderators ?? this.moderators,
  );

  factory ForumCategory.fromJson(Map<String, dynamic> json) {
    final capabilities = _map(json['capabilities']);
    final official =
        json['is_official'] == true ||
        (json['is_official'] is num && (json['is_official'] as num) != 0);
    final member = json['is_member'] == true;
    final moderator = json['is_moderator'] == true;
    final rawModerators = json['moderators'];
    return ForumCategory(
      id: _string(json['id']),
      name: _string(json['name']),
      description: _string(json['description']),
      sortOrder: _integer(json['sort_order']),
      isOfficial: official,
      isMine: json['is_mine'] == true,
      isMember: member,
      isModerator: moderator,
      visibility: _string(json['visibility'], fallback: 'public'),
      status: _string(json['status'], fallback: 'active'),
      rules: _string(json['rules']),
      memberCount: _integer(json['member_count']),
      version: _integer(json['version'], fallback: 1),
      createdAt: _optionalString(json['created_at']),
      canManage: capabilities?['can_manage'] == true || moderator,
      canPost:
          capabilities?['can_post'] == true || official || member || moderator,
      canJoin: capabilities?['can_join'] == true || (!official && !member),
      canReviewReports:
          capabilities?['can_review_reports'] == true || moderator,
      moderators: rawModerators is List
          ? rawModerators
                .whereType<Map<String, dynamic>>()
                .map(ForumCategoryModerator.fromJson)
                .toList()
          : const [],
    );
  }
}

/// 版块版主。`owner` 是创建者或管理员指定的所有者，同一版块仅一人。
class ForumCategoryModerator {
  const ForumCategoryModerator({required this.author, required this.role});

  final CampusAuthor author;
  final String role;

  bool get isOwner => role == 'owner';

  factory ForumCategoryModerator.fromJson(Map<String, dynamic> json) =>
      ForumCategoryModerator(
        author: CampusAuthor.fromJson(json),
        role: _string(json['role'], fallback: 'moderator'),
      );
}

/// 版块成员；加入后才能在该版块发帖。
class ForumCategoryMember {
  const ForumCategoryMember({required this.author, required this.joinedAt});

  final CampusAuthor author;
  final String joinedAt;

  factory ForumCategoryMember.fromJson(Map<String, dynamic> json) =>
      ForumCategoryMember(
        author: CampusAuthor.fromJson(json),
        joinedAt: _string(json['joined_at']),
      );
}

/// 版块管理日志。只保留操作类型、目标和理由，不包含帖子正文。
class ForumModerationLogEntry {
  const ForumModerationLogEntry({
    required this.id,
    required this.action,
    required this.targetType,
    required this.targetId,
    required this.reason,
    required this.createdAt,
    required this.actor,
  });

  final String id;
  final String action;
  final String targetType;
  final String? targetId;
  final String? reason;
  final String createdAt;
  final CampusAuthor actor;

  factory ForumModerationLogEntry.fromJson(Map<String, dynamic> json) {
    final actor = _map(json['actor']);
    return ForumModerationLogEntry(
      id: _string(json['id']),
      action: _string(json['action']),
      targetType: _string(json['target_type']),
      targetId: _optionalString(json['target_id']),
      reason: _optionalString(json['reason']),
      createdAt: _string(json['created_at']),
      actor: CampusAuthor.fromJson(actor),
    );
  }
}

/// 结构化投票的单个选项，人数与占比均由服务端计算。
class ForumPollOption {
  const ForumPollOption({
    required this.id,
    required this.label,
    required this.count,
    required this.percent,
  });

  final String id;
  final String label;
  final int count;

  /// 0 至 100 的百分比，保留一位小数。
  final double percent;

  factory ForumPollOption.fromJson(Map<String, dynamic> json) =>
      ForumPollOption(
        id: _string(json['id']),
        label: _string(json['label']),
        count: _integer(json['count']),
        percent: _decimal(json['percent']),
      );
}

/// 帖子附带的单选投票。旧帖子正文里的投票仍由 parseForumPoll 兼容。
class ForumPoll {
  const ForumPoll({
    required this.question,
    required this.totalVotes,
    required this.myOptionId,
    required this.options,
  });

  final String question;
  final int totalVotes;
  final String? myOptionId;
  final List<ForumPollOption> options;

  factory ForumPoll.fromJson(Map<String, dynamic> json) {
    final options = <ForumPollOption>[];
    final raw = json['options'];
    if (raw is List) {
      for (final item in raw) {
        final map = _map(item);
        if (map == null) continue;
        final option = ForumPollOption.fromJson(map);
        if (option.id.isEmpty || option.label.isEmpty) continue;
        options.add(option);
      }
    }
    return ForumPoll(
      question: _string(json['question']),
      totalVotes: _integer(json['total_votes']),
      myOptionId: _optionalString(json['my_option_id']),
      options: options,
    );
  }
}

/// 发帖时提交给服务端的投票草稿。
class ForumPollDraft {
  const ForumPollDraft({required this.question, required this.options});

  final String question;
  final List<String> options;

  Map<String, dynamic> toJson() => {'question': question, 'options': options};
}

/// 评分对象或二手内容在论坛中的关联卡片。
class ForumLinkedContent {
  const ForumLinkedContent({
    required this.type,
    required this.id,
    required this.title,
    required this.description,
    required this.imageAssetId,
    required this.status,
    this.ratingCount,
    this.ratingSum,
    this.ratingScore,
    this.priceCents,
    this.listingType,
    this.campus,
  });

  final String type;
  final String id;
  final String title;
  final String description;
  final String? imageAssetId;
  final String status;
  final int? ratingCount;
  final int? ratingSum;
  final double? ratingScore;
  final int? priceCents;
  final String? listingType;
  final String? campus;

  factory ForumLinkedContent.fromJson(Map<String, dynamic> json) =>
      ForumLinkedContent(
        type: _string(json['type']),
        id: _string(json['id']),
        title: _string(json['title']),
        description: _string(json['description']),
        imageAssetId: _optionalString(json['image_asset_id']),
        status: _string(json['status']),
        ratingCount: json['rating_count'] == null
            ? null
            : _integer(json['rating_count']),
        ratingSum: json['rating_sum'] == null
            ? null
            : _integer(json['rating_sum']),
        ratingScore: json['rating_score'] == null
            ? null
            : _decimal(json['rating_score']),
        priceCents: json['price_cents'] == null
            ? null
            : _integer(json['price_cents']),
        listingType: _optionalString(json['listing_type']),
        campus: _optionalString(json['campus']),
      );
}

/// 一条帖子下某个表情的聚合人数。
class ForumReaction {
  const ForumReaction({required this.emoji, required this.count});

  final String emoji;
  final int count;

  factory ForumReaction.fromJson(Map<String, dynamic> json) => ForumReaction(
    emoji: _string(json['emoji']),
    count: _integer(json['count']),
  );
}

/// 切换表情回应后的服务端最新聚合，客户端据此覆盖乐观状态。
class ForumThreadReaction {
  const ForumThreadReaction({
    required this.reactions,
    required this.myReaction,
  });

  final List<ForumReaction> reactions;
  final String? myReaction;

  factory ForumThreadReaction.fromJson(Map<String, dynamic> json) =>
      ForumThreadReaction(
        reactions: _reactionList(json['reactions']),
        myReaction: _optionalString(json['my_reaction']),
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
    this.reactions = const [],
    this.myReaction,
    this.poll,
    this.linkedContent,
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

  /// 所有用户的表情聚合，按人数和表情排序；页面直接渲染，不再本地计数。
  final List<ForumReaction> reactions;

  /// 当前登录用户选中的表情，null 表示未回应。
  final String? myReaction;

  /// 结构化投票；旧帖子可能仍把投票写在 body 中，此时为 null。
  final ForumPoll? poll;

  /// 评分对象或二手发布的来源数据，普通帖子为 null。
  final ForumLinkedContent? linkedContent;
  final bool isPinned;
  final bool isLocked;
  final String status;
  final int version;
  final String createdAt;
  final String lastActivityAt;
  final bool canEdit;
  final bool canDelete;

  bool get isHidden => status != 'normal';

  ForumThread copyWith({
    String? categoryId,
    String? categoryName,
    String? title,
    String? body,
    int? replyCount,
    int? likeCount,
    bool? isPinned,
    bool? isLocked,
    String? status,
    int? version,
    bool? canEdit,
    bool? canDelete,
    ForumLinkedContent? linkedContent,
  }) => ForumThread(
    id: id,
    categoryId: categoryId ?? this.categoryId,
    categoryName: categoryName ?? this.categoryName,
    title: title ?? this.title,
    body: body ?? this.body,
    author: author,
    imageAssetIds: imageAssetIds,
    replyCount: replyCount ?? this.replyCount,
    likeCount: likeCount ?? this.likeCount,
    reactions: reactions,
    myReaction: myReaction,
    poll: poll,
    linkedContent: linkedContent ?? this.linkedContent,
    isPinned: isPinned ?? this.isPinned,
    isLocked: isLocked ?? this.isLocked,
    status: status ?? this.status,
    version: version ?? this.version,
    createdAt: createdAt,
    lastActivityAt: lastActivityAt,
    canEdit: canEdit ?? this.canEdit,
    canDelete: canDelete ?? this.canDelete,
  );

  factory ForumThread.fromJson(Map<String, dynamic> json) {
    final category = _map(json['category']);
    final capabilities = _map(json['capabilities']);
    final poll = _map(json['poll']);
    final linkedContent = _map(json['linked_content']);
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
      reactions: _reactionList(json['reactions']),
      myReaction: _optionalString(json['my_reaction']),
      poll: poll == null ? null : ForumPoll.fromJson(poll),
      linkedContent: linkedContent == null
          ? null
          : ForumLinkedContent.fromJson(linkedContent),
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

/// 表情聚合丢弃空表情和非正数人数，避免后端异常数据撑出空胶囊。
List<ForumReaction> _reactionList(Object? value) {
  if (value is! List) return const [];
  final reactions = <ForumReaction>[];
  for (final item in value) {
    final map = _map(item);
    if (map == null) continue;
    final emoji = _string(map['emoji']);
    final count = _integer(map['count']);
    if (emoji.isEmpty || count <= 0) continue;
    reactions.add(ForumReaction(emoji: emoji, count: count));
  }
  reactions.sort((left, right) {
    final byCount = right.count.compareTo(left.count);
    return byCount != 0 ? byCount : left.emoji.compareTo(right.emoji);
  });
  return reactions;
}

int _integer(Object? value, {int fallback = 0}) =>
    value is num ? value.toInt() : fallback;

double _decimal(Object? value) => value is num ? value.toDouble() : 0;
