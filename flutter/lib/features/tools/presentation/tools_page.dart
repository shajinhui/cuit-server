import 'package:flutter/material.dart';

import 'package:chengxin_youyou/features/announcements/announcements.dart';

import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/config/app_settings.dart';

/// 校园工具入口：保留 Vue 版的公告、搜索和八个工具入口。
class ToolsPage extends StatefulWidget {
  const ToolsPage({super.key, this.announcements});
  final AnnouncementViewModel? announcements;

  @override
  State<ToolsPage> createState() => _ToolsPageState();
}

class _ToolsPageState extends State<ToolsPage> {
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
                    AnnouncementTile(
                      viewModel: widget.announcements,
                      lightweight: lightweight,
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
