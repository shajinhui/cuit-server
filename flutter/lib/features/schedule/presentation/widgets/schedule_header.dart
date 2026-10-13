import 'package:flutter/material.dart';

import '../schedule_view_model.dart';
import 'schedule_week_strip.dart';

/// 课表头部：日期与周次胶囊共用同一块纵向空间，安卓与 iOS 同一版式。
///
/// 旧版安卓把「日期」和「周次胶囊 + 操作按钮」拆成两行，头部固定占 86px；
/// 这里让胶囊行整体上移、接在日期行下方，并允许胶囊底部侵入周条顶部留白
/// （[scheduleStripTopGap]），头部因此只占 56px。
class ScheduleHeader extends StatelessWidget {
  const ScheduleHeader({
    super.key,
    required this.vm,
    required this.weekAnchor,
    required this.moreAnchor,
    required this.onWeek,
    required this.onMore,
    required this.onAdd,
    required this.onRefresh,
  });
  final ScheduleViewModel vm;
  final GlobalKey weekAnchor, moreAnchor;
  final VoidCallback onWeek, onMore, onAdd, onRefresh;

  /// 日期行占位：日期字号 20~24 时数字下沿最高约 21，再留一点呼吸位。
  static const double _dateLine = 24;

  /// 周次胶囊高度。
  static const double _capsuleHeight = 44;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final dark = Theme.of(context).brightness == Brightness.dark;
    final ink = dark ? const Color(0xfff2f2f7) : const Color(0xff101722);
    final muted = dark ? const Color(0xb8d1d1d6) : const Color(0x9426343d);
    final gutter = size.width <= 380 ? 16.0 : 22.0;
    final gap = size.width <= 380 ? 0.0 : 4.0;
    // 日期压到 20~24，才能和胶囊共用一行而不被胶囊的玻璃底盖住数字下沿。
    final dateStyle = TextStyle(
      fontSize: (size.width * .055).clamp(20.0, 24.0),
      height: 1,
      fontWeight: FontWeight.w500,
      letterSpacing: -.5,
    );
    const badgeStyle = TextStyle(
      fontSize: 11,
      height: 1,
      fontWeight: FontWeight.w600,
    );
    final badgeText = '当前为第 ${vm.currentWeek} 周';
    final weekText = '第 ${vm.selectedWeek} 周';
    const capsuleStyle = TextStyle(fontSize: 17, fontWeight: FontWeight.w500);
    final statusStyle = TextStyle(
      fontSize: size.height <= 740 ? 15 : 17,
      height: 1.1,
      color: muted,
    );
    // 胶囊固定占位：左右 padding 10、间距 6、箭头 14。
    final capsuleWidth = _textWidth(weekText, capsuleStyle) + 40;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        gutter,
        size.height <= 740 ? 0 : 4,
        gutter,
        0,
      ),
      child: Row(
        children: [
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final height =
                    _dateLine +
                    _capsuleHeight -
                    scheduleStripTopGap(size.height);
                // 「当前为第 N 周」只在放得下时显示（最多容忍 20% 的缩放）：
                // 更窄时优先保证日期完整可读，而不是把两者都缩成一团。
                final dateWidth = _textWidth(vm.dateTitle, dateStyle);
                final badgeWidth = _textWidth(badgeText, badgeStyle) + 14;
                final showBadge =
                    (vm.currentWeek ?? 0) > 0 &&
                    constraints.maxWidth >= dateWidth * .8 + 7 + badgeWidth;
                return SizedBox(
                  height: height,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Positioned(
                        top: 0,
                        left: 0,
                        right: 0,
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          // 极窄屏一起缩小，日期始终完整显示而不是被截断。
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(vm.dateTitle, maxLines: 1, style: dateStyle),
                              if (showBadge) ...[
                                const SizedBox(width: 7),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 7,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: vm.weekStatus == '本周'
                                        ? Colors.white.withValues(alpha: .18)
                                        : const Color(0x5565a6eb),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    badgeText,
                                    maxLines: 1,
                                    style: badgeStyle.copyWith(
                                      color: vm.weekStatus == '本周'
                                          ? muted
                                          : const Color(0xff397db5),
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                      Positioned(
                        top: _dateLine,
                        left: 0,
                        right: 0,
                        child: Row(
                          children: [
                            InkWell(
                              key: weekAnchor,
                              onTap: vm.isLoading && !vm.hasData
                                  ? null
                                  : onWeek,
                              child: _HeaderGlass(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                  ),
                                  child: SizedBox(
                                    height: _capsuleHeight,
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          weekText,
                                          key: const Key('selected-week'),
                                          style: capsuleStyle,
                                        ),
                                        const SizedBox(width: 6),
                                        const Icon(
                                          Icons.keyboard_arrow_down,
                                          size: 14,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            // 周次状态挤不下时直接省略，避免整行溢出。
                            if (capsuleWidth +
                                    12 +
                                    _textWidth(vm.weekStatus, statusStyle) <=
                                constraints.maxWidth) ...[
                              const SizedBox(width: 12),
                              Text(
                                vm.weekStatus,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: statusStyle,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          _action(
            ink: ink,
            label: '添加课程',
            icon: Icons.add,
            radius: 12,
            onPressed: vm.selectedSemester == null ? null : onAdd,
          ),
          SizedBox(width: gap),
          _action(
            ink: ink,
            label: '重新同步课表',
            icon: Icons.sync,
            onPressed: vm.isLoading || vm.isRefreshing ? null : onRefresh,
          ),
          SizedBox(width: gap),
          _action(
            key: moreAnchor,
            ink: ink,
            label: '更多操作',
            icon: Icons.more_horiz,
            onPressed: onMore,
          ),
        ],
      ),
    );
  }

  /// 单行文字宽度，用来判断附加信息是否真的放得下（避免依赖估宽）。
  static double _textWidth(String text, TextStyle style) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout();
    final width = painter.width;
    painter.dispose();
    return width;
  }

  Widget _action({
    Key? key,
    required Color ink,
    required String label,
    required IconData icon,
    double radius = 24,
    required VoidCallback? onPressed,
  }) => _HeaderGlass(
    radius: radius,
    child: IconButton(
      key: key,
      tooltip: label,
      onPressed: onPressed,
      // 固定 44：Material 默认的 48 触摸扩展会让安卓比 iOS 多占 12px 宽度。
      style: const ButtonStyle(tapTargetSize: MaterialTapTargetSize.shrinkWrap),
      icon: Icon(icon, size: icon == Icons.add ? 30 : 26, color: ink),
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints.tightFor(width: 44, height: 44),
    ),
  );
}

class _HeaderGlass extends StatelessWidget {
  const _HeaderGlass({required this.child, this.radius = 24});
  final Widget child;
  final double radius;
  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: Theme.of(context).brightness == Brightness.dark
          ? const Color(0x223c4654)
          : const Color(0x33ffffff),
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: Colors.white.withValues(alpha: .3)),
      boxShadow: [
        BoxShadow(color: Colors.black.withValues(alpha: .035), blurRadius: 8),
      ],
    ),
    child: child,
  );
}
