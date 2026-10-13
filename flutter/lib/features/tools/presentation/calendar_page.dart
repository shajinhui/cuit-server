import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'tool_page_scaffold.dart';

/// 校历按 Vue 版相同规则，从九月开始计算学年并加载教务处原图。
class AcademicCalendarPage extends StatefulWidget {
  const AcademicCalendarPage({super.key});

  @override
  State<AcademicCalendarPage> createState() => _AcademicCalendarPageState();
}

class _AcademicCalendarPageState extends State<AcademicCalendarPage> {
  late final int _startYear;
  late final Uri _imageUri;
  bool _loading = true;
  bool _failed = false;
  bool _zoomed = false;
  int _imageVersion = 0;
  final _transform = TransformationController();

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _startYear = now.month >= 9 ? now.year : now.year - 1;
    _imageUri = Uri.https(
      'jwc.cuit.edu.cn',
      '/xl${_startYear}_${_startYear + 1}.png',
    );
  }

  @override
  void dispose() {
    _transform.dispose();
    super.dispose();
  }

  void _toggleZoom() => setState(() {
    _zoomed = !_zoomed;
    final scale = _zoomed ? 2.0 : 1.0;
    _transform.value = Matrix4.identity()
      ..scaleByDouble(scale, scale, scale, 1);
  });

  void _retry() => setState(() {
    _loading = true;
    _failed = false;
    _imageVersion++;
  });

  @override
  Widget build(BuildContext context) => ToolPageScaffold(
    title: '校历',
    backgroundColor: Theme.of(context).brightness == Brightness.dark
        ? null
        : const Color(0xFFE9EBEE),
    subtitle: '$_startYear—${_startYear + 1} 学年',
    actions: [
      IconButton(
        tooltip: '打开校历原图',
        onPressed: () =>
            launchUrl(_imageUri, mode: LaunchMode.externalApplication),
        icon: const Icon(Icons.open_in_new_rounded),
      ),
    ],
    child: Padding(
      padding: const EdgeInsets.fromLTRB(22, 12, 22, 10),
      child: Column(
        children: [
          Expanded(
            child: ToolCard(
              radius: 18,
              padding: EdgeInsets.zero,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (!_failed)
                    InteractiveViewer(
                      transformationController: _transform,
                      minScale: 1,
                      maxScale: 3,
                      child: Center(
                        child: Image.network(
                          '$_imageUri?version=$_imageVersion',
                          key: ValueKey(_imageVersion),
                          fit: BoxFit.contain,
                          loadingBuilder: (context, child, progress) {
                            if (progress == null) {
                              WidgetsBinding.instance.addPostFrameCallback((_) {
                                if (mounted && _loading) {
                                  setState(() {
                                    _loading = false;
                                    _failed = false;
                                  });
                                }
                              });
                              return child;
                            }
                            return const SizedBox.shrink();
                          },
                          errorBuilder: (context, error, stack) {
                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              if (mounted && !_failed) {
                                setState(() {
                                  _loading = false;
                                  _failed = true;
                                });
                              }
                            });
                            return const SizedBox.shrink();
                          },
                        ),
                      ),
                    ),
                  if (_loading && !_failed) const ToolLoading(label: '正在读取校历…'),
                  if (_failed)
                    ToolMessage(
                      message: '校历暂未发布或加载失败。教务处可能尚未上传本学年校历，请稍后再试。',
                      onRetry: _retry,
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          ToolCard(
            radius: 27,
            padding: const EdgeInsets.all(4),
            child: Row(
              children: [
                Expanded(
                  child: TextButton.icon(
                    onPressed: _failed ? null : _toggleZoom,
                    icon: Icon(
                      _zoomed
                          ? Icons.fit_screen_rounded
                          : Icons.zoom_in_rounded,
                      size: 20,
                    ),
                    label: Text(
                      _zoomed ? '适应屏幕' : '放大查看',
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                ),
                Expanded(
                  child: TextButton.icon(
                    onPressed: () => launchUrl(
                      _imageUri,
                      mode: LaunchMode.externalApplication,
                    ),
                    icon: const Icon(Icons.file_download_outlined, size: 20),
                    label: const Text('打开原图', style: TextStyle(fontSize: 13)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '图片来源：成都信息工程大学教务处',
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
