import 'dart:async';
import 'dart:convert';

import 'package:chengxin_youyou/features/campus/data/campus_repository.dart';
import 'package:chengxin_youyou/features/campus/models/campus_models.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../ui/components/page_layout.dart';
import 'campus_report_dialog.dart';
import 'campus_widgets.dart';
import '../../community/data/community_repository.dart';

/// 帖子详情：主楼、楼中楼回复、点赞与举报。数据只在页面内存中保存，不做本机缓存。
class ForumThreadPage extends StatefulWidget {
  const ForumThreadPage({
    super.key,
    required this.repository,
    required this.threadId,
    this.focusReplyId,
  });

  final CampusRepository? repository;
  final String threadId;
  final String? focusReplyId;

  @override
  State<ForumThreadPage> createState() => _ForumThreadPageState();
}

class _ForumThreadPageState extends State<ForumThreadPage> {
  final _replyController = TextEditingController();
  final _replyFocusNode = FocusNode();
  ForumThreadDetail? _detail;
  List<ForumReply> _replies = [];
  final Map<String, List<ForumReply>> _replyChildren = {};
  final Map<String, String?> _childCursors = {};
  final Set<String> _childrenHasMore = {};
  final Set<String> _childrenLoading = {};
  final Set<String> _expandedReplies = {};
  ForumReply? _replyTarget;
  String _replyRequestId = createCampusRequestId();
  String? _lastReplyPayload;
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
  int _pageRequestVersion = 0;
  int _childrenRequestVersion = 0;
  final Set<String> _replyLikeSubmitting = {};
  final Set<String> _replyDeleting = {};
  bool _favorited = false,
      _favoriteKnown = false,
      _favoriteBusy = false,
      _favoriteSupported = true;
  ForumReply? _focusedReply, _focusedParent;
  String? _focusError;
  CommunityRepository? get _community =>
      widget.repository is CommunityRepository
      ? widget.repository as CommunityRepository
      : null;

  @override
  void initState() {
    super.initState();
    unawaited(_loadPage());
    unawaited(_loadReplies(reset: true));
    unawaited(_loadFavorite());
    unawaited(_loadFocus());
  }

  Future<void> _loadFavorite() async {
    final repository = _community;
    if (repository == null) return;
    try {
      final value = await repository.getForumFavorite(widget.threadId);
      if (mounted) {
        setState(() {
          _favorited = value;
          _favoriteKnown = true;
        });
      }
    } catch (error) {
      if (mounted &&
          error is CampusRepositoryException &&
          error.statusCode == 404) {
        setState(() => _favoriteSupported = false);
      }
    }
  }

  Future<void> _toggleFavorite() async {
    final repository = _community;
    if (repository == null || _favoriteBusy) return;
    setState(() => _favoriteBusy = true);
    try {
      if (!_favoriteKnown) {
        final value = await repository.getForumFavorite(widget.threadId);
        if (!mounted) return;
        setState(() {
          _favorited = value;
          _favoriteKnown = true;
        });
      }
      final value = await repository.setForumFavorite(
        widget.threadId,
        !_favorited,
      );
      if (mounted) {
        setState(() => _favorited = value);
        _showMessage(value ? '已加入我的收藏' : '已取消收藏');
      }
    } catch (error) {
      if (mounted) _showMessage(error.toString());
    } finally {
      if (mounted) setState(() => _favoriteBusy = false);
    }
  }

  Future<void> _loadFocus() async {
    final repository = _community;
    final id = widget.focusReplyId;
    if (repository == null || id == null) return;
    try {
      final reply = await repository.getForumReply(id);
      if (reply.threadId != widget.threadId) {
        throw const CampusRepositoryException('回复不属于这个帖子。');
      }
      final parent = reply.parentId == null
          ? null
          : await repository.getForumReply(reply.parentId!);
      if (mounted) {
        setState(() {
          _focusedReply = reply;
          _focusedParent = parent;
          _focusError = null;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _focusedReply = null;
          _focusedParent = null;
          _focusError = '消息中的回复已删除、隐藏或暂时无法加载。';
        });
      }
    }
  }

  @override
  void dispose() {
    _replyRequestVersion++;
    _pageRequestVersion++;
    _childrenRequestVersion++;
    _replyController.dispose();
    _replyFocusNode.dispose();
    super.dispose();
  }

