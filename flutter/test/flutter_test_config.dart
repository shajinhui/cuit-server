import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  TestWidgetsFlutterBinding.ensureInitialized();
  final fixture =
      jsonDecode(
            File('test/fixtures/schedule_reference.json').readAsStringSync(),
          )
          as Map<String, dynamic>;
  setUp(() {
    // 单元测试没有宿主插件，用原版 Intl 生成的顺序替代通道；原生测试另行验证系统排序。
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('native_collator'), (
          call,
        ) async {
          final args = call.arguments as Map;
          final order =
              (fixture['order'][args['locale'] == 'zh-CN'
                          ? 'chinese'
                          : 'standard']
                      as List)
                  .cast<String>();
          final ranks = {for (var i = 0; i < order.length; i++) order[i]: i};
          final values = (args['input'] as List).cast<String>();
          final indices = List.generate(values.length, (i) => i);
          indices.sort((a, b) {
            final leftValue = values[a].replaceAll('\u2060', '\u0000');
            final rightValue = values[b].replaceAll('\u2060', '\u0000');
            final left = ranks[leftValue], right = ranks[rightValue];
            return left != null && right != null
                ? left.compareTo(right)
                : leftValue.compareTo(rightValue);
          });
          return indices;
        });
  });
  await testMain();
}
