import 'package:flutter/material.dart';

/// One pin that shows TWO people standing at the same place.
///
/// Two phones next to each other never report the exact same GPS
/// position (each fix is off by 5–30 m in its own direction). When
/// zoomed in, that small error makes two separate pins look like the
/// people are in different places. When they are close enough to
/// count as "together", the map shows this pin instead:
///
///        ╭────────────╮
///        │ (ME)(THEM) │   two overlapping photos in one capsule
///        ╰─────┬──────╯
///              ▼          tail tip = the shared location
///
/// The widget is exactly [width] x [height] and the tail tip is the
/// bottom-centre pixel, so use it with `Alignment.topCenter` in a
/// flutter_map Marker (same as PhotoMarker).
class PairMarker extends StatelessWidget {
  final String? firstPhotoUrl;
  final String firstInitial;
  final Color firstColor;

  final String? secondPhotoUrl;
  final String secondInitial;
  final Color secondColor;

  /// Diameter of each photo circle.
  final double avatarSize;

  const PairMarker({
    super.key,
    required this.firstPhotoUrl,
    required this.firstInitial,
    required this.firstColor,
    required this.secondPhotoUrl,
    required this.secondInitial,
    required this.secondColor,
    this.avatarSize = 40,
  });

  static const double _padding = 3;
  static const double _overlapFraction = 0.3;

  double get _overlap => avatarSize * _overlapFraction;
  double get _tailHeight => avatarSize * 0.3;

  double get width => _padding * 2 + avatarSize * 2 - _overlap;
  double get capsuleHeight => _padding * 2 + avatarSize;
  double get height => capsuleHeight + _tailHeight;

  /// Size to give the flutter_map Marker for a given [avatarSize].
  static Size sizeFor(double avatarSize) {
    final overlap = avatarSize * _overlapFraction;
    return Size(
      _padding * 2 + avatarSize * 2 - overlap,
      _padding * 2 + avatarSize + avatarSize * 0.3,
    );
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: Stack(
        children: [
          // Tail, drawn first so the capsule covers its top edge.
          Positioned(
            left: 0,
            right: 0,
            top: capsuleHeight - 2,
            bottom: 0,
            child: CustomPaint(painter: _TailPainter()),
          ),

          // White capsule holding both photos.
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            height: capsuleHeight,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(capsuleHeight / 2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.25),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
            ),
          ),

          // Second person (behind).
          Positioned(
            top: _padding,
            left: _padding + avatarSize - _overlap,
            child: _Avatar(
              photoUrl: secondPhotoUrl,
              initial: secondInitial,
              color: secondColor,
              size: avatarSize,
            ),
          ),

          // First person (in front).
          Positioned(
            top: _padding,
            left: _padding,
            child: _Avatar(
              photoUrl: firstPhotoUrl,
              initial: firstInitial,
              color: firstColor,
              size: avatarSize,
            ),
          ),
        ],
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  final String? photoUrl;
  final String initial;
  final Color color;
  final double size;

  const _Avatar({
    required this.photoUrl,
    required this.initial,
    required this.color,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white,
        border: Border.all(color: color, width: 3),
      ),
      child: ClipOval(child: _photo()),
    );
  }

  Widget _photo() {
    final url = photoUrl;
    if (url != null && url.trim().isNotEmpty) {
      return Image.network(
        url,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => _fallback(),
        loadingBuilder: (context, child, progress) =>
            progress == null ? child : _fallback(),
      );
    }
    return _fallback();
  }

  Widget _fallback() {
    final text = initial.trim();
    return Container(
      color: color.withValues(alpha: 0.12),
      alignment: Alignment.center,
      child: Text(
        text.isNotEmpty ? text.characters.first.toUpperCase() : '?',
        style: TextStyle(
          fontSize: size * 0.42,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }
}

class _TailPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final halfBase = size.height * 0.7;
    final path = Path()
      ..moveTo(cx - halfBase, 0)
      ..lineTo(cx + halfBase, 0)
      ..lineTo(cx, size.height)
      ..close();
    canvas.drawShadow(path, Colors.black, 2, false);
    canvas.drawPath(path, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(covariant _TailPainter oldDelegate) => false;
}
