import 'package:flutter/material.dart';

import '../../../ui/components/page_dialog.dart';

import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import 'tool_page_scaffold.dart';

class CampusMapPage extends StatefulWidget {
  const CampusMapPage({super.key});

  @override
  State<CampusMapPage> createState() => _CampusMapPageState();
}

class _CampusMapPageState extends State<CampusMapPage> {
  static const _maps = [
    ('航空港', 'assets/maps/campus-map-airport.jpg', '成都信息工程大学-航空港校区地图.jpg'),
    ('龙泉', 'assets/maps/campus-map-longquan.jpg', '成都信息工程大学-龙泉校区地图.jpg'),
  ];

  int _selected = 0;
  double _scale = 1;
  bool _sharing = false;
  final TransformationController _transform = TransformationController();

  @override
  void dispose() {
    _transform.dispose();
    super.dispose();
  }

  void _setScale(double value) {
    final next = value.clamp(1.0, 2.5);
    setState(() => _scale = next);
    _transform.value = Matrix4.identity()..scaleByDouble(next, next, next, 1);
  }

  Future<void> _showOriginalImage() async {
    final map = _maps[_selected];
    await showPageDialog<void>(
      context,
      builder: (context) => Dialog.fullscreen(
        child: Scaffold(
          appBar: AppBar(
            title: Text('${map.$1}校区地图'),
            leading: IconButton(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.close_rounded),
            ),
          ),
          body: InteractiveViewer(
            minScale: 1,
            maxScale: 4,
            child: Center(child: Image.asset(map.$2)),
          ),
        ),
      ),
    );
  }

  Future<void> _shareMap() async {
    if (_sharing) return;
    setState(() => _sharing = true);
    try {
      final map = _maps[_selected];
      final data = await rootBundle.load(map.$2);
      await SharePlus.instance.share(
        ShareParams(
          files: [
            XFile.fromData(
              data.buffer.asUint8List(),
              mimeType: 'image/jpeg',
              name: map.$3,
            ),
          ],
          title: '${map.$1}校区地图',
        ),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('地图分享失败，请稍后重试')));
      }
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final map = _maps[_selected];
    return ToolPageScaffold(
      title: '校园地图',
      subtitle: '${map.$1}校区地图',
      maxWidth: 720,
      actions: [
        IconButton(
          tooltip: '打开原图',
          onPressed: _showOriginalImage,
          icon: const Icon(Icons.open_in_new_rounded),
        ),
      ],
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 9),
        child: Column(
          children: [
            ToolSegmentedControl<int>(
              values: const {0: '航空港', 1: '龙泉'},
              selected: _selected,
              onChanged: (value) => setState(() {
                _selected = value;
                _scale = 1;
                _transform.value = Matrix4.identity();
              }),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: ToolCard(
                padding: EdgeInsets.zero,
                child: InteractiveViewer(
                  transformationController: _transform,
                  minScale: 1,
                  maxScale: 2.5,
                  onInteractionEnd: (_) => setState(
                    () => _scale = _transform.value.getMaxScaleOnAxis(),
                  ),
                  child: Center(
                    child: GestureDetector(
                      onTap: _showOriginalImage,
                      child: Image.asset(map.$2, fit: BoxFit.contain),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ToolCard(
                    radius: 26,
                    padding: const EdgeInsets.all(4),
                    child: Row(
                      children: [
                        IconButton(
                          tooltip: '缩小地图',
                          onPressed: _scale <= 1
                              ? null
                              : () => _setScale(_scale - .25),
                          icon: const Icon(Icons.remove_rounded),
                        ),
                        Expanded(
                          child: TextButton(
                            onPressed: () => _setScale(1),
                            child: Column(
                              children: [
                                Text(
                                  '${(_scale * 100).round()}%',
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Text(
                                  _scale <= 1 ? '适应屏幕' : '轻点还原',
                                  style: const TextStyle(fontSize: 10),
                                ),
                              ],
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip: '放大地图',
                          onPressed: _scale >= 2.5
                              ? null
                              : () => _setScale(_scale + .25),
                          icon: const Icon(Icons.add_rounded),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                ToolCard(
                  radius: 26,
                  padding: EdgeInsets.zero,
                  child: TextButton.icon(
                    onPressed: _sharing ? null : _shareMap,
                    icon: const Icon(Icons.file_download_outlined, size: 20),
                    label: Text(
                      _sharing ? '准备中' : '保存',
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '轻点地图全屏查看 · 手绘示意图仅供参考',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 10,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
