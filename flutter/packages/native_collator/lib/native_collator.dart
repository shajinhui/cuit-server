import 'package:flutter/services.dart';

/// 使用系统 ICU 排序，返回原始字符串，保留课程标识里的 NUL 分隔符。
class NativeCollator {
  static const MethodChannel _channel = MethodChannel('native_collator');
  static Future<List<String>> sort(List<String> input, String locale) async {
    // NUL 与 WORD JOINER 在 ICU 中均无排序权重。后者可避免 iOS 的长字符串
    // 桥接截断；原始标识不离开 Dart，宿主只返回位置索引。
    final comparable = input
        .map((s) => s.replaceAll('\u0000', '\u2060'))
        .toList();
    final indices = await _channel.invokeListMethod<int>('sortIndices', {
      'input': comparable,
      'locale': locale,
    });
    if (indices == null ||
        indices.length != input.length ||
        indices.toSet().length != input.length ||
        indices.any((i) => i < 0 || i >= input.length)) {
      throw PlatformException(code: 'invalid_order', message: '系统排序返回了无效索引');
    }
    return indices.map((i) => input[i]).toList();
  }
}
