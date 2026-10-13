import 'dart:async';

import 'package:chengxin_youyou/features/campus/data/campus_repository.dart';
import 'package:chengxin_youyou/features/campus/models/campus_models.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../ui/components/page_layout.dart';
import 'campus_widgets.dart';

class RatingsMinePage extends StatefulWidget {
  const RatingsMinePage({super.key, required this.repository});
  final CampusRepository? repository;

  @override
  State<RatingsMinePage> createState() => _RatingsMinePageState();
}

class _RatingsMinePageState extends State<RatingsMinePage> {
  static const _kinds = <(String, String)>[
    ('boards', '板块'),
    ('items', '对象'),
    ('votes', '评分'),
    ('comments', '评论'),
  ];

  List<CampusMineEntry> _entries = [];
  String _kind = 'boards';
  String? _cursor;
  String? _error;
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = false;
  int _requestVersion = 0;

  @override
  void initState() {
    super.initState();
    unawaited(_load(reset: true));
  }

  @override
  void dispose() {
    _requestVersion++;
    super.dispose();
  }

  Future<void> _load({required bool reset}) async {
    final repository = widget.repository;
    final version = ++_requestVersion;
    setState(() {
      _loading = reset;
      _loadingMore = !reset;
      _error = null;
    });
    try {
      if (repository == null) {
        throw const CampusRepositoryException('评分服务暂时不可用。');
      }
      final page = await repository.listMyRatingContent(
        kind: _kind,
        cursor: reset ? null : _cursor,
      );
      if (!mounted || version != _requestVersion) return;
      setState(() {
        _entries = reset ? page.items : [..._entries, ...page.items];
        _cursor = page.nextCursor;
        _hasMore = page.hasMore;
      });
    } catch (error) {
      if (mounted && version == _requestVersion) {
        setState(() => _error = error.toString());
      }
    } finally {
      if (mounted && version == _requestVersion) {
        setState(() {
          _loading = false;
          _loadingMore = false;
        });
      }
    }
  }

  void _changeKind(String value) {
    if (_kind == value) return;
    setState(() {
      _kind = value;
      _cursor = null;
    });
    unawaited(_load(reset: true));
  }

  @override
  Widget build(BuildContext context) => PageScaffold(
    title: '我的评分内容',
    child: Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: PageSegmentedControl<String>(
            values: {for (final entry in _kinds) entry.$1: entry.$2},
            selected: _kind,
            onChanged: _changeKind,
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () => _load(reset: true),
            child: _loading && _entries.isEmpty
                ? const CampusPageState(title: '正在加载我的内容', loading: true)
                : _error != null && _entries.isEmpty
                ? CampusPageState(
                    title: '暂时无法加载',
                    description: _error,
                    actionLabel: '重新加载',
                    onAction: () => _load(reset: true),
                  )
                : _entries.isEmpty
                ? const CampusPageState(
                    title: '这里还没有内容',
                    description: '参与评分后，你的记录会出现在这里。',
                  )
                : ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                    children: [
                      if (_error != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Text(
                            _error!,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                            ),
                          ),
                        ),
                      for (final entry in _entries) _buildEntry(entry),
                      if (_hasMore)
                        Center(
                          child: OutlinedButton(
                            onPressed: _loadingMore
                                ? null
                                : () => _load(reset: false),
                            child: Text(_loadingMore ? '正在加载…' : '加载更多'),
                          ),
                        ),
                    ],
                  ),
          ),
        ),
      ],
    ),
  );

  Widget _buildEntry(CampusMineEntry entry) {
    if (entry.board case final board?) {
      return Card(
        margin: const EdgeInsets.only(bottom: 10),
        child: ListTile(
          onTap: () => context.pushNamed(
            'rating-board',
            pathParameters: {'boardId': board.id},
          ),
          leading: CampusAssetImage(
            assetId: board.coverAssetId,
            repository: widget.repository,
            height: 54,
            width: 54,
            fallback: Icons.forum_outlined,
          ),
          title: Text(board.title),
          subtitle: Text(
            '${board.itemCount} 个评分对象 · ${board.ratingCount} 人次评分',
          ),
          trailing: const Icon(Icons.chevron_right_rounded),
        ),
      );
    }
    if (entry.item case final item?) {
      final score = item.rating.score;
      return Card(
        margin: const EdgeInsets.only(bottom: 10),
        child: ListTile(
          onTap: () => context.pushNamed(
            'rating-item',
            pathParameters: {'itemId': item.id},
          ),
          leading: CampusAssetImage(
            assetId: item.imageAssetId,
            repository: widget.repository,
            height: 54,
            width: 54,
            fallback: Icons.storefront_outlined,
          ),
          title: Text(item.name),
          subtitle: Text(
            '${item.rating.count} 人评分 · ${campusFormatTime(item.createdAt)}',
          ),
          trailing: Text(score == null ? '—' : score.toStringAsFixed(1)),
        ),
      );
    }
    final comment = entry.comment;
    if (comment == null) return const SizedBox.shrink();
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        onTap: () => context.pushNamed(
          'rating-item',
          pathParameters: {'itemId': comment.itemId},
        ),
        leading: CampusAuthorAvatar(author: comment.author),
        title: Text(comment.body, maxLines: 3, overflow: TextOverflow.ellipsis),
        subtitle: Text('${campusFormatTime(comment.createdAt)} · 查看对象'),
        trailing: const Icon(Icons.chevron_right_rounded),
      ),
    );
  }
}
