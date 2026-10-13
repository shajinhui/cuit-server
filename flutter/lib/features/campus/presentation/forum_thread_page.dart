import 'dart:async';

import 'package:chengxin_youyou/features/campus/data/campus_repository.dart';
import 'package:chengxin_youyou/features/campus/models/campus_models.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../ui/components/page_layout.dart';
import 'campus_report_dialog.dart';
import 'campus_widgets.dart';

/// 帖子详情：主楼、楼中楼回复、点赞与举报。数据只在页面内存中保存，不做本机缓存。
class ForumThreadPage extends StatefulWidget {
  const ForumThreadPage({
    super.key,
    required this.repository,
    required this.threadId,
  });

  final CampusRepository? repository;
  final String threadId;

  @override
  State<ForumThreadPage> createState() => _ForumThreadPageState();
}

class _ForumThreadPageState extends State<ForumThreadPage> {
  final _replyController = TextEditingController();
  final _replyFocusNode = FocusNode();
  ForumThreadDetail? _detail;
  List<ForumReply> _replies = [];
  final Map<String, List<ForumReply>> _replyChildren = {};
  final Set<String> _expandedReplies = {};
  ForumReply? _replyTarget;
  String _replyRequestId = createCampusRequestId();
  String? _replyCursor;
  String? _error;
  String? _replyError;
  bool _liked = false;
  int _likeCount = 0;
  int _replyCount = 0;
  bool _likeSubmitting = false;
  bool _loading = true;
  bool _repliesLoading = false;
  bool _replySubmitting = false;
  bool _hasMoreReplies = false;
  int _replyRequestVersion = 0;
  final Set<String> _replyLikeSubmitting = {};

  @override
  void initState() {
    super.initState();
    unawaited(_loadPage());
    unawaited(_loadReplies(reset: true));
  }

  @override
  void dispose() {
    _replyRequestVersion++;
    _replyController.dispose();
    _replyFocusNode.dispose();
    super.dispose();
  }

  Future<void> _loadPage() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final detail = await widget.repository!.getForumThread(widget.threadId);
      if (!mounted) return;
      setState(() {
        _detail = detail;
        _liked = detail.liked;
        _likeCount = detail.thread.likeCount;
        _replyCount = detail.thread.replyCount;
      });
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadReplies({required bool reset}) async {
    final repository = widget.repository;
    if (!reset && !_hasMoreReplies) return;
    final version = ++_replyRequestVersion;
    setState(() {
      _repliesLoading = true;
      _replyError = null;
    });
    try {
      if (repository == null) {
        throw const CampusRepositoryException('论坛服务暂时不可用。');
      }
      final page = await repository.listForumReplies(
        threadId: widget.threadId,
        cursor: reset ? null : _replyCursor,
      );
      if (!mounted || version != _replyRequestVersion) return;
      final combined = <String, ForumReply>{};
      if (!reset) {
        for (final reply in _replies) {
          combined[reply.id] = reply;
        }
      }
      for (final reply in page.items) {
        combined[reply.id] = reply;
      }
      setState(() {
        _replies = combined.values.toList();
        _replyCursor = page.nextCursor;
        _hasMoreReplies = page.hasMore;
      });
    } catch (error) {
      if (mounted && version == _replyRequestVersion) {
        setState(() => _replyError = error.toString());
      }
    } finally {
      if (mounted && version == _replyRequestVersion) {
        setState(() => _repliesLoading = false);
      }
    }
  }

