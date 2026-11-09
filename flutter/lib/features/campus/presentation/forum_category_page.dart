import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../../ui/components/page_dialog.dart';
import '../../../ui/components/page_layout.dart';
import '../data/campus_repository.dart';
import '../models/campus_models.dart';
import 'campus_report_dialog.dart';
import 'campus_theme.dart';
import 'campus_widgets.dart';
import 'forum_moderation_dialog.dart';

/// 版块详情：规则、版主、成员数与加入／退出。
///
/// 用户版块默认未列出，知道版块号的登录用户可以在这里阅读并申请加入；
/// 管理入口只对服务端返回 `can_manage` 的账号显示。
class ForumCategoryPage extends StatefulWidget {
  const ForumCategoryPage({
    super.key,
    required this.repository,
    required this.categoryId,
  });

  final CampusRepository? repository;
  final String categoryId;

  @override
  State<ForumCategoryPage> createState() => _ForumCategoryPageState();
}

class _ForumCategoryPageState extends State<ForumCategoryPage> {
  ForumCategory? _category;
  String? _error;
  bool _loading = true;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    final repository = widget.repository;
    if (repository == null) {
      setState(() {
        _loading = false;
        _error = '论坛服务暂时不可用。';
      });
      return;
    }
    try {
      final category = await repository.getForumCategory(widget.categoryId);
      if (!mounted) return;
      setState(() {
        _category = category;
        _error = null;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString();
        _loading = false;
      });
    }
  }

  Future<void> _join() async {
    final repository = widget.repository;
    final category = _category;
    if (repository == null || category == null || _busy) return;
    setState(() => _busy = true);
    try {
      final updated = await repository.joinForumCategory(category.id);
      if (!mounted) return;
      setState(() => _category = updated);
      _showMessage('已加入「${updated.name}」');
    } catch (error) {
      if (mounted) _showMessage(error.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _leave() async {
    final repository = widget.repository;
    final category = _category;
    if (repository == null || category == null || _busy) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => Theme(
        data: pageTheme(dialogContext),
        child: AlertDialog(
          title: const Text('退出版块'),
          content: Text('退出「${category.name}」后将不能在该版块发帖，历史帖子仍保留。'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('取消'),
            ),
            FilledButton(
              key: const ValueKey('forum-category-leave-confirm'),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('退出'),
            ),
          ],
        ),
      ),
    );
    if (confirmed != true) return;
    setState(() => _busy = true);
    try {
      final updated = await repository.leaveForumCategory(category.id);
      if (!mounted) return;
      setState(() => _category = updated);
      _showMessage('已退出「${updated.name}」');
    } catch (error) {
      if (mounted) _showMessage(error.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _openBoard() {
    final category = _category;
    if (category == null) return;
    context.pop(category.id);
  }

  Future<void> _copyCategoryId() async {
    final category = _category;
    if (category == null) return;
    await Clipboard.setData(ClipboardData(text: category.id));
    if (mounted) _showMessage('版块号已复制');
  }

  Future<void> _report() async {
    final repository = widget.repository;
    final category = _category;
    if (repository == null || category == null) return;
    final reason = await askCampusReportReason(context);
    if (reason == null) return;
    try {
      await repository.reportForumCategory(
        categoryId: category.id,
        reason: reason,
      );
      if (mounted) _showMessage('举报已提交');
    } catch (error) {
      if (mounted) _showMessage(error.toString());
    }
  }

  Future<void> _editProfile() async {
    final repository = widget.repository;
    final category = _category;
    if (repository == null || category == null) return;
    final draft = await showPageDialog<_CategoryProfileDraft>(
      context,
      builder: (_) => _EditCategoryDialog(category: category),
    );
    if (draft == null || !mounted) return;
    setState(() => _busy = true);
    try {
      final updated = await repository.updateForumCategory(
        categoryId: category.id,
        expectedVersion: category.version,
        description: draft.description,
        rules: draft.rules,
      );
      if (!mounted) return;
      setState(() => _category = updated);
      _showMessage('版块信息已更新');
    } catch (error) {
      if (mounted) _showMessage(error.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _openMembers() async {
    final category = _category;
    final repository = widget.repository;
    if (category == null || repository == null) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => Theme(
          data: campusTheme(context),
          child: _ForumCategoryMembersPage(
            repository: repository,
            categoryId: category.id,
          ),
        ),
      ),
    );
    if (mounted) unawaited(_load());
  }

  Future<void> _openLogs() async {
    final category = _category;
    final repository = widget.repository;
    if (category == null || repository == null) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => Theme(
          data: campusTheme(context),
          child: _ForumModerationLogPage(
            repository: repository,
            categoryId: category.id,
          ),
        ),
      ),
    );
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final category = _category;
    return Theme(
      data: campusTheme(context),
      child: PageScaffold(
        title: category?.name ?? '版块',
        subtitle: category == null ? null : _categorySubtitle(category),
        backgroundColor: Theme.of(context).colorScheme.surface,
        actions: [
          if (category != null && !category.isOfficial)
            IconButton(
              key: const ValueKey('forum-category-report'),
              tooltip: '举报版块',
              onPressed: _busy ? null : _report,
              icon: const Icon(Icons.flag_outlined),
            ),
          if (category?.canManage == true)
            PopupMenuButton<String>(
              key: const ValueKey('forum-category-manage-menu'),
              tooltip: '管理版块',
              onSelected: (value) {
                switch (value) {
                  case 'edit':
                    unawaited(_editProfile());
                  case 'members':
                    unawaited(_openMembers());
                  case 'logs':
                    unawaited(_openLogs());
                }
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'edit', child: Text('编辑简介与规则')),
                PopupMenuItem(value: 'members', child: Text('成员管理')),
                PopupMenuItem(value: 'logs', child: Text('管理日志')),
              ],
            ),
        ],
        bottomNavigationBar: category == null
            ? null
            : _buildBottomBar(context, category),
        child: _buildBody(context),
      ),
    );
  }

  String _categorySubtitle(ForumCategory category) {
    final parts = <String>[
      if (category.isOfficial) '官方版块' else if (category.isUnlisted) '未公开',
      if (category.isArchived) '已归档',
      '${category.memberCount} 位成员',
    ];
    return parts.join(' · ');
  }

  Widget _buildBody(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_category == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.folder_off_outlined,
                size: 40,
                color: colors.onSurfaceVariant,
              ),
              const SizedBox(height: 12),
              Text(
                _error ?? '版块不存在或已关闭。',
                textAlign: TextAlign.center,
                style: TextStyle(color: colors.onSurfaceVariant),
              ),
              const SizedBox(height: 16),
              OutlinedButton(
                key: const ValueKey('forum-category-retry'),
                onPressed: () {
                  setState(() {
                    _loading = true;
                    _error = null;
                  });
                  unawaited(_load());
                },
                child: const Text('重试'),
              ),
            ],
          ),
        ),
      );
    }
    final category = _category!;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
      children: [
        _AboutCard(category: category),
        const SizedBox(height: 12),
        _RulesCard(category: category, onEdit: _editProfile),
        if (category.canManage) ...[
          const SizedBox(height: 12),
          _ManagementCard(
            onEdit: _editProfile,
            onMembers: _openMembers,
            onLogs: _openLogs,
          ),
        ],
        const SizedBox(height: 12),
        _CategoryIdCard(onCopy: _copyCategoryId, category: category),
      ],
    );
  }

  Widget _buildBottomBar(BuildContext context, ForumCategory category) {
    final colors = Theme.of(context).colorScheme;
    final action = category.canPost
        ? FilledButton.icon(
            key: const ValueKey('forum-category-enter'),
            onPressed: _busy ? null : _openBoard,
            icon: const Icon(Icons.forum_outlined, size: 18),
            label: const Text('进入版块'),
          )
        : FilledButton.icon(
            key: const ValueKey('forum-category-join'),
            onPressed: _busy || !category.canJoin ? null : _join,
            icon: const Icon(Icons.add_rounded, size: 18),
            label: Text(category.isArchived ? '版块已归档' : '加入版块'),
          );
    return SafeArea(
      top: false,
      child: Material(
        color: colors.surface,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
          child: Row(
            children: [
              if (category.canPost && !category.isOfficial) ...[
                TextButton(
                  key: const ValueKey('forum-category-leave'),
                  onPressed: _busy ? null : _leave,
                  child: const Text('退出'),
                ),
                const SizedBox(width: 8),
              ],
              Expanded(child: action),
            ],
          ),
        ),
      ),
    );
  }
}

