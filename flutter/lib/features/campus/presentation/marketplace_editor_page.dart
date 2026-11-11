import 'package:chengxin_youyou/features/campus/data/campus_repository.dart';
import 'package:chengxin_youyou/features/campus/models/campus_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../ui/components/page_layout.dart';
import 'campus_theme.dart';
import 'campus_image_picker.dart';
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
  bool _pickingImage = false;

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

  String _mimeFromName(String name) {
    final lower = name.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) return 'image/jpeg';
    return '';
  }

  Future<void> _submit() async {
    if (_submitting || _pickingImage) return;
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

  void _clearImage() {
    setState(() {
      _imageBytes = null;
      _filename = null;
      _uploadedAssetId = null;
      _imageError = null;
    });
  }

  InputDecoration _field({
    required String label,
    String? hint,
    String? errorText,
  }) => InputDecoration(
    labelText: label,
    hintText: hint,
    errorText: errorText,
    filled: true,
    fillColor: context.campusColors.controlSurface,
    isDense: true,
    counterText: '',
  );

  @override
  Widget build(BuildContext context) =>
      CampusThemeBuilder(builder: _buildScaffold);

  Widget _buildScaffold(BuildContext context) => PageScaffold(
    title: _wanted ? '发布求购' : '发布闲置',
    backgroundColor: context.campusColors.canvas,
    bottomNavigationBar: _PublishBar(
      error: _error,
      label: _submitting
          ? '正在发布…'
          : _wanted
          ? '发布求购'
          : '确认上架',
      onPressed: _submitting || _pickingImage ? null : _submit,
    ),
    child: ListView(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 20),
      children: [
        Container(
          padding: const EdgeInsets.all(5),
          decoration: campusCardDecoration(context, radius: 16),
          child: PageSegmentedControl<String>(
            values: const {'sell': '我要出售', 'wanted': '我想求购'},
            selected: _listingType,
            onChanged: _submitting
                ? null
                : (value) => setState(() => _listingType = value),
          ),
        ),
        const SizedBox(height: 10),
        _EditorSection(
          title: _wanted ? '求购信息' : '商品信息',
          trailing: '必填',
          children: [
            TextField(
              controller: _titleController,
              textInputAction: TextInputAction.next,
              enabled: !_submitting,
              // 用输入截断代替 maxLength，省掉输入框下方常驻的计数器占位。
              inputFormatters: [LengthLimitingTextInputFormatter(60)],
              decoration: _field(
                label: _wanted ? '求购标题' : '商品标题',
                hint: _wanted ? '例如：求购一盏护眼台灯' : '例如：九成新台灯',
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _descriptionController,
              minLines: 3,
              maxLines: 5,
              enabled: !_submitting,
              inputFormatters: [LengthLimitingTextInputFormatter(2000)],
              decoration: _field(
                label: _wanted ? '需求说明' : '商品描述',
                hint: _wanted
                    ? '说说想要的型号、成色要求和期望交易地点。'
                    : '说说成色、使用情况、配件和交易地点，如有瑕疵请注明。',
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _priceController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              enabled: !_submitting,
              inputFormatters: [LengthLimitingTextInputFormatter(8)],
              onChanged: (_) => setState(() {}),
              decoration: _field(
                label: _wanted ? '预算（元）' : '价格（元）',
                hint: '0.00',
                errorText:
                    _priceController.text.isNotEmpty && _priceCents == null
                    ? '金额为 0.01–99999.99 元，最多两位小数'
                    : null,
              ).copyWith(prefixText: '¥ '),
            ),
            const SizedBox(height: 4),
            _EditorLabel('交易校区'),
            const SizedBox(height: 8),
            _EditorChoiceRow<String>(
              values: const {'airport': '航空港校区', 'longquan': '龙泉校区'},
              selected: _campus,
              onChanged: _submitting
                  ? null
                  : (value) => setState(() => _campus = value),
            ),
          ],
        ),
        const SizedBox(height: 10),
        _EditorSection(
          title: _wanted ? '参考图片（选填）' : '商品图片（选填）',
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildImageTile(context),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _imageBytes == null
                            ? '点击左侧方框添加一张${_wanted ? '参考' : '实拍'}图'
                            : '已选择图片，点击图片可更换或移除',
                        style: const TextStyle(fontSize: 12),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '上传前会压缩，最大 5 MB。',
                        style: TextStyle(
                          fontSize: 11,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                      if (_imageError != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 5),
                          child: Text(
                            _imageError!,
                            style: TextStyle(
                              fontSize: 11,
                              color: Theme.of(context).colorScheme.error,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 10),
        _EditorSection(
          title: _wanted ? '我的联系方式' : '联系卖家',
          trailing: '对方看详情后才可见',
          children: [
            _EditorChoiceRow<String>(
              values: const {'wechat': '微信', 'qq': 'QQ', 'phone': '手机号'},
              selected: _contactType,
              onChanged: _submitting
                  ? null
                  : (value) => setState(() => _contactType = value),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _contactController,
              enabled: !_submitting,
              inputFormatters: [LengthLimitingTextInputFormatter(80)],
              onChanged: (_) => setState(() {}),
              keyboardType: _contactType == 'wechat'
                  ? TextInputType.text
                  : TextInputType.number,
              decoration: _field(
                label: switch (_contactType) {
                  'qq' => 'QQ 号',
                  'phone' => '手机号',
                  _ => '微信号',
                },
                hint: '填写对方可以联系到你的${contactLabel(_contactType)}',
                errorText: _contactController.text.isNotEmpty && !_contactValid
                    ? '请填写有效的${contactLabel(_contactType)}，不要包含空格'
                    : null,
              ),
            ),
          ],
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(4, 12, 4, 0),
          child: Text(
            '买卖双方自行联系、约定交易，本版本暂不支持在线支付。',
            style: TextStyle(fontSize: 11, color: context.campusColors.muted),
          ),
        ),
      ],
    ),
  );

  Widget _buildImageTile(BuildContext context) {
    final busy = _submitting || _pickingImage;
    return SizedBox(
      width: 88,
      height: 88,
      child: _imageBytes == null
          ? Material(
              color: context.campusColors.controlSurface,
              borderRadius: BorderRadius.circular(14),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: busy ? null : _pickImage,
                child: Center(
                  child: _pickingImage
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(
                          Icons.add_photo_alternate_outlined,
                          size: 26,
                        ),
                ),
              ),
            )
          : Stack(
              children: [
                Positioned.fill(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: Image.memory(
                      _imageBytes!,
                      // 缩略图只按 88 逻辑像素解码，避免整张原图占内存。
                      cacheWidth: (88 * MediaQuery.devicePixelRatioOf(context))
                          .ceil(),
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                Positioned.fill(
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(onTap: busy ? null : _pickImage),
                  ),
                ),
                Positioned(
                  top: 3,
                  right: 3,
                  child: Tooltip(
                    message: '移除图片',
                    child: Material(
                      color: const Color(0x8A000000),
                      shape: const CircleBorder(),
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: busy ? null : _clearImage,
                        child: const Padding(
                          padding: EdgeInsets.all(5),
                          child: Icon(
                            Icons.close_rounded,
                            size: 13,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

/// 表单分组：白面细描边卡片，标题一行到顶，避免多层标题堆叠。
class _EditorSection extends StatelessWidget {
  const _EditorSection({this.title, this.trailing, required this.children});
  final String? title;
  final String? trailing;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final title = this.title;
    final trailing = this.trailing;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      decoration: campusCardDecoration(context, radius: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null) ...[
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (trailing != null)
                  Flexible(
                    child: Text(
                      trailing,
                      textAlign: TextAlign.right,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),
          ],
          ...children,
        ],
      ),
    );
  }
}

class _EditorLabel extends StatelessWidget {
  const _EditorLabel(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Text(
    text,
    style: TextStyle(
      fontSize: 12,
      color: Theme.of(context).colorScheme.onSurfaceVariant,
    ),
  );
}

/// 胶囊选项组：替代下拉框，一行点选，节省一整个输入框的高度。
class _EditorChoiceRow<T> extends StatelessWidget {
  const _EditorChoiceRow({
    required this.values,
    required this.selected,
    required this.onChanged,
  });
  final Map<T, String> values;
  final T selected;
  final ValueChanged<T>? onChanged;

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 8,
    runSpacing: 8,
    children: [
      for (final entry in values.entries)
        Semantics(
          button: true,
          selected: entry.key == selected,
          child: GestureDetector(
            onTap: onChanged == null ? null : () => onChanged!(entry.key),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              constraints: const BoxConstraints(minHeight: 44),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: entry.key == selected
                    ? context.campusColors.ink
                    : context.campusColors.controlSurface,
                borderRadius: BorderRadius.circular(12),
              ),
              // Center 带 widthFactor，胶囊按文字宽度收缩，不再撑满整行。
              child: Center(
                widthFactor: 1,
                child: Text(
                  entry.value,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: entry.key == selected
                        ? context.campusColors.onInk
                        : context.campusColors.muted,
                  ),
                ),
              ),
            ),
          ),
        ),
    ],
  );
}

/// 固定在底部的发布栏：错误提示与主按钮始终可见，不用滚到列表末尾。
class _PublishBar extends StatelessWidget {
  const _PublishBar({
    required this.error,
    required this.label,
    required this.onPressed,
  });
  final String? error;
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => SafeArea(
    top: false,
    child: Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          top: BorderSide(color: context.campusColors.cardLine, width: .8),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                error!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.error,
                ),
              ),
            ),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: onPressed,
              style: FilledButton.styleFrom(
                backgroundColor: context.campusColors.ink,
                foregroundColor: context.campusColors.onInk,
              ),
              child: Text(label),
            ),
          ),
        ],
      ),
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
