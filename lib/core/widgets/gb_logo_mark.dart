import 'package:flutter/material.dart';

/// The GabayBatas logo: a shield holding the scales of justice, with a gold
/// balance point. Drawn on the same 64×64 grid as the website's mark
/// (includes/brand_mark.php on the website).
class GbLogoMark extends StatelessWidget {
  const GbLogoMark({super.key, this.size = 28, this.color = Colors.white});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _GbLogoPainter(color)),
    );
  }
}

class _GbLogoPainter extends CustomPainter {
  _GbLogoPainter(this.color);

  final Color color;
  static const Color _gold = Color(0xFFC9A227);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 64, size.height / 64);
    // Set slightly low: the shield is heavier at the top, so this looks centred.
    canvas.translate(0, 1.75);

    final shield = Path()
      ..moveTo(32, 5)
      ..lineTo(53, 12.5)
      ..lineTo(53, 30)
      ..cubicTo(53, 43.5, 44, 52.5, 32, 59)
      ..cubicTo(20, 52.5, 11, 43.5, 11, 30)
      ..lineTo(11, 12.5)
      ..close();
    canvas.drawPath(
      shield,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.6
        ..strokeJoin = StrokeJoin.round,
    );

    final line = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.8
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawLine(const Offset(32, 21), const Offset(32, 44), line);
    canvas.drawLine(const Offset(25.5, 45.5), const Offset(38.5, 45.5), line);
    canvas.drawLine(const Offset(21, 25), const Offset(43, 25), line);
    for (final x in const [21.0, 43.0]) {
      canvas.drawLine(Offset(x, 25), Offset(x - 3.5, 34), line);
      canvas.drawLine(Offset(x, 25), Offset(x + 3.5, 34), line);
      final pan = Path()
        ..moveTo(x - 4.5, 34)
        ..lineTo(x + 4.5, 34)
        ..quadraticBezierTo(x, 40, x - 4.5, 34)
        ..close();
      canvas.drawPath(pan, Paint()..color = color);
    }

    canvas.drawCircle(const Offset(32, 20), 3, Paint()..color = _gold);
  }

  @override
  bool shouldRepaint(_GbLogoPainter oldDelegate) => oldDelegate.color != color;
}
