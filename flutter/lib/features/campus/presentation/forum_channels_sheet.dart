import 'package:flutter/material.dart';

import '../../../ui/components/page_layout.dart';
import '../data/campus_repository.dart';
import '../models/campus_models.dart';
import 'campus_theme.dart';

/// 「更多板块」面板返回给论坛首页的最新选择。
///
/// 首页只持久化普通版块；「全部」和「热门」始终由客户端固定展示。
class ForumChannelsSheetResult {
  const ForumChannelsSheetResult({
    required this.categories,
    required this.homeCategoryIds,
    this.selectedCategoryId,
    this.openCategoryId,
    this.changed = false,
  });

  final List<ForumCategory> categories;
  final List<String> homeCategoryIds;
  final String? selectedCategoryId;

  /// 用户想查看版块详情（规则、加入、管理）而不是直接筛选帖子。
  final String? openCategoryId;
  final bool changed;
}

class ForumChannelsSheet extends StatefulWidget {
  const ForumChannelsSheet({
    super.key,
    required this.repository,
    required this.categories,
    required this.homeCategoryIds,
    this.selectedCategoryId,
  });

  final CampusRepository? repository;
  final List<ForumCategory> categories;
  final List<String> homeCategoryIds;
  final String? selectedCategoryId;

  @override
  State<ForumChannelsSheet> createState() => _ForumChannelsSheetState();
}

class _ForumChannelsSheetState extends State<ForumChannelsSheet> {
  static const _maxHomeCategories = 8;
  static const _maxOwnedCategories = 3;

