import 'package:flutter/material.dart';

import '../../../core/platform/desktop_widgets.dart';
import '../../../ui/components/page_layout.dart';
import '../models/desktop_widget_snapshot.dart';
import 'desktop_widget_controller.dart';

class DesktopWidgetPage extends StatefulWidget {
  const DesktopWidgetPage({super.key, required this.platform, this.controller});
  final DesktopWidgets platform;
  final DesktopWidgetController? controller;

  @override
  State<DesktopWidgetPage> createState() => _DesktopWidgetPageState();
}

class _DesktopWidgetPageState extends State<DesktopWidgetPage> {
  bool _pinning = false;
  String? _notice;

  Future<void> _pin() async {
    setState(() => _pinning = true);
    try {
      final requested = await widget.platform.requestPin();
      if (mounted) {
        setState(
          () => _notice = requested
              ? '请在系统弹窗中确认添加。'
              : '当前桌面不支持直接添加，请长按桌面，从小组件列表选择成信友友。',
        );
      }
    } catch (_) {
      if (mounted) setState(() => _notice = '请长按桌面，从小组件列表添加成信友友。');
    } finally {
      if (mounted) setState(() => _pinning = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    return ListenableBuilder(
      listenable: controller ?? const AlwaysStoppedAnimation(0),
      builder: (context, _) {
        final schoolNow = DateTime.now().toUtc().add(const Duration(hours: 8));
        final days = controller?.snapshot['days'] as List? ?? const [];
        final today = days
            .cast<Map>()
            .where((day) => day['date'] == desktopWidgetDate(schoolNow))
            .firstOrNull;
        final courses = (today?['courses'] as List? ?? const []).cast<Map>();
        return PageScaffold(
          title: '桌面小组件',
          child: ListView(
            padding: const EdgeInsets.all(22),
            children: [
              const PageSectionHeading(
                title: '内容预览',
                subtitle: '桌面添加时可选小、中、大三种尺寸',
              ),
              const SizedBox(height: 14),
              PageCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('今日课程', style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 12),
                    if (courses.isEmpty)
                      Text(
                        controller == null
                            ? '登录真实账号后同步桌面课表。'
                            : controller.snapshot['status'] != 'ready'
                            ? '${controller.snapshot['message']}'
                            : today == null
                            ? '当前不在已同步的教学周内。'
                            : '今天没有课程，好好休息。',
                      ),
                    for (final course in courses.take(4))
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${course['name']}',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            Text('${course['time']} · ${course['room']}'),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              const PageSectionHeading(title: '添加到桌面'),
              const SizedBox(height: 12),
              PageCard(
                child: Text(
                  widget.platform.canRequestPin
                      ? '点击下方按钮，在系统弹窗中确认添加。也可以长按桌面空白处打开小组件列表，在“下一节课（小）”“今日课程（中）”“今日课程（大）”中选一种。添加后仍可拖动边缘调整大小。'
                      : '长按主屏幕空白处，点击“编辑”或左上角“＋”，选择“添加小组件”，搜索“成信友友”，选择小、中或大尺寸后添加。',
                ),
              ),
              const SizedBox(height: 16),
              if (widget.platform.canRequestPin)
                FilledButton.icon(
                  key: const Key('desktop-widget-pin'),
                  onPressed: _pinning ? null : _pin,
                  icon: const Icon(Icons.add_to_home_screen_rounded),
                  label: Text(_pinning ? '正在打开…' : '添加到桌面'),
                ),
              if (controller != null)
                TextButton.icon(
                  onPressed: controller.syncing
                      ? null
                      : () => controller.synchronize(refresh: true),
                  icon: const Icon(Icons.refresh_rounded),
                  label: Text(controller.syncing ? '正在同步…' : '同步小组件课表'),
                ),
              if (controller?.error != null) Text(controller!.error!),
              if (_notice != null) Text(_notice!),
              const SizedBox(height: 14),
              const Text(
                '点击桌面卡片可打开今天的课表。已同步的课程离线也能查看；教务课表发生变化后，请打开应用刷新。退出登录会清空桌面课程。',
              ),
            ],
          ),
        );
      },
    );
  }
}
