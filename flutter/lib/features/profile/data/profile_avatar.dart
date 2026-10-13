import 'dart:convert';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';

import '../../../core/storage/app_storage.dart';

/// 头像与原 Vue 一样只保存在本机；账号和接口地址共同组成存储键。
class ProfileAvatar extends ChangeNotifier {
  ProfileAvatar(this.storage, this.key);
  // 与原项目 assets/avatars 中的 15 张头像保持一致。
  static const presetCount = 15;
  final AppStorage storage;
  final String key;
  int presetId = 1;
  Uint8List? customImage;
  bool saving = false;
  String? error;
  bool _disposed = false;
  int _version = 0;
  Future<void> _writes = Future.value();

  String get assetPath =>
      'assets/avatars/avatar-${presetId.toString().padLeft(2, '0')}.jpg';

  Future<void> initialize() async {
    final version = _version;
    try {
      final value = await storage.read(key);
      if (_disposed || version != _version) return;
      if (value != null) {
        final data = jsonDecode(value) as Map<String, dynamic>;
        final id = data['preset'] as int? ?? 1;
        presetId = id >= 1 && id <= presetCount ? id : 1;
        final encoded = data['image'];
        customImage = encoded is String ? base64Decode(encoded) : null;
      } else {
        presetId = Random().nextInt(presetCount) + 1;
        await _persist();
      }
      _notify();
    } catch (_) {
      if (!_disposed && version == _version) {
        error = '头像读取失败，可以重新选择。';
        _notify();
      }
    }
  }

  Future<void> selectPreset(int id) async {
    if (_disposed || saving || id < 1 || id > presetCount) return;
    _version++;
    presetId = id;
    customImage = null;
    await _save();
  }

  Future<void> selectCustom(Uint8List bytes) async {
    if (_disposed || saving) return;
    final version = ++_version;
    saving = true;
    error = null;
    _notify();
    try {
      // 先缩小解码尺寸，再居中裁成 512×512，避免大照片占用过多内存。
      final codec = await ui.instantiateImageCodec(bytes, targetWidth: 512);
      final frame = await codec.getNextFrame();
      codec.dispose();
      final image = frame.image;
      final side = min(image.width, image.height).toDouble();
      final recorder = ui.PictureRecorder();
      final canvas = ui.Canvas(recorder);
      canvas.drawColor(const ui.Color(0xFFFFFFFF), ui.BlendMode.src);
      canvas.drawImageRect(
        image,
        ui.Rect.fromLTWH(
          (image.width - side) / 2,
          (image.height - side) / 2,
          side,
          side,
        ),
        const ui.Rect.fromLTWH(0, 0, 512, 512),
        ui.Paint()..filterQuality = ui.FilterQuality.high,
      );
      final picture = recorder.endRecording();
      final square = await picture.toImage(512, 512);
      final encoded = await square.toByteData(format: ui.ImageByteFormat.png);
      square.dispose();
      picture.dispose();
      image.dispose();
      if (_disposed || version != _version) return;
      if (encoded == null) throw const FormatException('头像处理失败');
      customImage = encoded.buffer.asUint8List();
      await _persist();
    } catch (_) {
      if (!_disposed && version == _version) error = '头像保存失败，请换一张图片重试。';
    } finally {
      if (!_disposed && version == _version) {
        saving = false;
        _notify();
      }
    }
  }

  Future<void> _save() async {
    saving = true;
    error = null;
    _notify();
    try {
      await _persist();
    } catch (_) {
      if (!_disposed) error = '头像保存失败，请重试。';
    } finally {
      if (!_disposed) {
        saving = false;
        _notify();
      }
    }
  }

  Future<void> _persist() {
    final value = jsonEncode({
      'preset': presetId,
      'image': customImage == null ? null : base64Encode(customImage!),
    });
    final task = _writes.then((_) async {
      if (!_disposed) await storage.write(key, value);
    });
    _writes = task.catchError((Object _) {});
    return task;
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _version++;
    super.dispose();
  }
}
