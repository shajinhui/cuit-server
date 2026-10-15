import 'package:flutter/material.dart';
import '../../../ui/components/glass_surface.dart';
import '../../../ui/components/page_dialog.dart';
import 'announcement_dialog.dart';
import 'announcement_view_model.dart';

class AnnouncementTile extends StatelessWidget {
  const AnnouncementTile({
    super.key,
    required this.viewModel,
    required this.lightweight,
  });
  final AnnouncementViewModel? viewModel;
  final bool lightweight;
  @override
  Widget build(BuildContext context) {
    final vm = viewModel;
    if (vm == null) return const SizedBox.shrink();
    return ListenableBuilder(
      listenable: vm,
      builder: (context, _) {
        final item = vm.latest;
        return ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: GlassSurface(
            lightweight: lightweight,
            child: Material(
              color: Colors.transparent,
              child: ListTile(
                key: const Key('tools-announcement'),
                leading: const Icon(Icons.campaign_outlined),
                title: Text(
                  item?.title ??
                      (vm.loading
                          ? '正在更新公告'
                          : vm.error != null
                          ? '公告暂时无法更新'
                          : '暂无公告'),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(
                  vm.cacheWarning ??
                      (item == null
                          ? vm.error ?? '最新消息会显示在这里'
                          : '${vm.viewCount(item) == 0 ? '未读 · ' : ''}${vm.isOffline ? '离线缓存 · ' : ''}点击查看近期公告'),
                ),
                trailing: IconButton(
                  tooltip: '刷新公告',
                  onPressed: vm.loading ? null : () => vm.refresh(force: true),
                  icon: vm.loading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.refresh_rounded),
                ),
                onTap: item == null
                    ? () => vm.refresh(force: true)
                    : () => _openList(context, vm),
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _openList(BuildContext context, AnnouncementViewModel vm) async {
    final items = vm.items;
    if (items.length == 1) {
      await showAnnouncement(context, vm, items.single);
      return;
    }
    final selected = await showPageDialog<int>(
      context,
      builder: (dialogContext) => PageAlertDialog(
        title: const Text('公告'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < items.length; i++)
              ListTile(
                title: Text(items[i].title),
                subtitle: Text(vm.viewCount(items[i]) == 0 ? '未读' : '已读'),
                onTap: () => Navigator.pop(dialogContext, i),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
    if (selected != null && context.mounted) {
      await showAnnouncement(context, vm, items[selected]);
    }
  }
}