  Future<void> _submitReply() async {
    final detail = _detail;
    final repository = widget.repository;
    final body = _replyController.text.trim();
    if (detail == null ||
        repository == null ||
        !detail.canReply ||
        body.isEmpty ||
        body.characters.length > 1000 ||
        _replySubmitting) {
      return;
    }
    setState(() {
      _replySubmitting = true;
      _replyError = null;
    });
    final replyTarget = _replyTarget;
    try {
      final created = await repository.createForumReply(
        threadId: widget.threadId,
        body: body,
        parentId: replyTarget?.id,
        requestId: _replyRequestId,
      );
      if (!mounted) return;
      setState(() {
        if (replyTarget case final target?) {
          // 已加载的楼中楼才直接追加；未加载时保持可展开状态。
          if (_replyChildren.containsKey(target.id)) {
            _replyChildren[target.id] = [
              ..._replyChildren[target.id]!,
              created,
            ];
            _expandedReplies.add(target.id);
          }
          final index = _replies.indexWhere((item) => item.id == target.id);
          if (index >= 0) {
            final current = _replies[index];
            _replies[index] = _copyReply(
              current,
              replyCount: current.replyCount + 1,
            );
          }
        } else {
          // 回复按最新在前展示，新回复直接进入列表顶部。
          _replies.insert(0, created);
        }
        _replyTarget = null;
        _replyController.clear();
        _replyRequestId = createCampusRequestId();
        _replyCount = (_replyCount + 1).clamp(0, 1 << 30);
      });
      if (replyTarget != null && !_replyChildren.containsKey(replyTarget.id)) {
        await _toggleReplyChildren(replyTarget);
      }
    } catch (error) {
      if (mounted) setState(() => _replyError = error.toString());
    } finally {
      if (mounted) setState(() => _replySubmitting = false);
    }
  }

  Future<void> _toggleReplyChildren(ForumReply reply) async {
    if (_expandedReplies.remove(reply.id)) {
      setState(() {});
      return;
    }
    if (!_replyChildren.containsKey(reply.id)) {
      try {
        final page = await widget.repository!.listForumReplyChildren(
          replyId: reply.id,
        );
        if (!mounted) return;
        _replyChildren[reply.id] = page.items;
      } catch (error) {
        if (mounted) setState(() => _replyError = error.toString());
        return;
      }
    }
    if (mounted) setState(() => _expandedReplies.add(reply.id));
  }

  Future<void> _toggleLike() async {
    final detail = _detail;
    final repository = widget.repository;
    if (detail == null || repository == null || _likeSubmitting) return;
    setState(() {
      _likeSubmitting = true;
      _error = null;
    });
    try {
      // 前端先切换展示状态，服务端返回最新计数后覆盖，失败时回滚。
      setState(() {
        _liked = !_liked;
        _likeCount = (_likeCount + (_liked ? 1 : -1)).clamp(0, 1 << 30);
      });
      final result = await repository.toggleForumThreadLike(
        threadId: widget.threadId,
        like: _liked,
      );
      if (!mounted) return;
      setState(() {
        _liked = result.liked;
        _likeCount = result.likeCount;
      });
    } catch (error) {
      if (mounted) {
        setState(() {
          _liked = detail.liked;
          _likeCount = detail.thread.likeCount;
          _error = error.toString();
        });
      }
    } finally {
      if (mounted) setState(() => _likeSubmitting = false);
    }
  }

  /// 回复点赞：先乐观切换，服务端返回最新计数后覆盖，失败时回滚。
  Future<void> _toggleReplyLike(ForumReply reply) async {
    final repository = widget.repository;
    if (repository == null || _replyLikeSubmitting.contains(reply.id)) return;
    setState(() {
      _replyLikeSubmitting.add(reply.id);
      _replyError = null;
      _replaceReply(
        _copyReply(
          reply,
          liked: !reply.liked,
          likeCount: (reply.likeCount + (reply.liked ? -1 : 1)).clamp(
            0,
            1 << 30,
          ),
        ),
      );
    });
    try {
      final result = await repository.toggleForumReplyLike(
        replyId: reply.id,
        like: !reply.liked,
      );
      if (!mounted) return;
      setState(() {
        _replaceReply(
          _copyReply(reply, liked: result.liked, likeCount: result.likeCount),
        );
      });
    } catch (error) {
      if (mounted) {
        setState(() {
          _replaceReply(reply);
          _replyError = error.toString();
        });
      }
    } finally {
      if (mounted) setState(() => _replyLikeSubmitting.remove(reply.id));
    }
  }

