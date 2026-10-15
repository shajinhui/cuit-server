import 'dart:async';
import 'package:flutter/material.dart';
import 'announcement_dialog.dart';
import 'announcement_view_model.dart';

/// 只在首页、前台、没有键盘或其他根弹窗时展示，避免抢占登录和编辑流程。
class AnnouncementPresenter extends StatefulWidget {
  const AnnouncementPresenter({
    super.key,
    required this.viewModel,
    required this.allowed,
    required this.child,
  });
  final AnnouncementViewModel viewModel;
  final bool allowed;
  final Widget child;
  @override
  State<AnnouncementPresenter> createState() => _AnnouncementPresenterState();
}

class _AnnouncementPresenterState extends State<AnnouncementPresenter>
    with WidgetsBindingObserver {
  Timer? _pending;
  bool _foreground = true;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.viewModel.addListener(_check);
    _check();
  }

  @override
  void didUpdateWidget(AnnouncementPresenter oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.viewModel != widget.viewModel) {
      oldWidget.viewModel.removeListener(_check);
      widget.viewModel.addListener(_check);
    }
    _check();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    if (_foreground) unawaited(widget.viewModel.refresh());
    _check();
  }

  void _check() {
    _pending?.cancel();
    if (!mounted ||
        !_foreground ||
        !widget.allowed ||
        widget.viewModel.autoCandidate == null) {
      return;
    }
    _pending = Timer(const Duration(milliseconds: 400), () {
      if (!mounted || !_foreground || !widget.allowed) return;
      final item = widget.viewModel.autoCandidate;
      if (item == null) return;
      if (MediaQuery.viewInsetsOf(context).bottom > 0 ||
          ModalRoute.of(context)?.isCurrent != true) {
        _check();
        return;
      }
      unawaited(
        showAnnouncement(context, widget.viewModel, item, automatic: true),
      );
    });
  }

  @override
  void dispose() {
    _pending?.cancel();
    widget.viewModel.removeListener(_check);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
