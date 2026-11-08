import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:chengxin_youyou/features/campus/data/campus_repository.dart';
import 'package:chengxin_youyou/features/campus/models/campus_models.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../ui/components/page_layout.dart';
import 'campus_widgets.dart';
import 'campus_image_picker.dart';
import 'campus_theme.dart';
import 'forum_widgets.dart';

/// 发帖页：正文优先，版块折叠选择，底部提供表情、文件、投票和长文工具。
/// 传入 editingThread 时进入编辑模式。
class ForumEditorPage extends StatefulWidget {
  const ForumEditorPage({
    super.key,
    required this.repository,
    this.editingThread,
  });

  final CampusRepository? repository;

  /// 编辑模式下的原帖，为 null 时是发布新帖。
  final ForumThread? editingThread;

  @override
  State<ForumEditorPage> createState() => _ForumEditorPageState();
}

class _ForumEditorPageState extends State<ForumEditorPage> {
  static const _maxImages = 3;

  final _picker = ImagePicker();
  final _titleController = TextEditingController();
  final _bodyController = TextEditingController();
  final _images = <_ForumImage>[];
  List<String> _keptAssetIds = [];
  List<ForumCategory> _categories = [];
  String? _selectedCategoryId;
  ForumPollDraft? _pollDraft;
  String? _categoriesError;
  String? _imageError;
  String? _error;
  String _requestId = createCampusRequestId();
  String _lastPayload = '';
  bool _categoriesLoading = true;
  bool _submitting = false;
  bool _pickingImages = false;
  bool _longArticleMode = false;

  bool get _editing => widget.editingThread != null;

  @override
  void initState() {
    super.initState();
    final editing = widget.editingThread;
    if (editing != null) {
      _titleController.text = editing.title;
      _bodyController.text = editing.body;
      _selectedCategoryId = editing.categoryId;
      _keptAssetIds = [...editing.imageAssetIds];
    }
    unawaited(_loadCategories());
  }

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  Future<void> _loadCategories() async {
    setState(() {
      _categoriesLoading = true;
      _categoriesError = null;
    });
    try {
      final categories = await widget.repository!.listForumCategories();
      if (!mounted) return;
      setState(() {
        _categories = categories;
        // 已选版块失效时回到第一个版块，避免带着过期目录提交。
        if (_selectedCategoryId == null ||
            !categories.any((c) => c.id == _selectedCategoryId)) {
          _selectedCategoryId = categories.isEmpty ? null : categories.first.id;
        }
      });
    } catch (error) {
      if (mounted) setState(() => _categoriesError = error.toString());
    } finally {
      if (mounted) setState(() => _categoriesLoading = false);
    }
  }

  Future<void> _pickImages() async {
    if (_submitting || _pickingImages) return;
    final remaining = _maxImages - _images.length - _keptAssetIds.length;
    if (remaining <= 0) {
      setState(() => _imageError = '最多添加 $_maxImages 张图片');
      return;
    }
    setState(() => _pickingImages = true);
    try {
      final files = await pickCampusImages(_picker, remaining);
      if (!mounted || files.isEmpty) return;
      String? error;
      for (final file in files) {
        try {
          final image = await readCampusUploadImage(file);
          if (!mounted) return;
          _images.add(
            _ForumImage(bytes: image.bytes, filename: image.filename),
          );
        } on CampusImageException catch (failure) {
          error = failure.message;
        }
      }
      if (mounted) setState(() => _imageError = error);
    } catch (_) {
      if (mounted) setState(() => _imageError = '无法读取图片，请重新选择。');
    } finally {
      if (mounted) setState(() => _pickingImages = false);
    }
  }

