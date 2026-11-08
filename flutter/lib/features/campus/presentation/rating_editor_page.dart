import 'dart:typed_data';

import 'package:chengxin_youyou/features/campus/data/campus_repository.dart';
import 'package:chengxin_youyou/features/campus/models/campus_models.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../ui/components/page_layout.dart';
import 'campus_theme.dart';
import 'campus_image_picker.dart';

class RatingEditorPage extends StatefulWidget {
  const RatingEditorPage({super.key, required this.repository, this.boardId});

  final CampusRepository? repository;
  final String? boardId;

  @override
  State<RatingEditorPage> createState() => _RatingEditorPageState();
}

class _RatingEditorPageState extends State<RatingEditorPage> {
  final _picker = ImagePicker();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  Uint8List? _imageBytes;
  String? _filename;
  String? _imageError;
  String? _error;
  String? _uploadedAssetId;
  final _requestId = createCampusRequestId();
  bool _submitting = false;
  bool _pickingImage = false;

  bool get _creatingItem => widget.boardId != null;

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    if (_pickingImage || _submitting) return;
    setState(() => _pickingImage = true);
    try {
      final file = await pickCampusImage(_picker);
      if (file == null || !mounted) return;
      final image = await readCampusUploadImage(file);
      if (!mounted) return;
      setState(() {
        _imageBytes = image.bytes;
        _filename = image.filename;
        _uploadedAssetId = null;
        _imageError = null;
      });
    } catch (error) {
      if (mounted) {
        setState(
          () => _imageError = error is CampusImageException
              ? error.message
              : '无法读取图片，请重新选择。',
        );
      }
    } finally {
      if (mounted) setState(() => _pickingImage = false);
    }
  }

  String _mimeFromName(String name) => name.toLowerCase().endsWith('.png')
      ? 'image/png'
      : name.toLowerCase().endsWith('.jpg') ||
            name.toLowerCase().endsWith('.jpeg')
      ? 'image/jpeg'
      : '';

  Future<void> _submit() async {
    if (_submitting || _pickingImage) return;
    final title = _titleController.text.trim();
    final description = _descriptionController.text.trim();
    final titleLength = title.characters.length;
    final descriptionLimit = _creatingItem ? 1000 : 500;
    if (titleLength < (_creatingItem ? 1 : 2) ||
        titleLength > (_creatingItem ? 60 : 40) ||
        description.characters.length > descriptionLimit ||
        widget.repository == null) {
      setState(() => _error = '请检查标题和介绍内容。');
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      if (_imageBytes != null && _uploadedAssetId == null) {
        _uploadedAssetId = await widget.repository!.uploadAsset(
          filename: _filename ?? 'campus-image.jpg',
          bytes: _imageBytes!,
          mimeType: _mimeFromName(_filename ?? ''),
        );
      }
      if (_creatingItem) {
        final item = await widget.repository!.createRatingItem(
          boardId: widget.boardId!,
          name: title,
          description: description,
          imageAssetId: _uploadedAssetId,
          requestId: _requestId,
        );
        if (mounted) {
          context.goNamed('rating-item', pathParameters: {'itemId': item.id});
        }
      } else {
        final board = await widget.repository!.createBoard(
          title: title,
          description: description,
          coverAssetId: _uploadedAssetId,
          requestId: _requestId,
        );
        if (mounted) {
          context.goNamed(
            'rating-board',
            pathParameters: {'boardId': board.id},
          );
        }
      }
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) =>
      CampusThemeBuilder(builder: _buildScaffold);

  Widget _buildScaffold(BuildContext context) => PageScaffold(
    title: _creatingItem ? '添加评分对象' : '创建评分板块',
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
                        _creatingItem ? '对象信息' : '板块信息',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    const Text('必填'),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _titleController,
                  maxLength: _creatingItem ? 60 : 40,
                  decoration: InputDecoration(
                    labelText: _creatingItem ? '对象名称' : '板块标题',
                    hintText: _creatingItem ? '例如：航空港一食堂麻辣烫' : '例如：校园食堂窗口评分',
                  ),
                ),
                TextField(
                  controller: _descriptionController,
                  maxLength: _creatingItem ? 1000 : 500,
                  minLines: 3,
                  maxLines: 6,
                  decoration: InputDecoration(
                    labelText: '介绍',
                    hintText: _creatingItem
                        ? '介绍这个对象，帮助大家确认评价的是谁。'
                        : '说明这个板块评价什么、如何区分评分对象。',
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
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        _creatingItem ? '对象图片' : '板块封面',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    const Text('可选'),
                  ],
                ),
                const SizedBox(height: 12),
                InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: _submitting || _pickingImage ? null : _pickImage,
                  child: Container(
                    height: _imageBytes == null ? 104 : 140,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Theme.of(
                        context,
                      ).colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: _imageBytes == null
                        ? const Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.add_photo_alternate_outlined,
                                size: 36,
                              ),
                              SizedBox(height: 8),
                              Text('选择 JPG 或 PNG'),
                            ],
                          )
                        : ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: Image.memory(
                              _imageBytes!,
                              // 预览区不到 400 逻辑像素宽，按预览尺寸解码即可。
                              cacheWidth:
                                  (MediaQuery.sizeOf(context).width *
                                          MediaQuery.devicePixelRatioOf(
                                            context,
                                          ))
                                      .ceil(),
                              fit: BoxFit.cover,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 8),
                const Text('上传前会适度压缩图片，处理后不超过 5 MB。'),
                if (_imageBytes != null || _imageError != null)
                  TextButton.icon(
                    onPressed: _submitting
                        ? null
                        : () => setState(() {
                            _imageBytes = null;
                            _filename = null;
                            _uploadedAssetId = null;
                            _imageError = null;
                          }),
                    icon: const Icon(Icons.delete_outline_rounded),
                    label: const Text('移除图片'),
                  ),
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
          onPressed: _submitting || _pickingImage ? null : _submit,
          child: Text(_submitting ? '正在发布…' : '确认发布'),
        ),
      ],
    ),
  );
}
