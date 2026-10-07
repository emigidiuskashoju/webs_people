import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/theme/webs_colors.dart';

class SplashScreen extends StatefulWidget {
  final VoidCallback onFinished;
  final Duration minimumDuration;

  /// The user's saved theme mode. Drives which palette the splash
  /// uses so the screen matches the rest of the app.
  final ThemeMode themeMode;

  const SplashScreen({
    super.key,
    required this.onFinished,
    required this.themeMode,
    this.minimumDuration = const Duration(seconds: 2),
  });

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  // ============================================================
  // PER-LOGO COLOUR MAP
  // ============================================================
  static const Map<String, Color> _logoColors = {
    'assets/logos/liko_1.png': Color(0xFF2E7D32),
    'assets/logos/liko_2.png': Color(0xFF1565C0),
    'assets/logos/liko_3.png': Color(0xFF00838F),
    'assets/logos/liko_4.png': Color(0xFF6A1B9A),
    'assets/logos/liko_5.png': Color(0xFFC62828),
    'assets/logos/liko_6.png': Color(0xFFEF6C00),
    'assets/logos/liko_7.png': Color(0xFF4527A0),
    'assets/logos/liko_8.png': Color(0xFF00695C),
    'assets/logos/liko_9.png': Color(0xFFAD1457),
    'assets/logos/liko_10.png': Color(0xFF283593),
    'assets/logos/liko_11.png': Color(0xFF2E7D32),
    'assets/logos/liko_12.png': Color(0xFF8E24AA),
    'assets/logos/liko_13.png': Color(0xFF00897B),
    'assets/logos/liko_14.png': Color(0xFF37474F),
  };

  static List<String> get _logoPaths => _logoColors.keys.toList();

  /// Diameter of the visible logo PNG.
  static const double _circleSize = 38;

  /// Extra padding around the PNG for the coloured disc.
  static const double _discPadding = 12;

  /// Full diameter of the coloured disc.
  static double get _discSize => _circleSize + _discPadding;

  /// Number of full loops in the middle — your spec says 2.
  static const int _orbitTurns = 2;

  /// Radius of the orbit path around the center. Bigger radius =
  /// the two circles stay further apart during the loop.
  /// 2.5x discSize keeps them clearly separated.
  static double get _orbitRadius => _discSize * 0.6;

  /// Vertical offset while travelling straight in and out — keeps
  /// the two circles on parallel tracks (never touching).
  static double get _travelYOffset => _discSize * 0.55;

  /// Full cycle duration.
  static const Duration _cycleDuration = Duration(seconds: 3);

  // Phase boundaries (must sum to 1.0).
  static const double _enterEnd = 0.20;  // 0.00 → 0.20 : enter straight
  static const double _loopEnd = 0.80;   // 0.20 → 0.80 : loop 2x
  //                                        0.80 → 1.00 : exit straight

  late String _leftLogo;
  late String _rightLogo;

  late final AnimationController _cycleController;

  Timer? _finishTimer;

  final math.Random _random = math.Random();

  // Track which phase each circle is in so we know when to
  // trigger a colour swap ("hits the wall").
  bool _leftExitColorSwapped = false;
  bool _rightExitColorSwapped = false;

  @override
  void initState() {
    super.initState();

    final shuffled = List<String>.from(_logoPaths)..shuffle(_random);

    _leftLogo = shuffled[0];
    _rightLogo = shuffled[1];

    _cycleController = AnimationController(
      vsync: this,
      duration: _cycleDuration,
    )..addListener(_onTick)
     ..repeat();

    _finishTimer = Timer(widget.minimumDuration, () {
      if (!mounted) return;
      widget.onFinished();
    });
  }

  @override
  void dispose() {
    _finishTimer?.cancel();
    _cycleController.dispose();
    super.dispose();
  }

  void _onTick() {
    final t = _cycleController.value;

    // Reset swap flags at the start of each cycle.
    if (t < _enterEnd) {
      _leftExitColorSwapped = false;
      _rightExitColorSwapped = false;
      return;
    }

    // -------- Colour swap: only when a circle "hits the wall" --------
    // The left circle exits to the LEFT wall at end of loop phase.
    // The right circle exits to the RIGHT wall at end of loop phase.
    // We swap colours exactly when each enters the exit phase.

    final inExitPhase = t >= _loopEnd;

    if (inExitPhase && !_leftExitColorSwapped) {
      _leftExitColorSwapped = true;
      if (mounted) {
        setState(() {
          _leftLogo = _pickReplacement(_leftLogo, _rightLogo);
        });
      }
    }

    if (inExitPhase && !_rightExitColorSwapped) {
      _rightExitColorSwapped = true;
      if (mounted) {
        setState(() {
          _rightLogo = _pickReplacement(_rightLogo, _leftLogo);
        });
      }
    }
  }

  String _pickReplacement(String current, String other) {
    final available = List<String>.from(_logoPaths)
      ..remove(current)
      ..remove(other);

    if (available.isEmpty) return current;

    available.shuffle(_random);

    return available.first;
  }

  // ============================================================
  // THEME
  // ============================================================

  Brightness _resolveBrightness(BuildContext context) {
    switch (widget.themeMode) {
      case ThemeMode.light:
        return Brightness.light;
      case ThemeMode.dark:
        return Brightness.dark;
      case ThemeMode.system:
        return MediaQuery.of(context).platformBrightness;
    }
  }