class _AboutCard extends StatelessWidget {
  const _AboutCard({required this.category});

  final ForumCategory category;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final accent = pageAccent(context);
    return _SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _Badge(label: category.isOfficial ? '官方' : '用户版块', color: accent),
              if (category.isUnlisted)
                _Badge(label: '未公开', color: colors.onSurfaceVariant),
              if (category.isArchived)
                _Badge(label: '已归档', color: colors.error),
            ],
          ),
          if (category.description.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              category.description,
              style: const TextStyle(fontSize: 14, height: 1.5),
            ),
          ],
          const SizedBox(height: 14),
          Row(
            children: [
              Icon(
                Icons.people_outline_rounded,
                size: 16,
                color: colors.onSurfaceVariant,
              ),
              const SizedBox(width: 5),
              Text(
                '${category.memberCount} 位成员',
                style: TextStyle(
                  fontSize: 12.5,
                  color: colors.onSurfaceVariant,
                ),
              ),
              const Spacer(),
              Text(
                '版块号 ${_shortId(category.id)}',
                style: TextStyle(fontSize: 12, color: colors.onSurfaceVariant),
              ),
            ],
          ),
          if (category.moderators.isNotEmpty) ...[
            const SizedBox(height: 14),
            Text(
              '版主',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: colors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 6),
            for (final moderator in category.moderators)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    CampusAuthorAvatar(
                      author: moderator.author,
                      radius: 13,
                      repository: null,
                      linkToProfile: false,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        moderator.author.displayName,
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                    Text(
                      moderator.isOwner ? '所有者' : '版主',
                      style: TextStyle(
                        fontSize: 11,
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _RulesCard extends StatelessWidget {
  const _RulesCard({required this.category, required this.onEdit});

  final ForumCategory category;
  final Future<void> Function() onEdit;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return _SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.rule_rounded, size: 17),
              const SizedBox(width: 6),
              const Expanded(
                child: Text(
                  '版块规则',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
              ),
              if (category.canManage)
                TextButton(
                  key: const ValueKey('forum-category-edit-rules'),
                  onPressed: onEdit,
                  child: const Text('编辑'),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            category.rules.trim().isEmpty
                ? (category.canManage
                      ? '还没有规则。写清楚什么内容适合这个版块，能减少后续争议。'
                      : '版主暂未填写版块规则。')
                : category.rules,
            style: TextStyle(
              fontSize: 13,
              height: 1.55,
              color: category.rules.trim().isEmpty
                  ? colors.onSurfaceVariant
                  : colors.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}

class _ManagementCard extends StatelessWidget {
  const _ManagementCard({
    required this.onEdit,
    required this.onMembers,
    required this.onLogs,
  });

  final Future<void> Function() onEdit;
  final Future<void> Function() onMembers;
  final Future<void> Function() onLogs;

  @override
  Widget build(BuildContext context) => _SectionCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '管理',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 4),
        ListTile(
          key: const ValueKey('forum-category-members'),
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.people_alt_outlined, size: 20),
          title: const Text('成员管理'),
          subtitle: const Text('查看成员，移除后可设置冷却期'),
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: onMembers,
        ),
        ListTile(
          key: const ValueKey('forum-category-logs'),
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.history_rounded, size: 20),
          title: const Text('管理日志'),
          subtitle: const Text('置顶、锁定、隐藏和成员变更都会留痕'),
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: onLogs,
        ),
        ListTile(
          key: const ValueKey('forum-category-edit'),
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.edit_note_rounded, size: 20),
          title: const Text('编辑简介与规则'),
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: onEdit,
        ),
      ],
    ),
  );
}

