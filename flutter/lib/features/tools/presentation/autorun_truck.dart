import 'package:flutter/material.dart';

/// 还原 Vue 俱乐部页的小货车装饰，不引入额外图片或动画依赖。
class AutoRunTruck extends StatelessWidget {
  const AutoRunTruck({super.key});

  @override
  Widget build(BuildContext context) => const ExcludeSemantics(
    child: SizedBox(
      width: 200,
      height: 84,
      child: CustomPaint(painter: _TruckPainter()),
    ),
  );
}

class _TruckPainter extends CustomPainter {
  const _TruckPainter();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 220, size.height / 106);
    final outline = Paint()
      ..color = const Color(0xFF282828)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    final body = Paint()..color = const Color(0xFFDFDFDF);
    const trailer = Rect.fromLTWH(10, 3, 120, 88);
    canvas.drawRect(trailer, body);
    canvas.drawRect(trailer, outline);
    final cab = Path()
      ..moveTo(138, 24)
      ..lineTo(180, 24)
      ..lineTo(195, 59)
      ..lineTo(195, 91)
      ..lineTo(138, 91)
      ..close();
    canvas.drawPath(cab, Paint()..color = const Color(0xFFF83D3D));
    canvas.drawPath(cab, outline);
    final window = Path()
      ..moveTo(149, 35)
      ..lineTo(184, 35)
      ..lineTo(192, 56)
      ..lineTo(149, 56)
      ..close();
    canvas.drawPath(window, Paint()..color = const Color(0xFF7D7C7C));
    canvas.drawPath(window, outline);
    for (final x in [39.0, 167.0]) {
      canvas.drawCircle(
        Offset(x, 86),
        12,
        Paint()..color = const Color(0xFF282828),
      );
      canvas.drawCircle(Offset(x, 86), 6, body);
    }
    canvas.drawLine(const Offset(0, 103), const Offset(220, 103), outline);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _TruckPainter oldDelegate) => false;
}
