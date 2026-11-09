import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

/// 先展示已下载的小图，打开预览后再通过原有鉴权接口加载原图。
Future<void> showCampusImagePreview(
  BuildContext context,
  Uint8List bytes, {
  Future<Uint8List?> Function(bool refresh)? loadOriginal,
  String? downloadName,
}) => showDialog<void>(
  context: context,
  useSafeArea: false,
  builder: (_) => _CampusImagePreview(
    bytes: bytes,
    loadOriginal: loadOriginal,
    downloadName: downloadName,
  ),
);

class _CampusImagePreview extends StatefulWidget {
  const _CampusImagePreview({
    required this.bytes,
    this.loadOriginal,
    this.downloadName,
  });
  final Uint8List bytes;
  final Future<Uint8List?> Function(bool refresh)? loadOriginal;
  final String? downloadName;

  @override
  State<_CampusImagePreview> createState() => _CampusImagePreviewState();
}

class _CampusImagePreviewState extends State<_CampusImagePreview> {
  Future<Uint8List?>? _original;
  bool _downloading = false;

  void _loadOriginal({bool refresh = false}) {
    final loader = widget.loadOriginal;
    if (loader == null || _original != null) return;
    final future = loader(refresh);
    setState(() {
      _original = future;
    });
  }

  Future<void> _downloadOriginal() async {
    final loader = widget.loadOriginal;
    if (loader == null || _downloading) return;
    setState(() => _downloading = true);
    try {
      final future = _original ?? loader(false);
      if (_original == null && mounted) {
        setState(() {
          _original = future;
        });
      }
      final bytes = await future;
      if (!mounted || bytes == null || bytes.isEmpty) throw StateError('image');
      final directory = await getApplicationDocumentsDirectory();
      final name = _safeFileName(widget.downloadName ?? 'campus-image');
      final file = File('${directory.path}/$name.jpg');
      await file.writeAsBytes(bytes, flush: true);
      if (!mounted) return;
      final result = await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path, mimeType: 'image/jpeg')],
          title: '保存图片',
        ),
      );
      if (!mounted) return;
      if (result.status != ShareResultStatus.dismissed) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('图片已保存，可在分享面板中存入本地相册或文件')));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('图片下载失败，请稍后重试')));
      }
    } finally {
      if (mounted) setState(() => _downloading = false);
    }
  }

  String _safeFileName(String value) {
    final cleaned = value.replaceAll(RegExp(r'[^A-Za-z0-9_-]+'), '-');
    return cleaned.isEmpty ? 'campus-image' : 'campus-image-$cleaned';
  }

  Widget _image(Uint8List bytes, {bool canRetry = false}) => Image(
    // 保持原图比例并限制解码尺寸，避免大照片预览耗尽内存。
    image: ResizeImage(
      MemoryImage(bytes),
      width: 4096,
      height: 4096,
      policy: ResizeImagePolicy.fit,
    ),
    fit: BoxFit.contain,
    gaplessPlayback: true,
    semanticLabel: '图片预览，可双指缩放',
    errorBuilder: (_, _, _) => canRetry
        ? Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(child: _image(widget.bytes)),
              _retry(),
            ],
          )
        : const Text('图片无法显示，请关闭后重试', style: TextStyle(color: Colors.white)),
  );

  Widget _retry() => TextButton(
    onPressed: () {
      _original = null;
      _loadOriginal(refresh: true);
    },
    child: const Text('原图加载失败，点击重试', style: TextStyle(color: Colors.white)),
  );

  @override
  Widget build(BuildContext context) => Dialog.fullscreen(
    backgroundColor: Colors.black,
    child: FutureBuilder<Uint8List?>(
      future: _original,
      builder: (context, snapshot) {
        final bytes = snapshot.connectionState == ConnectionState.done
            ? snapshot.data
            : null;
        return Stack(
          children: [
            Positioned.fill(
              child: InteractiveViewer(
                minScale: 1,
                maxScale: 5,
                child: Center(
                  child: _image(bytes ?? widget.bytes, canRetry: bytes != null),
                ),
              ),
            ),
            if (widget.loadOriginal != null)
              SafeArea(
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 18),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        FilledButton.tonalIcon(
                          onPressed:
                              snapshot.connectionState ==
                                  ConnectionState.waiting
                              ? null
                              : bytes == null
                              ? () => _loadOriginal()
                              : null,
                          icon: const Icon(Icons.high_quality_outlined),
                          label: Text(
                            snapshot.connectionState == ConnectionState.waiting
                                ? '正在加载…'
                                : bytes == null
                                ? '加载原图'
                                : '原图已加载',
                          ),
                        ),
                        const SizedBox(width: 8),
                        FilledButton.tonalIcon(
                          onPressed: _downloading ? null : _downloadOriginal,
                          icon: _downloading
                              ? const SizedBox.square(
                                  dimension: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.file_download_outlined),
                          label: const Text('下载到本地'),
                        ),
                        if (bytes == null &&
                            snapshot.connectionState == ConnectionState.done)
                          _retry(),
                      ],
                    ),
                  ),
                ),
              ),
            SafeArea(
              child: Align(
                alignment: Alignment.topRight,
                child: IconButton(
                  tooltip: '关闭大图',
                  color: Colors.white,
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded),
                ),
              ),
            ),
          ],
        );
      },
    ),
  );
}