class _CategoryIdCard extends StatelessWidget {
  const _CategoryIdCard({required this.category, required this.onCopy});

  final ForumCategory category;
  final Future<void> Function() onCopy;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return _SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '邀请同学',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          Text(
            category.isUnlisted
                ? '这个版块还没有公开。复制版块号发给同学，对方在「更多版块 → 输入版块号」打开并加入。'
                : '版块已进入公共目录，也可以复制版块号直接分享。',
            style: TextStyle(
              fontSize: 12.5,
              height: 1.5,
              color: colors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            decoration: BoxDecoration(
              color: colors.surfaceContainerHighest.withValues(alpha: .45),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Expanded(
                  child: SelectableText(
                    category.id,
                    maxLines: 1,
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
                IconButton(
                  key: const ValueKey('forum-category-copy-id'),
                  tooltip: '复制版块号',
                  visualDensity: VisualDensity.compact,
                  onPressed: onCopy,
                  icon: const Icon(Icons.copy_rounded, size: 18),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Material(
      color: colors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: colors.outlineVariant, width: .8),
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: child,
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: color.withValues(alpha: .1),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Text(
      label,
      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: color),
    ),
  );
}

class _CategoryProfileDraft {
  const _CategoryProfileDraft({required this.description, required this.rules});

  final String description;
  final String rules;
}

class _EditCategoryDialog extends StatefulWidget {
  const _EditCategoryDialog({required this.category});

  final ForumCategory category;

  @override
  State<_EditCategoryDialog> createState() => _EditCategoryDialogState();
}

class _EditCategoryDialogState extends State<_EditCategoryDialog> {
  late final TextEditingController _descriptionController;
  late final TextEditingController _rulesController;
  String? _error;

  @override
  void initState() {
    super.initState();
    _descriptionController = TextEditingController(
      text: widget.category.description,
    );
    _rulesController = TextEditingController(text: widget.category.rules);
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _rulesController.dispose();
    super.dispose();
  }

  void _submit() {
    final description = _descriptionController.text.trim();
    final rules = _rulesController.text.trim();
    if (description.characters.length > 100) {
      setState(() => _error = '版块介绍不能超过 100 个字。');
      return;
    }
    if (rules.characters.length > 1000) {
      setState(() => _error = '版块规则不能超过 1000 个字。');
      return;
    }
    Navigator.of(
      context,
    ).pop(_CategoryProfileDraft(description: description, rules: rules));
  }

  @override
  Widget build(BuildContext context) => PageAlertDialog(
    title: const Text('编辑版块'),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          key: const ValueKey('forum-category-edit-description'),
          controller: _descriptionController,
          maxLength: 100,
          minLines: 2,
          maxLines: 4,
          decoration: const InputDecoration(
            labelText: '版块介绍',
            hintText: '说明这个版块适合讨论什么',
          ),
        ),
        const SizedBox(height: 4),
        TextField(
          key: const ValueKey('forum-category-edit-rules'),
          controller: _rulesController,
          maxLength: 1000,
          minLines: 3,
          maxLines: 8,
          decoration: const InputDecoration(
            labelText: '版块规则',
            hintText: '例如：只发本人作品、注明拍摄地点、禁止广告',
          ),
        ),
        if (_error != null)
          Text(
            _error!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
      ],
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('取消'),
      ),
      FilledButton(
        key: const ValueKey('forum-category-edit-submit'),
        onPressed: _submit,
        child: const Text('保存'),
      ),
    ],
  );
}

class _ForumCategoryMembersPage extends StatefulWidget {
  const _ForumCategoryMembersPage({
    required this.repository,
    required this.categoryId,
  });

