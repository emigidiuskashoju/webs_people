import 'package:flutter/material.dart';

import 'models/call_record.dart';
import 'services/call_history_service.dart';

class CallHistoryScreen extends StatefulWidget {
  const CallHistoryScreen({
    super.key,
  });

  @override
  State<CallHistoryScreen> createState() =>
      _CallHistoryScreenState();
}

class _CallHistoryScreenState
    extends State<CallHistoryScreen> {
  final CallHistoryService _service =
      CallHistoryService();

  List<CallRecord> _calls = [];

  bool _isLoading = true;

  String? _error;

  @override
  void initState() {
    super.initState();

    _loadCalls();
  }

  Future<void> _loadCalls() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final calls =
          await _service.getHistory();

      if (!mounted) {
        return;
      }

      setState(() {
        _calls = calls;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isLoading = false;
        _error =
            'Unable to load call history.';
      });
    }
  }

  Future<void> _refresh() async {
    await _loadCalls();
  }

  @override
  Widget build(
    BuildContext context,
  ) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Calls'),
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_error != null) {
      return ListView(
        children: [
          SizedBox(
            height: 500,
            child: Center(
              child: Column(
                mainAxisSize:
                    MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.error_outline,
                    size: 48,
                  ),
                  const SizedBox(
                    height: 12,
                  ),
                  Text(_error!),
                  const SizedBox(
                    height: 12,
                  ),
                  FilledButton(
                    onPressed:
                        _loadCalls,
                    child:
                        const Text('Retry'),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    }

    if (_calls.isEmpty) {
      return ListView(
        children: const [
          SizedBox(
            height: 500,
            child: Center(
              child: Column(
                mainAxisSize:
                    MainAxisSize.min,
                children: [
                  Icon(
                    Icons.call_outlined,
                    size: 64,
                  ),
                  SizedBox(
                    height: 16,
                  ),
                  Text(
                    'No calls yet',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight:
                          FontWeight.w600,
                    ),
                  ),
                  SizedBox(
                    height: 8,
                  ),
                  Text(
                    'Your call history will appear here.',
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    }

    return ListView.separated(
      physics:
          const AlwaysScrollableScrollPhysics(),
      padding:
          const EdgeInsets.only(
        top: 8,
        bottom: 24,
      ),
      itemCount: _calls.length,
      separatorBuilder:
          (_, __) =>
              const Divider(
        height: 1,
      ),
      itemBuilder:
          (context, index) {
        final call =
            _calls[index];

        return _CallHistoryTile(
          call: call,
        );
      },
    );
  }
}

class _CallHistoryTile
    extends StatelessWidget {
  final CallRecord call;

  const _CallHistoryTile({
    required this.call,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    final isIncoming =
        call.direction ==
            CallDirection.incoming;

    final isMissed =
        call.status ==
            CallStatus.missed;

    final icon =
        call.type == CallType.audio
            ? Icons.call
            : Icons.videocam;

    final directionIcon =
        isIncoming
            ? Icons.call_received
            : Icons.call_made;

    return ListTile(
      leading: CircleAvatar(
        child: Icon(icon),
      ),
      title: Text(
        call.remoteName.isEmpty
            ? call.remotePhoneNumber
            : call.remoteName,
      ),
      subtitle: Row(
        children: [
          Icon(
            directionIcon,
            size: 16,
            color: isMissed
                ? Colors.red
                : null,
          ),
          const SizedBox(
            width: 4,
          ),
          Text(
            _statusText(call),
          ),
        ],
      ),
      trailing: Text(
        _formatDate(call.startedAt),
        style: Theme.of(context)
            .textTheme
            .bodySmall,
      ),
    );
  }

  String _statusText(
    CallRecord call,
  ) {
    switch (call.status) {
      case CallStatus.ringing:
        return 'Incoming call';

      case CallStatus.calling:
        return 'Outgoing call';

      case CallStatus.connecting:
        return 'Connecting';

      case CallStatus.connected:
        return _formatDuration(
          call.durationSeconds,
        );

      case CallStatus.ended:
        return _formatDuration(
          call.durationSeconds,
        );

      case CallStatus.declined:
        return 'Declined';

      case CallStatus.missed:
        return 'Missed call';

      case CallStatus.failed:
        return 'Failed';
    }
  }

  String _formatDuration(
    int seconds,
  ) {
    final minutes =
        seconds ~/ 60;

    final remainingSeconds =
        seconds % 60;

    return '$minutes:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  String _formatDate(
    DateTime dateTime,
  ) {
    final local =
        dateTime.toLocal();

    final hour =
        local.hour
            .toString()
            .padLeft(2, '0');

    final minute =
        local.minute
            .toString()
            .padLeft(2, '0');

    return '$hour:$minute';
  }
}