  Future<void> _loadPage() async {
    final version = ++_pageRequestVersion;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final repository = widget.repository;
      if (repository == null) {
        throw const CampusRepositoryException('论坛服务暂时不可用。');
      }
      final detail = await repository.getForumThread(widget.threadId);
      if (!mounted || version != _pageRequestVersion) return;
      setState(() {
        _detail = detail;
        _liked = detail.liked;
        _likeCount = detail.thread.likeCount;
        _replyCount = detail.thread.replyCount;
      });
    } catch (error) {
      if (mounted && version == _pageRequestVersion) {
        setState(() {
          _error = error.toString();
          // 明确删除／隐藏时不能继续展示旧正文；断网仍保留当前内容。
          if (error is CampusRepositoryException && error.statusCode == 404) {
            _detail = null;
            _replies.clear();
            _replyChildren.clear();
            _expandedReplies.clear();
            _childrenRequestVersion++;
          }
        });
      }
    } finally {
      if (mounted && version == _pageRequestVersion) {
        setState(() => _loading = false);
      }
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
    // 相同正文与回复目标沿用幂等键；修改任何字段都属于一次新的提交。
    final payload = jsonEncode([widget.threadId, replyTarget?.id, body]);
    if (_lastReplyPayload != null && _lastReplyPayload != payload) {
      _replyRequestId = createCampusRequestId();
    }
    _lastReplyPayload = payload;
    try {
      final created = await repository.createForumReply(
        threadId: widget.threadId,
        body: body,
        parentId: replyTarget?.id,
        requestId: _replyRequestId,
      );
      if (!mounted) return;
      _replyRequestVersion++;
      _pageRequestVersion++;
      _childrenRequestVersion++;
      setState(() {
        _childrenLoading.clear();
        _loading = false;
        _repliesLoading = false;
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
        _lastReplyPayload = null;
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
    setState(() => _expandedReplies.add(reply.id));
    if (!_replyChildren.containsKey(reply.id)) {
      await _loadReplyChildren(reply.id, reset: true);
    }
  }

  Future<void> _loadReplyChildren(String replyId, {required bool reset}) async {
    final repository = widget.repository;
    if (repository == null || _childrenLoading.contains(replyId)) return;
    if (!reset && !_childrenHasMore.contains(replyId)) return;
    final version = _childrenRequestVersion;
    setState(() {
      _childrenLoading.add(replyId);
      _replyError = null;
    });
    try {
      final page = await repository.listForumReplyChildren(
        replyId: replyId,
        cursor: reset ? null : _childCursors[replyId],
      );
      if (!mounted || version != _childrenRequestVersion) return;
      final combined = <String, ForumReply>{
        if (!reset)
          for (final child in _replyChildren[replyId] ?? []) child.id: child,
        for (final child in page.items) child.id: child,
      };
      setState(() {
        _replyChildren[replyId] = combined.values.toList()
          ..sort((a, b) {
            final time = a.createdAt.compareTo(b.createdAt);
            return time == 0 ? a.id.compareTo(b.id) : time;
          });
        _childCursors[replyId] = page.nextCursor;
        if (page.hasMore) {
          _childrenHasMore.add(replyId);
        } else {
          _childrenHasMore.remove(replyId);
        }
      });
    } catch (error) {
      if (mounted && version == _childrenRequestVersion) {
        setState(() => _replyError = error.toString());
      }
    } finally {
      if (mounted && version == _childrenRequestVersion) {
        setState(() => _childrenLoading.remove(replyId));
      }
    }
  }

  Future<void> _refresh() async {
    // 写操作完成前不读取旧快照覆盖乐观状态。
    if (_replySubmitting ||
        _likeSubmitting ||
        _replyLikeSubmitting.isNotEmpty) {
      return;
    }
    _childrenRequestVersion++;
    _childrenLoading.clear();
    await Future.wait([
      _loadPage(),
      _loadReplies(reset: true),
      _loadFocus(),
      _loadFavorite(),
    ]);
    if (!mounted || _replyError != null) return;
    final roots = _replies.map((reply) => reply.id).toSet();
    setState(() {
      _expandedReplies.removeWhere((id) => !roots.contains(id));
      _replyChildren.removeWhere((id, _) => !_expandedReplies.contains(id));
      _childCursors.clear();
      _childrenHasMore.clear();
    });
    await Future.wait([
      for (final id in _expandedReplies.toList())
        _loadReplyChildren(id, reset: true),
    ]);
  }

  Future<void> _toggleLike() async {
    final detail = _detail;
    final repository = widget.repository;
    if (detail == null || repository == null || _likeSubmitting) return;
    final previousLiked = _liked;
    final previousLikeCount = _likeCount;
    _pageRequestVersion++;
    setState(() {
      _loading = false;
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
          _liked = previousLiked;
          _likeCount = previousLikeCount;
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
      context.pop(true);
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    }
  }

  /// 删除自己的回复：主楼回复从列表移除，楼中楼从父级移除并同步计数。
  Future<void> _deleteReply(ForumReply reply) async {
    final repository = widget.repository;
    if (repository == null ||
        !reply.canDelete ||
        _replyDeleting.contains(reply.id)) {
      return;
    }
    setState(() => _replyDeleting.add(reply.id));
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
          _replyChildren.remove(reply.id);
          _expandedReplies.remove(reply.id);
          _childCursors.remove(reply.id);
          _childrenHasMore.remove(reply.id);
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
        if (_replyTarget?.id == reply.id) _replyTarget = null;
        final removed = 1 + (parentId == null ? reply.replyCount : 0);
        _replyCount = (_replyCount - removed).clamp(0, 1 << 30);
      });
      await _refresh();
    } catch (error) {
      if (mounted) setState(() => _replyError = error.toString());
    } finally {
      if (mounted) setState(() => _replyDeleting.remove(reply.id));
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
      backgroundColor: Theme.of(context).colorScheme.surface,
      actions: [
        if (detail != null && _community != null && _favoriteSupported)
          IconButton(
            key: const ValueKey('forum-thread-favorite'),
            tooltip: _favorited ? '取消收藏' : '收藏帖子',
            onPressed: _favoriteBusy ? null : _toggleFavorite,
            icon: Icon(
              _favorited ? Icons.star_rounded : Icons.star_outline_rounded,
            ),
          ),
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
                              onPressed: _replySubmitting
                                  ? null
                                  : () => setState(() => _replyTarget = null),
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
                              enabled: !_replySubmitting,
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
    onRefresh: _refresh,
    child: ListView(
      padding: const EdgeInsets.only(bottom: 28),
      children: [
        _buildMainPost(detail),
        if (_focusedReply != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: PageCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '消息中的回复',
                    style: TextStyle(
                      color: pageAccent(context),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      CampusAuthorAvatar(
                        author: _focusedReply!.author,
                        radius: 14,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: CampusAuthorName(author: _focusedReply!.author),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(_focusedReply!.body),
                  if (detail.canReply)
                    TextButton(
                      onPressed: () {
                        setState(
                          () => _replyTarget = _focusedParent ?? _focusedReply,
                        );
                        _replyFocusNode.requestFocus();
                      },
                      child: const Text('回复这条讨论'),
                    ),
                ],
              ),
            ),
          ),
        if (_focusError != null)
          Padding(padding: const EdgeInsets.all(16), child: Text(_focusError!)),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        Container(
          constraints: const BoxConstraints(minHeight: 44),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: Theme.of(
                  context,
                ).colorScheme.outlineVariant.withValues(alpha: .65),
                width: .6,
              ),
            ),
          ),
          child: Text(
            '全部回复 / $_replyCount',
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
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
    final colors = theme.colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: pageBackground(context), width: 7),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CampusAuthorAvatar(
                  author: thread.author,
                  radius: 20,
                  repository: widget.repository,
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CampusAuthorName(
                        author: thread.author,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        campusFormatTime(thread.createdAt),
                        style: TextStyle(
                          fontSize: 10,
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (thread.title.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                thread.title,
                style: const TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w700,
                  height: 1.45,
                ),
              ),
            ],
            if (thread.body.isNotEmpty) ...[
              const SizedBox(height: 10),
              // 帖子正文保持服务端原始换行，不做富文本渲染。
              Text(
                thread.body,
                style: const TextStyle(fontSize: 16, height: 1.7),
              ),
            ],
            if (thread.imageAssetIds.isNotEmpty) ...[
              const SizedBox(height: 12),
              Builder(
                builder: (context) {
                  final ids = thread.imageAssetIds.take(3).toList();
                  if (ids.length == 1) {
                    return CampusAssetImage(
                      assetId: ids.single,
                      repository: widget.repository,
                      width: 320,
                      height: 360,
                      radius: 8,
                      adaptive: true,
                      fallback: Icons.image_outlined,
                    );
                  }
                  return SizedBox(
                    width: double.infinity,
                    height: 118,
                    child: Row(
                      children: [
                        for (var index = 0; index < ids.length; index++) ...[
                          if (index > 0) const SizedBox(width: 4),
                          Expanded(
                            child: CampusAssetImage(
                              assetId: ids[index],
                              repository: widget.repository,
                              height: 118,
                              radius: 8,
                              fallback: Icons.image_outlined,
                            ),
                          ),
                        ],
                      ],
                    ),
                  );
                },
              ),
            ],
            if (thread.categoryName.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                '# ${thread.categoryName}',
                style: TextStyle(fontSize: 11, color: colors.onSurfaceVariant),
              ),
            ],
            const SizedBox(height: 5),
            SizedBox(
              width: double.infinity,
              child: Wrap(
                alignment: WrapAlignment.spaceAround,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  TextButton.icon(
                    key: const ValueKey('forum-thread-like'),
                    onPressed: _likeSubmitting ? null : _toggleLike,
                    style: TextButton.styleFrom(
                      minimumSize: const Size(44, 44),
                      foregroundColor: _liked
                          ? pageAccent(context)
                          : colors.onSurfaceVariant,
                    ),
                    icon: Icon(
                      _liked
                          ? Icons.thumb_up_alt_rounded
                          : Icons.thumb_up_alt_outlined,
                      size: 20,
                    ),
                    label: Text('$_likeCount'),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 12,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.chat_bubble_outline_rounded,
                          size: 19,
                          color: colors.onSurfaceVariant,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '$_replyCount',
                          style: TextStyle(color: colors.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (thread.isLocked)
              Text(
                '帖子已锁定，无法回复',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildReply(ForumReply reply) {
    final colors = Theme.of(context).colorScheme;
    final isThreadAuthor = _detail?.thread.author.id == reply.author.id;
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: colors.outlineVariant.withValues(alpha: .65),
            width: .6,
          ),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 13, 10, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CampusAuthorAvatar(
                  author: reply.author,
                  radius: 15,
                  repository: widget.repository,
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 6,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          CampusAuthorName(
                            author: reply.author,
                            style: TextStyle(
                              fontSize: 11,
                              color: colors.onSurfaceVariant,
                            ),
                          ),
                          if (isThreadAuthor)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4,
                              ),
                              decoration: BoxDecoration(
                                color: pageAccent(
                                  context,
                                ).withValues(alpha: .1),
                                borderRadius: BorderRadius.circular(3),
                              ),
                              child: Text(
                                '作者',
                                style: TextStyle(
                                  fontSize: 8,
                                  height: 1.6,
                                  color: pageAccent(context),
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        reply.body,
                        style: const TextStyle(fontSize: 14, height: 1.55),
                      ),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 2,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            child: Text(
                              campusFormatTime(reply.createdAt),
                              style: TextStyle(
                                fontSize: 9,
                                color: colors.onSurfaceVariant,
                              ),
                            ),
                          ),
                          TextButton(
                            onPressed: _replySubmitting
                                ? null
                                : () {
                                    setState(() => _replyTarget = reply);
                                    _replyFocusNode.requestFocus();
                                  },
                            style: _replyActionStyle,
                            child: const Text('回复'),
                          ),
                          if (reply.canDelete)
                            TextButton(
                              key: ValueKey('forum-reply-delete-${reply.id}'),
                              onPressed: _replyDeleting.contains(reply.id)
                                  ? null
                                  : () => _deleteReply(reply),
                              style: _replyActionStyle,
                              child: const Text('删除'),
                            ),
                          TextButton(
                            onPressed: () => _report('forum_reply', reply.id),
                            style: _replyActionStyle,
                            child: const Text('举报'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                TextButton(
                  key: ValueKey('forum-reply-like-${reply.id}'),
                  onPressed: _replyLikeSubmitting.contains(reply.id)
                      ? null
                      : () => _toggleReplyLike(reply),
                  style: TextButton.styleFrom(
                    minimumSize: const Size(40, 44),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    padding: const EdgeInsets.symmetric(horizontal: 5),
                    foregroundColor: reply.liked
                        ? pageAccent(context)
                        : colors.onSurfaceVariant,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        reply.liked
                            ? Icons.thumb_up_alt_rounded
                            : Icons.thumb_up_alt_outlined,
                        size: 16,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${reply.likeCount}',
                        style: const TextStyle(fontSize: 9),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (reply.replyCount > 0)
              Padding(
                padding: const EdgeInsets.only(left: 39),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: () => _toggleReplyChildren(reply),
                    style: _replyActionStyle,
                    icon: Icon(
                      _expandedReplies.contains(reply.id)
                          ? Icons.expand_less
                          : Icons.expand_more,
                      size: 17,
                    ),
                    label: Text(
                      _expandedReplies.contains(reply.id)
                          ? '收起回复'
                          : '查看 ${reply.replyCount} 条回复',
                    ),
                  ),
                ),
              ),
            if (_expandedReplies.contains(reply.id))
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(left: 39, top: 4),
                padding: const EdgeInsets.fromLTRB(10, 4, 6, 7),
                decoration: BoxDecoration(
                  color: colors.surfaceContainerHighest.withValues(alpha: .45),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    if (_childrenLoading.contains(reply.id))
                      const Padding(
                        padding: EdgeInsets.all(8),
                        child: CircularProgressIndicator(),
                      ),
                    for (final child in _replyChildren[reply.id] ?? [])
                      _buildChildReply(child),
                    if (_childrenHasMore.contains(reply.id) ||
                        !_replyChildren.containsKey(reply.id))
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton(
                          key: ValueKey('forum-children-more-${reply.id}'),
                          onPressed: _childrenLoading.contains(reply.id)
                              ? null
                              : () => _loadReplyChildren(
                                  reply.id,
                                  reset: !_replyChildren.containsKey(reply.id),
                                ),
                          style: _replyActionStyle,
                          child: const Text('加载更多回复'),
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

  ButtonStyle get _replyActionStyle => TextButton.styleFrom(
    minimumSize: const Size(40, 40),
    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 8),
    textStyle: const TextStyle(fontSize: 10),
    foregroundColor: Theme.of(context).colorScheme.onSurfaceVariant,
  );

  Widget _buildChildReply(ForumReply child) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CampusAuthorAvatar(
            author: child.author,
            radius: 12,
            repository: widget.repository,
          ),
          const SizedBox(width: 7),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CampusAuthorName(
                  author: child.author,
                  style: TextStyle(
                    fontSize: 11,
                    color: colors.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  child.body,
                  style: const TextStyle(fontSize: 12, height: 1.5),
                ),
                const SizedBox(height: 4),
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      campusFormatTime(child.createdAt),
                      style: TextStyle(
                        fontSize: 9,
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                    TextButton.icon(
                      key: ValueKey('forum-reply-like-${child.id}'),
                      onPressed: _replyLikeSubmitting.contains(child.id)
                          ? null
                          : () => _toggleReplyLike(child),
                      style: _replyActionStyle,
                      icon: Icon(
                        child.liked
                            ? Icons.thumb_up_alt_rounded
                            : Icons.thumb_up_alt_outlined,
                        size: 14,
                      ),
                      label: Text('${child.likeCount}'),
                    ),
                    if (child.canDelete)
                      IconButton(
                        key: ValueKey('forum-reply-delete-${child.id}'),
                        tooltip: '删除回复',
                        onPressed: _replyDeleting.contains(child.id)
                            ? null
                            : () => _deleteReply(child),
                        icon: const Icon(Icons.delete_outline, size: 17),
                      ),
                    IconButton(
                      tooltip: '举报回复',
                      onPressed: () => _report('forum_reply', child.id),
                      icon: const Icon(Icons.flag_outlined, size: 17),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
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