  late List<ForumCategory> _categories;
  late Set<String> _homeCategoryIds;
  bool _editingHome = false;
  bool _creating = false;
  bool _saving = false;
  bool _changed = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _categories = [...widget.categories];
    _homeCategoryIds = widget.homeCategoryIds.toSet();
  }

  List<String> get _orderedHomeCategoryIds => [
    for (final category in _categories)
      if (_homeCategoryIds.contains(category.id)) category.id,
  ];

  void _close() {
    Navigator.of(context).pop(
      ForumChannelsSheetResult(
        categories: List.unmodifiable(_categories),
        homeCategoryIds: List.unmodifiable(_orderedHomeCategoryIds),
        changed: _changed,
      ),
    );
  }

  void _selectCategory(ForumCategory category) {
    if (_editingHome) {
      _toggleHomeCategory(category);
      return;
    }
    // 用户版块先进详情页确认规则并加入；官方版块保持一键筛选。
    Navigator.of(context).pop(
      ForumChannelsSheetResult(
        categories: List.unmodifiable(_categories),
        homeCategoryIds: List.unmodifiable(_orderedHomeCategoryIds),
        selectedCategoryId: category.isOfficial ? category.id : null,
        openCategoryId: category.isOfficial ? null : category.id,
        changed: _changed,
      ),
    );
  }

  Future<void> _openJoinById() async {
    final id = await showDialog<String>(
      context: context,
      useRootNavigator: true,
      builder: (dialogContext) => Theme(
        data: campusTheme(dialogContext),
        child: const _JoinCategoryByIdDialog(),
      ),
    );
    if (!mounted || id == null) return;
    Navigator.of(context).pop(
      ForumChannelsSheetResult(
        categories: List.unmodifiable(_categories),
        homeCategoryIds: List.unmodifiable(_orderedHomeCategoryIds),
        openCategoryId: id,
        changed: _changed,
      ),
    );
  }

  void _toggleHomeCategory(ForumCategory category) {
    setState(() {
      _error = null;
      if (_homeCategoryIds.remove(category.id)) return;
      if (_homeCategoryIds.length >= _maxHomeCategories) {
        _error = '首页最多展示 $_maxHomeCategories 个版块，请先取消一个。';
        return;
      }
      _homeCategoryIds.add(category.id);
      _changed = true;
    });
  }

  Future<void> _createCategory() async {
    if (_creating || _saving) return;
    final owned = _categories.where((category) => category.isMine).length;
    if (owned >= _maxOwnedCategories) {
      setState(() => _error = '每人最多创建 $_maxOwnedCategories 个版块。');
      return;
    }
    final draft = await showDialog<_ForumCategoryDraft>(
      context: context,
      useRootNavigator: true,
      builder: (dialogContext) => Theme(
        data: campusTheme(dialogContext),
        child: const _CreateForumCategoryDialog(),
      ),
    );
    if (!mounted || draft == null) return;
    final repository = widget.repository;
    if (repository == null) {
      setState(() => _error = '论坛服务暂时不可用。');
      return;
    }
    setState(() {
      _creating = true;
      _error = null;
    });
    try {
      final category = await repository.createForumCategory(
        name: draft.name,
        description: draft.description,
        rules: draft.rules,
      );
      if (!mounted) return;
      setState(() {
        _categories = [..._categories, category];
        if (_homeCategoryIds.length < _maxHomeCategories) {
          _homeCategoryIds.add(category.id);
        }
        _changed = true;
        _creating = false;
      });
      // 创建后立即保存一次首页设置，避免用户以为新板块已固定但退出后丢失。
      try {
        final saved = await repository.setForumHomeCategories(
          _orderedHomeCategoryIds,
        );
        if (!mounted) return;
        setState(() => _homeCategoryIds = saved.toSet());
      } catch (_) {
        if (!mounted) return;
        setState(() => _error = '版块已创建，但首页设置未保存，可稍后重试。');
      }
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _creating = false;
        _error = error.toString();
      });
    }
  }

  Future<void> _saveHomeSettings() async {
    if (_saving || _creating) return;
    final repository = widget.repository;
    if (repository == null) {
      setState(() => _error = '论坛服务暂时不可用。');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final saved = await repository.setForumHomeCategories(
        _orderedHomeCategoryIds,
      );
      if (!mounted) return;
      Navigator.of(context).pop(
        ForumChannelsSheetResult(
          categories: List.unmodifiable(_categories),
          homeCategoryIds: saved,
          changed: true,
        ),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = error.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final accent = pageAccent(context);
    final largeText = MediaQuery.textScalerOf(context).scale(12) > 18;
    final title = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _editingHome ? '设置首页展示' : '频道版块',
          style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 2),
        Text(
          '「全部」和「热门」始终显示在论坛首页',
          style: TextStyle(fontSize: 11, color: colors.onSurfaceVariant),
        ),
      ],
    );
    final action = _editingHome
        ? TextButton(
            key: const ValueKey('forum-channels-cancel-edit'),
            onPressed: _saving || _creating
                ? null
                : () => setState(() {
                    _editingHome = false;
                    _error = null;
                  }),
            child: const Text('取消'),
          )
        : TextButton.icon(
            key: const ValueKey('forum-channels-edit'),
            onPressed: _creating || _saving
                ? null
                : () => setState(() {
                    _editingHome = true;
                    _error = null;
                  }),
            icon: const Icon(Icons.tune_rounded, size: 17),
            label: const Text('编辑首页'),
          );
    return Theme(
      data: pageTheme(context),
      child: Container(
        key: const ValueKey('forum-channels-sheet'),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 12, 4),
              child: largeText
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        title,
                        Align(alignment: Alignment.centerRight, child: action),
                      ],
                    )
                  : Row(
                      children: [
                        Expanded(child: title),
                        action,
                      ],
                    ),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 2, 20, 4),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: colors.errorContainer.withValues(alpha: .55),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    _error!,
                    style: TextStyle(
                      fontSize: 12,
                      color: colors.onErrorContainer,
                    ),
                  ),
                ),
              ),
            Flexible(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 6, 20, 12),
                children: [
                  Row(
                    children: [
                      Icon(
                        _editingHome
                            ? Icons.check_circle_outline_rounded
                            : Icons.widgets_outlined,
                        size: 17,
                        color: accent,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          _editingHome
                              ? '选择需要在首页展示的版块，最多 $_maxHomeCategories 个'
                              : '选择版块查看帖子，或创建自己的版块',
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (_categories.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      child: Center(
                        child: Text(
                          '还没有版块，先创建一个吧。',
                          style: TextStyle(
                            fontSize: 13,
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                      ),
                    )
                  else
                    _buildSections(),
                  if (!_editingHome)
                    ListTile(
                      key: const ValueKey('forum-channels-join-by-id'),
                      contentPadding: const EdgeInsets.symmetric(vertical: 2),
                      leading: Icon(Icons.key_rounded, size: 18, color: accent),
                      title: const Text(
                        '输入版块号',
                        style: TextStyle(fontSize: 13),
                      ),
                      subtitle: const Text(
                        '用同学分享的版块号打开未公开版块',
                        style: TextStyle(fontSize: 11.5),
                      ),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: _creating || _saving ? null : _openJoinById,
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 14),
              child: largeText
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildCreateButton(),
                        const SizedBox(height: 8),
                        _buildDoneButton(),
                      ],
                    )
                  : Row(
                      children: [
                        Expanded(child: _buildCreateButton()),
                        const SizedBox(width: 8),
                        Expanded(child: _buildDoneButton()),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCreateButton() => OutlinedButton.icon(
    key: const ValueKey('forum-channels-create'),
    onPressed: _creating || _saving ? null : _createCategory,
    icon: _creating
        ? const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        : const Icon(Icons.add_rounded, size: 18),
    label: const Text('创建板块'),
  );

  Widget _buildDoneButton() => FilledButton(
    key: const ValueKey('forum-channels-save-or-done'),
    onPressed: _creating || _saving
        ? null
        : (_editingHome ? _saveHomeSettings : _close),
    child: _saving
        ? const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Colors.white,
            ),
          )
        : Text(_editingHome ? '保存' : '完成'),
  );

  Widget _buildSections() {
    final managed = _categories
        .where((category) => !category.isOfficial && category.canManage)
        .toList();
    final official = _categories
        .where((category) => category.isOfficial)
        .toList();
    final joined = _categories
        .where(
          (category) =>
              !category.isOfficial && category.isMember && !category.canManage,
        )
        .toList();
    final others = _categories
        .where(
          (category) =>
              !category.isOfficial && !category.isMember && !category.canManage,
        )
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (managed.isNotEmpty) ...[
          _sectionTitle('我管理的'),
          _buildChannelGrid(managed),
          const SizedBox(height: 12),
        ],
        if (official.isNotEmpty) ...[
          _sectionTitle('官方版块'),
          _buildChannelGrid(official),
          const SizedBox(height: 12),
        ],
        if (joined.isNotEmpty) ...[
          _sectionTitle('我加入的版块'),
          _buildChannelGrid(joined),
          if (others.isNotEmpty) const SizedBox(height: 12),
        ],
        if (others.isNotEmpty) ...[
          _sectionTitle('校园版块'),
          _buildChannelGrid(others),
        ],
      ],
    );
  }

  Widget _sectionTitle(String title) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Text(
      title,
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    ),
  );

  Widget _buildChannelGrid(List<ForumCategory> categories) => LayoutBuilder(
    builder: (context, constraints) {
      final columns = constraints.maxWidth < 310 ? 2 : 3;
      final tileWidth = (constraints.maxWidth - (columns - 1) * 8) / columns;
      return Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final category in categories)
            SizedBox(
              width: tileWidth,
              child: _ForumChannelTile(
                key: ValueKey('forum-channel-tile-${category.id}'),
                category: category,
                selected: _editingHome
                    ? _homeCategoryIds.contains(category.id)
                    : category.id == widget.selectedCategoryId,
                editing: _editingHome,
                onTap: () => _selectCategory(category),
              ),
            ),
        ],
      );
    },
  );
}

