import 'package:flutter/material.dart';

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
  State<AudioCallScreen> createState() =>
      _AudioCallScreenState();
}

class _AudioCallScreenState
    extends State<AudioCallScreen> {
  bool _ending = false;

  @override
  void initState() {
    super.initState();

    widget.callService.callStatus.addListener(
      _onCallStatusChanged,
    );
  }

  @override
  void dispose() {
    widget.callService.callStatus.removeListener(
      _onCallStatusChanged,
    );

    super.dispose();
  }

  void _onCallStatusChanged() {
    if (!mounted) {
      return;
    }

    setState(() {});

    final status =
        widget.callService.callStatus.value;

    if (status == CallStatus.ended ||
        status == CallStatus.declined ||
        status == CallStatus.failed) {
      Future<void>.delayed(
        const Duration(milliseconds: 300),
        () {
          if (!mounted) {
            return;
          }

          Navigator.of(context).pop();
        },
      );
    }
  }

  Future<void> _endCall() async {
    if (_ending) {
      return;
    }

    setState(() {
      _ending = true;
    });

    try {
      await widget.callService.endCall();

      if (!mounted) {
        return;
      }

      Navigator.of(context).pop();
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _ending = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Unable to end the call cleanly.',
          ),
        ),
      );
    }
  }

  String _statusText() {
    final status =
        widget.callService.callStatus.value;

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
    final status =
        widget.callService.callStatus.value;

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

  @override
  Widget build(
    BuildContext context,
  ) {
    final colorScheme =
        Theme.of(context).colorScheme;

    final status =
        widget.callService.callStatus.value;

    final isConnected =
        status == CallStatus.connected;

    final displayName =
        widget.callRecord.remoteName.trim().isEmpty
            ? widget.callRecord.remotePhoneNumber
            : widget.callRecord.remoteName;

    String initial = '?';

    if (displayName.trim().isNotEmpty) {
      initial =
          displayName.trim()[0].toUpperCase();
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Audio Call',
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            const Spacer(),

            CircleAvatar(
              radius: 58,
              child: Text(
                initial,
                style: const TextStyle(
                  fontSize: 42,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),

            const SizedBox(
              height: 24,
            ),

            Text(
              displayName,
              style: Theme.of(context)
                  .textTheme
                  .headlineSmall
                  ?.copyWith(
                    fontWeight:
                        FontWeight.w600,
                  ),
              textAlign:
                  TextAlign.center,
            ),

            if (widget.callRecord.remotePhoneNumber
                .trim()
                .isNotEmpty) ...[
              const SizedBox(
                height: 8,
              ),
              Text(
                widget.callRecord.remotePhoneNumber,
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium,
              ),
            ],

            const SizedBox(
              height: 28,
            ),

            Icon(
              _statusIcon(),
              size: 28,
              color: isConnected
                  ? colorScheme.primary
                  : colorScheme.onSurfaceVariant,
            ),

            const SizedBox(
              height: 12,
            ),

            Text(
              _statusText(),
              style: Theme.of(context)
                  .textTheme
                  .titleMedium,
            ),

            if (widget.callService.callError !=
                null) ...[
              const SizedBox(
                height: 12,
              ),
              Padding(
                padding:
                    const EdgeInsets.symmetric(
                  horizontal: 30,
                ),
                child: Text(
                  widget.callService.callError!,
                  textAlign:
                      TextAlign.center,
                  style: TextStyle(
                    color:
                        colorScheme.error,
                  ),
                ),
              ),
            ],

            const Spacer(),

            Padding(
              padding:
                  const EdgeInsets.only(
                bottom: 40,
              ),
              child: FloatingActionButton.large(
                heroTag:
                    'end_audio_call',
                backgroundColor:
                    colorScheme.error,
                foregroundColor:
                    colorScheme.onError,
                onPressed:
                    _ending
                        ? null
                        : _endCall,
                child: _ending
                    ? const SizedBox(
                        width: 28,
                        height: 28,
                        child:
                            CircularProgressIndicator(
                          strokeWidth: 3,
                        ),
                      )
                    : const Icon(
                        Icons.call_end,
                        size: 32,
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}