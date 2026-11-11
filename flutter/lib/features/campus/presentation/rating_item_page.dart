import 'dart:async';

import 'package:chengxin_youyou/features/campus/data/campus_repository.dart';
import 'package:chengxin_youyou/features/campus/models/campus_models.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../ui/components/page_layout.dart';
import 'campus_theme.dart';
import '../../../ui/components/page_menu.dart';
import '../../../ui/components/page_selection.dart';
import 'campus_report_dialog.dart';
import 'campus_widgets.dart';

class RatingItemPage extends StatefulWidget {
  const RatingItemPage({
    super.key,
    required this.repository,
    required this.itemId,
  });

  final CampusRepository? repository;
  final String itemId;

  @override
  State<RatingItemPage> createState() => _RatingItemPageState();
}

class _RatingItemPageState extends State<RatingItemPage> {
  final _commentController = TextEditingController();
  final _commentFocusNode = FocusNode();
  CampusRatingItemDetail? _detail;
  List<CampusComment> _comments = [];
  final Map<String, List<CampusComment>> _replies = {};
  final Map<String, String?> _replyCursors = {};
  final Set<String> _replyHasMore = {};
  final Set<String> _replyLoading = {};
  final Set<String> _expandedReplies = {};
  CampusComment? _replyTarget;
  CampusUserRating? _myRating;
  CampusRatingSummary? _summary;
  String _commentSort = 'newest';
  String? _commentCursor;
  String? _error;
  String? _commentError;
  String? _ratingError;
  String _commentRequestId = createCampusRequestId();
  int _commentCount = 0;
  int _selectedStars = 0;
  bool _loading = true;
  bool _commentsLoading = false;
  bool _ratingSubmitting = false;
  bool _commentSubmitting = false;
  bool _hasMoreComments = false;
  int _commentRequestVersion = 0;

  CampusUserRating? get _activeRating =>
      _myRating?.status == 'active' ? _myRating : null;

  @override
  void initState() {
    super.initState();
    unawaited(_loadPage());
    unawaited(_loadComments(reset: true));
  }

  @override
  void dispose() {
    _commentRequestVersion++;
    _commentController.dispose();
    _commentFocusNode.dispose();
    super.dispose();
  }

  Future<void> _loadPage() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final detail = await widget.repository!.getRatingItem(widget.itemId);
      if (!mounted) return;
      setState(() {
        _detail = detail;
        _myRating = detail.myRating;
        _summary = detail.item.rating;
        _commentCount = detail.commentCount;
        _selectedStars = detail.myRating?.status == 'active'
            ? detail.myRating!.stars
            : 0;
      });
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _submitRating() async {
    final detail = _detail;
    final repository = widget.repository;
    if (detail == null ||
        repository == null ||
        !detail.canRate ||
        _selectedStars < 1 ||
        _selectedStars == (_activeRating?.stars ?? 0) ||
        _ratingSubmitting) {
      return;
    }
    setState(() {
      _ratingSubmitting = true;
      _ratingError = null;
    });
    try {
      final result = await repository.submitRating(
        itemId: widget.itemId,
        stars: _selectedStars,
        expectedVersion: _myRating?.version ?? 0,
      );
      if (!mounted) return;
      setState(() {
        _summary = result.rating;
        _myRating = result.myRating;
      });
    } catch (error) {
      if (mounted) setState(() => _ratingError = error.toString());
    } finally {
      if (mounted) setState(() => _ratingSubmitting = false);
    }
  }

  Future<void> _withdrawRating() async {
    final rating = _activeRating;
    final repository = widget.repository;
    if (rating == null || repository == null || _ratingSubmitting) return;
    setState(() {
      _ratingSubmitting = true;
      _ratingError = null;
    });
    try {
      final result = await repository.withdrawRating(
        itemId: widget.itemId,
        expectedVersion: rating.version,
      );
      if (!mounted) return;
      setState(() {
        _summary = result.rating;
        _myRating = null;
        _selectedStars = 0;
      });
    } catch (error) {
      if (mounted) setState(() => _ratingError = error.toString());
    } finally {
      if (mounted) setState(() => _ratingSubmitting = false);
    }
  }

