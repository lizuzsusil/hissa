import 'package:flutter/material.dart';

/// Official multi-colour Google "G" logo, rendered via a high-performance
/// native CustomPainter (zero external dependencies).
class GoogleLogo extends StatelessWidget {
  final double size;

  const GoogleLogo({super.key, this.size = 18});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size, size),
      painter: const _GoogleLogoPainter(),
    );
  }
}

class _GoogleLogoPainter extends CustomPainter {
  const _GoogleLogoPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / 48.0;
    canvas.scale(scale, scale);

    // Yellow path
    final pathYellow = Path()
      ..moveTo(43.611, 20.083)
      ..lineTo(42.0, 20.083)
      ..lineTo(42.0, 20.0)
      ..lineTo(24.0, 20.0)
      ..lineTo(24.0, 28.0)
      ..lineTo(35.303, 28.0)
      ..cubicTo(33.654, 32.657, 29.223, 36.0, 24.0, 36.0)
      ..cubicTo(17.373, 36.0, 12.0, 30.627, 12.0, 24.0)
      ..cubicTo(12.0, 17.373, 17.373, 12.0, 24.0, 12.0)
      ..cubicTo(27.059, 12.0, 29.842, 13.154, 31.961, 15.039)
      ..lineTo(37.618, 9.382)
      ..cubicTo(34.046, 6.053, 29.268, 4.0, 24.0, 4.0)
      ..cubicTo(12.955, 4.0, 4.0, 12.955, 4.0, 24.0)
      ..cubicTo(4.0, 35.045, 12.955, 44.0, 24.0, 44.0)
      ..cubicTo(34.0, 44.0, 44.0, 35.045, 44.0, 24.0)
      ..cubicTo(44.0, 22.659, 43.862, 21.35, 43.611, 20.083)
      ..close();
    canvas.drawPath(pathYellow, Paint()..color = const Color(0xFFFFC107));

    // Red path
    final pathRed = Path()
      ..moveTo(6.306, 14.691)
      ..lineTo(12.877, 19.51)
      ..cubicTo(14.655, 15.108, 18.961, 12.0, 24.0, 12.0)
      ..cubicTo(27.059, 12.0, 29.842, 13.154, 31.961, 15.039)
      ..lineTo(37.618, 9.382)
      ..cubicTo(34.046, 6.053, 29.268, 4.0, 24.0, 4.0)
      ..cubicTo(16.318, 4.0, 9.656, 8.337, 6.306, 14.691)
      ..close();
    canvas.drawPath(pathRed, Paint()..color = const Color(0xFFFF3D00));

    // Green path
    final pathGreen = Path()
      ..moveTo(24.0, 44.0)
      ..cubicTo(29.166, 44.0, 33.86, 42.023, 37.409, 38.808)
      ..lineTo(31.219, 33.57)
      ..cubicTo(29.211, 35.091, 26.715, 36.0, 24.0, 36.0)
      ..cubicTo(18.798, 36.0, 14.381, 32.683, 12.717, 28.054)
      ..lineTo(6.195, 33.079)
      ..cubicTo(9.505, 39.556, 16.227, 44.0, 24.0, 44.0)
      ..close();
    canvas.drawPath(pathGreen, Paint()..color = const Color(0xFF4CAF50));

    // Blue path
    final pathBlue = Path()
      ..moveTo(43.611, 20.083)
      ..lineTo(42.0, 20.083)
      ..lineTo(42.0, 20.0)
      ..lineTo(24.0, 20.0)
      ..lineTo(24.0, 28.0)
      ..lineTo(35.303, 28.0)
      ..cubicTo(34.511, 30.237, 33.072, 32.166, 31.216, 33.571)
      ..lineTo(37.406, 38.809)
      ..cubicTo(41.406, 35.045, 44.0, 29.842, 44.0, 24.0)
      ..cubicTo(44.0, 22.659, 43.862, 21.35, 43.611, 20.083)
      ..close();
    canvas.drawPath(pathBlue, Paint()..color = const Color(0xFF1976D2));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
