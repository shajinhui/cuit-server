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

/// 发帖页：选择版块 + 标题 + 正文 + 最多三张附图。传入 editingThread 时进入编辑模式。
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
  static const _maxImageBytes = 5 * 1024 * 1024;

  final _picker = ImagePicker();
  final _titleController = TextEditingController();
  final _bodyController = TextEditingController();
  final _images = <_ForumImage>[];
  List<String> _keptAssetIds = [];
  List<ForumCategory> _categories = [];
  String? _selectedCategoryId;
  String? _categoriesError;
  String? _imageError;
  String? _error;
  String _requestId = createCampusRequestId();
  String _lastPayload = '';
  bool _categoriesLoading = true;
  bool _submitting = false;

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
    final remaining = _maxImages - _images.length - _keptAssetIds.length;
    if (remaining <= 0) {
      setState(() => _imageError = '最多添加 $_maxImages 张图片');
      return;
    }
    try {
      final files = await _picker.pickMultiImage(
        requestFullMetadata: false,
        limit: remaining,
      );
      if (files.isEmpty) return;
      String? error;
      for (final file in files) {
        final mime = file.mimeType ?? _mimeFromName(file.name);
        if (mime != 'image/jpeg' && mime != 'image/png') {
          error = '只支持 JPG 或 PNG 图片';
          continue;
        }
        final bytes = await file.readAsBytes();
        if (bytes.length > _maxImageBytes) {
          error = '单张图片不能超过 5 MB';
          continue;
        }
        _images.add(_ForumImage(bytes: bytes, filename: file.name));
      }
      if (mounted) setState(() => _imageError = error);
    } catch (error) {
      if (mounted) setState(() => _imageError = '无法读取图片：$error');
    }
  }

  String _mimeFromName(String name) {
    final lower = name.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) return 'image/jpeg';
    return '';
  }

  Future<void> _submit() async {
    if (_submitting) return;
    final repository = widget.repository;
    final categoryId = _selectedCategoryId;
    final title = _titleController.text.trim();
    final body = _bodyController.text.trim();
    final titleLength = title.characters.length;
    if (repository == null ||
        categoryId == null ||
        titleLength < 2 ||
        titleLength > 50 ||
        body.isEmpty ||
        body.characters.length > 2000) {
      setState(() => _error = '请选择版块，并填写 2 到 50 字的标题与正文。');
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

  @override
  Widget build(BuildContext context) => PageScaffold(
    title: _editing ? '编辑帖子' : '发布帖子',
    child: ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: [
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
                        '选择版块',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    const Text('必填'),
                  ],
                ),
                const SizedBox(height: 12),
                if (_categoriesLoading)
                  const CampusPageState(title: '正在加载版块', loading: true)
                else if (_categoriesError != null)
                  CampusPageState(
                    title: '版块加载失败',
                    description: _categoriesError,
                    actionLabel: '重新加载',
                    onAction: _loadCategories,
                  )
                else if (_categories.isEmpty)
                  const Text('暂时没有可用版块，稍后再试。')
                else
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final category in _categories)
                        PageChoiceButton(
                          key: ValueKey('forum-category-${category.id}'),
                          label: category.name,
                          selected: category.id == _selectedCategoryId,
                          onPressed: _submitting
                              ? null
                              : () => setState(
                                  () => _selectedCategoryId = category.id,
                                ),
                        ),
                    ],
                  ),
              ],
            ),
          ),
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
                        '帖子内容',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    const Text('必填'),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  key: const ValueKey('forum-thread-title'),
                  controller: _titleController,
                  enabled: !_submitting,
                  maxLength: 50,
                  decoration: const InputDecoration(
                    labelText: '标题',
                    hintText: '一句话说清要讨论什么',
                  ),
                ),
                TextField(
                  key: const ValueKey('forum-thread-body'),
                  controller: _bodyController,
                  enabled: !_submitting,
                  maxLength: 2000,
                  minLines: 5,
                  maxLines: 12,
                  decoration: const InputDecoration(
                    labelText: '正文',
                    hintText: '展开说说你的想法，纯文本即可。',
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '附图（选填，最多 $_maxImages 张）',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    // 编辑模式下先列出保留的原图，其次才是新选的图。
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
                    if (_images.length + _keptAssetIds.length < _maxImages)
                      InkWell(
                        key: const ValueKey('forum-add-image'),
                        borderRadius: BorderRadius.circular(12),
                        onTap: _submitting ? null : _pickImages,
                        child: Container(
                          width: 88,
                          height: 88,
                          decoration: BoxDecoration(
                            color: Theme.of(
                              context,
                            ).colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.add_photo_alternate_outlined),
                              SizedBox(height: 4),
                              Text('添加图片', style: TextStyle(fontSize: 12)),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                const Text('支持 JPG、PNG，单张最大 5 MB。'),
                if (_imageError != null)
                  Text(
                    _imageError!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
              ],
            ),
          ),
        ),
        if (_error != null) ...[
          const SizedBox(height: 8),
          Text(
            _error!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ],
        const SizedBox(height: 12),
        FilledButton(
          key: const ValueKey('forum-thread-submit'),
          onPressed: _submitting ? null : _submit,
          child: Text(
            _submitting
                ? (_editing ? '正在保存…' : '正在发布…')
                : (_editing ? '保存修改' : '发布帖子'),
          ),
        ),
      ],
    ),
  );
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
