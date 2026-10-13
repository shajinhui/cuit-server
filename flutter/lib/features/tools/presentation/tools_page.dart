import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';

import '../../../ui/components/page_dialog.dart';

import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:provider/provider.dart';

import '../../../core/config/app_settings.dart';
import '../../../ui/components/glass_surface.dart';

/// 校园工具入口：保留 Vue 版的公告、搜索和八个工具入口。
class ToolsPage extends StatefulWidget {
  const ToolsPage({super.key});

  @override
  State<ToolsPage> createState() => _ToolsPageState();
}

class _ToolsPageState extends State<ToolsPage> {
  static const _announcementId = 'sponsor-workbuddy-2026-09-29';
  static const _announcementStorageKey = 'app-announcement-view-state';
  static const _legacyAnnouncementStorageKey = 'app-announcement-seen-id';
  static final Uri _promotionUri = Uri.parse('https://uv.qq.com/s1gi24WP');
  static const _announcementTitle = '接了个小广告，谢谢支持';
  static const _announcementDescription =
      '作者维护需要成本，这里打一个小广告，大家动动手指支持作者：点击专属链接进去注册，然后领取积分，谢谢支持。';

  static const _tools = <_ToolItem>[
    _ToolItem('classrooms', '查空教室', 'assets/icons/tools/tool-classroom.png'),
    _ToolItem('grades', '查成绩', 'assets/icons/tools/tool-grades.png'),
    _ToolItem('calendar', '校历', 'assets/icons/tools/tool-calendar.png'),
    _ToolItem('exams', '考场查询', 'assets/icons/tools/tool-exam-room.png'),
    _ToolItem('campus-map', '校园地图', 'assets/icons/tools/tool-campus-map.png'),
    _ToolItem('autorun', '校园跑与俱乐部', null),
    _ToolItem('past-exams', '历年试卷', 'assets/icons/tools/tool-past-exams.png'),
    _ToolItem('library', '图书馆', 'assets/icons/tools/tool-library.png'),
  ];

  final _searchController = TextEditingController();
  String _query = '';
  bool _announcementViewed = false;

  @override
  void initState() {
    super.initState();
    unawaited(_loadAnnouncementState());
  }

  Future<void> _loadAnnouncementState() async {
    final preferences = await SharedPreferences.getInstance();
    final saved = preferences.getString(_announcementStorageKey);
    var viewed =
        preferences.getString(_legacyAnnouncementStorageKey) == _announcementId;
    if (saved != null) {
      try {
        final state = jsonDecode(saved);
        viewed =
            state is Map &&
            state['id'] == _announcementId &&
            state['viewCount'] is num &&
            (state['viewCount'] as num) > 0;
      } on FormatException {
        // 无法识别旧状态时，将公告显示为未读。
      }
    }
    if (mounted) setState(() => _announcementViewed = viewed);
  }

