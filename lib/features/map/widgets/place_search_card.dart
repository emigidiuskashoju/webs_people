import 'package:flutter/material.dart';

import '../../../core/theme/webs_colors.dart';
import '../models/place.dart';

class PlaceSearchCard extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool isLoading;
  final List<Place> results;
  final String? error;
  final bool hasActiveDestination;
  final String? activeDestinationName;
  final double? remainingDistanceMeters;
  final double? remainingDurationSeconds;
  final ValueChanged<String> onQueryChanged;
  final ValueChanged<Place> onPlaceSelected;
  final VoidCallback onClear;

  const PlaceSearchCard({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.isLoading,
    required this.results,
    required this.error,
    required this.hasActiveDestination,
    required this.activeDestinationName,
    required this.remainingDistanceMeters,
    required this.remainingDurationSeconds,
    required this.onQueryChanged,
    required this.onPlaceSelected,
    required this.onClear,
  });

  String _formatDistance(double? meters) {
    if (meters == null) return '--';
    if (meters < 1000) return '${meters.round()} m';
    return '${(meters / 1000).toStringAsFixed(2)} km';
  }

  String _formatDuration(double? seconds) {
    if (seconds == null) return '--';
    final total = seconds.round();
    final h = total ~/ 3600;
    final m = (total % 3600) ~/ 60;
    if (h > 0) return '${h}h ${m}m';
    return '${m} min';
  }

  @override
  Widget build(BuildContext context) {
    final surface = WebsColors.surface(context);
    final border = WebsColors.border(context);
    final textDark = WebsColors.textDark(context);
    final textLight = WebsColors.textLight(context);
    final softGreen = WebsColors.softGreen(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: WebsColors.shadow(context),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
        border: Border.all(color: border, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Search for a place',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 17,
              color: textDark,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Find any location and get a route. '
            'The route updates as you move.',
            style: TextStyle(color: textLight, fontSize: 13),
          ),
          const SizedBox(height: 12),

          TextField(
            controller: controller,
            focusNode: focusNode,
            textInputAction: TextInputAction.search,
            style: TextStyle(color: textDark),
            onChanged: onQueryChanged,
            decoration: InputDecoration(
              hintText: 'Type a place, e.g. Mwanza',
              hintStyle: TextStyle(color: textLight),
              prefixIcon: const Icon(
                Icons.search,
                color: WebsColors.primaryGreen,
              ),
              suffixIcon: (controller.text.isEmpty && !hasActiveDestination)
                  ? null
                  : IconButton(
                      tooltip: 'Clear',
                      icon: Icon(Icons.close, color: textLight),
                      onPressed: onClear,
                    ),
              filled: true,
              fillColor: softGreen,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 18,
                vertical: 14,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(
                  color: WebsColors.primaryGreen,
                  width: 2,
                ),
              ),
            ),
          ),

          if (isLoading) ...[
            const SizedBox(height: 10),
            const LinearProgressIndicator(
              color: WebsColors.primaryGreen,
              backgroundColor: Colors.transparent,
            ),
          ],

          if (error != null) ...[
            const SizedBox(height: 10),
            Text(
              error!,
              style: const TextStyle(color: Colors.redAccent, fontSize: 12),
            ),
          ],

          if (results.isNotEmpty && !hasActiveDestination) ...[
            const SizedBox(height: 10),
            Container(
              decoration: BoxDecoration(
                color: surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: border, width: 1.5),
              ),
              child: Column(
                children: [
                  for (int i = 0; i < results.length; i++) ...[
                    InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: () => onPlaceSelected(results[i]),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: softGreen,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.place_outlined,
                                size: 18,
                                color: WebsColors.primaryGreen,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    results[i].name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      color: textDark,
                                      fontSize: 14,
                                    ),
                                  ),
                                  if (results[i].displayName.isNotEmpty)
                                    Text(
                                      results[i].displayName,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: textLight,
                                        fontSize: 12,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            Icon(
                              Icons.chevron_right,
                              color: textLight,
                              size: 18,
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (i < results.length - 1)
                      Divider(
                        height: 1,
                        color: border,
                        indent: 12,
                        endIndent: 12,
                      ),
                  ],
                ],
              ),
            ),
          ],

          if (hasActiveDestination) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: softGreen,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.route,
                        size: 20,
                        color: WebsColors.primaryGreen,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Route to ${activeDestinationName ?? 'destination'}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: textDark,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _pill(
                        context,
                        icon: Icons.straighten,
                        label: 'Remaining',
                        value: _formatDistance(remainingDistanceMeters),
                      ),
                      const SizedBox(width: 8),
                      _pill(
                        context,
                        icon: Icons.schedule,
                        label: 'ETA',
                        value: _formatDuration(remainingDurationSeconds),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _pill(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: WebsColors.surface(context),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: WebsColors.border(context), width: 1.5),
        ),
        child: Row(
          children: [
            Icon(icon, size: 14, color: WebsColors.primaryGreen),
            const SizedBox(width: 6),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 10,
                    color: WebsColors.textLight(context),
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.4,
                  ),
                ),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 13,
                    color: WebsColors.textDark(context),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}