  final CampusRepository repository;
  final String categoryId;

  @override
  State<_ForumCategoryMembersPage> createState() =>
      _ForumCategoryMembersPageState();
}

class _ForumCategoryMembersPageState extends State<_ForumCategoryMembersPage> {
  final List<ForumCategoryMember> _members = [];
  String? _cursor;
  String? _error;
  bool _loading = true;
  bool _hasMore = false;
  final Set<String> _removing = {};

  @override
  void initState() {
    super.initState();
    unawaited(_load(reset: true));
  }

  Future<void> _load({required bool reset}) async {
    if (reset) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final page = await widget.repository.listForumCategoryMembers(
        widget.categoryId,
        cursor: reset ? null : _cursor,
      );
      if (!mounted) return;
      setState(() {
        if (reset) _members.clear();
        _members.addAll(page.items);
        _cursor = page.nextCursor;
        _hasMore = page.hasMore;
        _loading = false;
        _error = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString();
        _loading = false;
      });
    }
  }

  Future<void> _remove(ForumCategoryMember member) async {
    if (_removing.contains(member.author.id)) return;
    final reason = await askForumModerationReason(
      context,
      title: '移除成员',
      hint: '移除后对方 7 天内不能重新加入，理由会记录在管理日志里。',
      confirmLabel: '移除',
    );
    if (reason == null || !mounted) return;
    setState(() => _removing.add(member.author.id));
    try {
      await widget.repository.removeForumCategoryMember(
        categoryId: widget.categoryId,
        userId: member.author.id,
        reason: reason,
      );
      if (!mounted) return;
      setState(
        () =>
            _members.removeWhere((item) => item.author.id == member.author.id),
      );
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('已移除 ${member.author.displayName}')),
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.toString())));
      }
    } finally {
      if (mounted) setState(() => _removing.remove(member.author.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return PageScaffold(
      title: '成员',
      child: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
              children: [
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(_error!, textAlign: TextAlign.center),
                  ),
                if (_members.isEmpty && _error == null)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 40),
                    child: Center(
                      child: Text(
                        '还没有成员。',
                        style: TextStyle(color: colors.onSurfaceVariant),
                      ),
                    ),
                  ),
                for (final member in _members)
                  ListTile(
                    key: ValueKey('forum-member-${member.author.id}'),
                    contentPadding: EdgeInsets.zero,
                    leading: CampusAuthorAvatar(
                      author: member.author,
                      radius: 18,
                      repository: null,
                      linkToProfile: false,
                    ),
                    title: Text(member.author.displayName),
                    subtitle: Text('加入于 ${_shortDate(member.joinedAt)}'),
                    trailing: IconButton(
                      key: ValueKey('forum-member-remove-${member.author.id}'),
                      tooltip: '移除成员',
                      onPressed: _removing.contains(member.author.id)
                          ? null
                          : () => unawaited(_remove(member)),
                      icon: const Icon(Icons.person_remove_outlined, size: 20),
                    ),
                  ),
                if (_hasMore)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: OutlinedButton(
                      onPressed: () => unawaited(_load(reset: false)),
                      child: const Text('加载更多'),
                    ),
                  ),
              ],
            ),
    );
  }
}