  List<_ToolItem> get _filteredTools {
    final keyword = _query.trim();
    if (keyword.isEmpty) return _tools;
    return _tools.where((tool) => tool.name.contains(keyword)).toList();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _openTool(_ToolItem tool) => context.pushNamed(tool.id);

  Future<void> _openAnnouncement() async {
    final openPromotion = await showPageDialog<bool>(
      context,
      builder: (dialogContext) => PageAlertDialog(
        icon: const Icon(Icons.chat_bubble_outline_rounded),
        title: const Text(_announcementTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(_announcementDescription),
            const SizedBox(height: 16),
            DecoratedBox(
              decoration: BoxDecoration(
                color: Theme.of(
                  dialogContext,
                ).colorScheme.primaryContainer.withValues(alpha: .55),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Padding(
                padding: EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('作者小广告'),
                    SizedBox(height: 5),
                    Text(
                      '点击领取 WorkBuddy 积分，让 AI 替你肝',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            const Text('QQ群 151247227'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('我知道了'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('立即领取积分'),
          ),
        ],
      ),
    );

    final preferences = await SharedPreferences.getInstance();
    final previous = preferences.getString(_announcementStorageKey);
    var previousCount = 0;
    if (previous != null) {
      try {
        final state = jsonDecode(previous);
        if (state is Map && state['id'] == _announcementId) {
          final count = state['viewCount'];
          if (count is num) previousCount = count.toInt();
        }
      } on FormatException {
        // 从零开始记录本次查看。
      }
    }
    await preferences.setString(
      _announcementStorageKey,
      jsonEncode({
        'id': _announcementId,
        'viewCount': (previousCount + 1).clamp(0, 2),
      }),
    );
    await preferences.remove(_legacyAnnouncementStorageKey);
    if (mounted) setState(() => _announcementViewed = true);

    if (openPromotion == true) {
      final opened = await launchUrl(
        _promotionUri,
        mode: LaunchMode.externalApplication,
      );
      if (!opened && mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('暂时无法打开推广链接')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final lightweight = context.watch<AppSettings>().lightweightGlass;
    final tools = _filteredTools;

    return SafeArea(
      bottom: false,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: CustomScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(22, 12, 22, 0),
                sliver: SliverToBoxAdapter(
                  child: Text(
                    '校园工具',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(22, 12, 22, 0),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    _AnnouncementCard(
                      viewed: _announcementViewed,
                      lightweight: lightweight,
                      onTap: _openAnnouncement,
                    ),
                    const SizedBox(height: 12),
                    _ToolSearchField(
                      controller: _searchController,
                      dark: dark,
                      query: _query,
                      onChanged: (value) => setState(() => _query = value),
                      onClear: () {
                        _searchController.clear();
                        setState(() => _query = '');
                      },
                    ),
                  ]),
                ),
              ),
              if (tools.isEmpty)
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(22, 30, 22, 150),
                  sliver: SliverToBoxAdapter(
                    child: Center(
                      child: Text(
                        '没有找到相关工具',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(22, 12, 22, 148),
                  sliver: SliverGrid.builder(
                    itemCount: tools.length,
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      // 安卓系统字体放大时，图标和两行工具名需要额外高度。
                      // 固定 124 会让 Column 在 2～3 倍字体下溢出。
                      mainAxisExtent:
                          MediaQuery.textScalerOf(context).scale(15) > 20
                          ? 152
                          : 124,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                    ),
                    itemBuilder: (context, index) => _ToolCard(
                      key: ValueKey('tool-card-${tools[index].id}'),
                      tool: tools[index],
                      onTap: () => _openTool(tools[index]),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AnnouncementCard extends StatelessWidget {
  const _AnnouncementCard({
    required this.viewed,
    required this.lightweight,
    required this.onTap,
  });

  final bool viewed;
  final bool lightweight;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final iconSize = viewed ? 34.0 : 42.0;

    return ClipRRect(
      borderRadius: BorderRadius.circular(viewed ? 18 : 22),
      child: GlassSurface(
        lightweight: lightweight,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            key: const Key('tools-announcement'),
            onTap: onTap,
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: viewed ? 58 : 82),
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: viewed ? 9 : 12,
                ),
                child: Row(
                  children: [
                    Container(
                      width: iconSize,
                      height: iconSize,
                      decoration: BoxDecoration(
                        color: scheme.primary,
                        borderRadius: BorderRadius.circular(viewed ? 10 : 13),
                        boxShadow: viewed
                            ? null
                            : [
                                BoxShadow(
                                  color: scheme.primary.withValues(alpha: .22),
                                  blurRadius: 14,
                                  offset: const Offset(0, 5),
                                ),
                              ],
                      ),
                      alignment: Alignment.center,
                      child: Icon(
                        Icons.chat_bubble_outline_rounded,
                        size: viewed ? 20 : 25,
                        color: scheme.onPrimary,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (!viewed)
                            Text(
                              '最新公告',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: scheme.onSurfaceVariant,
                                fontWeight: FontWeight.w600,
                                letterSpacing: .4,
                              ),
                            ),
                          Text(
                            _ToolsPageState._announcementTitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (!viewed)
                            Text(
                              _ToolsPageState._announcementDescription,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: scheme.onSurfaceVariant,
                                height: 1.35,
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(
                      Icons.chevron_right_rounded,
                      color: scheme.onSurfaceVariant.withValues(alpha: .65),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ToolItem {
  const _ToolItem(this.id, this.name, this.iconAsset);

  final String id;
  final String name;
  final String? iconAsset;
}

class _ToolSearchField extends StatelessWidget {
  const _ToolSearchField({
    required this.controller,
    required this.dark,
    required this.query,
    required this.onChanged,
    required this.onClear,
  });

  final TextEditingController controller;
  final bool dark;
  final String query;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      height: 52,
      child: TextField(
        key: const Key('tool-search'),
        controller: controller,
        onChanged: onChanged,
        textInputAction: TextInputAction.search,
        onSubmitted: (_) => FocusScope.of(context).unfocus(),
        decoration: InputDecoration(
          hintText: '搜索校园服务',
          prefixIcon: const Icon(Icons.search_rounded, size: 21),
          suffixIcon: query.isEmpty
              ? null
              : IconButton(
                  tooltip: '清除搜索',
                  onPressed: onClear,
                  icon: const Icon(Icons.close_rounded, size: 18),
                ),
          filled: true,
          fillColor: dark
              ? const Color(0xff24262c)
              : Colors.white.withValues(alpha: .58),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(28),
            borderSide: BorderSide(
              color: theme.colorScheme.outlineVariant.withValues(alpha: .45),
              width: .6,
            ),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(28),
            borderSide: BorderSide(
              color: theme.colorScheme.outlineVariant.withValues(alpha: .45),
              width: .6,
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(28),
            borderSide: BorderSide(
              color: theme.colorScheme.primary.withValues(alpha: .8),
              width: 1.2,
            ),
          ),
        ),
      ),
    );
  }
}

class _ToolCard extends StatelessWidget {
  const _ToolCard({super.key, required this.tool, required this.onTap});

  final _ToolItem tool;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(22),
      side: BorderSide(
        color: theme.colorScheme.outlineVariant.withValues(alpha: .42),
        width: .6,
      ),
    );

    return Card(
      margin: EdgeInsets.zero,
      elevation: .5,
      shadowColor: Colors.black.withValues(alpha: dark ? .18 : .07),
      color: dark
          ? const Color(0xff1c1c1e).withValues(alpha: .88)
          : Colors.white.withValues(alpha: .78),
      surfaceTintColor: Colors.transparent,
      shape: shape,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: MediaQuery.withClampedTextScaling(
          // 卡片最多跟随 1.5 倍系统字体；更大的字体仍可在页面滚动，
          // 但不会把图标和入口名称挤出卡片边界。
          maxScaleFactor: 1.5,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: 52,
                  height: 52,
                  child: tool.iconAsset == null
                      ? const _CampusRunIcon()
                      : Image.asset(tool.iconAsset!, fit: BoxFit.contain),
                ),
                const SizedBox(height: 6),
                Text(
                  tool.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontSize: 15,
                    height: 1.2,
                    fontWeight: FontWeight.w600,
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

class _CampusRunIcon extends StatelessWidget {
  const _CampusRunIcon();

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        colors: [Color(0xff0a84ff), Color(0xff64d2ff)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      borderRadius: BorderRadius.circular(16),
    ),
    alignment: Alignment.center,
    child: const Icon(
      Icons.directions_run_rounded,
      color: Colors.white,
      size: 33,
    ),
  );
}
