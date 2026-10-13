import 'package:chengxin_youyou/ui/components/glass_navigation_bar.dart';
import 'package:chengxin_youyou/ui/theme/app_theme.dart';
import 'package:flutter/material.dart';

/// 为导航交互与着色器验收提供可滚动背景，不使用账号或网络接口。
class NavigationPreview extends StatefulWidget {
  const NavigationPreview({
    super.key,
    this.lightweight = false,
    this.dark = false,
    this.reduceMotion = false,
    this.highContrast = false,
    this.textScale = 1,
  });

  final bool lightweight;
  final bool dark;
  final bool reduceMotion;
  final bool highContrast;
  final double textScale;

  @override
  State<NavigationPreview> createState() => _NavigationPreviewState();
}

class _NavigationPreviewState extends State<NavigationPreview> {
  var selectedIndex = 0;
  var cardTaps = 0;

  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: AppTheme.build(widget.dark ? Brightness.dark : Brightness.light),
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(
        textScaler: TextScaler.linear(widget.textScale),
        disableAnimations: widget.reduceMotion,
        highContrast: widget.highContrast,
      ),
      child: child!,
    ),
    home: Scaffold(
      extendBody: true,
      appBar: AppBar(
        title: Text('${GlassNavigationBar.labels[selectedIndex]} · 导航预览'),
      ),
      body: ListView.builder(
        key: const Key('preview-list'),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 130),
        itemCount: 16,
        itemBuilder: (context, index) => Card(
          color: const [
            Color(0xFFCEE4FF),
            Color(0xFFD8F0E1),
            Color(0xFFE8DDFF),
            Color(0xFFFFE0C4),
          ][index % 4],
          child: ListTile(
            key: ValueKey('preview-card-$index'),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 20,
              vertical: 14,
            ),
            title: Text('校园生活 ${index + 1}'),
            subtitle: Text('页面点击次数：$cardTaps'),
            textColor: const Color(0xFF24334A),
            leading: const Icon(Icons.school_outlined),
            onTap: () => setState(() => cardTaps++),
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        minimum: const EdgeInsets.fromLTRB(24, 0, 24, 12),
        child: Center(
          heightFactor: 1,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 390),
            child: GlassNavigationBar(
              selectedIndex: selectedIndex,
              lightweight: widget.lightweight,
              onSelected: (index) => setState(() => selectedIndex = index),
            ),
          ),
        ),
      ),
    ),
  );
}
