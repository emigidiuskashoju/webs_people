import 'package:flutter/material.dart';

import '../../../core/theme/webs_colors.dart';

/// The banner shown above the destination search card while a
/// route is active. Displays distance/duration and a single
/// "Reroute" button that the user taps manually.
class DestinationRouteBar extends StatelessWidget {
  final double? remainingMeters;
  final double? remainingSeconds;
  final bool isRerouting;
  final VoidCallback onReroute;
  final VoidCallback onClear;

  const DestinationRouteBar({
    super.key,
    required this.remainingMeters,
    required this.remainingSeconds,
    required this.isRerouting,
    required this.onReroute,
    required this.onClear,
  });

  String _formatDistance(double? meters) {
    if (meters == null) return '—';
    if (meters < 1000) return '${meters.round()} m';
    return '${(meters / 1000).toStringAsFixed(2)} km';
  }

  String _formatDuration(double? seconds) {
    if (seconds == null) return '—';
    final s = seconds.round();
    if (s < 60) return '$s s';
    final m = s ~/ 60;
    if (m < 60) return '$m min';
    final h = m ~/ 60;
    final rem = m % 60;
    return '${h}h ${rem}m';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
      decoration: BoxDecoration(
        color: WebsColors.surface(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: WebsColors.border(context),
          width: 1.5,
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.alt_route,
            size: 20,
            color: WebsColors.primaryGreen,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${_formatDistance(remainingMeters)} · '
                  '${_formatDuration(remainingSeconds)}',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: WebsColors.textDark(context),
                  ),
                ),
                Text(
                  'Tap Reroute if you took a different road.',
                  style: TextStyle(
                    fontSize: 11,
                    color: WebsColors.textLight(context),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (isRerouting)
            const SizedBox(
              width: 90,
              height: 36,
              child: Center(
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: WebsColors.primaryGreen,
                  ),
                ),
              ),
            )
          else
            FilledButton.icon(
              onPressed: onReroute,
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('Reroute'),
              style: FilledButton.styleFrom(
                backgroundColor: WebsColors.primaryGreen,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                textStyle: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          IconButton(
            tooltip: 'Clear',
            onPressed: onClear,
            icon: Icon(
              Icons.close,
              size: 18,
              color: WebsColors.textLight(context),
            ),
          ),
        ],
      ),
    );
  }
}