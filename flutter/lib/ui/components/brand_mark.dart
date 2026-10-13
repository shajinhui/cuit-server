import 'package:flutter/material.dart';

class BrandMark extends StatelessWidget {
  const BrandMark({super.key, this.size = 64});
  final double size;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF5397FF), Color(0xFF2466E8)],
      ),
      borderRadius: BorderRadius.circular(size * .29),
      boxShadow: [
        BoxShadow(
          color: const Color(0xFF2574F5).withValues(alpha: .16),
          blurRadius: 22,
          offset: const Offset(0, 8),
        ),
      ],
    ),
    child: Icon(Icons.school_rounded, color: Colors.white, size: size * .56),
  );
}
