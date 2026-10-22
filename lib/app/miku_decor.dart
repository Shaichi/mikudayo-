import 'package:flutter/material.dart';

import 'theme.dart';

/// Dải sọc chéo hồng–trắng, lấy từ nơ/băng đô của trang phục Miku Live2D.
class CandyStripe extends StatelessWidget {
  const CandyStripe({super.key, this.height = 10, this.radius = 0});

  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(radius),
    child: SizedBox(
      height: height,
      width: double.infinity,
      child: const CustomPaint(painter: _StripePainter()),
    ),
  );
}

class _StripePainter extends CustomPainter {
  const _StripePainter();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = Colors.white);
    final pink = Paint()..color = MikuTheme.accent;
    const w = 9.0;
    for (var x = -size.height; x < size.width + size.height; x += w * 2) {
      canvas.drawPath(
        Path()
          ..moveTo(x, size.height)
          ..lineTo(x + size.height, 0)
          ..lineTo(x + size.height + w, 0)
          ..lineTo(x + w, size.height)
          ..close(),
        pink,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Năm dòng kẻ khuông nhạc lượn nhẹ — Miku là ca sĩ. Dùng làm nền rất mờ.
class StaffLines extends StatelessWidget {
  const StaffLines({
    super.key,
    this.color = MikuTheme.stageCyan,
    this.opacity = 0.18,
  });

  final Color color;
  final double opacity;

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: CustomPaint(
      painter: _StaffPainter(color.withValues(alpha: opacity)),
      size: Size.infinite,
    ),
  );
}

class _StaffPainter extends CustomPainter {
  _StaffPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    final top = size.height * 0.30;
    for (var i = 0; i < 5; i++) {
      final y = top + i * 9.0;
      canvas.drawPath(
        Path()
          ..moveTo(-10, y + 26)
          ..cubicTo(
            size.width * 0.3,
            y - 30,
            size.width * 0.65,
            y + 50,
            size.width + 10,
            y - 6,
          ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _StaffPainter oldDelegate) =>
      oldDelegate.color != color;
}
