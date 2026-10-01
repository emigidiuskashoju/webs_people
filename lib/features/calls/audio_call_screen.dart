import 'package:flutter/material.dart';

import '../../core/theme/webs_colors.dart';
import 'models/call_record.dart';
import 'services/call_service.dart';

class AudioCallScreen extends StatefulWidget {
  final CallService callService;
  final CallRecord callRecord;

  const AudioCallScreen({
    super.key,
    required this.callService,
    required this.callRecord,
  });

  @override
  State<AudioCallScreen> createState() => _AudioCallScreenState();
}

class _AudioCallScreenState extends State<AudioCallScreen>
    with SingleTickerProviderStateMixin {
  bool _ending = false;
  late final AnimationController _pulseController;

  @override
  void initState() {
    super.initState();

    widget.callService.callStatus.addListener(_onCallStatusChanged);

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
  }

  @override
  void dispose() {
    widget.callService.callStatus.removeListener(_onCallStatusChanged);
    _pulseController.dispose();
    super.dispose();
  }

  void _onCallStatusChanged() {
    if (!mounted) return;
    setState(() {});

    final status = widget.callService.callStatus.value;
    if (status == CallStatus.ended ||
        status == CallStatus.declined ||
        status == CallStatus.failed) {
      Future<void>.delayed(const Duration(milliseconds: 300), () {
        if (!mounted) return;
        Navigator.of(context).pop();
      });
    }
  }

  Future<void> _endCall() async {
    if (_ending) return;
    setState(() => _ending = true);
    try {
      await widget.callService.endCall();
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (_) {
      if (!mounted) return;
      setState(() => _ending = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to end the call cleanly.')),
      );
    }
  }

  String _statusText() {
    final status = widget.callService.callStatus.value;
    switch (status) {
      case CallStatus.ringing:
        return 'Incoming call';
      case CallStatus.calling:
        return 'Calling...';
      case CallStatus.connecting:
        return 'Connecting...';
      case CallStatus.connected:
        return 'Connected';
      case CallStatus.ended:
        return 'Call ended';
      case CallStatus.declined:
        return 'Call declined';
      case CallStatus.missed:
        return 'Missed call';
      case CallStatus.failed:
        return 'Call failed';
    }
  }

  IconData _statusIcon() {
    final status = widget.callService.callStatus.value;
    switch (status) {
      case CallStatus.calling:
        return Icons.phone_in_talk;
      case CallStatus.connecting:
        return Icons.sync;
      case CallStatus.connected:
        return Icons.call;
      case CallStatus.declined:
        return Icons.call_end;
      case CallStatus.failed:
        return Icons.error_outline;
      case CallStatus.ended:
        return Icons.call_end;
      case CallStatus.ringing:
        return Icons.call;
      case CallStatus.missed:
        return Icons.phone_missed;
    }
  }

  bool get _shouldPulse {
    final status = widget.callService.callStatus.value;
    return status == CallStatus.calling ||
        status == CallStatus.ringing ||
        status == CallStatus.connecting;
  }

  @override
  Widget build(BuildContext context) {
    final status = widget.callService.callStatus.value;
    final isConnected = status == CallStatus.connected;

    final displayName = widget.callRecord.remoteName.trim().isEmpty
        ? widget.callRecord.remotePhoneNumber
        : widget.callRecord.remoteName;

    String initial = '?';
    if (displayName.trim().isNotEmpty) {
      initial = displayName.trim()[0].toUpperCase();
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Audio Call')),
      body: SafeArea(
        child: Stack(
          children: [
            Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 24,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // --------------------------------------------------
                    // Avatar with optional heartbeat rings
                    // --------------------------------------------------
                    SizedBox(
                      width: 220,
                      height: 220,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          if (_shouldPulse)
                            AnimatedBuilder(
                              animation: _pulseController,
                              builder: (context, _) {
                                return Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    _buildPulse(
                                      _pulseController.value,
                                    ),
                                    _buildPulse(
                                      (_pulseController.value + 0.33) % 1.0,
                                    ),
                                    _buildPulse(
                                      (_pulseController.value + 0.66) % 1.0,
                                    ),
                                  ],
                                );
                              },
                            ),
                          CircleAvatar(
                            radius: 58,
                            backgroundColor: WebsColors.softGreen(context),
                            child: Text(
                              initial,
                              style: const TextStyle(
                                fontSize: 42,
                                fontWeight: FontWeight.w600,
                                color: WebsColors.primaryGreen,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    Text(
                      displayName,
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w600,
                        color: WebsColors.textDark(context),
                      ),
                      textAlign: TextAlign.center,
                    ),

                    if (widget.callRecord.remotePhoneNumber.trim().isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        widget.callRecord.remotePhoneNumber,
                        style: TextStyle(
                          fontSize: 14,
                          color: WebsColors.textLight(context),
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],

                    const SizedBox(height: 28),

                    Icon(
                      _statusIcon(),
                      size: 28,
                      color: isConnected
                          ? WebsColors.primaryGreen
                          : WebsColors.textLight(context),
                    ),

                    const SizedBox(height: 12),

                    Text(
                      _statusText(),
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: WebsColors.textDark(context),
                      ),
                      textAlign: TextAlign.center,
                    ),

                    if (widget.callService.callError != null) ...[
                      const SizedBox(height: 12),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 30),
                        child: Text(
                          widget.callService.callError!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.redAccent),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 40),
                child: FloatingActionButton.large(
                  heroTag: 'end_audio_call',
                  backgroundColor: Colors.redAccent,
                  foregroundColor: Colors.white,
                  onPressed: _ending ? null : _endCall,
                  child: _ending
                      ? const SizedBox(
                          width: 28,
                          height: 28,
                          child: CircularProgressIndicator(
                            strokeWidth: 3,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.call_end, size: 32),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPulse(double t) {
    final scale = 0.75 + (t * 0.55);
    final opacity = (1 - t) * 0.4;

    return Transform.scale(
      scale: scale,
      child: Container(
        width: 130,
        height: 130,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: WebsColors.primaryGreen.withValues(alpha: opacity),
            width: 2.5,
          ),
        ),
      ),
    );
  }
}