class _ForumModerationLogPage extends StatefulWidget {
  const _ForumModerationLogPage({
    required this.repository,
    required this.categoryId,
  });

  final CampusRepository repository;
  final String categoryId;

  @override
  State<_ForumModerationLogPage> createState() =>
      _ForumModerationLogPageState();
}

class _ForumModerationLogPageState extends State<_ForumModerationLogPage> {
  final List<ForumModerationLogEntry> _logs = [];
  String? _cursor;
  String? _error;
  bool _loading = true;
  bool _hasMore = false;

  @override
  void initState() {
    super.initState();
    unawaited(_load(reset: true));
  }

  Future<void> _load({required bool reset}) async {
    if (reset) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final page = await widget.repository.listForumModerationLogs(
        widget.categoryId,
        cursor: reset ? null : _cursor,
      );
      if (!mounted) return;
      setState(() {
        if (reset) _logs.clear();
        _logs.addAll(page.items);
        _cursor = page.nextCursor;
        _hasMore = page.hasMore;
        _loading = false;
        _error = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return PageScaffold(
      title: '管理日志',
      child: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null && _logs.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(_error!, textAlign: TextAlign.center),
                    const SizedBox(height: 12),
                    OutlinedButton(
                      onPressed: () => unawaited(_load(reset: true)),
                      child: const Text('重试'),
                    ),
                  ],
                ),
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
              itemCount: _logs.length + (_hasMore ? 1 : 0),
              separatorBuilder: (_, _) => Divider(
                height: 1,
                color: colors.outlineVariant.withValues(alpha: .5),
              ),
              itemBuilder: (context, index) {
                if (index >= _logs.length) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: OutlinedButton(
                      onPressed: () => unawaited(_load(reset: false)),
                      child: const Text('加载更多'),
                    ),
                  );
                }
                final entry = _logs[index];
                return ListTile(
                  key: ValueKey('forum-log-${entry.id}'),
                  contentPadding: const EdgeInsets.symmetric(vertical: 4),
                  leading: CircleAvatar(
                    radius: 15,
                    backgroundColor: colors.primary.withValues(alpha: .12),
                    child: Icon(
                      _actionIcon(entry.action),
                      size: 16,
                      color: colors.primary,
                    ),
                  ),
                  title: Text(
                    forumModerationActionLabel(entry.action),
                    style: const TextStyle(fontSize: 13.5),
                  ),
                  subtitle: Text(
                    [
                      entry.actor.displayName,
                      _shortDate(entry.createdAt),
                      if ((entry.reason ?? '').trim().isNotEmpty)
                        entry.reason!.trim(),
                    ].join(' · '),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                );
              },
            ),
    );
  }

  IconData _actionIcon(String action) => switch (action) {
    'pin' || 'unpin' => Icons.push_pin_outlined,
    'lock' || 'unlock' => Icons.lock_outline_rounded,
    'hide_thread' || 'restore_thread' => Icons.visibility_off_outlined,
    'remove_member' => Icons.person_remove_outlined,
    'publish' || 'unpublish' || 'archive' || 'restore' => Icons.tune_rounded,
    _ => Icons.history_rounded,
  };
}

String _shortId(String id) => id.length <= 8 ? id : '${id.substring(0, 8)}…';

String _shortDate(String value) =>
    value.length >= 10 ? value.substring(0, 10) : value;