class _ForumChannelTile extends StatelessWidget {
  const _ForumChannelTile({
    super.key,
    required this.category,
    required this.selected,
    required this.editing,
    required this.onTap,
  });

  final ForumCategory category;
  final bool selected;
  final bool editing;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final accent = pageAccent(context);
    return Semantics(
      button: true,
      selected: selected,
      label: category.name,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 140),
            constraints: const BoxConstraints(minHeight: 46),
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
            decoration: BoxDecoration(
              color: selected ? accent.withValues(alpha: .1) : colors.surface,
              border: Border.all(
                color: selected ? accent : colors.outlineVariant,
                width: selected ? 1.2 : .8,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisAlignment: editing
                  ? MainAxisAlignment.start
                  : MainAxisAlignment.center,
              children: [
                if (editing) ...[
                  Icon(
                    selected
                        ? Icons.check_circle_rounded
                        : Icons.radio_button_unchecked_rounded,
                    size: 17,
                    color: selected ? accent : colors.onSurfaceVariant,
                  ),
                  const SizedBox(width: 6),
                ] else if (category.isUnlisted) ...[
                  Icon(
                    Icons.lock_outline_rounded,
                    size: 12,
                    color: colors.onSurfaceVariant,
                  ),
                  const SizedBox(width: 4),
                ],
                Flexible(
                  child: Text(
                    category.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: editing ? TextAlign.start : TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.25,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                      color: selected ? accent : colors.onSurface,
                    ),
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

class _ForumCategoryDraft {
  const _ForumCategoryDraft({
    required this.name,
    required this.description,
    required this.rules,
  });

  final String name;
  final String description;
  final String rules;
}

class _CreateForumCategoryDialog extends StatefulWidget {
  const _CreateForumCategoryDialog();

  @override
  State<_CreateForumCategoryDialog> createState() =>
      _CreateForumCategoryDialogState();
}

class _CreateForumCategoryDialogState
    extends State<_CreateForumCategoryDialog> {
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _rulesController = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _rulesController.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _nameController.text.trim();
    final description = _descriptionController.text.trim();
    if (name.characters.length < 2 || name.characters.length > 12) {
      setState(() => _error = '版块名称需要 2 到 12 个字。');
      return;
    }
    if (description.characters.length > 100) {
      setState(() => _error = '版块介绍不能超过 100 个字。');
      return;
    }
    final rules = _rulesController.text.trim();
    if (rules.characters.length > 1000) {
      setState(() => _error = '版块规则不能超过 1000 个字。');
      return;
    }
    Navigator.of(context).pop(
      _ForumCategoryDraft(name: name, description: description, rules: rules),
    );
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    key: const ValueKey('forum-channel-create-dialog'),
    title: const Text('创建板块'),
    content: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            key: const ValueKey('forum-channel-create-name'),
            controller: _nameController,
            autofocus: true,
            maxLength: 12,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              labelText: '版块名称',
              hintText: '例如：租房',
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            key: const ValueKey('forum-channel-create-description'),
            controller: _descriptionController,
            maxLength: 100,
            minLines: 2,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: '版块介绍（可选）',
              hintText: '说明这个版块适合讨论什么',
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            key: const ValueKey('forum-channel-create-rules'),
            controller: _rulesController,
            maxLength: 1000,
            minLines: 2,
            maxLines: 5,
            decoration: const InputDecoration(
              labelText: '版块规则（可选）',
              hintText: '例如：只发本人作品、禁止广告和人身攻击',
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '创建后版块默认不公开，只有拿到版块号的同学能进入；管理员公开后才会出现在目录里。',
            style: TextStyle(
              fontSize: 11.5,
              height: 1.4,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 6),
            Text(
              _error!,
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.error,
              ),
            ),
          ],
        ],
      ),
    ),
    actions: [
      TextButton(
        key: const ValueKey('forum-channel-create-cancel'),
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('取消'),
      ),
      FilledButton(
        key: const ValueKey('forum-channel-create-submit'),
        onPressed: _submit,
        child: const Text('创建'),
      ),
    ],
  );
}

