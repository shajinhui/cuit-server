import 'dart:async';
import 'package:chengxin_youyou/features/campus/models/campus_models.dart';
import 'package:chengxin_youyou/features/community/data/community_repository.dart';
import 'package:chengxin_youyou/features/community/models/community_models.dart';
import 'campus_preview_repository.dart';

class FakeCommunityRepository extends CampusPreviewRepository
    implements CommunityRepository {
  CampusAuthor profile = const CampusAuthor(
    id: 'community-me',
    displayName: '公开昵称',
    avatarPreset: 2,
  );
  Completer<CampusAuthor>? pendingProfile;
  Object? profileError;
  int profileLoads = 0, updates = 0, reads = 0;
  String? lastWatermark;
  bool favorite = false;
  Object? favoriteError;
  final readIds = <String>[];
  CampusPageResult<CommunityFavorite> favorites = const CampusPageResult(
    items: [],
    nextCursor: null,
    hasMore: false,
  );
  CommunityInbox inbox = const CommunityInbox(
    page: CampusPageResult(items: [], nextCursor: null, hasMore: false),
    readWatermark: '0',
    unreadCount: 0,
  );
  @override
  Future<CampusAuthor> getCommunityProfile({String? profileId}) async {
    profileLoads++;
    if (profileError != null) throw profileError!;
    return pendingProfile == null ? profile : pendingProfile!.future;
  }

  @override
  Future<CampusAuthor> updateCommunityProfile({
    required String displayName,
    required int avatarPreset,
    required int expectedVersion,
    String? avatarAssetId,
  }) async {
    updates++;
    profile = CampusAuthor(
      id: profile.id,
      displayName: displayName,
      avatarPreset: avatarPreset,
      avatarAssetId: avatarAssetId,
      profileVersion: expectedVersion + 1,
    );
    return profile;
  }

  @override
  Future<CampusPageResult<ForumThread>> listProfileThreads(
    String profileId, {
    String? cursor,
  }) => listForumThreads();
  @override
  Future<CommunityInbox> listNotifications({String? cursor}) async => inbox;
  @override
  Future<int> getUnreadCount() async => inbox.unreadCount;
  @override
  Future<void> readNotification(String id) async {
    reads++;
    readIds.add(id);
  }

  @override
  Future<int> readAllNotifications(String watermark) async {
    lastWatermark = watermark;
    return 1;
  }

  @override
  Future<CampusPageResult<CommunityFavorite>> listFavorites({
    String? cursor,
  }) async => favorites;
  @override
  Future<bool> getForumFavorite(String threadId) async => favorite;
  @override
  Future<bool> setForumFavorite(String threadId, bool favorited) async {
    if (favoriteError != null) throw favoriteError!;
    favorite = favorited;
    return favorite;
  }

  @override
  Future<ForumReply> getForumReply(String replyId) async => ForumReply(
    id: replyId,
    threadId: 'thread-1',
    parentId: null,
    body: '消息定位到的回复',
    author: profile,
    likeCount: 0,
    liked: false,
    replyCount: 0,
    version: 1,
    createdAt: '2026-10-20T10:00:00Z',
    canDelete: false,
  );
}
