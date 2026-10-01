import 'package:flutter/material.dart';
import 'package:flutter_ringtone_player/flutter_ringtone_player.dart';

import '../../core/notifications/notification_service.dart';
import '../../core/theme/webs_colors.dart';
import 'audio_call_screen.dart';
import 'models/call_record.dart';
import 'services/call_service.dart';
import 'services/call_signaling_service.dart';

class IncomingCallScreen extends StatefulWidget {
  final String callId;
  final int callerId;
  final String callerName;
  final String callerPhone;
  final String type;
  final CallRecord record;

  const IncomingCallScreen({
    super.key,
    required this.callId,
    required this.callerId,
    required this.callerName,
    required this.callerPhone,
    required this.type,
    required this.record,
  });

  @override
  State<IncomingCallScreen> createState() =>
      _IncomingCallScreenState();
}

class _IncomingCallScreenState extends State<IncomingCallScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;
  final CallService _callService = CallService();
  final CallSignalingService _signaling = CallSignalingService();

  bool _handling = false;

  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    FlutterRingtonePlayer().stop();
    super.dispose();
  }

  Future<void> _accept() async {
    if (_handling) return;
    setState(() => _handling = true);

    FlutterRingtonePlayer().stop();

    try {
      await _signaling.sendEvent(
        callId: widget.callId,
        recipientId: widget.callerId,
        event: 'accept',
      );

      final events = await _signaling.getCallEvents(
        widget.callId,
      );

      final offerEvent = events.firstWhere(
        (e) => e.event == 'offer',
        orElse: () =>
            throw Exception('Offer not received.'),
      );

      final sdp =
          offerEvent.payload['sdp']?.toString() ?? '';
      final type =
          offerEvent.payload['type']?.toString() ?? 'offer';

      await _callService.webRtc.initialize();
      await _callService.webRtc.setRemoteOffer(
        sdp: sdp,
        type: type,
      );

      final answer =
          await _callService.webRtc.createAnswer();

      await _signaling.sendEvent(
        callId: widget.callId,
        recipientId: widget.callerId,
        event: 'answer',
        payload: {
          'sdp': answer.sdp ?? '',
          'type': answer.type ?? 'answer',
        },
      );

      await _callService.webRtc.flushPendingCandidates();

      // Stop the vibration and remove the notification.
      try {
        await NotificationService.instance
            .dismissIncomingCallNotification(widget.callId);
      } catch (_) {}

      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => AudioCallScreen(
            callService: _callService,
            callRecord: widget.record,
          ),
        ),
      );
    } catch (e) {
      debugPrint('INCOMING-CALL: accept failed: $e');
      if (!mounted) return;
      setState(() => _handling = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to accept call: $e')),
      );
    }
  }

  Future<void> _decline() async {
    if (_handling) return;
    setState(() => _handling = true);

    FlutterRingtonePlayer().stop();

    // Stop the vibration and remove the notification.
    try {
      await NotificationService.instance
          .dismissIncomingCallNotification(widget.callId);
    } catch (_) {}

    try {
      await _signaling.sendEvent(
        callId: widget.callId,
        recipientId: widget.callerId,
        event: 'decline',
      );
    } catch (_) {}

    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final displayName = widget.callerName.trim().isEmpty
        ? widget.callerPhone
        : widget.callerName;

    String initial = '?';
    if (displayName.trim().isNotEmpty) {
      initial = displayName.trim()[0].toUpperCase();
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0F1A10),
      body: SafeArea(
        child: Stack(
          children: [
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 240,
                    height: 240,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
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
                                  (_pulseController.value +
                                          0.33) %
                                      1.0,
                                ),
                                _buildPulse(
                                  (_pulseController.value +
                                          0.66) %
                                      1.0,
                                ),
                              ],
                            );
                          },
                        ),
                        CircleAvatar(
                          radius: 58,
                          backgroundColor:
                              WebsColors.softGreen(context),
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
                    style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Incoming ${widget.type} call',
                    style: TextStyle(
                      fontSize: 15,
                      color: Colors.white.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
            ),
            Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 60),
                child: Row(
                  mainAxisAlignment:
                      MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildButton(
                      icon: Icons.call_end,
                      color: Colors.redAccent,
                      label: 'Decline',
                      onTap: _handling ? null : _decline,
                    ),
                    _buildButton(
                      icon: Icons.call,
                      color: WebsColors.primaryGreen,
                      label: 'Accept',
                      onTap: _handling ? null : _accept,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPulse(double t) {
    final scale = 0.7 + (t * 0.6);
    final opacity = (1 - t) * 0.35;

    return Transform.scale(
      scale: scale,
      child: Container(
        width: 140,
        height: 140,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: WebsColors.primaryGreen
                .withValues(alpha: opacity),
            width: 2,
          ),
        ),
      ),
    );
  }

  Widget _buildButton({
    required IconData icon,
    required Color color,
    required String label,
    required VoidCallback? onTap,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Material(
          color: color,
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: SizedBox(
              width: 68,
              height: 68,
              child: Icon(
                icon,
                size: 30,
                color: Colors.white,
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
          ),
        ),
      ],
    );
  }
}