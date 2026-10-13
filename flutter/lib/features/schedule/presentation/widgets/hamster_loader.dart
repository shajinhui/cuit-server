import 'dart:math' as math;

import 'package:flutter/material.dart';

/// 用画布绘制原版仓鼠滚轮，只有加载期间运行动画，不触发整张课表重建。
class HamsterLoader extends StatefulWidget {
  const HamsterLoader({super.key, required this.label});
  final String label;
  @override
  State<HamsterLoader> createState() => _HamsterLoaderState();
}

class _HamsterLoaderState extends State<HamsterLoader>
    with SingleTickerProviderStateMixin {
  late final _animation = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 1),
  );
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _animation.stop();
    } else {
      _animation.repeat();
    }
  }

  @override
  void dispose() {
    _animation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Semantics(
    label: '仓鼠在滚轮中奔跑，${widget.label}',
    liveRegion: true,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        RepaintBoundary(
          child: SizedBox(
            width: 88,
            height: 88,
            child: CustomPaint(painter: _HamsterPainter(_animation)),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          widget.label,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        ),
      ],
    ),
  );
}

class _HamsterPainter extends CustomPainter {
  _HamsterPainter(this.animation) : super(repaint: animation);
  final Animation<double> animation;
  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 120);
    final paint = Paint();
    canvas.drawCircle(
      const Offset(60, 60),
      60,
      paint..color = const Color(0xfff0f4f9),
    );
    // 滚轮与仓鼠采用独立运动，步频沿用原版的一秒四步。
    canvas.save();
    canvas.translate(60, 60);
    canvas.rotate(-animation.value * math.pi * 2);
    paint
      ..color = const Color(0xffa6a6a6)
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;
    canvas.drawCircle(Offset.zero, 57, paint);
    canvas.drawLine(Offset.zero, const Offset(0, 56), paint);
    canvas.drawCircle(Offset.zero, 4, paint);
    canvas.restore();
    canvas.save();
    canvas.translate(0, math.sin(animation.value * math.pi * 8) * 1.2);
    paint.style = PaintingStyle.fill;
    canvas.drawOval(
      const Rect.fromLTWH(28, 70, 64, 32),
      paint..color = const Color(0xffffdcac),
    );
    canvas.drawOval(
      const Rect.fromLTWH(30, 79, 61, 21),
      paint..color = const Color(0xfffff0dc),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(13, 69, 31, 25),
        const Radius.circular(12),
      ),
      paint..color = const Color(0xfff79425),
    );
    canvas.drawOval(
      const Rect.fromLTWH(13, 79, 27, 16),
      paint..color = const Color(0xffffdcac),
    );
    canvas.drawOval(
      const Rect.fromLTWH(31, 65, 9, 10),
      paint..color = const Color(0xffffb6b6),
    );
    canvas.drawCircle(const Offset(22, 77), 2.5, paint..color = Colors.black);
    canvas.drawOval(
      const Rect.fromLTWH(11, 83, 5, 4),
      paint..color = const Color(0xffffb6b6),
    );
    for (var limb = 0; limb < 4; limb++) {
      canvas.save();
      canvas.translate(limb < 2 ? 41 : 78, 94);
      canvas.rotate(
        math.sin(animation.value * math.pi * 8 + (limb % 2) * math.pi) * .6,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTWH(-3, 0, 8, 12),
          const Radius.circular(4),
        ),
        paint
          ..color = limb.isEven
              ? const Color(0xffffb6b6)
              : const Color(0xffffdcac),
      );
      canvas.restore();
    }
    canvas.drawOval(
      const Rect.fromLTWH(89, 84, 10, 6),
      paint..color = const Color(0xffffb6b6),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_HamsterPainter old) => old.animation != animation;
}