class _JoinCategoryByIdDialog extends StatefulWidget {
  const _JoinCategoryByIdDialog();

  @override
  State<_JoinCategoryByIdDialog> createState() =>
      _JoinCategoryByIdDialogState();
}

class _JoinCategoryByIdDialogState extends State<_JoinCategoryByIdDialog> {
  final _controller = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final id = _controller.text.trim();
    if (!RegExp(r'^[A-Za-z0-9_-]{8,80}$').hasMatch(id)) {
      setState(() => _error = '版块号格式不正确，请检查后重试。');
      return;
    }
    Navigator.of(context).pop(id);
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    key: const ValueKey('forum-join-by-id-dialog'),
    title: const Text('输入版块号'),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('粘贴同学分享的版块号，打开版块并申请加入。'),
        const SizedBox(height: 12),
        TextField(
          key: const ValueKey('forum-join-by-id-input'),
          controller: _controller,
          autofocus: true,
          autocorrect: false,
          enableSuggestions: false,
          decoration: const InputDecoration(hintText: '例如：3f2a9c1e-…'),
        ),
        if (_error != null) ...[
          const SizedBox(height: 6),
          Text(
            _error!,
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).colorScheme.error,
            ),
          ),
        ],
      ],
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('取消'),
      ),
      FilledButton(
        key: const ValueKey('forum-join-by-id-submit'),
        onPressed: _submit,
        child: const Text('打开'),
      ),
    ],
  );
}
