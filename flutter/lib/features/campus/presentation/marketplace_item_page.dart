import 'package:chengxin_youyou/features/campus/data/campus_repository.dart';
import 'package:chengxin_youyou/features/campus/models/campus_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../../ui/components/page_layout.dart';
import 'campus_theme.dart';
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
  Widget build(BuildContext context) =>
      CampusThemeBuilder(builder: _buildScaffold);

  Widget _buildScaffold(BuildContext context) {
    final item = _item;
    final wanted = item?.listingType == 'wanted';
    return PageScaffold(
      title: wanted ? '求购详情' : '商品详情',
      backgroundColor: context.campusColors.canvas,
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
              child: Container(
                padding: const EdgeInsets.fromLTRB(16, 9, 16, 9),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  border: Border(
                    top: BorderSide(
                      color: context.campusColors.cardLine,
                      width: .8,
                    ),
                  ),
                ),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _busy || item.status != 'on_sale'
                        ? null
                        : _revealContact,
                    style: FilledButton.styleFrom(
                      backgroundColor: context.campusColors.ink,
                      foregroundColor: context.campusColors.onInk,
                      minimumSize: const Size(44, 50),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
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

  Widget _buildPanel({
    required Widget child,
    EdgeInsetsGeometry padding = const EdgeInsets.all(17),
  }) => Container(
    decoration: campusCardDecoration(context, radius: 18),
    child: Padding(padding: padding, child: child),
  );

  Widget _buildContent(CampusListing item) {
    final wanted = item.listingType == 'wanted';
    final colors = Theme.of(context).colorScheme;
    final published = DateTime.tryParse(item.createdAt)?.toLocal();
    final publishedText = published == null
        ? ''
        : '${published.year}/${published.month}/${published.day} 发布';
    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 30),
      children: [
        if (item.imageAssetId != null)
          Container(
            padding: const EdgeInsets.all(6),
            decoration: campusCardDecoration(context, radius: 20),
            child: Stack(
              children: [
                CampusAssetImage(
                  assetId: item.imageAssetId,
                  repository: widget.repository,
                  width: double.infinity,
                  height: 250,
                  radius: 14,
                  fit: BoxFit.contain,
                  fallback: Icons.shopping_bag_outlined,
                ),
                Positioned(
                  left: 10,
                  top: 10,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: context.campusColors.surface.withValues(
                        alpha: .92,
                      ),
                      borderRadius: BorderRadius.circular(99),
                    ),
                    child: Text(
                      wanted ? '求购' : '闲置',
                      style: const TextStyle(
                        fontSize: 10,
                        height: 1.2,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        if (item.imageAssetId != null) const SizedBox(height: 14),
        _buildPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      '${wanted ? '预算 ' : ''}¥${campusFormatPrice(item.priceCents)}',
                      style: TextStyle(
                        fontSize: 30,
                        height: 1.15,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -.8,
                        color: context.campusColors.ink,
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: context.campusColors.controlSurface,
                      borderRadius: BorderRadius.circular(99),
                    ),
                    child: Text(
                      listingStatusLabel(item),
                      style: TextStyle(
                        fontSize: 10.5,
                        height: 1.2,
                        fontWeight: FontWeight.w600,
                        color: context.campusColors.muted,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                item.title,
                style: const TextStyle(
                  fontSize: 21,
                  height: 1.32,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -.3,
                ),
              ),
              const SizedBox(height: 9),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.location_on_outlined,
                        size: 13,
                        color: colors.onSurfaceVariant,
                      ),
                      const SizedBox(width: 3),
                      Text(
                        campusLabel(item.campus),
                        style: TextStyle(
                          fontSize: 11.5,
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                  if (publishedText.isNotEmpty)
                    Text(
                      publishedText,
                      style: TextStyle(
                        fontSize: 11.5,
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 15),
                child: Divider(height: 1, thickness: .7),
              ),
              Text(
                item.description.isEmpty ? '发布者没有填写描述。' : item.description,
                style: TextStyle(
                  fontSize: 14,
                  height: 1.65,
                  color: item.description.isEmpty
                      ? colors.onSurfaceVariant
                      : colors.onSurface,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: context.campusColors.canvas,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: context.campusColors.cardLine,
                    width: .7,
                  ),
                ),
                child: Row(
                  children: [
                    CampusAuthorAvatar(author: item.seller, radius: 15),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          CampusAuthorName(
                            author: item.seller,
                            style: const TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            item.isMine
                                ? '我发布的'
                                : wanted
                                ? '求购者'
                                : '卖家',
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
              ),
            ],
          ),
        ),
        if (_contact != null) ...[
          const SizedBox(height: 12),
          _buildPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        color: context.campusColors.ink,
                        borderRadius: BorderRadius.circular(9),
                      ),
                      child: Icon(
                        Icons.chat_bubble_outline_rounded,
                        size: 15,
                        color: context.campusColors.onInk,
                      ),
                    ),
                    const SizedBox(width: 9),
                    Text(
                      wanted ? '求购者联系方式' : '卖家联系方式',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 13),
                SelectableText(
                  '${contactLabel(_contact!.type)}：${_contact!.value}',
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -.1,
                  ),
                ),
                const SizedBox(height: 3),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: _copyContact,
                    style: TextButton.styleFrom(
                      foregroundColor: context.campusColors.ink,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                    ),
                    icon: const Icon(Icons.copy_rounded, size: 16),
                    label: const Text('复制联系方式'),
                  ),
                ),
                Text(
                  _copyMessage ??
                      (wanted
                          ? '联系求购者确认需求和交易方式。获取联系方式不代表已成交。'
                          : '联系卖家确认商品情况和交易方式。获取联系方式不代表已预订或成交。'),
                  style: TextStyle(
                    fontSize: 11.5,
                    height: 1.5,
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
        if (item.isMine) ...[
          const SizedBox(height: 12),
          _buildOwnerActions(item),
        ],
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 18, 8, 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.shield_outlined,
                size: 13,
                color: colors.onSurfaceVariant,
              ),
              const SizedBox(width: 5),
              Flexible(
                child: Text(
                  '买卖双方自行联系、约定交易，本版本暂不支持在线支付。',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 10.5,
                    height: 1.4,
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ),
        if (_actionError != null) ...[
          const SizedBox(height: 10),
          Text(
            _actionError!,
            style: TextStyle(color: colors.error, fontSize: 12),
          ),
        ],
      ],
    );
  }

  Widget _buildOwnerActions(CampusListing item) {
    final wanted = item.listingType == 'wanted';
    final colors = Theme.of(context).colorScheme;
    return _buildPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: context.campusColors.controlSurface,
                  borderRadius: BorderRadius.circular(9),
                ),
                child: const Icon(Icons.tune_rounded, size: 16),
              ),
              const SizedBox(width: 9),
              Text(
                wanted ? '管理求购' : '管理商品',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            item.status == 'sold'
                ? (wanted ? '已求到物品，不再出现在求购列表中。' : '商品已售出，不再出现在二手列表中。')
                : (wanted ? '求到物品后，请标记已求到。' : '交易完成后，请标记已售出。'),
            style: TextStyle(
              fontSize: 12,
              height: 1.5,
              color: colors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 13),
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
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(44, 42),
                    foregroundColor: context.campusColors.ink,
                    side: BorderSide(color: context.campusColors.cardLine),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    item.status == 'on_sale'
                        ? (wanted ? '关闭求购' : '下架商品')
                        : (wanted ? '重新开启求购' : '重新上架'),
                  ),
                ),
                FilledButton.tonal(
                  onPressed: _busy ? null : () => _changeStatus('sold'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(44, 42),
                    backgroundColor: context.campusColors.controlSurface,
                    foregroundColor: context.campusColors.ink,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(wanted ? '标记已求到' : '标记已售出'),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