  Future<void> _loadComments({required bool reset}) async {
    final repository = widget.repository;
    if (!reset && !_hasMoreComments) return;
    final version = ++_commentRequestVersion;
    setState(() {
      _commentsLoading = true;
      _commentError = null;
    });
    try {
      if (repository == null) {
        throw const CampusRepositoryException('评论服务暂时不可用。');
      }
      final page = await repository.listComments(
        itemId: widget.itemId,
        sort: _commentSort,
        cursor: reset ? null : _commentCursor,
      );
      if (!mounted || version != _commentRequestVersion) return;
      final combined = <String, CampusComment>{};
      if (!reset) {
        for (final comment in _comments) {
          combined[comment.id] = comment;
        }
      }
      for (final comment in page.items) {
        combined[comment.id] = comment;
      }
      setState(() {
        if (reset) {
          _replies.clear();
          _replyCursors.clear();
          _replyHasMore.clear();
          _replyLoading.clear();
          _expandedReplies.clear();
        }
        _comments = combined.values.toList();
        _commentCursor = page.nextCursor;
        _hasMoreComments = page.hasMore;
      });
      _ensureFirstReplies();
    } catch (error) {
      if (mounted && version == _commentRequestVersion) {
        setState(() => _commentError = error.toString());
      }
    } finally {
      if (mounted && version == _commentRequestVersion) {
        setState(() => _commentsLoading = false);
      }
    }
  }

  Future<void> _submitComment() async {
    final detail = _detail;
    final repository = widget.repository;
    final body = _commentController.text.trim();
    if (detail == null ||
        repository == null ||
        !detail.canComment ||
        body.isEmpty ||
        body.characters.length > 1000 ||
        _commentSubmitting) {
      return;
    }
    setState(() {
      _commentSubmitting = true;
      _commentError = null;
    });
    final replyTarget = _replyTarget;
    try {
      final created = await repository.createComment(
        itemId: widget.itemId,
        body: body,
        parentId: replyTarget?.id,
        requestId: _commentRequestId,
      );
      if (!mounted) return;
      setState(() {
        if (replyTarget case final target?) {
          // 已加载的回复列表才可直接追加；未加载时保留可请求的状态。
          if (_replies.containsKey(target.id)) {
            final replies = [..._replies[target.id]!];
            final index = replies.indexWhere((item) => item.id == created.id);
            if (index >= 0) {
              replies[index] = created;
            } else {
              replies.add(created);
            }
            _replies[target.id] = replies;
            _expandedReplies.add(target.id);
          }
          final index = _comments.indexWhere((item) => item.id == target.id);
          if (index >= 0) {
            _comments[index] = _copyComment(
              _comments[index],
              replyCount: _comments[index].replyCount + 1,
            );
          }
        } else {
          if (_commentSort == 'newest') {
            _comments.insert(0, created);
          } else {
            _comments.add(created);
          }
          _commentCount++;
        }
        _replyTarget = null;
        _commentController.clear();
        _commentRequestId = createCampusRequestId();
      });
      if (replyTarget != null && !_replies.containsKey(replyTarget.id)) {
        await _toggleReplies(replyTarget);
      }
    } catch (error) {
      if (mounted) setState(() => _commentError = error.toString());
    } finally {
      if (mounted) setState(() => _commentSubmitting = false);
    }
  }

  void _ensureFirstReplies() {
    for (final comment in _comments) {
      if (comment.replyCount > 0 &&
          !_replies.containsKey(comment.id) &&
          !_replyLoading.contains(comment.id)) {
        unawaited(_loadReplies(comment.id, reset: true));
      }
    }
  }

  Future<void> _loadReplies(String commentId, {required bool reset}) async {
    final repository = widget.repository;
    if (repository == null ||
        _replyLoading.contains(commentId) ||
        (!reset && !_replyHasMore.contains(commentId))) {
      return;
    }
    setState(() {
      _replyLoading.add(commentId);
      _commentError = null;
    });
    try {
      final page = await repository.listReplies(
        commentId: commentId,
        cursor: reset ? null : _replyCursors[commentId],
      );
      if (!mounted) return;
      final combined = <String, CampusComment>{
        if (!reset)
          for (final reply in _replies[commentId] ?? []) reply.id: reply,
        for (final reply in page.items) reply.id: reply,
      };
      setState(() {
        _replies[commentId] = combined.values.toList();
        _replyCursors[commentId] = page.nextCursor;
        if (page.hasMore) {
          _replyHasMore.add(commentId);
        } else {
          _replyHasMore.remove(commentId);
        }
      });
    } catch (error) {
      if (mounted) setState(() => _commentError = error.toString());
    } finally {
      if (mounted) setState(() => _replyLoading.remove(commentId));
    }
  }

