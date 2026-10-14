import 'dart:io';

import 'package:flutter/material.dart';

import '../../../core/cache/profile_photo_cache.dart';
import '../../../core/map/map_style_preference.dart';
import '../../../core/theme/webs_colors.dart';
import '../../../core/map/mapbox_tile_layer.dart';

/// Bottom sheet that lets the user pick the map style.
///
/// Matches the WhatsApp-style tile picker with three thumbnail
/// options: Default, Satellite, Terrain.
///
/// The preview images are downloaded once and cached on disk
/// using [ProfilePhotoCache], so the sheet opens instantly on
/// every subsequent open — no network required.
class MapStyleSheet extends StatelessWidget {
  final MapStyleKind current;
  final ValueChanged<MapStyleKind> onSelected;

  const MapStyleSheet({
    super.key,
    required this.current,
    required this.onSelected,
  });

  static Future<MapStyleKind?> show(
    BuildContext context, {
    required MapStyleKind current,
  }) {
    return showModalBottomSheet<MapStyleKind>(
      context: context,
      backgroundColor: WebsColors.surface(context),
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(24),
        ),
      ),
      builder: (_) => MapStyleSheet(
        current: current,
        onSelected: (kind) =>
            Navigator.of(context).pop(kind),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Map type',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: WebsColors.textDark(context),
                    ),
                  ),
                ),
                IconButton(
                  icon: Icon(
                    Icons.close,
                    color: WebsColors.textDark(context),
                  ),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: MapStyleKind.values.map((kind) {
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: _StyleTile(
                      kind: kind,
                      isSelected: kind == current,
                      onTap: () => onSelected(kind),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}

class _StyleTile extends StatelessWidget {
  final MapStyleKind kind;
  final bool isSelected;
  final VoidCallback onTap;

  const _StyleTile({
    required this.kind,
    required this.isSelected,
    required this.onTap,
  });

  /// Mapbox static preview URL for this style.
  ///
  /// Note: the token used here must be the same one used by
  /// MapboxTileLayer. Keep them in sync.
  String get _previewUrl {
    // Imported from mapbox_tile_layer.dart would be cleaner, but
    // the token lives in that file. We re-declare the same value
    // here so this widget doesn't depend on map tile internals.
    const token = kMapboxAccessToken;

    switch (kind) {
      case MapStyleKind.defaultStyle:
        return 'https://api.mapbox.com/styles/v1/mapbox/streets-v12/static/-6.7924,39.2083,10,0/200x200?access_token=$token';
      case MapStyleKind.satellite:
        return 'https://api.mapbox.com/styles/v1/mapbox/satellite-streets-v12/static/-6.7924,39.2083,10,0/200x200?access_token=$token';
      case MapStyleKind.terrain:
        return 'https://api.mapbox.com/styles/v1/mapbox/outdoors-v12/static/-6.7924,39.2083,10,0/200x200?access_token=$token';
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            height: 90,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isSelected
                    ? WebsColors.primaryGreen
                    : WebsColors.border(context),
                width: isSelected ? 3 : 1.5,
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(
                isSelected ? 13 : 15,
              ),
              child: _CachedStylePreview(url: _previewUrl),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            kind.label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: isSelected
                  ? FontWeight.bold
                  : FontWeight.normal,
              color: isSelected
                  ? WebsColors.primaryGreen
                  : WebsColors.textDark(context),
            ),
          ),
        ],
      ),
    );
  }
}

/// Renders a map style preview image using the shared
/// [ProfilePhotoCache] as a disk cache.
///
/// Behaviour:
///   - If the image is cached → shows instantly from disk.
///   - If not cached → shows a placeholder while downloading,
///     then swaps in the real image once available.
///
/// After the first download, subsequent opens of the sheet
/// are instant with zero network traffic.
class _CachedStylePreview extends StatefulWidget {
  final String url;

  const _CachedStylePreview({required this.url});

  @override
  State<_CachedStylePreview> createState() => _CachedStylePreviewState();
}

class _CachedStylePreviewState extends State<_CachedStylePreview> {
  File? _file;
  bool _resolved = false;

  @override
  void initState() {
    super.initState();
    _resolve();
  }

  @override
  void didUpdateWidget(_CachedStylePreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) {
      _file = null;
      _resolved = false;
      _resolve();
    }
  }

  Future<void> _resolve() async {
    // 1. Try the local disk cache first — instant.
    final cached = await ProfilePhotoCache.instance.get(widget.url);

    if (!mounted) return;

    if (cached != null) {
      setState(() {
        _file = cached;
        _resolved = true;
      });
      return;
    }

    // 2. Not cached — show placeholder while downloading.
    setState(() => _resolved = true);

    final downloaded =
        await ProfilePhotoCache.instance.download(widget.url);

    if (!mounted) return;
    if (downloaded != null) {
      setState(() => _file = downloaded);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_file != null && _file!.existsSync()) {
      return Image.file(
        _file!,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
      );
    }

    // Placeholder while resolving / downloading.
    if (!_resolved) {
      return _placeholder(context, showSpinner: true);
    }

    return _placeholder(context, showSpinner: false);
  }

  Widget _placeholder(
    BuildContext context, {
    required bool showSpinner,
  }) {
    return Container(
      color: WebsColors.softGreen(context),
      alignment: Alignment.center,
      child: showSpinner
          ? const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: WebsColors.primaryGreen,
              ),
            )
          : Icon(
              Icons.map_outlined,
              color: WebsColors.primaryGreen,
              size: 32,
            ),
    );
  }
}