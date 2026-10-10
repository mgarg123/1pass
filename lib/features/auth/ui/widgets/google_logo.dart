import 'package:flutter/material.dart';

/// Renders the official multi-color Google 'G' brand logo.
///
/// Tries to load 'assets/images/google_logo.png' first, and falls back to
/// a pixel-perfect Skia/Impeller vector [GoogleLogoPainter] if the asset
/// is not yet in the asset manifest or is unavailable.
class GoogleLogo extends StatelessWidget {
  final double size;
  final bool withBackgroundCircle;

  const GoogleLogo({
    super.key,
    this.size = 20.0,
    this.withBackgroundCircle = false,
  });

  @override
  Widget build(BuildContext context) {
    final Widget logo = Image.asset(
      'assets/images/google_logo.png',
      width: size,
      height: size,
      errorBuilder: (context, error, stackTrace) => SizedBox(
        width: size,
        height: size,
        child: const CustomPaint(
          painter: GoogleLogoPainter(),
        ),
      ),
    );

    if (withBackgroundCircle) {
      return Container(
        width: size + 8,
        height: size + 8,
        decoration: const BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
        ),
        padding: const EdgeInsets.all(4),
        child: logo,
      );
    }

    return logo;
  }
}

/// Vector painter that renders the exact official 4-color Google 'G' logo
/// based on the official Google Identity Brand Guidelines.
class GoogleLogoPainter extends CustomPainter {
  const GoogleLogoPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final double scale = size.width / 48.0;
    canvas.save();
    canvas.scale(scale, scale);

    // 1. Red (top curve: #EA4335)
    final redPaint = Paint()
      ..color = const Color(0xFFEA4335)
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;
    final redPath = Path()
      ..moveTo(24.00, 9.50)
      ..cubicTo(27.54, 9.50, 30.71, 10.72, 33.21, 13.10)
      ..lineTo(40.06, 6.25)
      ..cubicTo(35.90, 2.38, 30.47, 0.00, 24.00, 0.00)
      ..cubicTo(14.66, 0.00, 6.60, 5.38, 2.56, 13.22)
      ..lineTo(10.54, 19.41)
      ..cubicTo(12.43, 13.72, 17.74, 9.50, 24.00, 9.50)
      ..close();
    canvas.drawPath(redPath, redPaint);

    // 2. Blue (crossbar & outer right arc: #4285F4)
    final bluePaint = Paint()
      ..color = const Color(0xFF4285F4)
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;
    final bluePath = Path()
      ..moveTo(46.98, 24.55)
      ..cubicTo(46.98, 22.98, 46.83, 21.46, 46.60, 20.00)
      ..lineTo(24.00, 20.00)
      ..lineTo(24.00, 29.02)
      ..lineTo(36.94, 29.02)
      ..cubicTo(36.36, 31.98, 34.68, 34.50, 32.16, 36.20)
      ..lineTo(39.89, 42.20)
      ..cubicTo(44.40, 38.02, 46.98, 31.84, 46.98, 24.55)
      ..close();
    canvas.drawPath(bluePath, bluePaint);

    // 3. Yellow (left curve: #FBBC05)
    final yellowPaint = Paint()
      ..color = const Color(0xFFFBBC05)
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;
    final yellowPath = Path()
      ..moveTo(10.53, 28.59)
      ..cubicTo(10.05, 27.14, 9.77, 25.60, 9.77, 24.00)
      ..cubicTo(9.77, 22.40, 10.04, 20.86, 10.53, 19.41)
      ..lineTo(2.55, 13.22)
      ..cubicTo(0.92, 16.46, 0.00, 20.12, 0.00, 24.00)
      ..cubicTo(0.00, 27.88, 0.92, 31.54, 2.56, 34.79)
      ..lineTo(10.53, 28.59)
      ..close();
    canvas.drawPath(yellowPath, yellowPaint);

    // 4. Green (bottom curve: #34A853)
    final greenPaint = Paint()
      ..color = const Color(0xFF34A853)
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;
    final greenPath = Path()
      ..moveTo(24.00, 48.00)
      ..cubicTo(30.48, 48.00, 35.93, 45.87, 39.89, 42.19)
      ..lineTo(32.16, 36.19)
      ..cubicTo(30.01, 37.64, 27.24, 38.49, 24.00, 38.49)
      ..cubicTo(17.74, 38.49, 12.43, 34.27, 10.53, 28.58)
      ..lineTo(2.55, 34.77)
      ..cubicTo(6.60, 42.62, 14.66, 48.00, 24.00, 48.00)
      ..close();
    canvas.drawPath(greenPath, greenPaint);

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