  Color _backgroundColorFor(Brightness brightness) {
    return brightness == Brightness.dark
        ? const Color(0xFF0F1A2E)
        : const Color(0xFFE8F5E9);
  }

  Color _captionPrimaryFor(Brightness brightness) {
    return brightness == Brightness.dark
        ? WebsColors.accentGreen
        : WebsColors.primaryGreen;
  }

  Color _captionSecondaryFor(Brightness brightness) {
    return brightness == Brightness.dark
        ? const Color(0xFFC9A227)
        : const Color(0xFFB8860B);
  }

  // ============================================================
  // MOTION MATH
  // ============================================================
  //
  // Both circles follow the same path shape but 180° out of
  // phase. So when the left circle is on the left side of the
  // orbit, the right circle is on the right side — always
  // separated by 2 × orbitRadius.
  //
  // Offset for the LEFT circle. The RIGHT circle uses the same
  // function with its phase shifted by π.
  //
  // Enter phase  : travels straight from far-left to orbit-start
  // Loop phase   : 2 full loops around center
  // Exit phase   : travels straight from orbit-end to far-right

  Offset _circleOffset(double t, double maxSpread, {required bool mirrored}) {
    double x;
    double y;

    if (t < _enterEnd) {
      // ---- ENTER STRAIGHT ----
      final local = t / _enterEnd;
      final eased = Curves.easeOutCubic.transform(local);

      // Start off-screen at maxSpread and slide in to the
      // orbit-start position (0, -orbitRadius).
      final startX = -maxSpread;
      final endX = 0.0;
      final startY = -_travelYOffset;
      final endY = -_orbitRadius;

      x = startX + (endX - startX) * eased;
      y = startY + (endY - startY) * eased;
    } else if (t < _loopEnd) {
      // ---- LOOP ----
      final local = (t - _enterEnd) / (_loopEnd - _enterEnd);

      // Use a linear (constant-speed) progression so the circle
      // does NOT stall at the middle — just keeps rotating.
      final angle = local * _orbitTurns * 2 * math.pi;

      x = math.sin(angle) * _orbitRadius;
      y = -math.cos(angle) * _orbitRadius;
    } else {
      // ---- EXIT STRAIGHT ----
      final local = (t - _loopEnd) / (1.0 - _loopEnd);
      final eased = Curves.easeInCubic.transform(local);

      // Orbit-end position (0, -orbitRadius) → exit off-screen
      // at +maxSpread on the same parallel track.
      final startX = 0.0;
      final endX = maxSpread;
      final startY = -_orbitRadius;
      final endY = -_travelYOffset;

      x = startX + (endX - startX) * eased;
      y = startY + (endY - startY) * eased;
    }

    if (mirrored) {
      return Offset(-x, -y);
    }
    return Offset(x, y);
  }

  @override
  Widget build(BuildContext context) {
    final brightness = _resolveBrightness(context);

    final backgroundColor = _backgroundColorFor(brightness);
    final captionPrimary = _captionPrimaryFor(brightness);
    final captionSecondary = _captionSecondaryFor(brightness);

    final screenWidth = MediaQuery.of(context).size.width;
    final maxSpread = (screenWidth / 2) + _discSize; // exits fully off-screen

    return Scaffold(
      backgroundColor: backgroundColor,
      body: Stack(
        children: [
          Center(
            child: AnimatedBuilder(
              animation: _cycleController,
              builder: (context, _) {
                final t = _cycleController.value;

                final leftOffset = _circleOffset(
                  t,
                  maxSpread,
                  mirrored: false,
                );

                final rightOffset = _circleOffset(
                  t,
                  maxSpread,
                  mirrored: true,
                );

                // Circles rotate with the loop so the logo
                // spins around its own axis during the loop only.
                final loopAngle = t < _enterEnd || t >= _loopEnd
                    ? 0.0
                    : ((t - _enterEnd) / (_loopEnd - _enterEnd)) *
                        _orbitTurns *
                        2 *
                        math.pi;

                return SizedBox(
                  width: screenWidth,
                  height: screenWidth,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Transform.translate(
                        offset: leftOffset,
                        child: Transform.rotate(
                          angle: loopAngle,
                          child: _buildCircularLogo(_leftLogo),
                        ),
                      ),
                      Transform.translate(
                        offset: rightOffset,
                        child: Transform.rotate(
                          angle: loopAngle,
                          child: _buildCircularLogo(_rightLogo),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),

          // -----------------------------------------------------
          // Bottom caption
          // -----------------------------------------------------
          Align(
            alignment: Alignment.bottomCenter,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 48),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      'LIKO',
                      style: TextStyle(
                        color: captionPrimary,
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.5,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'unit',
                      style: TextStyle(
                        color: captionSecondary,
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCircularLogo(String logoPath) {
    final discColor = _logoColors[logoPath] ?? Colors.black87;

    return SizedBox(
      width: _discSize,
      height: _discSize,
      child: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: discColor,
          boxShadow: [
            BoxShadow(
              color: discColor.withValues(alpha: 0.35),
              blurRadius: 10,
              spreadRadius: 1,
            ),
          ],
        ),
        alignment: Alignment.center,
        child: ClipOval(
          child: SizedBox(
            width: _circleSize,
            height: _circleSize,
            child: Image.asset(
              logoPath,
              fit: BoxFit.cover,
              filterQuality: FilterQuality.medium,
            ),
          ),
        ),
      ),
    );
  }
}