  Future<void> _toggleReplies(CampusComment comment) async {
    if (_expandedReplies.remove(comment.id)) {
      setState(() {});
      return;
    }
    setState(() => _expandedReplies.add(comment.id));
    if (!_replies.containsKey(comment.id) &&
        !_replyLoading.contains(comment.id)) {
      await _loadReplies(comment.id, reset: true);
    }
  }

  Future<void> _deleteComment(CampusComment comment, {String? rootId}) async {
    if (!comment.canDelete || widget.repository == null) return;
    try {
      await widget.repository!.deleteComment(
        commentId: comment.id,
        expectedVersion: comment.version,
      );
      if (!mounted) return;
      setState(() {
        if (rootId != null) {
          _replies[rootId] = (_replies[rootId] ?? [])
              .where((item) => item.id != comment.id)
              .toList();
        } else {
          _comments.removeWhere((item) => item.id == comment.id);
          _commentCount = (_commentCount - 1).clamp(0, 1 << 30);
        }
      });
    } catch (error) {
      if (mounted) setState(() => _commentError = error.toString());
    }
  }

  Future<void> _report(String type, String id) async {
    final reason = await askCampusReportReason(context);
    if (reason == null || widget.repository == null) return;
    try {
      await widget.repository!.report(
        targetType: type,
        targetId: id,
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
  Widget build(BuildContext context) =>
      CampusThemeBuilder(builder: _buildScaffold);

  Widget _buildScaffold(BuildContext context) {
    final detail = _detail;
    return PageScaffold(
      title: '评分详情',
      backgroundColor: context.campusColors.canvas,
      actions: [
        if (detail != null)
          IconButton(
            tooltip: '举报对象',
            onPressed: () => _report('item', widget.itemId),
            icon: const Icon(Icons.flag_outlined),
          ),
      ],
      bottomNavigationBar: detail == null || !detail.canComment
          ? null
          : SafeArea(
              top: false,
              child: Material(
                elevation: 0,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(10, 6, 10, 6),
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
                              key: const ValueKey('rating-comment-input'),
                              controller: _commentController,
                              focusNode: _commentFocusNode,
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
                                    ? '写下你的看法…'
                                    : '写下回复…',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton.filled(
                            onPressed: _commentSubmitting
                                ? null
                                : _submitComment,
                            tooltip: '发送评论',
                            icon: _commentSubmitting
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
          ? const CampusPageState(title: '正在加载评分详情', loading: true)
          : _error != null && detail == null
          ? CampusPageState(
              title: '无法打开这个评分对象',
              description: _error,
              actionLabel: '重新加载',
              onAction: _loadPage,
            )
          : detail == null
          ? const CampusPageState(title: '评分对象不存在')
          : _buildContent(detail),
    );
  }

  Widget _buildContent(CampusRatingItemDetail detail) => RefreshIndicator(
    onRefresh: () async {
      await Future.wait([_loadPage(), _loadComments(reset: true)]);
    },
    child: ListView(
      padding: const EdgeInsets.fromLTRB(10, 0, 10, 20),
      children: [
        _ItemHero(
          item: detail.item,
          boardTitle: detail.boardTitle,
          repository: widget.repository,
        ),
        const SizedBox(height: 8),
        TextButton.icon(
          onPressed: () => context.pushNamed(
            'rating-board',
            pathParameters: {'boardId': detail.item.boardId},
          ),
          icon: const Icon(Icons.arrow_back_rounded, size: 16),
          label: Text(detail.boardTitle),
          style: TextButton.styleFrom(
            alignment: Alignment.centerLeft,
            minimumSize: const Size(0, 34),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            padding: const EdgeInsets.symmetric(vertical: 4),
            textStyle: const TextStyle(fontSize: 12.5),
          ),
        ),
        CampusRatingSummaryCard(
          key: const ValueKey('rating-summary-card'),
          summary: _summary ?? detail.item.rating,
        ),
        const SizedBox(height: 8),
        _buildRatingAction(detail),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              child: Text(
                '全部评论 / $_commentCount',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            PageDropdown<String>(
              value: _commentSort,
              semanticLabel: '评论排序',
              values: const {'newest': '最新', 'oldest': '最早'},
              onChanged: (value) {
                if (value == null) return;
                setState(() {
                  _commentSort = value;
                  _commentCursor = null;
                });
                unawaited(_loadComments(reset: true));
              },
            ),
          ],
        ),
        if (_commentError != null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              _commentError!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        if (_commentsLoading && _comments.isEmpty)
          const CampusPageState(title: '正在加载评论', loading: true)
        else if (_comments.isEmpty)
          const CampusPageState(title: '还没有评论', description: '说说你对这个对象的看法。')
        else ...[
          for (final comment in _comments) _buildComment(comment),
          if (_hasMoreComments)
            Center(
              child: OutlinedButton(
                onPressed: _commentsLoading
                    ? null
                    : () => _loadComments(reset: false),
                child: Text(_commentsLoading ? '正在加载…' : '加载更多评论'),
              ),
            ),
        ],
      ],
    ),
  );

  Widget _buildRatingAction(CampusRatingItemDetail detail) {
    final active = _activeRating;
    final changed = _selectedStars != (active?.stars ?? 0);
    return Card(
      key: const ValueKey('rating-action-card'),
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _myRating?.status == 'excluded'
                  ? '评分已排除'
                  : active == null
                  ? '立即评分'
                  : '已评 ${active.stars * 2} 分',
              style: const TextStyle(
                fontSize: 14.5,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 2),
            Wrap(
              spacing: 0,
              children: [
                for (var stars = 1; stars <= 5; stars++)
                  IconButton(
                    tooltip: '$stars 星',
                    onPressed: _ratingSubmitting || !detail.canRate
                        ? null
                        : () => setState(() => _selectedStars = stars),
                    constraints: const BoxConstraints.tightFor(
                      width: 34,
                      height: 34,
                    ),
                    padding: EdgeInsets.zero,
                    icon: Icon(
                      stars <= _selectedStars
                          ? Icons.star_rounded
                          : Icons.star_outline_rounded,
                      color: Colors.amber.shade700,
                      size: 25,
                    ),
                  ),
              ],
            ),
            if (_myRating?.status == 'excluded')
              const Text('这份评分当前为只读状态，如有疑问请联系管理员。'),
            if (_ratingError != null)
              Text(
                _ratingError!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            if (active != null || changed)
              Wrap(
                spacing: 8,
                children: [
                  if (active != null)
                    OutlinedButton(
                      onPressed: _ratingSubmitting ? null : _withdrawRating,
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(0, 34),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        textStyle: const TextStyle(fontSize: 12),
                      ),
                      child: const Text('撤回评分'),
                    ),
                  if (changed && _selectedStars > 0 && detail.canRate)
                    FilledButton(
                      onPressed: _ratingSubmitting ? null : _submitRating,
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(0, 34),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        textStyle: const TextStyle(fontSize: 12),
                      ),
                      child: Text(
                        _ratingSubmitting
                            ? '正在保存…'
                            : '${active == null ? '提交' : '更新'}评分 · ${_selectedStars * 2} 分',
                      ),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  void _focusCommentComposer() {
    // 等回复目标提示先完成重建，再请求焦点，确保 TextField 已经就位并调起键盘。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _commentFocusNode.requestFocus();
    });
  }

  void _startCommentReply(CampusComment comment) {
    if (_commentSubmitting) return;
    setState(() => _replyTarget = comment);
    _focusCommentComposer();
  }

  Widget _buildComment(CampusComment comment) {
    final colors = Theme.of(context).colorScheme;
    final replies = _replies[comment.id] ?? const <CampusComment>[];
    final expanded = _expandedReplies.contains(comment.id);
    final canExpand =
        comment.replyCount > 1 ||
        replies.length > 1 ||
        _replyHasMore.contains(comment.id);
    final hiddenReplyCount = comment.replyCount > 1
        ? comment.replyCount - 1
        : replies.length - 1;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _startCommentReply(comment),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(2, 6, 0, 2),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CampusAuthorAvatar(
                  author: comment.author,
                  radius: 12,
                  linkToProfile: false,
                ),
                const SizedBox(width: 7),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 6,
                        runSpacing: 2,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          CampusAuthorName(
                            author: comment.author,
                            style: TextStyle(
                              fontSize: 11,
                              color: colors.onSurfaceVariant,
                            ),
                          ),
                          if (comment.starsSnapshot != null)
                            Text(
                              '${comment.starsSnapshot! * 2} 分',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: Colors.amber.shade700,
                              ),
                            ),
                          Text(
                            campusFormatTime(comment.createdAt),
                            style: TextStyle(
                              fontSize: 9,
                              color: colors.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 1),
                      Text(
                        comment.body,
                        style: const TextStyle(fontSize: 13, height: 1.4),
                      ),
                      const SizedBox(height: 1),
                      Wrap(
                        spacing: 2,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          TextButton(
                            onPressed: () => _startCommentReply(comment),
                            style: _commentActionStyle,
                            child: const Text('回复'),
                          ),
                          TextButton(
                            onPressed: () => _report('comment', comment.id),
                            style: _commentActionStyle,
                            child: const Text('举报'),
                          ),
                          if (comment.canDelete)
                            TextButton(
                              onPressed: () => _deleteComment(comment),
                              style: _commentActionStyle,
                              child: const Text('删除'),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (comment.replyCount > 0)
              Padding(
                padding: const EdgeInsets.only(left: 31, top: 2),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (replies.isNotEmpty)
                      _buildCommentReply(replies.first, rootId: comment.id)
                    else if (_replyLoading.contains(comment.id))
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 6),
                        child: SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 1.8),
                        ),
                      )
                    else if (!_replies.containsKey(comment.id))
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton(
                          key: ValueKey('rating-replies-retry-${comment.id}'),
                          onPressed: () =>
                              _loadReplies(comment.id, reset: true),
                          style: _commentActionStyle,
                          child: const Text('重新加载回复'),
                        ),
                      ),
                    if (expanded)
                      for (final reply in replies.skip(1))
                        _buildCommentReply(reply, rootId: comment.id),
                    if (expanded && _replyHasMore.contains(comment.id))
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton(
                          key: ValueKey('rating-replies-more-${comment.id}'),
                          onPressed: _replyLoading.contains(comment.id)
                              ? null
                              : () => _loadReplies(comment.id, reset: false),
                          style: _commentActionStyle,
                          child: const Text('加载更多回复'),
                        ),
                      ),
                    if (canExpand)
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton(
                          key: ValueKey('rating-replies-toggle-${comment.id}'),
                          onPressed: _replyLoading.contains(comment.id)
                              ? null
                              : () => _toggleReplies(comment),
                          style: _commentActionStyle,
                          child: Text(
                            expanded
                                ? '收起回复'
                                : hiddenReplyCount > 0
                                ? '展开其余 $hiddenReplyCount 条回复'
                                : '展开更多回复',
                          ),
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

  ButtonStyle get _commentActionStyle => TextButton.styleFrom(
    minimumSize: const Size(0, 28),
    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
    textStyle: const TextStyle(fontSize: 10),
    foregroundColor: Theme.of(context).colorScheme.onSurfaceVariant,
  );

  Widget _buildCommentReply(CampusComment reply, {required String rootId}) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CampusAuthorAvatar(
            author: reply.author,
            radius: 9,
            linkToProfile: false,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CampusAuthorName(
                  author: reply.author,
                  style: TextStyle(
                    fontSize: 11,
                    color: colors.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  reply.body,
                  style: const TextStyle(fontSize: 11.5, height: 1.35),
                ),
                const SizedBox(height: 2),
                Text(
                  campusFormatTime(reply.createdAt),
                  style: TextStyle(fontSize: 9, color: colors.onSurfaceVariant),
                ),
              ],
            ),
          ),
          PageActionMenu<String>(
            onSelected: (action) {
              if (action == 'report') _report('comment', reply.id);
              if (action == 'delete') _deleteComment(reply, rootId: rootId);
            },
            actions: [
              const PageMenuAction(
                value: 'report',
                label: '举报',
                icon: Icons.flag_outlined,
              ),
              if (reply.canDelete)
                const PageMenuAction(
                  value: 'delete',
                  label: '删除',
                  icon: Icons.delete_outline_rounded,
                  destructive: true,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ItemHero extends StatelessWidget {
  const _ItemHero({
    required this.item,
    required this.boardTitle,
    required this.repository,
  });
  final CampusRatingItem item;
  final String boardTitle;
  final CampusRepository? repository;

  @override
  Widget build(BuildContext context) => CampusHero(
    key: const ValueKey('rating-item-hero'),
    name: item.name,
    description: item.description,
    assetId: item.imageAssetId,
    author: item.creator,
    authorSuffix: '添加',
    repository: repository,
    fallback: Icons.storefront_outlined,
  );
}

CampusComment _copyComment(CampusComment comment, {int? replyCount}) =>
    CampusComment(
      id: comment.id,
      itemId: comment.itemId,
      parentId: comment.parentId,
      author: comment.author,
      body: comment.body,
      starsSnapshot: comment.starsSnapshot,
      replyCount: replyCount ?? comment.replyCount,
      version: comment.version,
      createdAt: comment.createdAt,
      canDelete: comment.canDelete,
    );
