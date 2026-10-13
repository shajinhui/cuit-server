import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// 安卓桌面「添加时可选小／中／大」完全依赖静态声明：
/// 每个尺寸必须是一个独立组件，并且各自声明可拖动的方向与上下限。
/// 这里锁住这份契约，避免以后改布局时把尺寸选项或调整能力改没。
void main() {
  final root = Directory.current.path;
  final xmlDirectory = '$root/android/app/src/main/res/xml';
  final providerSource =
      '$root/android/app/src/main/kotlin/org/dpdns/fanxiaogao05/chengxin_youyou/ScheduleWidgetProvider.kt';

  Map<String, String> attributes(String path) {
    final source = File(path).readAsStringSync();
    final tag = RegExp(r'<appwidget-provider\b([\s\S]*?)/>').firstMatch(source);
    expect(tag, isNotNull, reason: '$path 缺少 appwidget-provider 声明');
    return {
      for (final match in RegExp(
        r'android:(\w+)="([^"]*)"',
      ).allMatches(tag!.group(1)!))
        match.group(1)!: match.group(2)!,
    };
  }

  int dp(Map<String, String> attrs, String name) {
    final raw = attrs[name];
    expect(raw, isNotNull, reason: '缺少 android:$name');
    expect(raw, endsWith('dp'), reason: 'android:$name 应为 dp：$raw');
    return int.parse(raw!.substring(0, raw.length - 2));
  }

  group('桌面小组件尺寸声明', () {
    // 文件 → 默认格数，顺序与系统列表一致。
    const variants = {
      'schedule_widget_info_small.xml': [2, 2],
      'schedule_widget_info.xml': [4, 2],
      'schedule_widget_info_large.xml': [4, 4],
    };

    variants.forEach((file, cells) {
      test('$file 默认 ${cells[0]}×${cells[1]} 格并可拖动调整', () {
        final attrs = attributes('$xmlDirectory/$file');
        expect(int.parse(attrs['targetCellWidth']!), cells[0]);
        expect(int.parse(attrs['targetCellHeight']!), cells[1]);
        // 未声明 resizeMode 或写成 none，桌面就不会给出调整手柄。
        expect(attrs['resizeMode'], contains('horizontal'));
        expect(attrs['resizeMode'], contains('vertical'));

        final minWidth = dp(attrs, 'minResizeWidth');
        final minHeight = dp(attrs, 'minResizeHeight');
        expect(minWidth, lessThanOrEqualTo(dp(attrs, 'minWidth')));
        expect(minHeight, lessThanOrEqualTo(dp(attrs, 'minHeight')));
        // 上限缺省时框架按 0 下发，各家桌面解释不同；必须写死才能稳定放大。
        expect(dp(attrs, 'maxResizeWidth'), greaterThan(minWidth));
        expect(dp(attrs, 'maxResizeHeight'), greaterThan(minHeight));
      });
    });

    test('三种尺寸在清单里各注册一个接收者且标签互不相同', () {
      final manifest = File(
        '$root/android/app/src/main/AndroidManifest.xml',
      ).readAsStringSync();
      const receivers = {
        'ScheduleWidgetSmallProvider': 'schedule_widget_info_small',
        'ScheduleWidgetProvider': 'schedule_widget_info',
        'ScheduleWidgetLargeProvider': 'schedule_widget_info_large',
      };
      final labels = <String>{};
      receivers.forEach((name, resource) {
        final block = RegExp(
          '<receiver[^>]*\\.$name"[\\s\\S]*?</receiver>',
        ).firstMatch(manifest);
        expect(block, isNotNull, reason: '清单未注册 $name，系统列表里不会出现这个尺寸');
        final element = block!.group(0)!;
        expect(element, contains('@xml/$resource'));
        // 日期、时间、重启等隐式广播只送达声明过它的组件。
        expect(element, contains('BOOT_COMPLETED'));
        labels.add(
          RegExp(
            r'android:label="@string/(\w+)"',
          ).firstMatch(element)!.group(1)!,
        );
      });
      expect(labels.length, 3, reason: '标签重复时桌面列表无法区分不同尺寸');
    });

    test('三种尺寸共用一份渲染实现', () {
      final source = File(providerSource).readAsStringSync();
      expect(
        source,
        contains(
          'class ScheduleWidgetSmallProvider : ScheduleWidgetProvider()',
        ),
      );
      expect(
        source,
        contains(
          'class ScheduleWidgetLargeProvider : ScheduleWidgetProvider()',
        ),
      );
      // 刷新与统计必须遍历全部组件，否则只会更新其中一种尺寸。
      expect(source, contains('providerClasses'));
      expect(source, contains('ScheduleWidgetSmallProvider::class.java'));
      expect(source, contains('ScheduleWidgetLargeProvider::class.java'));
    });
  });
}
