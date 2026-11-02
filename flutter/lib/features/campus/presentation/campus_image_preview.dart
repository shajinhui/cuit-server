import 'dart:typed_data';

import 'package:flutter/material.dart';

/// 先展示已下载的小图，打开预览后再通过原有鉴权接口加载原图。
Future<void> showCampusImagePreview(
  BuildContext context,
  Uint8List bytes, {
  Future<Uint8List?> Function(bool refresh)? loadOriginal,
}) => showDialog<void>(
  context: context,
  useSafeArea: false,
  builder: (_) => _CampusImagePreview(bytes: bytes, loadOriginal: loadOriginal),
);

class _CampusImagePreview extends StatefulWidget {
  const _CampusImagePreview({required this.bytes, this.loadOriginal});
  final Uint8List bytes;
  final Future<Uint8List?> Function(bool refresh)? loadOriginal;

  @override
  State<_CampusImagePreview> createState() => _CampusImagePreviewState();
}

class _CampusImagePreviewState extends State<_CampusImagePreview> {
  Future<Uint8List?>? _original;

  @override
  void initState() {
    super.initState();
    _original = widget.loadOriginal?.call(false);
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
      final original = widget.loadOriginal?.call(true);
      setState(() {
        _original = original;
      });
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
                  child: snapshot.connectionState != ConnectionState.done
                      ? const Padding(
                          padding: EdgeInsets.all(16),
                          child: Text(
                            '正在加载原图…',
                            style: TextStyle(color: Colors.white),
                          ),
                        )
                      : bytes == null
                      ? _retry()
                      : const SizedBox.shrink(),
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