  String _mimeFromName(String name) {
    final lower = name.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) return 'image/jpeg';
    return '';
  }

  Future<void> _submit() async {
    if (_submitting || _pickingImages) return;
    final repository = widget.repository;
    final categoryId = _selectedCategoryId;
    final rawTitle = _titleController.text.trim();
    final body = _bodyController.text.trim();
    final pollDraft = _pollDraft;
    final title = rawTitle.isEmpty
        ? _deriveTitle(body, fallback: pollDraft?.question)
        : rawTitle;
    final titleLength = title.characters.length;
    if (repository == null ||
        categoryId == null ||
        titleLength < 2 ||
        titleLength > 50 ||
        (body.isEmpty && pollDraft == null) ||
        body.characters.length > 2000) {
      setState(() => _error = '请选择版块，并填写 2 到 50 字的标题，以及正文或投票。');
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      // 已上传成功的图片不重复上传，网络失败后重试只补传缺失部分。
      for (final image in _images) {
        image.assetId ??= await repository.uploadAsset(
          filename: image.filename,
          bytes: image.bytes,
          mimeType: _mimeFromName(image.filename),
        );
      }
      final imageAssetIds = [
        ..._keptAssetIds,
        ..._images.map((image) => image.assetId).whereType<String>(),
      ];
      final editing = widget.editingThread;
      final ForumThread thread;
      if (editing != null) {
        // 编辑走版本号乐观锁，与二手改状态同一套并发约定。
        thread = await repository.updateForumThread(
          threadId: editing.id,
          categoryId: categoryId,
          title: title,
          body: body,
          imageAssetIds: imageAssetIds,
          expectedVersion: editing.version,
        );
      } else {
        // 内容变化后更换幂等键，避免把修改后的内容当成旧请求的重试。
        final payloadKey = jsonEncode([
          categoryId,
          title,
          body,
          ...imageAssetIds,
          pollDraft?.question,
          if (pollDraft != null) ...pollDraft.options,
        ]);
        if (_lastPayload.isNotEmpty && _lastPayload != payloadKey) {
          _requestId = createCampusRequestId();
        }
        _lastPayload = payloadKey;
        thread = await repository.createForumThread(
          categoryId: categoryId,
          title: title,
          body: body,
          imageAssetIds: imageAssetIds,
          poll: pollDraft,
          requestId: _requestId,
        );
      }
      if (mounted) {
        context.goNamed(
          'forum-thread',
          pathParameters: {'threadId': thread.id},
        );
      }
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  String _deriveTitle(String body, {String? fallback}) {
    final firstLine = body
        .split('\n')
        .map((line) => line.trim())
        .firstWhere(
          (line) => line.isNotEmpty,
          orElse: () => (fallback != null && fallback.trim().isNotEmpty)
              ? fallback.trim()
              : '校园分享',
        );
    return firstLine.characters.take(50).toString();
  }

  void _insertEmoji(String emoji) {
    final value = _bodyController.value;
    final start = value.selection.start < 0
        ? value.text.length
        : value.selection.start;
    final end = value.selection.end < 0 ? start : value.selection.end;
    final text = value.text.replaceRange(start, end, emoji);
    final cursor = start + emoji.length;
    _bodyController.value = value.copyWith(
      text: text,
      selection: TextSelection.collapsed(offset: cursor),
      composing: TextRange.empty,
    );
  }

  Future<void> _showEmojiPicker() async {
    final emoji = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => Theme(
        data: campusTheme(context),
        child: SafeArea(
          child: GridView.count(
            crossAxisCount: 8,
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
            children: [
              for (final item in const [
                '😀',
                '😂',
                '🥹',
                '😍',
                '🥰',
                '😎',
                '🤔',
                '😴',
                '😭',
                '😡',
                '👏',
                '👍',
                '👎',
                '❤️',
                '🔥',
                '✨',
                '🎉',
                '🙌',
                '💡',
                '📚',
                '🎓',
                '🌳',
                '🍜',
                '🏃',
              ])
                Center(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: () => Navigator.of(context).pop(item),
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Text(item, style: const TextStyle(fontSize: 24)),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
    if (mounted && emoji != null) {
      _insertEmoji(emoji);
      setState(() {});
    }
  }

  Future<void> _showPollComposer() async {
    final questionController = TextEditingController(
      text: _pollDraft?.question ?? '',
    );
    final optionControllers = [
      for (final option in _pollDraft?.options ?? const <String>['', ''])
        TextEditingController(text: option),
    ];
    final draft = await showDialog<ForumPollDraft>(
      context: context,
      builder: (context) => Theme(
        data: campusTheme(context),
        child: StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: const Text('发起投票'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    key: const ValueKey('forum-poll-question'),
                    controller: questionController,
                    autofocus: true,
                    maxLength: 80,
                    decoration: const InputDecoration(labelText: '投票问题'),
                  ),
                  for (var index = 0; index < optionControllers.length; index++)
                    TextField(
                      key: ValueKey('forum-poll-option-$index'),
                      controller: optionControllers[index],
                      maxLength: 40,
                      decoration: InputDecoration(labelText: '选项 ${index + 1}'),
                    ),
                  if (optionControllers.length < 4)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: () => setDialogState(
                          () => optionControllers.add(TextEditingController()),
                        ),
                        icon: const Icon(Icons.add),
                        label: const Text('添加选项'),
                      ),
                    ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('取消'),
              ),
              FilledButton(
                onPressed: () {
                  final question = questionController.text.trim();
                  final options = optionControllers
                      .map((controller) => controller.text.trim())
                      .where((option) => option.isNotEmpty)
                      .toList();
                  if (question.isEmpty || options.length < 2) return;
                  Navigator.of(
                    context,
                  ).pop(ForumPollDraft(question: question, options: options));
                },
                child: const Text('完成'),
              ),
            ],
          ),
        ),
      ),
    );
    // 等弹窗退出动画完成后再释放控制器，避免弹窗过渡帧仍在监听它们。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      questionController.dispose();
      for (final controller in optionControllers) {
        controller.dispose();
      }
    });
    if (mounted && draft != null) setState(() => _pollDraft = draft);
  }

  Widget _buildHeader(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final accent = pageAccent(context);
    return Container(
      height: 62,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(
          bottom: BorderSide(
            color: colors.outlineVariant.withValues(alpha: .45),
            width: .7,
          ),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            tooltip: '关闭',
            onPressed: () => Navigator.of(context).maybePop(),
            style: IconButton.styleFrom(
              minimumSize: const Size(38, 38),
              maximumSize: const Size(38, 38),
              backgroundColor: colors.onSurface.withValues(alpha: .045),
              foregroundColor: colors.onSurface,
            ),
            icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 26),
          ),
          Expanded(
            child: Text(
              _editing ? '编辑帖子' : '发新帖',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
            ),
          ),
          FilledButton(
            key: const ValueKey('forum-thread-submit'),
            onPressed: _submitting || _pickingImages ? null : _submit,
            style: FilledButton.styleFrom(
              minimumSize: const Size(66, 36),
              maximumSize: const Size(76, 36),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              backgroundColor: accent,
              disabledBackgroundColor: accent.withValues(alpha: .35),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              textStyle: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            child: _submitting
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Text(_editing ? '保存' : '发布'),
          ),
        ],
      ),
    );
  }

  Widget _buildToolbar(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return SafeArea(
      top: false,
      child: Container(
        decoration: BoxDecoration(
          color: colors.surface,
          border: Border(
            top: BorderSide(
              color: colors.outlineVariant.withValues(alpha: .5),
              width: .7,
            ),
          ),
          boxShadow: [
            BoxShadow(
              color: colors.shadow.withValues(alpha: .035),
              blurRadius: 16,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 9),
        child: Row(
          children: [
            _EditorToolButton(
              key: const ValueKey('forum-tool-emoji'),
              label: '表情',
              icon: Icons.sentiment_satisfied_alt_outlined,
              onTap: _submitting ? null : _showEmojiPicker,
            ),
            _EditorToolButton(
              key: const ValueKey('forum-tool-file'),
              label: '图片',
              icon: Icons.photo_library_outlined,
              onTap: _submitting || _pickingImages ? null : _pickImages,
              busy: _pickingImages,
            ),
            _EditorToolButton(
              key: const ValueKey('forum-tool-poll'),
              label: '投票',
              icon: Icons.how_to_vote_outlined,
              onTap: _submitting || _editing ? null : _showPollComposer,
              selected: _pollDraft != null,
            ),
            _EditorToolButton(
              key: const ValueKey('forum-tool-long-article'),
              label: '长文',
              icon: _longArticleMode
                  ? Icons.edit_document
                  : Icons.edit_note_outlined,
              onTap: _submitting
                  ? null
                  : () => setState(() => _longArticleMode = !_longArticleMode),
              selected: _longArticleMode,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAttachmentEntry(BuildContext context) {
    final count = _images.length + _keptAssetIds.length;
    if (count >= _maxImages) return const SizedBox.shrink();
    final colors = Theme.of(context).colorScheme;
    final accent = pageAccent(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Material(
        color: accent.withValues(alpha: .035),
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          key: const ValueKey('forum-add-image'),
          borderRadius: BorderRadius.circular(14),
          onTap: _submitting || _pickingImages ? null : _pickImages,
          child: Container(
            height: 56,
            decoration: BoxDecoration(
              border: Border.all(color: accent.withValues(alpha: .16)),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.add_photo_alternate_outlined,
                  size: 20,
                  color: accent,
                ),
                const SizedBox(width: 8),
                Text(
                  '添加图片',
                  style: TextStyle(
                    color: accent,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  '$count/$_maxImages',
                  style: TextStyle(
                    color: colors.onSurfaceVariant,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryRow(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final accent = pageAccent(context);
    final categoryName = _selectedCategoryId == null
        ? '选择版块'
        : _categories
              .firstWhere(
                (category) => category.id == _selectedCategoryId,
                orElse: () => const ForumCategory(
                  id: '',
                  name: '选择版块',
                  description: '',
                  sortOrder: 0,
                ),
              )
              .name;
    return Material(
      color: accent.withValues(alpha: .04),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        key: const ValueKey('forum-category-selector'),
        borderRadius: BorderRadius.circular(14),
        onTap: _submitting || _categoriesLoading || _categories.isEmpty
            ? null
            : () async {
                final selected = await showModalBottomSheet<String>(
                  context: context,
                  showDragHandle: true,
                  builder: (context) => Theme(
                    data: campusTheme(context),
                    child: SafeArea(
                      child: ListView(
                        shrinkWrap: true,
                        padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                        children: [
                          for (final category in _categories)
                            ListTile(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              selected: category.id == _selectedCategoryId,
                              selectedColor: accent,
                              selectedTileColor: accent.withValues(alpha: .06),
                              title: Text(category.name),
                              subtitle: category.description.isEmpty
                                  ? null
                                  : Text(category.description),
                              trailing: category.id == _selectedCategoryId
                                  ? Icon(Icons.check_rounded, color: accent)
                                  : null,
                              onTap: () =>
                                  Navigator.of(context).pop(category.id),
                            ),
                        ],
                      ),
                    ),
                  ),
                );
                if (mounted && selected != null) {
                  setState(() => _selectedCategoryId = selected);
                }
              },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            border: Border.all(color: accent.withValues(alpha: .13)),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: .09),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(Icons.layers_outlined, size: 16, color: accent),
              ),
              const SizedBox(width: 10),
              Text(
                '发布到',
                style: TextStyle(color: colors.onSurfaceVariant, fontSize: 12),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  categoryName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: accent,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.keyboard_arrow_down_rounded,
                size: 20,
                color: colors.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildErrorBanner(String message) {
    final error = Theme.of(context).colorScheme.error;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: error.withValues(alpha: .055),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: error.withValues(alpha: .12)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.error_outline_rounded, size: 17, color: error),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: error, fontSize: 12, height: 1.45),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Theme(
    data: campusTheme(context),
    child: Builder(builder: _buildScaffold),
  );

  Widget _buildScaffold(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return PageScaffold(
      title: _editing ? '编辑帖子' : '发新帖',
      header: _buildHeader(context),
      backgroundColor: colors.surface,
      bottomNavigationBar: _buildToolbar(context),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 30),
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        children: [
          if (_categoriesLoading)
            Container(
              height: 50,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: colors.onSurface.withValues(alpha: .025),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else if (_categoriesError != null)
            Row(
              children: [
                Expanded(child: _buildErrorBanner(_categoriesError!)),
                const SizedBox(width: 6),
                TextButton(onPressed: _loadCategories, child: const Text('重试')),
              ],
            )
          else if (_categories.isEmpty)
            _buildErrorBanner('暂时没有可用版块，请稍后再试。')
          else
            _buildCategoryRow(context),
          const SizedBox(height: 14),
          Container(
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: colors.outlineVariant.withValues(alpha: .55),
                  width: .7,
                ),
              ),
            ),
            child: TextField(
              key: const ValueKey('forum-thread-title'),
              controller: _titleController,
              enabled: !_submitting,
              maxLength: 50,
              style: const TextStyle(
                fontSize: 21,
                height: 1.35,
                fontWeight: FontWeight.w700,
                letterSpacing: -.25,
              ),
              decoration: InputDecoration(
                hintText: '写一个标题（选填）',
                hintStyle: TextStyle(
                  color: colors.onSurfaceVariant.withValues(alpha: .5),
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                ),
                counterText: '',
                filled: false,
                isDense: true,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
          TextField(
            key: const ValueKey('forum-thread-body'),
            controller: _bodyController,
            enabled: !_submitting,
            maxLength: 2000,
            minLines: _longArticleMode ? 14 : 8,
            maxLines: _longArticleMode ? null : 14,
            textCapitalization: TextCapitalization.sentences,
            style: const TextStyle(fontSize: 16, height: 1.6),
            decoration: InputDecoration(
              hintText: _longArticleMode ? '从这里开始你的长文…' : '分享校园里的新鲜事、经验或问题…',
              hintStyle: TextStyle(
                color: colors.onSurfaceVariant.withValues(alpha: .65),
                fontSize: 15,
              ),
              filled: false,
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              counterText: '${_bodyController.text.characters.length}/2000',
              counterStyle: TextStyle(
                color: colors.onSurfaceVariant.withValues(alpha: .75),
                fontSize: 11,
              ),
              contentPadding: const EdgeInsets.symmetric(vertical: 14),
            ),
            onChanged: (_) => setState(() {}),
          ),
          if (_pollDraft != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: ForumPollCard(
                data: ForumPollData(
                  question: _pollDraft!.question,
                  options: _pollDraft!.options,
                ),
                onRemove: _submitting
                    ? null
                    : () => setState(() => _pollDraft = null),
              ),
            ),
          if (_images.isNotEmpty || _keptAssetIds.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final assetId in _keptAssetIds)
                    _AssetThumbnail(
                      key: ValueKey('forum-kept-image-$assetId'),
                      assetId: assetId,
                      repository: widget.repository,
                      onRemove: _submitting
                          ? null
                          : () => setState(() {
                              _keptAssetIds.remove(assetId);
                              _imageError = null;
                            }),
                    ),
                  for (var index = 0; index < _images.length; index++)
                    _ImageThumbnail(
                      key: ValueKey('forum-image-$index'),
                      image: _images[index],
                      onRemove: _submitting
                          ? null
                          : () => setState(() {
                              _images.removeAt(index);
                              _imageError = null;
                            }),
                    ),
                ],
              ),
            ),
          if (_imageError != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: _buildErrorBanner(_imageError!),
            ),
          _buildAttachmentEntry(context),
          if (_error != null) _buildErrorBanner(_error!),
        ],
      ),
    );
  }
}

class _EditorToolButton extends StatelessWidget {
  const _EditorToolButton({
    super.key,
    required this.label,
    required this.icon,
    required this.onTap,
    this.selected = false,
    this.busy = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onTap;
  final bool selected;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final accent = pageAccent(context);
    final foreground = onTap == null && !busy
        ? colors.onSurfaceVariant.withValues(alpha: .35)
        : selected
        ? accent
        : colors.onSurfaceVariant;
    return Expanded(
      child: Semantics(
        button: true,
        label: label,
        child: Material(
          color: selected ? accent.withValues(alpha: .075) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(12),
            splashColor: accent.withValues(alpha: .07),
            child: SizedBox(
              height: 48,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (busy)
                    SizedBox(
                      width: 19,
                      height: 19,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: accent,
                      ),
                    )
                  else
                    Icon(icon, size: 22, color: foreground),
                  const SizedBox(height: 4),
                  Text(
                    label,
                    style: TextStyle(
                      color: foreground,
                      fontSize: 11,
                      height: 1.2,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 待上传的附图：assetId 在上传成功后回填，重试时跳过已上传部分。
class _ForumImage {
  _ForumImage({required this.bytes, required this.filename});

  final Uint8List bytes;
  final String filename;
  String? assetId;
}

class _ImageThumbnail extends StatelessWidget {
  const _ImageThumbnail({super.key, required this.image, this.onRemove});

  final _ForumImage image;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) => Stack(
    children: [
      ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.memory(
          image.bytes,
          width: 88,
          height: 88,
          // 选图后最多 1920px，缩略图只按 88 逻辑像素解码。
          cacheWidth: (88 * MediaQuery.devicePixelRatioOf(context)).ceil(),
          fit: BoxFit.cover,
        ),
      ),
      Positioned(
        top: 2,
        right: 2,
        child: InkWell(
          onTap: onRemove,
          customBorder: const CircleBorder(),
          child: Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: .55),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.close_rounded,
              size: 14,
              color: Colors.white,
            ),
          ),
        ),
      ),
    ],
  );
}

/// 编辑模式下列出保留的已上传图片，复用受保护资产缓存。
class _AssetThumbnail extends StatelessWidget {
  const _AssetThumbnail({
    super.key,
    required this.assetId,
    required this.repository,
    this.onRemove,
  });

  final String assetId;
  final CampusRepository? repository;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) => Stack(
    children: [
      CampusAssetImage(
        assetId: assetId,
        repository: repository,
        width: 88,
        height: 88,
        radius: 12,
        fallback: Icons.image_outlined,
      ),
      Positioned(
        top: 2,
        right: 2,
        child: InkWell(
          onTap: onRemove,
          customBorder: const CircleBorder(),
          child: Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: .55),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.close_rounded,
              size: 14,
              color: Colors.white,
            ),
          ),
        ),
      ),
    ],
  );
}
