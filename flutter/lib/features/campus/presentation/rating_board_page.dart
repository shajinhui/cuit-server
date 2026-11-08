import 'dart:async';

import 'package:chengxin_youyou/features/campus/data/campus_repository.dart';
import 'package:chengxin_youyou/features/campus/models/campus_models.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../ui/components/page_layout.dart';
import 'campus_theme.dart';
import '../../../ui/components/page_selection.dart';
import 'campus_report_dialog.dart';
import 'campus_widgets.dart';

class RatingBoardPage extends StatefulWidget {
  const RatingBoardPage({
    super.key,
    required this.repository,
    required this.boardId,
  });

  final CampusRepository? repository;
  final String boardId;

  @override
  State<RatingBoardPage> createState() => _RatingBoardPageState();
}

class _RatingBoardPageState extends State<RatingBoardPage> {
  final _searchController = TextEditingController();
  CampusBoard? _board;
  List<CampusRatingItem> _items = [];
  String _sort = 'popular';
  String _submittedQuery = '';
  String? _nextCursor;
  String? _error;
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = false;
  int _version = 0;

  @override
  void initState() {
    super.initState();
    unawaited(_loadBoard());
    unawaited(_loadItems(reset: true));
  }

  @override
  void dispose() {
    _version++;
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadBoard() async {
    try {
      final board = await widget.repository!.getBoard(widget.boardId);
      if (mounted) setState(() => _board = board);
    } catch (error) {
      if (mounted && _board == null) setState(() => _error = error.toString());
    }
  }

  Future<void> _loadItems({required bool reset}) async {
    final repository = widget.repository;
    final version = ++_version;
    setState(() {
      _error = null;
      _loading = reset;
      _loadingMore = !reset;
    });
    try {
      if (repository == null) {
        throw const CampusRepositoryException('评分服务暂时不可用。');
      }
      final page = await repository.listRatingItems(
        boardId: widget.boardId,
        query: _submittedQuery,
        sort: _sort,
        cursor: reset ? null : _nextCursor,
      );
      if (!mounted || version != _version) return;
      final values = <String, CampusRatingItem>{};
      if (!reset) {
        for (final item in _items) {
          values[item.id] = item;
        }
      }
      for (final item in page.items) {
        values[item.id] = item;
      }
      setState(() {
        _items = values.values.toList();
        _nextCursor = page.nextCursor;
        _hasMore = page.hasMore;
      });
    } catch (error) {
      if (mounted && version == _version) {
        setState(() => _error = error.toString());
      }
    } finally {
      if (mounted && version == _version) {
        setState(() {
          _loading = false;
          _loadingMore = false;
        });
      }
    }
  }

  void _search() {
    setState(() {
      _submittedQuery = _searchController.text.trim();
      _nextCursor = null;
    });
    unawaited(_loadItems(reset: true));
  }

  Future<void> _reportBoard() async {
    final reason = await askCampusReportReason(context);
    if (reason == null || widget.repository == null) return;
    try {
      await widget.repository!.report(
        targetType: 'board',
        targetId: widget.boardId,
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
    final board = _board;
    final colors = Theme.of(context).colorScheme;
    return PageScaffold(
      title: '评分板块',
      backgroundColor: campusCanvas,
      actions: [
        if (board != null)
          IconButton(
            tooltip: '举报板块',
            onPressed: _reportBoard,
            icon: const Icon(Icons.flag_outlined),
          ),
      ],
      bottomNavigationBar: board == null
          ? null
          : SafeArea(
              top: false,
              child: Container(
                padding: const EdgeInsets.fromLTRB(14, 9, 14, 10),
                decoration: BoxDecoration(
                  color: colors.surface,
                  border: Border(
                    top: BorderSide(color: campusCardLine, width: .8),
                  ),
                ),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () => context.pushNamed(
                      'rating-create-item',
                      pathParameters: {'boardId': board.id},
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: campusInk,
                      foregroundColor: campusOnInk,
                      minimumSize: const Size(44, 48),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    icon: const Icon(Icons.add_rounded, size: 20),
                    label: const Text('添加评分对象'),
                  ),
                ),
              ),
            ),
      child: RefreshIndicator(
        onRefresh: () async {
          await Future.wait([_loadBoard(), _loadItems(reset: true)]);
        },
        child: ListView(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 28),
          children: [
            if (board != null) ...[
              _BoardHero(board: board, repository: widget.repository),
              const SizedBox(height: 16),
            ],
            TextField(
              controller: _searchController,
              maxLength: 50,
              buildCounter:
                  (
                    _, {
                    required currentLength,
                    required isFocused,
                    maxLength,
                  }) => null,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _search(),
              decoration: InputDecoration(
                hintText: '搜索这个板块的对象',
                hintStyle: TextStyle(
                  fontSize: 13,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                filled: true,
                fillColor: Theme.of(context).colorScheme.surface,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 13,
                ),
                prefixIcon: const Icon(Icons.search_rounded, size: 20),
                suffixIcon: _searchController.text.isEmpty
                    ? null
                    : IconButton(
                        tooltip: '清空搜索',
                        onPressed: () {
                          _searchController.clear();
                          _search();
                        },
                        icon: const Icon(Icons.close_rounded),
                      ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(
                    color: campusCardLine,
                    width: .8,
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(
                    color: campusCardLine,
                    width: .8,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: campusInk, width: 1.1),
                ),
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Text(
                    '全部评分${board == null ? '' : ' / ${board.itemCount}'}',
                    style: const TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -.2,
                    ),
                  ),
                ),
                PageDropdown<String>(
                  value: _sort,
                  semanticLabel: '评分排序',
                  values: const {
                    'popular': '热门',
                    'newest': '最新',
                    'highest': '高分',
                    'lowest': '低分',
                  },
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() {
                      _sort = value;
                      _nextCursor = null;
                    });
                    unawaited(_loadItems(reset: true));
                  },
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (_submittedQuery.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text('搜索：$_submittedQuery'),
              ),
            if (_loading && _items.isEmpty)
              const CampusPageState(title: '正在加载评分对象', loading: true)
            else if (_error != null && _items.isEmpty)
              CampusPageState(
                title: '无法加载这个板块',
                description: _error,
                actionLabel: '重新加载',
                onAction: () {
                  unawaited(_loadBoard());
                  unawaited(_loadItems(reset: true));
                },
              )
            else if (_items.isEmpty)
              CampusPageState(
                title: _submittedQuery.isEmpty ? '还没有评分对象' : '没有找到相关对象',
                description: '你可以为这个板块添加第一个对象。',
                actionLabel: '添加评分对象',
                onAction: () => context.pushNamed(
                  'rating-create-item',
                  pathParameters: {'boardId': widget.boardId},
                ),
              )
            else ...[
              if (_error != null) _InlineCampusError(message: _error!),
              for (final item in _items)
                _RatingItemCard(
                  item: item,
                  repository: widget.repository,
                  onTap: () => context.pushNamed(
                    'rating-item',
                    pathParameters: {'itemId': item.id},
                  ),
                ),
              if (_hasMore)
                Center(
                  child: OutlinedButton(
                    onPressed: _loadingMore
                        ? null
                        : () => _loadItems(reset: false),
                    child: Text(_loadingMore ? '正在加载…' : '加载更多'),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _BoardHero extends StatelessWidget {
  const _BoardHero({required this.board, required this.repository});
  final CampusBoard board;
  final CampusRepository? repository;

  @override
  Widget build(BuildContext context) => CampusHero(
    name: board.title,
    description: board.description,
    assetId: board.coverAssetId,
    author: board.creator,
    authorSuffix: '创建',
    stats: '${board.itemCount} 个对象 · ${board.ratingCount} 人次评分',
    repository: repository,
    fallback: Icons.forum_outlined,
  );
}

class _RatingItemCard extends StatelessWidget {
  const _RatingItemCard({
    required this.item,
    required this.repository,
    required this.onTap,
  });
  final CampusRatingItem item;
  final CampusRepository? repository;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final score = item.rating.score;
    final colors = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: campusCardDecoration(radius: 18),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(18),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(13),
            child: Row(
              children: [
                CampusAssetImage(
                  assetId: item.imageAssetId,
                  repository: repository,
                  height: 68,
                  width: 68,
                  radius: 14,
                  fallback: Icons.storefront_outlined,
                ),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 16,
                          height: 1.3,
                          fontWeight: FontWeight.w600,
                          letterSpacing: -.1,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        item.description.isEmpty
                            ? '${item.rating.count} 人评分'
                            : item.description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          height: 1.45,
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.fromLTRB(10, 7, 10, 8),
                  decoration: BoxDecoration(
                    color: campusCanvas,
                    borderRadius: BorderRadius.circular(13),
                    border: Border.all(color: campusCardLine, width: .7),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        score == null ? '—' : score.toStringAsFixed(1),
                        style: const TextStyle(
                          fontSize: 23,
                          height: 1,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -.5,
                          color: campusInk,
                          fontFeatures: [FontFeature.tabularFigures()],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${item.rating.count} 人评',
                        style: TextStyle(
                          fontSize: 9,
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _InlineCampusError extends StatelessWidget {
  const _InlineCampusError({required this.message});
  final String message;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Text(
      message,
      style: TextStyle(color: Theme.of(context).colorScheme.error),
    ),
  );
}