  /// 主楼和楼中楼分开存放，按 id 找到并替换为最新状态。
  void _replaceReply(ForumReply updated) {
    final index = _replies.indexWhere((item) => item.id == updated.id);
    if (index >= 0) {
      _replies[index] = updated;
      return;
    }
    for (final entry in _replyChildren.entries) {
      final childIndex = entry.value.indexWhere(
        (item) => item.id == updated.id,
      );
      if (childIndex >= 0) {
        entry.value[childIndex] = updated;
        return;
      }
    }
  }

  /// 删除帖子前必须二次确认，删除成功后返回上一页。
  Future<void> _deleteThread() async {
    final detail = _detail;
    final repository = widget.repository;
    if (detail == null || repository == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('删除帖子'),
        content: const Text('删除后无法恢复，确定删除这篇帖子吗？'),
        actions: [
          TextButton(
            key: const ValueKey('forum-thread-delete-cancel'),
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            key: const ValueKey('forum-thread-delete-confirm'),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await repository.deleteForumThread(
        threadId: widget.threadId,
        expectedVersion: detail.thread.version,
      );
      if (!mounted) return;
      context.pop();
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    }
  }

  /// 删除自己的回复：主楼回复从列表移除，楼中楼从父级移除并同步计数。
  Future<void> _deleteReply(ForumReply reply) async {
    final repository = widget.repository;
    if (repository == null || !reply.canDelete) return;
    try {
      await repository.deleteForumReply(
        replyId: reply.id,
        expectedVersion: reply.version,
      );
      if (!mounted) return;
      setState(() {
        final parentId = reply.parentId;
        if (parentId == null) {
          _replies.removeWhere((item) => item.id == reply.id);
        } else {
          final children = _replyChildren[parentId];
          if (children != null) {
            _replyChildren[parentId] = children
                .where((item) => item.id != reply.id)
                .toList();
          }
          final index = _replies.indexWhere((item) => item.id == parentId);
          if (index >= 0) {
            final parent = _replies[index];
            _replies[index] = _copyReply(
              parent,
              replyCount: (parent.replyCount - 1).clamp(0, 1 << 30),
            );
          }
        }
        _replyCount = (_replyCount - 1).clamp(0, 1 << 30);
      });
    } catch (error) {
      if (mounted) setState(() => _replyError = error.toString());
    }
  }

  Future<void> _report(String targetType, String targetId) async {
    final reason = await askCampusReportReason(context);
    if (reason == null || widget.repository == null) return;
    try {
      await widget.repository!.report(
        targetType: targetType,
        targetId: targetId,
        reason: reason,
      );
      if (mounted) _showMessage('举报已提交');
    } catch (error) {
      if (mounted) _showMessage(error.toString());
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final detail = _detail;
    return PageScaffold(
      title: '帖子详情',
      actions: [
        if (detail?.thread.canEdit == true)
          IconButton(
            key: const ValueKey('forum-thread-edit'),
            tooltip: '编辑帖子',
            onPressed: () => context.pushNamed(
              'forum-edit',
              pathParameters: {'threadId': widget.threadId},
              extra: detail!.thread,
            ),
            icon: const Icon(Icons.edit_outlined),
          ),
        if (detail?.thread.canDelete == true)
          IconButton(
            key: const ValueKey('forum-thread-delete'),
            tooltip: '删除帖子',
            onPressed: _deleteThread,
            icon: const Icon(Icons.delete_outline),
          ),
        if (detail != null)
          IconButton(
            tooltip: '举报帖子',
            onPressed: () => _report('forum_thread', widget.threadId),
            icon: const Icon(Icons.flag_outlined),
          ),
      ],
      bottomNavigationBar: detail == null || !detail.canReply
          ? null
          : SafeArea(
              top: false,
              child: Material(
                elevation: 0,
                color: Theme.of(context).scaffoldBackgroundColor,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_replyTarget != null)
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                '回复 ${_replyTarget!.author.displayName}',
                              ),
                            ),
                            IconButton(
                              tooltip: '取消回复',
                              onPressed: () =>
                                  setState(() => _replyTarget = null),
                              icon: const Icon(Icons.close_rounded),
                            ),
                          ],
                        ),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              key: const ValueKey('forum-reply-input'),
                              controller: _replyController,
                              focusNode: _replyFocusNode,
                              minLines: 1,
                              maxLines: 4,
                              maxLength: 1000,
                              buildCounter:
                                  (
                                    _, {
                                    required currentLength,
                                    required isFocused,
                                    maxLength,
                                  }) => null,
                              decoration: InputDecoration(
                                hintText: _replyTarget == null
                                    ? '写下你的回复…'
                                    : '写下楼中楼回复…',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 10,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton.filled(
                            key: const ValueKey('forum-reply-submit'),
                            onPressed: _replySubmitting ? null : _submitReply,
                            tooltip: '发送回复',
                            icon: _replySubmitting
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.send_rounded),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
      child: _loading && detail == null
          ? const CampusPageState(title: '正在加载帖子', loading: true)
          : _error != null && detail == null
          ? CampusPageState(
              title: '无法打开这个帖子',
              description: _error,
              actionLabel: '重新加载',
              onAction: _loadPage,
            )
          : detail == null
          ? const CampusPageState(title: '帖子不存在或已被删除')
          : _buildContent(detail),
    );
  }

  Widget _buildContent(ForumThreadDetail detail) => RefreshIndicator(
    onRefresh: () async {
      await Future.wait([_loadPage(), _loadReplies(reset: true)]);
    },
    child: ListView(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 28),
      children: [
        _buildMainPost(detail),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        const SizedBox(height: 16),
        Text(
          '全部回复 / $_replyCount',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        if (_replyError != null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              _replyError!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        if (_repliesLoading && _replies.isEmpty)
          const CampusPageState(title: '正在加载回复', loading: true)
        else if (_replies.isEmpty)
          const CampusPageState(title: '还没有回复', description: '来写下第一条回复。')
        else ...[
          for (final reply in _replies) _buildReply(reply),
          if (_hasMoreReplies)
            Center(
              child: OutlinedButton(
                onPressed: _repliesLoading
                    ? null
                    : () => _loadReplies(reset: false),
                child: Text(_repliesLoading ? '正在加载…' : '加载更多回复'),
              ),
            ),
        ],
      ],
    ),
  );

  Widget _buildMainPost(ForumThreadDetail detail) {
    final thread = detail.thread;
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (thread.categoryName.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  thread.categoryName,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: pageAccent(context),
                  ),
                ),
              ),
            Text(
              thread.title,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                CampusAuthorAvatar(author: thread.author, radius: 13),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    thread.author.displayName,
                    style: theme.textTheme.titleSmall,
                  ),
                ),
                Text(
                  campusFormatTime(thread.createdAt),
                  style: theme.textTheme.labelSmall,
                ),
              ],
            ),
            const SizedBox(height: 12),
            // 帖子正文保持服务端原始换行，不做富文本渲染。
            Text(
              thread.body,
              style: const TextStyle(fontSize: 15, height: 1.6),
            ),
            if (thread.imageAssetIds.isNotEmpty) ...[
              const SizedBox(height: 12),
              SizedBox(
                height: 160,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: thread.imageAssetIds.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 8),
                  itemBuilder: (context, index) => CampusAssetImage(
                    assetId: thread.imageAssetIds[index],
                    repository: widget.repository,
                    height: 160,
                    width: 160,
                    radius: 12,
                    fallback: Icons.image_outlined,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                FilledButton.tonalIcon(
                  key: const ValueKey('forum-thread-like'),
                  onPressed: _likeSubmitting ? null : _toggleLike,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(44, 44),
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                  ),
                  icon: Icon(
                    _liked
                        ? Icons.thumb_up_alt_rounded
                        : Icons.thumb_up_alt_outlined,
                  ),
                  label: Text('$_likeCount'),
                ),
                if (thread.isLocked) ...[
                  const SizedBox(width: 8),
                  Text(
                    '帖子已锁定，无法回复',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReply(ForumReply reply) => Card(
    margin: const EdgeInsets.only(bottom: 10),
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CampusAuthorAvatar(author: reply.author, radius: 14),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  reply.author.displayName,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
              Text(
                campusFormatTime(reply.createdAt),
                style: Theme.of(context).textTheme.labelSmall,
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(38, 8, 0, 4),
            child: Text(reply.body),
          ),
          Padding(
            padding: const EdgeInsets.only(left: 30),
            child: Wrap(
              spacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                TextButton.icon(
                  key: ValueKey('forum-reply-like-${reply.id}'),
                  onPressed: _replyLikeSubmitting.contains(reply.id)
                      ? null
                      : () => _toggleReplyLike(reply),
                  icon: Icon(
                    reply.liked
                        ? Icons.thumb_up_alt_rounded
                        : Icons.thumb_up_alt_outlined,
                    size: 16,
                  ),
                  label: Text('${reply.likeCount}'),
                ),
                TextButton(
                  onPressed: () {
                    setState(() => _replyTarget = reply);
                    _replyFocusNode.requestFocus();
                  },
                  child: const Text('回复'),
                ),
                if (reply.canDelete)
                  TextButton(
                    key: ValueKey('forum-reply-delete-${reply.id}'),
                    onPressed: () => _deleteReply(reply),
                    child: const Text('删除'),
                  ),
                TextButton(
                  onPressed: () => _report('forum_reply', reply.id),
                  child: const Text('举报'),
                ),
              ],
            ),
          ),
          if (reply.replyCount > 0)
            TextButton.icon(
              onPressed: () => _toggleReplyChildren(reply),
              icon: Icon(
                _expandedReplies.contains(reply.id)
                    ? Icons.expand_less
                    : Icons.expand_more,
              ),
              label: Text(
                _expandedReplies.contains(reply.id)
                    ? '收起回复'
                    : '查看 ${reply.replyCount} 条回复',
              ),
            ),
          if (_expandedReplies.contains(reply.id))
            Padding(
              padding: const EdgeInsets.only(left: 28),
              child: Column(
                children: [
                  for (final child in _replyChildren[reply.id] ?? [])
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: CampusAuthorAvatar(
                        author: child.author,
                        radius: 12,
                      ),
                      title: Text(child.author.displayName),
                      subtitle: Text(
                        '${child.body}\n${campusFormatTime(child.createdAt)}',
                      ),
                      isThreeLine: true,
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          InkWell(
                            key: ValueKey('forum-reply-like-${child.id}'),
                            borderRadius: BorderRadius.circular(16),
                            onTap: _replyLikeSubmitting.contains(child.id)
                                ? null
                                : () => _toggleReplyLike(child),
                            child: Padding(
                              padding: const EdgeInsets.all(6),
                              child: Row(
                                children: [
                                  Icon(
                                    child.liked
                                        ? Icons.thumb_up_alt_rounded
                                        : Icons.thumb_up_alt_outlined,
                                    size: 15,
                                  ),
                                  const SizedBox(width: 3),
                                  Text('${child.likeCount}'),
                                ],
                              ),
                            ),
                          ),
                          if (child.canDelete)
                            IconButton(
                              key: ValueKey('forum-reply-delete-${child.id}'),
                              tooltip: '删除回复',
                              onPressed: () => _deleteReply(child),
                              icon: const Icon(Icons.delete_outline, size: 18),
                            ),
                          IconButton(
                            tooltip: '举报回复',
                            onPressed: () => _report('forum_reply', child.id),
                            icon: const Icon(Icons.flag_outlined, size: 18),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    ),
  );
}

ForumReply _copyReply(
  ForumReply reply, {
  int? replyCount,
  int? likeCount,
  bool? liked,
}) => ForumReply(
  id: reply.id,
  threadId: reply.threadId,
  parentId: reply.parentId,
  author: reply.author,
  body: reply.body,
  likeCount: likeCount ?? reply.likeCount,
  liked: liked ?? reply.liked,
  replyCount: replyCount ?? reply.replyCount,
  version: reply.version,
  createdAt: reply.createdAt,
  canDelete: reply.canDelete,
);
