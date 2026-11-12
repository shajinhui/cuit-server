import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../ui/components/auto_hide_scaffold.dart';

import '../../models/academic_calendar.dart';
import '../../models/course_block.dart';
import '../../models/semester.dart';
import 'course_palette.dart';

/// 时间栏 40、七个等宽日期列；安卓避开导航，小屏保留行高并允许滚动。
class CourseGrid extends StatelessWidget {
  const CourseGrid({
    super.key,
    required this.blocks,
    required this.semester,
    required this.campus,
    required this.rowCount,
    required this.opacity,
    required this.onCourse,
  });
  final List<CourseBlock> blocks;
  final Semester semester;
  final String campus;
  final int rowCount;
  final double opacity;
  final ValueChanged<CourseBlock> onCourse;
  @override
  Widget build(BuildContext context) {
    // 依赖查找必须在 build 作用域完成；如果在 LayoutBuilder 的布局回调里
    // 读取 InheritedWidget，导航显隐时会把 Element 标脏到错误的 build scope。
    final android = Theme.of(context).platform == TargetPlatform.android;
    final navigation = AutoHideNavigationScope.maybeOf(context);
    final scaffoldBottom = MediaQuery.paddingOf(context).bottom;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return MediaQuery.withClampedTextScaling(
      maxScaleFactor: 1,
      child: LayoutBuilder(
        builder: (context, size) {
          // extendBody 的 Scaffold 会把应用导航高度放进 padding.bottom。导航
          // 自动收起后不能继续预留这条高度，否则课表底部会留下一条被截断的空带。
          final navigationInset = navigation == null
              ? scaffoldBottom + 4
              : navigation.visible
              ? math.max(scaffoldBottom, navigation.bottomBarHeight) + 4
              : navigation.systemBottomInset + 4;
          // 导航是浮在内容上的一层玻璃，网格必须铺到屏幕底边，让最后一节课
          // 从导航后面穿过去；否则课程色块会在导航上沿被切一刀，看着像页面
          // 到那里就结束了。底部只留滚动余量，滑到底时最后一节仍能完整露出。
          final bottomPadding = android
              ? navigationInset
              : math.max(64.0, 52 + scaffoldBottom);
          final visibleHeight = size.maxHeight;
          // 短屏保留课程名称与教室的空间，通过滚动查看，不能强行压进 11 节。
          final rowHeight = android
              ? math.max(40.0, visibleHeight / 11)
              : visibleHeight / 11;
          final columnWidth = (size.maxWidth - 40) / 7;
          final ink = dark ? const Color(0xfff2f2f7) : const Color(0xff101722);
          final font = (size.maxWidth * .03).clamp(11.0, 14.0);
          final scrollView = SingleChildScrollView(
            key: const PageStorageKey('schedule-scroll'),
            padding: EdgeInsets.only(bottom: bottomPadding),
            child: SizedBox(
              height: rowHeight * rowCount,
              child: Stack(
                key: const Key('schedule-grid'),
                children: [
                  for (var section = 1; section <= rowCount; section++)
                    Positioned(
                      left: 0,
                      top: (section - 1) * rowHeight,
                      width: 40,
                      height: rowHeight,
                      child: Center(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '$section',
                                style: TextStyle(
                                  color: ink,
                                  fontSize: 17,
                                  fontWeight: FontWeight.w500,
                                  height: 1,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                '${sectionStart(section, semester, campus)}\n${sectionEnd(section, semester, campus)}',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: ink,
                                  fontSize: 11,
                                  height: 1.3,
                                  letterSpacing: 0,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  for (final block in blocks)
                    Positioned(
                      left: 40 + (block.day - 1) * columnWidth + 1,
                      top:
                          (block.start - 1) * rowHeight +
                          (size.maxWidth <= 380 ? 2 : 3),
                      width: columnWidth - 2,
                      height:
                          block.span * rowHeight -
                          (size.maxWidth <= 380 ? 4 : 6),
                      child: Opacity(
                        opacity: block.muted ? opacity : 1,
                        child: Semantics(
                          button: true,
                          label: '${block.name}，${block.room}，查看课程详情',
                          child: GestureDetector(
                            key: ValueKey('course-${block.id}'),
                            onTap: () => onCourse(block),
                            child: Container(
                              decoration: BoxDecoration(
                                color: block.color,
                                borderRadius: BorderRadius.circular(7),
                                border: Border.all(
                                  color: dark
                                      ? const Color(
                                          0xff1c1c1e,
                                        ).withValues(alpha: .62)
                                      : Colors.white.withValues(alpha: .62),
                                  width: 2,
                                ),
                              ),
                              padding: EdgeInsets.fromLTRB(
                                2,
                                4,
                                2,
                                block.muted || block.conflict ? 18 : 4,
                              ),
                              child: Stack(
                                clipBehavior: Clip.none,
                                children: [
                                  Positioned.fill(
                                    child: Column(
                                      children: [
                                        Expanded(
                                          child: Center(
                                            child: Text(
                                              block.name,
                                              maxLines:
                                                  block.span == 1 ||
                                                      block
                                                          .experimentStartTime
                                                          .isNotEmpty
                                                  ? 2
                                                  : 4,
                                              overflow: TextOverflow.clip,
                                              textAlign: TextAlign.center,
                                              style: TextStyle(
                                                fontSize: block.span == 1
                                                    ? (size.maxWidth * .027)
                                                          .clamp(10.0, 12.0)
                                                    : font,
                                                height: block.span == 1
                                                    ? 1.12
                                                    : 1.25,
                                                fontWeight: FontWeight.w600,
                                                color: dark
                                                    ? const Color(0xffd1d1d6)
                                                    : const Color(0xff26343d),
                                                letterSpacing: 0,
                                              ),
                                            ),
                                          ),
                                        ),
                                        if (block
                                                .experimentStartTime
                                                .isNotEmpty &&
                                            block.span > 1)
                                          FittedBox(
                                            fit: BoxFit.scaleDown,
                                            child: Text(
                                              '${block.experimentStartTime}${size.maxWidth <= 480 ? '\n' : '–'}${block.experimentEndTime}',
                                              style: TextStyle(
                                                fontSize: size.maxWidth <= 480
                                                    ? 9
                                                    : 11,
                                                height: size.maxWidth <= 480
                                                    ? 1
                                                    : 1.2,
                                                color: dark
                                                    ? const Color(0xffd1d1d6)
                                                    : const Color(0xff26343d),
                                              ),
                                            ),
                                          ),
                                        Text(
                                          '@${block.room}',
                                          textAlign: TextAlign.center,
                                          maxLines: block.span == 1 ? 1 : 3,
                                          overflow: TextOverflow.clip,
                                          style: TextStyle(
                                            fontSize: block.span == 1
                                                ? (size.maxWidth * .025).clamp(
                                                    9.0,
                                                    11.0,
                                                  )
                                                : block
                                                      .experimentStartTime
                                                      .isNotEmpty
                                                ? (size.maxWidth * .027).clamp(
                                                    10.0,
                                                    12.0,
                                                  )
                                                : font,
                                            fontWeight: FontWeight.w600,
                                            height: block.span == 1
                                                ? 1.1
                                                : block
                                                      .experimentStartTime
                                                      .isNotEmpty
                                                ? 1.15
                                                : 1.25,
                                            color: dark
                                                ? const Color(0xffd1d1d6)
                                                : const Color(0xff26343d),
                                            letterSpacing: 0,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (block.muted || block.conflict)
                                    Positioned(
                                      left: -1,
                                      right: -1,
                                      bottom: -16,
                                      child: Container(
                                        decoration: BoxDecoration(
                                          color: Colors.white.withValues(
                                            alpha: .4,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            4,
                                          ),
                                        ),
                                        child: Text(
                                          block.conflict ? '课程冲突' : '非本周',
                                          textAlign: TextAlign.center,
                                          maxLines: 1,
                                          style: TextStyle(
                                            fontSize: 8,
                                            height: 1.5,
                                            fontWeight: FontWeight.w600,
                                            color: block.conflict
                                                ? const Color(0xff963d3d)
                                                : const Color(0xff26343d),
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          );
          return scrollView;
        },
      ),
    );
  }
}
