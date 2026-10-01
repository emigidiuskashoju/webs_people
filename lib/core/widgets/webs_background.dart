import 'package:flutter/material.dart';

class WebsBackground extends StatelessWidget {
  final Widget child;
  final double lightOpacity;
  final double darkOpacity;

  const WebsBackground({
    super.key,
    required this.child,
    this.lightOpacity = 0.18,
    this.darkOpacity = 0.35,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final baseColor = isDark
        ? const Color(0xFF0F1A10)
        : const Color(0xFFF4F9F4);

    final imagePath = isDark
        ? 'assets/images/webs_bg_dark.png'
        : 'assets/images/webs_bg_light.png';

    final imageOpacity = isDark ? darkOpacity : lightOpacity;

    // Light: MULTIPLY removes the light-grey background of the image.
    // Dark:  SCREEN removes the black background of the image.
    final blendMode = isDark ? BlendMode.screen : BlendMode.multiply;

    final tintColor =
        isDark ? const Color(0xFF4CAF50) : const Color(0xFFF4F9F4);

    return Stack(
      children: [
        Container(color: baseColor),
        Positioned.fill(
          child: Opacity(
            opacity: imageOpacity,
            child: Image.asset(
              imagePath,
              fit: BoxFit.cover,
              alignment: Alignment.topLeft,
              colorBlendMode: blendMode,
              color: tintColor,
            ),
          ),
        ),
        child,
      ],
    );
  }
}