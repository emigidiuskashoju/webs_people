import 'package:flutter/material.dart';

import '../../core/theme/webs_colors.dart';
import '../../shared/widgets/webs_background.dart';
import 'models/recovery_device.dart';
import 'services/recovery_service.dart';

class LocationHistoryScreen extends StatefulWidget {
  final RecoveryDevice device;
  const LocationHistoryScreen({super.key, required this.device});

  @override
  State<LocationHistoryScreen> createState() => _LocationHistoryScreenState();
}

class _LocationHistoryScreenState extends State<LocationHistoryScreen> {
  final RecoveryService _service = RecoveryService();
  List<Map<String, dynamic>> _locations = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final locations = await _service.getLocationHistory(widget.device.id);
      if (!mounted) return;
      setState(() {
        _locations = locations;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      appBar: securityAppBar(title: '${widget.device.name} History'),
      body: WebsBackground(child: _buildBody()),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: WebsColors.primaryGreen),
      );
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.error_outline,
                size: 60,
                color: Colors.redAccent,
              ),
              const SizedBox(height: 16),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: TextStyle(color: WebsColors.textLight(context)),
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _loadHistory,
                style: FilledButton.styleFrom(
                  backgroundColor: WebsColors.primaryGreen,
                ),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (_locations.isEmpty) {
      return RefreshIndicator(
        color: WebsColors.primaryGreen,
        onRefresh: _loadHistory,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            SizedBox(height: MediaQuery.of(context).size.height * 0.3),
            Icon(
              Icons.history_toggle_off,
              size: 80,
              color: WebsColors.softGreen(context),
            ),
            const SizedBox(height: 16),
            Center(
              child: Text(
                'No location history available.',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: WebsColors.textLight(context),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Center(
              child: Text(
                'Pull down to refresh.',
                style: TextStyle(
                  fontSize: 13,
                  color: WebsColors.textLight(context),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      color: WebsColors.primaryGreen,
      onRefresh: _loadHistory,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 100, 16, 16),
        itemCount: _locations.length,
        itemBuilder: (context, i) => _buildTimelineTile(
          _locations[i],
          i,
          isLast: i == _locations.length - 1,
        ),
      ),
    );
  }

  Widget _buildTimelineTile(
    Map<String, dynamic> location,
    int index, {
    bool isLast = false,
  }) {
    final latitude = location['latitude'];
    final longitude = location['longitude'];
    final accuracy = location['accuracy'];
    final recordedAt = location['recorded_at'];

    String formattedDate = recordedAt?.toString() ?? 'Unknown time';
    try {
      final parsed = DateTime.parse(recordedAt.toString());
      formattedDate = '${parsed.toLocal()}'.split('.').first;
    } catch (_) {}

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Column(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: const BoxDecoration(
                  color: WebsColors.primaryGreen,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    '${index + 1}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 2,
                    color: WebsColors.softGreen(context),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: WebsColors.surface(context),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: WebsColors.shadow(context),
                    blurRadius: 15,
                    offset: const Offset(0, 5),
                  ),
                ],
                border: Border.all(
                  color: WebsColors.border(context),
                  width: 2,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.location_on,
                        color: WebsColors.primaryGreen,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '$latitude, $longitude',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: WebsColors.textDark(context),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: WebsColors.softGreen(context),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.gps_fixed,
                          size: 14,
                          color: WebsColors.primaryGreen,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Accuracy: ${accuracy ?? 'unknown'} m',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: WebsColors.primaryGreen,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Icon(
                        Icons.access_time,
                        size: 16,
                        color: WebsColors.textLight(context),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          formattedDate,
                          style: TextStyle(
                            fontSize: 13,
                            color: WebsColors.textLight(context),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}