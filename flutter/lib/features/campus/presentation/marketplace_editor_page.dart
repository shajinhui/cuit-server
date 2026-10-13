import 'dart:typed_data';

import 'package:chengxin_youyou/features/campus/data/campus_repository.dart';
import 'package:chengxin_youyou/features/campus/models/campus_models.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../ui/components/page_layout.dart';
import '../../../ui/components/page_selection.dart';
import 'campus_widgets.dart';

class MarketplaceEditorPage extends StatefulWidget {
  const MarketplaceEditorPage({
    super.key,
    required this.repository,
    this.initialType = 'sell',
  });

  final CampusRepository? repository;
  final String initialType;

  @override
  State<MarketplaceEditorPage> createState() => _MarketplaceEditorPageState();
}

class _MarketplaceEditorPageState extends State<MarketplaceEditorPage> {
  final _picker = ImagePicker();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _priceController = TextEditingController();
  final _contactController = TextEditingController();
  String _listingType = 'sell';
  String _campus = 'airport';
  String _contactType = 'wechat';
  Uint8List? _imageBytes;
  String? _filename;
  String? _imageError;
  String? _uploadedAssetId;
  String? _error;
  String _requestId = '';
  String _lastPayload = '';
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _listingType = widget.initialType == 'wanted' ? 'wanted' : 'sell';
    _requestId = createCampusRequestId();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    _contactController.dispose();
    super.dispose();
  }

  bool get _wanted => _listingType == 'wanted';
  int? get _priceCents => parseCampusPrice(_priceController.text);
  bool get _contactValid =>
      isCampusContactValid(_contactType, _contactController.text);

  Future<void> _pickImage() async {
    try {
      final file = await _picker.pickImage(
        source: ImageSource.gallery,
        requestFullMetadata: false,
      );
      if (file == null) return;
      final mime = file.mimeType ?? _mimeFromName(file.name);
      if (mime != 'image/jpeg' && mime != 'image/png') {
        setState(() {
          _imageBytes = null;
          _filename = null;
          _uploadedAssetId = null;
          _imageError = '请选择 JPG 或 PNG 图片';
        });
        return;
      }
      final bytes = await file.readAsBytes();
      if (bytes.length > 5 * 1024 * 1024) {
        setState(() {
          _imageBytes = null;
          _filename = null;
          _uploadedAssetId = null;
          _imageError = '图片不能超过 5 MB';
        });
        return;
      }
      setState(() {
        _imageBytes = bytes;
        _filename = file.name;
        _uploadedAssetId = null;
        _imageError = null;
      });
    } catch (error) {
      setState(() => _imageError = '无法读取图片：$error');
    }
  }

  String _mimeFromName(String name) {
    final lower = name.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) return 'image/jpeg';
    return '';
  }

  Future<void> _submit() async {
    final title = _titleController.text.trim();
    final description = _descriptionController.text.trim();
    final price = _priceCents;
    final contact = _contactController.text.trim();
    if (title.isEmpty ||
        title.characters.length > 60 ||
        description.isEmpty ||
        description.characters.length > 2000 ||
        price == null ||
        !_contactValid ||
        _imageError != null ||
        widget.repository == null) {
      setState(() => _error = '请检查必填内容、价格和联系方式。');
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final payloadKey = [
        _listingType,
        title,
        description,
        price,
        _campus,
        _contactType,
        contact,
        _filename ?? '',
        _imageBytes == null ? '' : Object.hashAll(_imageBytes!).toString(),
      ].join('\u0000');
      if (_lastPayload.isNotEmpty && _lastPayload != payloadKey) {
        _requestId = createCampusRequestId();
      }
      _lastPayload = payloadKey;
      if (_imageBytes != null && _uploadedAssetId == null) {
        _uploadedAssetId = await widget.repository!.uploadAsset(
          filename: _filename ?? 'marketplace-image.jpg',
          bytes: _imageBytes!,
          mimeType: _mimeFromName(_filename ?? ''),
        );
      }
      final item = await widget.repository!.createListing(
        title: title,
        description: description,
        priceCents: price,
        campus: _campus,
        type: _listingType,
        contactType: _contactType,
        contactValue: contact,
        imageAssetId: _uploadedAssetId,
        requestId: _requestId,
      );
      if (mounted) {
        context.goNamed(
          'marketplace-item',
          pathParameters: {'itemId': item.id},
          queryParameters: {'type': item.listingType},
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
    title: _wanted ? '发布求购' : '发布闲置',
    child: ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                PageSegmentedControl<String>(
                  values: const {'sell': '我要出售', 'wanted': '我想求购'},
                  selected: _listingType,
                  onChanged: _submitting
                      ? null
                      : (value) => setState(() => _listingType = value),
                ),
                const SizedBox(height: 16),
                Text(
                  _wanted ? '求购信息' : '商品信息',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _titleController,
                  maxLength: 60,
                  decoration: InputDecoration(
                    labelText: _wanted ? '求购标题' : '商品标题',
                    hintText: _wanted ? '例如：求购一盏护眼台灯' : '例如：九成新台灯',
                  ),
                ),
                TextField(
                  controller: _descriptionController,
                  maxLength: 2000,
                  minLines: 3,
                  maxLines: 6,
                  decoration: InputDecoration(
                    labelText: _wanted ? '需求说明' : '商品描述',
                    hintText: _wanted
                        ? '说说想要的型号、成色要求和期望交易地点。'
                        : '说说成色、使用情况、配件和交易地点，如有瑕疵请注明。',
                  ),
                ),
                TextField(
                  controller: _priceController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  maxLength: 8,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    labelText: _wanted ? '预算（元）' : '价格（元）',
                    prefixText: '¥ ',
                    hintText: '0.00',
                    counterText: '',
                    errorText:
                        _priceController.text.isNotEmpty && _priceCents == null
                        ? '金额为 0.01–99999.99 元，最多两位小数'
                        : null,
                  ),
                ),
                PageDropdownField<String>(
                  value: _campus,
                  decoration: const InputDecoration(labelText: '交易校区'),
                  values: const {'airport': '航空港校区', 'longquan': '龙泉校区'},
                  onChanged: _submitting
                      ? null
                      : (value) {
                          if (value != null) setState(() => _campus = value);
                        },
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
                  _wanted ? '参考图片（选填）' : '商品图片（选填）',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 10),
                InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: _submitting ? null : _pickImage,
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
                        ? Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.add_photo_alternate_outlined,
                                size: 36,
                              ),
                              const SizedBox(height: 8),
                              Text(_wanted ? '添加一张参考图' : '添加一张实拍图'),
                            ],
                          )
                        : ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: Image.memory(
                              _imageBytes!,
                              fit: BoxFit.cover,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 6),
                const Text('支持 JPG、PNG，最大 5 MB。'),
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
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _wanted ? '我的联系方式' : '联系卖家',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                PageDropdownField<String>(
                  value: _contactType,
                  decoration: const InputDecoration(labelText: '联系方式'),
                  values: const {'wechat': '微信', 'qq': 'QQ', 'phone': '手机号'},
                  onChanged: _submitting
                      ? null
                      : (value) {
                          if (value != null) {
                            setState(() => _contactType = value);
                          }
                        },
                ),
                TextField(
                  controller: _contactController,
                  maxLength: 80,
                  onChanged: (_) => setState(() {}),
                  keyboardType: _contactType == 'wechat'
                      ? TextInputType.text
                      : TextInputType.number,
                  decoration: InputDecoration(
                    labelText: contactLabel(_contactType),
                    hintText: '填写对方可以联系到你的${contactLabel(_contactType)}',
                    counterText: '',
                    errorText:
                        _contactController.text.isNotEmpty && !_contactValid
                        ? '请填写有效的${contactLabel(_contactType)}，不要包含空格'
                        : null,
                  ),
                ),
                Text('发布即同意向点击“${_wanted ? '我有闲置' : '我想购买'}”的登录用户展示此联系方式。'),
              ],
            ),
          ),
        ),
        const Padding(
          padding: EdgeInsets.all(8),
          child: Text('买卖双方自行联系、约定交易。本版本暂不支持在线支付。'),
        ),
        if (_error != null)
          Text(
            _error!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        const SizedBox(height: 8),
        FilledButton(
          onPressed: _submitting ? null : _submit,
          child: Text(
            _submitting
                ? '正在发布…'
                : _wanted
                ? '发布求购'
                : '确认上架',
          ),
        ),
      ],
    ),
  );
}

int? parseCampusPrice(String input) {
  final value = input.trim();
  if (!RegExp(r'^\d{1,5}(?:\.\d{1,2})?$').hasMatch(value)) return null;
  final parts = value.split('.');
  final cents =
      int.parse(parts.first) * 100 +
      (parts.length == 1 ? 0 : int.parse(parts.last.padRight(2, '0')));
  return cents >= 1 && cents <= 9999999 ? cents : null;
}

bool isCampusContactValid(String type, String value) {
  final contact = value.trim();
  if (contact.isEmpty ||
      contact.length > 80 ||
      RegExp(r'\s').hasMatch(contact)) {
    return false;
  }
  if (type == 'phone') return RegExp(r'^1[3-9]\d{9}$').hasMatch(contact);
  if (type == 'qq') return RegExp(r'^[1-9]\d{4,11}$').hasMatch(contact);
  return true;
}
