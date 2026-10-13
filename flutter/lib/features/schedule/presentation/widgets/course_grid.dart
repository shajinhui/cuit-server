import 'dart:math' as math;

import 'package:flutter/material.dart';

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
  Widget build(BuildContext context) => MediaQuery.withClampedTextScaling(
    maxScaleFactor: 1,
    child: LayoutBuilder(
      builder: (context, size) {
        final android = Theme.of(context).platform == TargetPlatform.android;
        // extendBody 的 Scaffold 已把导航完整高度放进 padding.bottom。
        // 视口与行高都要扣除它，滚动中的节次也不能绘制到导航下面。
        final bottomPadding = android
            ? MediaQuery.paddingOf(context).bottom + 8
            : math.max(64.0, 52 + MediaQuery.paddingOf(context).bottom);
        final visibleHeight = android
            ? math.max(0.0, size.maxHeight - bottomPadding)
            : size.maxHeight;
        // 短屏保留课程名称与教室的空间，通过滚动查看，不能强行压进 11 节。
        final rowHeight = android
            ? math.max(40.0, visibleHeight / 11)
            : visibleHeight / 11;
        final columnWidth = (size.maxWidth - 40) / 7;
        final dark = Theme.of(context).brightness == Brightness.dark;
        final ink = dark ? const Color(0xfff2f2f7) : const Color(0xff101722);
        final font = (size.maxWidth * .03).clamp(11.0, 14.0);
        final scrollView = SingleChildScrollView(
          key: const PageStorageKey('schedule-scroll'),
          padding: EdgeInsets.only(bottom: android ? 0 : bottomPadding),
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
                        block.span * rowHeight - (size.maxWidth <= 380 ? 4 : 6),
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
                                        borderRadius: BorderRadius.circular(4),
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
        return android
            ? Padding(
                padding: EdgeInsets.only(bottom: bottomPadding),
                child: scrollView,
              )
            : scrollView;
      },
    ),
  );
}
