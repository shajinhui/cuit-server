import 'dart:async';

import 'package:flutter/material.dart';

import 'app/app.dart';
import 'app/app_dependencies.dart';
import 'ui/theme/app_theme.dart';

void main() {
  final binding = WidgetsFlutterBinding.ensureInitialized();
  // 本机初始化完成后直接提交实际页面，省去额外的品牌图标和转圈过渡。
  binding.deferFirstFrame();
  runApp(AppBootstrap(onInitialized: binding.allowFirstFrame));
}

class AppBootstrap extends StatefulWidget {
  const AppBootstrap({super.key, this.createDependencies, this.onInitialized});

  final Future<AppDependencies> Function()? createDependencies;
  final VoidCallback? onInitialized;

  @override
  State<AppBootstrap> createState() => _AppBootstrapState();
}

class _AppBootstrapState extends State<AppBootstrap> {
  AppDependencies? _dependencies;
  bool _initializing = true;
  bool _failed = false;
  bool _firstFrameReleased = false;

  @override
  void initState() {
    super.initState();
    unawaited(_initialize());
  }

  Future<void> _initialize() async {
    try {
      final dependencies =
          await (widget.createDependencies ?? AppDependencies.create)();
      if (!mounted) {
        dependencies.dispose();
        return;
      }
      setState(() {
        _dependencies = dependencies;
        _initializing = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _failed = true;
        _initializing = false;
      });
    }
  }

  void _releaseFirstFrame() {
    if (_firstFrameReleased) return;
    _firstFrameReleased = true;
    widget.onInitialized?.call();
  }

  @override
  void dispose() {
    _dependencies?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dependencies = _dependencies;
    if (dependencies != null) {
      _releaseFirstFrame();
      return ChengxinApp(dependencies: dependencies);
    }
    if (_failed) {
      _releaseFirstFrame();
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.build(Brightness.light),
        home: Scaffold(
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('启动未完成，请重试。'),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: _initializing
                        ? null
                        : () {
                            setState(() => _initializing = true);
                            unawaited(_initialize());
                          },
                    child: Text(_initializing ? '正在重试…' : '重新打开'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }
    return const SizedBox.shrink();
  }
}
