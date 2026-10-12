import 'package:flutter/material.dart';

/// A teardrop-shaped map marker with a circular profile photo
/// inside.
///
/// Shape (from the sketch):
///
///         ╭──────╮
///        ╱  PHOTO  ╲
///       │  CIRCLE   │
///        ╲         ╱
///         ╰───┬───╯
///             │
///             ▼
///             ●  ← anchor point (this is the map coordinate)
///
/// Colors:
///   - ringColor:  gold for current user, green for other user
///   - fillColor:  light version of ring color
class PhotoMarker extends StatelessWidget {
  final String? photoUrl;
  final String fallbackInitial;
  final Color ringColor;
  final Color fillColor;
  final double size;

  const PhotoMarker({
    super.key,
    this.photoUrl,
    required this.fallbackInitial,
    required this.ringColor,
    required this.fillColor,
    this.size = 60,
  });

  @override
  Widget build(BuildContext context) {
    // Total height = size + tail.
    // Circle is at the top; tail points to the anchor.
    final double circleSize = size;
    final double tailHeight = size * 0.25;
    final double totalHeight = circleSize + tailHeight;
    final double totalWidth = circleSize;

    return SizedBox(
      width: totalWidth,
      height: totalHeight,
      child: Stack(
        alignment: Alignment.topCenter,
        children: [
          // Teardrop outline + tail
          CustomPaint(
            size: Size(totalWidth, totalHeight),
            painter: _TeardropPainter(
              ringColor: ringColor,
              fillColor: fillColor,
            ),
          ),

          // Photo circle
          Positioned(
            top: 0,
            child: Container(
              width: circleSize,
              height: circleSize,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: fillColor,
                border: Border.all(
                  color: ringColor,
                  width: 3,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.25),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: ClipOval(
                child: _buildPhoto(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPhoto() {
    final url = photoUrl;

    if (url != null && url.trim().isNotEmpty) {
      return Image.network(
        url,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => _fallback(),
        loadingBuilder: (context, child, progress) {
          if (progress == null) return child;
          return _fallback();
        },
      );
    }

    return _fallback();
  }

  Widget _fallback() {
    return Container(
      color: fillColor,
      alignment: Alignment.center,
      child: Text(
        fallbackInitial.isNotEmpty
            ? fallbackInitial[0].toUpperCase()
            : '?',
        style: TextStyle(
          fontSize: size * 0.45,
          fontWeight: FontWeight.bold,
          color: ringColor,
        ),
      ),
    );
  }
}

/// Draws the teardrop body and the tail that points downward.
///
/// The tail is a curved triangle that reaches down to the
/// bottom of the canvas, which is where the marker anchors
/// on the map.
class _TeardropPainter extends CustomPainter {
  final Color ringColor;
  final Color fillColor;

  _TeardropPainter({
    required this.ringColor,
    required this.fillColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final double circleRadius = size.width / 2;
    final double circleCenterX = size.width / 2;
    final double circleCenterY = circleRadius;
    final double anchorY = size.height;

    // ---------------------------------------------------------
    // 1. Draw the tail (behind the circle)
    // ---------------------------------------------------------
    final tailPaint = Paint()
      ..color = fillColor
      ..style = PaintingStyle.fill;

    final tailPath = Path()
      ..moveTo(circleCenterX - circleRadius * 0.55, circleCenterY)
      ..quadraticBezierTo(
        circleCenterX - 4,
        circleCenterY + circleRadius * 0.9,
        circleCenterX,
        anchorY,
      )
      ..quadraticBezierTo(
        circleCenterX + 4,
        circleCenterY + circleRadius * 0.9,
        circleCenterX + circleRadius * 0.55,
        circleCenterY,
      )
      ..close();

    canvas.drawPath(tailPath, tailPaint);

    // ---------------------------------------------------------
    // 2. Tail outline (same shape as above but stroke only)
    // ---------------------------------------------------------
    final tailOutlinePaint = Paint()
      ..color = ringColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round;

    canvas.drawPath(tailPath, tailOutlinePaint);

    // ---------------------------------------------------------
    // 3. Circle body with ring
    // ---------------------------------------------------------
    final circleFillPaint = Paint()
      ..color = fillColor
      ..style = PaintingStyle.fill;

    canvas.drawCircle(
      Offset(circleCenterX, circleCenterY),
      circleRadius - 1.5,
      circleFillPaint,
    );

    // The ring is drawn by the Container's border in the widget,
    // so we don't redraw it here to avoid double-stroking.
  }

  @override
  bool shouldRepaint(covariant _TeardropPainter oldDelegate) {
    return oldDelegate.ringColor != ringColor ||
        oldDelegate.fillColor != fillColor;
  }
}