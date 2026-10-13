import 'package:chengxin_youyou/features/campus/data/campus_repository.dart';
import 'package:chengxin_youyou/features/campus/models/campus_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../../ui/components/page_layout.dart';
import 'campus_widgets.dart';

class MarketplaceItemPage extends StatefulWidget {
  const MarketplaceItemPage({
    super.key,
    required this.repository,
    required this.itemId,
  });

  final CampusRepository? repository;
  final String itemId;

  @override
  State<MarketplaceItemPage> createState() => _MarketplaceItemPageState();
}

class _MarketplaceItemPageState extends State<MarketplaceItemPage> {
  CampusListing? _item;
  CampusContact? _contact;
  String? _error;
  String? _actionError;
  String? _copyMessage;
  bool _loading = true;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
      _contact = null;
    });
    try {
      final item = await widget.repository!.getListing(widget.itemId);
      if (mounted) setState(() => _item = item);
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _revealContact() async {
    final item = _item;
    if (item == null || _busy || item.status != 'on_sale') return;
    if (_contact != null) return;
    setState(() {
      _busy = true;
      _actionError = null;
    });
    try {
      final contact = await widget.repository!.revealContact(item.id);
      if (mounted) setState(() => _contact = contact);
    } catch (error) {
      if (mounted) {
        setState(() => _actionError = error.toString());
        if (error is CampusRepositoryException &&
            (error.statusCode == 404 || error.statusCode == 409)) {
          await _load();
        }
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _changeStatus(String status) async {
    final item = _item;
    final repository = widget.repository;
    if (item == null || repository == null || _busy) return;
    setState(() {
      _busy = true;
      _actionError = null;
    });
    try {
      final updated = await repository.updateListingStatus(
        itemId: item.id,
        status: status,
        expectedVersion: item.version,
      );
      if (mounted) setState(() => _item = updated);
    } catch (error) {
      if (mounted) {
        setState(() => _actionError = error.toString());
        if (error is CampusRepositoryException && error.statusCode == 409) {
          await _load();
        }
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _copyContact() async {
    final contact = _contact;
    if (contact == null) return;
    try {
      await Clipboard.setData(ClipboardData(text: contact.value));
      if (mounted) setState(() => _copyMessage = '已复制联系方式');
    } catch (_) {
      if (mounted) setState(() => _copyMessage = '复制失败，请长按联系方式手动复制');
    }
  }

  @override
  Widget build(BuildContext context) {
    final item = _item;
    final wanted = item?.listingType == 'wanted';
    return PageScaffold(
      title: wanted ? '求购详情' : '商品详情',
      actions: [
        if (item?.isMine == true)
          TextButton(
            onPressed: () => context.pushNamed(
              'marketplace-mine',
              queryParameters: {'type': item!.listingType},
            ),
            child: const Text('我的'),
          ),
      ],
      bottomNavigationBar: item == null || item.isMine
          ? null
          : SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: FilledButton(
                  onPressed: _busy || item.status != 'on_sale'
                      ? null
                      : _revealContact,
                  child: Text(
                    item.status != 'on_sale'
                        ? listingStatusLabel(item)
                        : _busy
                        ? '正在获取联系方式…'
                        : _contact != null
                        ? (wanted ? '查看求购者联系方式' : '查看卖家联系方式')
                        : wanted
                        ? '我有闲置'
                        : '我想购买',
                  ),
                ),
              ),
            ),
      child: _loading && item == null
          ? CampusPageState(title: wanted ? '正在加载求购' : '正在加载商品', loading: true)
          : _error != null && item == null
          ? CampusPageState(
              title: '暂时无法查看',
              description: _error,
              actionLabel: '重新加载',
              onAction: _load,
            )
          : item == null
          ? const CampusPageState(title: '内容不存在')
          : RefreshIndicator(onRefresh: _load, child: _buildContent(item)),
    );
  }

  Widget _buildContent(CampusListing item) {
    final wanted = item.listingType == 'wanted';
    final published = DateTime.tryParse(item.createdAt)?.toLocal();
    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 28),
      children: [
        if (item.imageAssetId != null)
          CampusAssetImage(
            assetId: item.imageAssetId,
            repository: widget.repository,
            width: double.infinity,
            height: 230,
            radius: 12,
            fit: BoxFit.contain,
            fallback: Icons.shopping_bag_outlined,
          ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${wanted ? '预算 ' : ''}¥${campusFormatPrice(item.priceCents)}',
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(
                              color: Theme.of(context).colorScheme.primary,
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                    ),
                    Chip(label: Text(listingStatusLabel(item))),
                  ],
                ),
                const SizedBox(height: 8),
                Text(item.title, style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 8),
                Text(
                  '${campusLabel(item.campus)} · ${published == null ? '' : '${published.year}/${published.month}/${published.day} 发布'}',
                ),
                const SizedBox(height: 14),
                Text(
                  item.description.isEmpty ? '发布者没有填写描述。' : item.description,
                ),
                const Divider(height: 28),
                Row(
                  children: [
                    CampusAuthorAvatar(author: item.seller),
                    const SizedBox(width: 10),
                    Expanded(child: Text(item.seller.displayName)),
                    const SizedBox(width: 8),
                    Text(
                      item.isMine
                          ? '我发布的'
                          : wanted
                          ? '求购者'
                          : '卖家',
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        if (_contact != null)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    wanted ? '求购者联系方式' : '卖家联系方式',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 10),
                  SelectableText(
                    '${contactLabel(_contact!.type)}：${_contact!.value}',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: _copyContact,
                      icon: const Icon(Icons.copy_rounded),
                      label: const Text('复制联系方式'),
                    ),
                  ),
                  Text(
                    _copyMessage ??
                        (wanted
                            ? '联系求购者确认需求和交易方式。获取联系方式不代表已成交。'
                            : '联系卖家确认商品情况和交易方式。获取联系方式不代表已预订或成交。'),
                  ),
                ],
              ),
            ),
          ),
        if (item.isMine) _buildOwnerActions(item),
        const Padding(
          padding: EdgeInsets.all(8),
          child: Text('买卖双方自行联系、约定交易。本版本暂不支持在线支付。'),
        ),
        if (_actionError != null)
          Text(
            _actionError!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
      ],
    );
  }

  Widget _buildOwnerActions(CampusListing item) {
    final wanted = item.listingType == 'wanted';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              wanted ? '管理求购' : '管理商品',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 6),
            Text(
              item.status == 'sold'
                  ? (wanted ? '已求到物品，不再出现在求购列表中。' : '商品已售出，不再出现在二手列表中。')
                  : (wanted ? '求到物品后，请标记已求到。' : '交易完成后，请标记已售出。'),
            ),
            const SizedBox(height: 12),
            if (item.status != 'sold')
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton(
                    onPressed: _busy
                        ? null
                        : () => _changeStatus(
                            item.status == 'on_sale' ? 'withdrawn' : 'on_sale',
                          ),
                    child: Text(
                      item.status == 'on_sale'
                          ? (wanted ? '关闭求购' : '下架商品')
                          : (wanted ? '重新开启求购' : '重新上架'),
                    ),
                  ),
                  FilledButton.tonal(
                    onPressed: _busy ? null : () => _changeStatus('sold'),
                    child: Text(wanted ? '标记已求到' : '标记已售出'),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
