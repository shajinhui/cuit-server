import '../../campus/models/campus_models.dart';

class CommunityNotification {
  const CommunityNotification({
    required this.id,
    required this.kind,
    required this.title,
    required this.excerpt,
    required this.createdAt,
    required this.isRead,
    required this.available,
    this.actor,
    this.threadId,
    this.replyId,
    this.parentId,
  });
  final String id, kind, title, excerpt, createdAt;
  final bool isRead, available;
  final CampusAuthor? actor;
  final String? threadId, replyId, parentId;

  factory CommunityNotification.fromJson(Map<String, dynamic> json) =>
      CommunityNotification(
        id: '${json['id']}',
        kind: '${json['kind'] ?? ''}',
        title: '${json['title'] ?? ''}',
        excerpt: '${json['excerpt'] ?? ''}',
        createdAt: '${json['created_at'] ?? ''}',
        isRead: json['is_read'] == true,
        available: json['available'] == true,
        actor: json['actor'] is Map<String, dynamic>
            ? CampusAuthor.fromJson(json['actor'])
            : null,
        threadId: json['thread_id'] as String?,
        replyId: json['reply_id'] as String?,
        parentId: json['parent_id'] as String?,
      );
}

class CommunityInbox {
  const CommunityInbox({
    required this.page,
    required this.readWatermark,
    required this.unreadCount,
  });
  final CampusPageResult<CommunityNotification> page;
  final String readWatermark;
  final int unreadCount;
  factory CommunityInbox.fromJson(Map<String, dynamic> json) => CommunityInbox(
    page: CampusPageResult.fromJson(json, CommunityNotification.fromJson),
    readWatermark: '${json['read_watermark'] ?? '0'}',
    unreadCount: (json['unread_count'] as num?)?.toInt() ?? 0,
  );
}

class CommunityFavorite {
  const CommunityFavorite({
    required this.targetId,
    required this.title,
    required this.excerpt,
    required this.createdAt,
    required this.available,
    this.author,
  });
  final String targetId, title, excerpt, createdAt;
  final bool available;
  final CampusAuthor? author;
  factory CommunityFavorite.fromJson(Map<String, dynamic> json) =>
      CommunityFavorite(
        targetId: '${json['target_id'] ?? ''}',
        title: '${json['title'] ?? ''}',
        excerpt: '${json['excerpt'] ?? ''}',
        createdAt: '${json['created_at'] ?? ''}',
        available: json['available'] == true,
        author: json['author'] is Map<String, dynamic>
            ? CampusAuthor.fromJson(json['author'])
            : null,
      );
}
