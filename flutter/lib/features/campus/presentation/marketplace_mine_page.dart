import 'dart:async';

import 'package:chengxin_youyou/features/campus/data/campus_repository.dart';
import 'package:chengxin_youyou/features/campus/models/campus_models.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../ui/components/page_layout.dart';
import 'campus_widgets.dart';

class MarketplaceMinePage extends StatefulWidget {
  const MarketplaceMinePage({
    super.key,
    required this.repository,
    this.initialType = 'sell',
  });

  final CampusRepository? repository;
  final String initialType;

  @override
  State<MarketplaceMinePage> createState() => _MarketplaceMinePageState();
}

class _MarketplaceMinePageState extends State<MarketplaceMinePage> {
  final _searchController = TextEditingController();
  List<CampusListing> _items = [];
  String _type = 'sell';
  String _submittedQuery = '';
  String? _cursor;
  String? _error;
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = false;
  int _requestVersion = 0;

  @override
  void initState() {
    super.initState();
    _type = widget.initialType == 'wanted' ? 'wanted' : 'sell';
    unawaited(_load(reset: true));
  }

  @override
  void dispose() {
    _requestVersion++;
    _searchController.dispose();
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
        throw const CampusRepositoryException('二手服务暂时不可用。');
      }
      final page = await repository.listListings(
        mine: true,
        type: _type,
        query: _submittedQuery,
        cursor: reset ? null : _cursor,
      );
      if (!mounted || version != _requestVersion) return;
      final values = <String, CampusListing>{};
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

  void _changeType(String value) {
    if (_type == value) return;
    setState(() {
      _type = value;
      _cursor = null;
    });
    unawaited(_load(reset: true));
  }

  void _search() {
    setState(() {
      _submittedQuery = _searchController.text.trim();
      _cursor = null;
    });
    unawaited(_load(reset: true));
  }

  @override
  Widget build(BuildContext context) => PageScaffold(
    title: _type == 'wanted' ? '我的求购' : '我的二手发布',
    actions: [
      IconButton(
        tooltip: _type == 'wanted' ? '发布求购' : '发布闲置',
        onPressed: () => context.pushNamed(
          'marketplace-create',
          queryParameters: {'type': _type},
        ),
        icon: const Icon(Icons.add_rounded),
      ),
    ],
    child: Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 6),
          child: TextField(
            controller: _searchController,
            maxLength: 50,
            buildCounter:
                (_, {required currentLength, required isFocused, maxLength}) =>
                    null,
            textInputAction: TextInputAction.search,
            onSubmitted: (_) => _search(),
            decoration: InputDecoration(
              hintText: _type == 'wanted' ? '搜索我的求购' : '搜索我的发布',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: _searchController.text.isEmpty
                  ? null
                  : IconButton(
                      onPressed: () {
                        _searchController.clear();
                        _search();
                      },
                      icon: const Icon(Icons.close_rounded),
                    ),
            ),
            onChanged: (_) => setState(() {}),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              _TypeChip(
                value: 'sell',
                selected: _type,
                label: '出售',
                onSelected: _changeType,
              ),
              _TypeChip(
                value: 'wanted',
                selected: _type,
                label: '求购',
                onSelected: _changeType,
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: _loading ? null : () => _load(reset: true),
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('刷新'),
              ),
            ],
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () => _load(reset: true),
            child: _loading && _items.isEmpty
                ? CampusPageState(
                    title: _type == 'wanted' ? '正在加载我的求购' : '正在加载我的发布',
                    loading: true,
                  )
                : _error != null && _items.isEmpty
                ? CampusPageState(
                    title: '暂时无法加载',
                    description: _error,
                    actionLabel: '重新加载',
                    onAction: () => _load(reset: true),
                  )
                : _items.isEmpty
                ? CampusPageState(
                    title: _submittedQuery.isEmpty
                        ? (_type == 'wanted' ? '还没有发布求购' : '还没有发布商品')
                        : '没有找到相关内容',
                    description: _submittedQuery.isEmpty
                        ? '发布内容后会在这里显示。'
                        : '换个关键词试试。',
                    actionLabel: _submittedQuery.isEmpty ? '立即发布' : '清空搜索',
                    onAction: _submittedQuery.isEmpty
                        ? () => context.pushNamed(
                            'marketplace-create',
                            queryParameters: {'type': _type},
                          )
                        : () {
                            _searchController.clear();
                            _search();
                          },
                  )
                : ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
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
                      for (final item in _items)
                        _ListingTile(item: item, repository: widget.repository),
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
}

class _TypeChip extends StatelessWidget {
  const _TypeChip({
    required this.value,
    required this.selected,
    required this.label,
    required this.onSelected,
  });
  final String value;
  final String selected;
  final String label;
  final ValueChanged<String> onSelected;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(right: 6),
    child: ChoiceChip(
      label: Text(label),
      selected: value == selected,
      onSelected: (_) => onSelected(value),
    ),
  );
}

class _ListingTile extends StatelessWidget {
  const _ListingTile({required this.item, required this.repository});
  final CampusListing item;
  final CampusRepository? repository;
  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.only(bottom: 10),
    child: ListTile(
      onTap: () => context.pushNamed(
        'marketplace-item',
        pathParameters: {'itemId': item.id},
        queryParameters: {'type': item.listingType},
      ),
      contentPadding: const EdgeInsets.all(12),
      leading: CampusAssetImage(
        assetId: item.imageAssetId,
        repository: repository,
        height: 62,
        width: 62,
        fallback: Icons.shopping_bag_outlined,
      ),
      title: Text(item.title, maxLines: 2, overflow: TextOverflow.ellipsis),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 5),
        child: Text(
          '${campusLabel(item.campus)} · ${item.listingType == 'wanted' ? '预算 ' : ''}¥${campusFormatPrice(item.priceCents)}',
        ),
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            listingStatusLabel(item),
            style: Theme.of(context).textTheme.labelMedium,
          ),
          const Icon(Icons.chevron_right_rounded),
        ],
      ),
    ),
  );
}
