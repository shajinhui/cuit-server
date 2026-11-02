import '../../campus/models/campus_models.dart';
import '../models/community_models.dart';

/// Personal community data uses the same authenticated transport as campus
/// content, but has no persistent or anonymous announcement cache.
abstract interface class CommunityRepository {
  Future<CampusAuthor> getCommunityProfile({String? profileId});
  Future<CampusAuthor> updateCommunityProfile({
    required String displayName,
    required int avatarPreset,
    required int expectedVersion,
    String? avatarAssetId,
  });
  Future<CampusPageResult<ForumThread>> listProfileThreads(
    String profileId, {
    String? cursor,
  });
  Future<CommunityInbox> listNotifications({String? cursor});
  Future<int> getUnreadCount();
  Future<void> readNotification(String id);
  Future<int> readAllNotifications(String watermark);
  Future<CampusPageResult<CommunityFavorite>> listFavorites({String? cursor});
  Future<bool> getForumFavorite(String threadId);
  Future<bool> setForumFavorite(String threadId, bool favorited);
  Future<ForumReply> getForumReply(String replyId);
}
