import 'package:flutter/cupertino.dart';

class NotchCapsulePainter extends CustomPainter {
  const NotchCapsulePainter({
    required this.isExpanded,
    this.earRadius = 12.0,
    this.bottomRadius = 20.0,
    this.borderColor = const Color(0x338FA9C8),
    this.fillColor = const Color(0xEE0D0D11),
    this.isDynamicIsland = false,
  });

  final bool isExpanded;
  final double earRadius;
  final double bottomRadius;
  final Color borderColor;
  final Color fillColor;
  final bool isDynamicIsland;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path();
    final width = size.width;
    final height = size.height;

    if (isDynamicIsland) {
      // Pill shape for Dynamic Island
      final rrect = RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 0, width, height),
        Radius.circular(bottomRadius),
      );
      path.addRRect(rrect);
    } else {
      // MacBook Notch shape with outward ears at the top
      // Starts at top-left outside ear
      path.moveTo(0, 0);
      // Curve in from top left
      path.quadraticBezierTo(earRadius, 0, earRadius, earRadius);
      // Down to bottom left
      path.lineTo(earRadius, height - bottomRadius);
      // Bottom left corner
      path.quadraticBezierTo(
        earRadius,
        height,
        earRadius + bottomRadius,
        height,
      );
      // Across bottom to bottom right
      path.lineTo(width - earRadius - bottomRadius, height);
      // Bottom right corner
      path.quadraticBezierTo(
        width - earRadius,
        height,
        width - earRadius,
        height - bottomRadius,
      );
      // Up to top right ear
      path.lineTo(width - earRadius, earRadius);
      // Top right ear curve out
      path.quadraticBezierTo(width - earRadius, 0, width, 0);
      path.close();
    }

    // Shadow (only when expanded or floating dynamic island)
    if (isExpanded) {
      canvas.drawShadow(path, const Color(0x88000000), 16, true);
    } else if (isDynamicIsland) {
      canvas.drawShadow(path, const Color(0x44000000), 6, true);
    }

    // Background fill
    final fillPaint = Paint()
      ..color = fillColor
      ..style = PaintingStyle.fill;
    canvas.drawPath(path, fillPaint);

    // Rim stroke highlight
    if (borderColor.a > 0) {
      final borderPaint = Paint()
        ..color = borderColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0;
      canvas.drawPath(path, borderPaint);
    }
  }

  @override
  bool shouldRepaint(covariant NotchCapsulePainter oldDelegate) {
    return oldDelegate.isExpanded != isExpanded ||
        oldDelegate.isDynamicIsland != isDynamicIsland ||
        oldDelegate.fillColor != fillColor ||
        oldDelegate.borderColor != borderColor;
  }
}
