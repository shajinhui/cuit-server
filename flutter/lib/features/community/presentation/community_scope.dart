import 'package:flutter/widgets.dart';
import 'community_view_model.dart';

class CommunityScope extends InheritedNotifier<CommunityViewModel> {
  const CommunityScope({
    super.key,
    required CommunityViewModel? model,
    required super.child,
  }) : super(notifier: model);
  static CommunityViewModel? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<CommunityScope>()?.notifier;
}
