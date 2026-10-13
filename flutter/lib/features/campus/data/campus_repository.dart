import 'dart:typed_data';

import '../models/campus_models.dart';

/// 校园评分与二手模块的数据入口，页面不直接拼接 API 地址。
abstract interface class CampusRepository {
  Future<CampusPageResult<CampusBoard>> listBoards({
    bool mine = false,
    String query = '',
    String sort = 'popular',
    String? cursor,
  });

  Future<CampusBoard> getBoard(String boardId);

  Future<CampusBoard> createBoard({
    required String title,
    required String description,
    String? coverAssetId,
    String? requestId,
  });

  Future<CampusPageResult<CampusRatingItem>> listRatingItems({
    required String boardId,
    String query = '',
    String sort = 'popular',
    String? cursor,
  });

  Future<CampusRatingItem> createRatingItem({
    required String boardId,
    required String name,
    required String description,
    String? imageAssetId,
    String? requestId,
  });

  Future<CampusRatingItemDetail> getRatingItem(String itemId);

  Future<CampusRatingMutation> submitRating({
    required String itemId,
    required int stars,
    required int expectedVersion,
  });

  Future<CampusRatingMutation> withdrawRating({
    required String itemId,
    required int expectedVersion,
  });

  Future<CampusPageResult<CampusComment>> listComments({
    required String itemId,
    String sort = 'newest',
    String? cursor,
  });

  Future<CampusPageResult<CampusComment>> listReplies({
    required String commentId,
    String? cursor,
  });

  Future<CampusComment> createComment({
    required String itemId,
    required String body,
    String? parentId,
    String? requestId,
  });

  Future<void> deleteComment({
    required String commentId,
    required int expectedVersion,
  });

  Future<CampusPageResult<CampusMineEntry>> listMyRatingContent({
    required String kind,
    String? cursor,
  });

  Future<void> report({
    required String targetType,
    required String targetId,
    required String reason,
  });

  Future<String> uploadAsset({
    required String filename,
    required Uint8List bytes,
    required String mimeType,
  });

  Future<CampusPageResult<CampusListing>> listListings({
    bool mine = false,
    String query = '',
    String type = 'sell',
    String? cursor,
  });

  Future<List<ForumCategory>> listForumCategories();

  Future<CampusPageResult<ForumThread>> listForumThreads({
    bool mine = false,
    String? categoryId,
    String query = '',
    String sort = 'latest',
    String? cursor,
  });

  Future<ForumThreadDetail> getForumThread(String threadId);

  Future<ForumThread> createForumThread({
    required String categoryId,
    required String title,
    required String body,
    List<String> imageAssetIds = const [],
    String? requestId,
  });

  Future<ForumThread> updateForumThread({
    required String threadId,
    required String categoryId,
    required String title,
    required String body,
    required List<String> imageAssetIds,
    required int expectedVersion,
  });

  Future<void> deleteForumThread({
    required String threadId,
    required int expectedVersion,
  });

  Future<void> deleteForumReply({
    required String replyId,
    required int expectedVersion,
  });

  Future<CampusPageResult<ForumReply>> listForumReplies({
    required String threadId,
    String? cursor,
  });

  Future<CampusPageResult<ForumReply>> listForumReplyChildren({
    required String replyId,
    String? cursor,
  });

  Future<ForumReply> createForumReply({
    required String threadId,
    required String body,
    String? parentId,
    String? requestId,
  });

  Future<ForumThreadLike> toggleForumThreadLike({
    required String threadId,
    required bool like,
  });

  Future<ForumThreadLike> toggleForumReplyLike({
    required String replyId,
    required bool like,
  });

  Future<CampusListing> getListing(String itemId);

  Future<CampusListing> updateListingStatus({
    required String itemId,
    required String status,
    required int expectedVersion,
  });

  Future<CampusContact> revealContact(String itemId);

  Future<CampusListing> createListing({
    required String title,
    required String description,
    required int priceCents,
    required String campus,
    required String type,
    required String contactType,
    required String contactValue,
    String? imageAssetId,
    String? requestId,
  });

  Future<Uint8List?> loadAsset(String assetId);

  void clearSession();

  void dispose();
}

class CampusRepositoryException implements Exception {
  const CampusRepositoryException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}
