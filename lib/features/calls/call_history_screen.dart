import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/theme/webs_colors.dart';
import '../../core/widgets/webs_background.dart';
import 'models/call_record.dart';
import 'services/call_history_service.dart';

class CallHistoryScreen extends StatefulWidget {
  const CallHistoryScreen({super.key});

  @override
  State<CallHistoryScreen> createState() => _CallHistoryScreenState();
}

class _CallHistoryScreenState extends State<CallHistoryScreen> {
  final CallHistoryService _service = CallHistoryService();

  List<CallRecord> _calls = [];
  bool _isLoading = true;
  String? _error;

  Timer? _autoRefreshTimer;
  bool _firstLoadDone = false;

  @override
  void initState() {
    super.initState();
    _loadCalls();
    _autoRefreshTimer = Timer.periodic(
      const Duration(seconds: 10),
      (_) => _loadCalls(silent: true),
    );
  }

  @override
  void dispose() {
    _autoRefreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadCalls({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _isLoading = true;
        _error = null;
      });
    }
    try {
      final calls = await _service.getHistory();
      if (!mounted) return;
      setState(() {
        _calls = calls;
        _isLoading = false;
        _firstLoadDone = true;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        if (!silent || !_firstLoadDone) {
          _error = 'Unable to load call history.';
        }
      });
    }
  }

  Future<void> _refresh() async => await _loadCalls();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('Calls'),
      ),
      body: WebsBackground(
        child: SafeArea(
          child: RefreshIndicator(
            color: WebsColors.primaryGreen,
            onRefresh: _refresh,
            child: _buildBody(),
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading && !_firstLoadDone) {
      return const Center(
        child: CircularProgressIndicator(color: WebsColors.primaryGreen),
      );
    }

    if (_error != null && _calls.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(height: MediaQuery.of(context).size.height * 0.3),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 40),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: WebsColors.surface(context),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: WebsColors.border(context),
                width: 2,
              ),
            ),
            child: Column(
              children: [
                const Icon(
                  Icons.error_outline,
                  size: 56,
                  color: Colors.redAccent,
                ),
                const SizedBox(height: 12),
                Text(
                  _error!,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: WebsColors.textLight(context),
                  ),
                ),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: _loadCalls,
                  style: FilledButton.styleFrom(
                    backgroundColor: WebsColors.primaryGreen,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 32,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ],
      );
    }

    if (_calls.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(height: MediaQuery.of(context).size.height * 0.3),
          Icon(
            Icons.call_outlined,
            size: 80,
            color: WebsColors.softGreen(context),
          ),
          const SizedBox(height: 16),
          Center(
            child: Text(
              'No calls yet',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: WebsColors.textDark(context),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: Text(
              'Your call history will appear here.',
              style: TextStyle(
                color: WebsColors.textLight(context),
              ),
            ),
          ),
        ],
      );
    }

    final topPadding =
        kToolbarHeight + MediaQuery.of(context).padding.top + 8;

    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.fromLTRB(16, topPadding, 16, 24),
      itemCount: _calls.length,
      itemBuilder: (context, index) {
        return _CallHistoryTile(call: _calls[index]);
      },
    );
  }
}

class _CallHistoryTile extends StatelessWidget {
  final CallRecord call;

  const _CallHistoryTile({required this.call});

  @override
  Widget build(BuildContext context) {
    final isIncoming = call.direction == CallDirection.incoming;
    final isMissed = call.status == CallStatus.missed;
    final icon =
        call.type == CallType.audio ? Icons.call : Icons.videocam;
    final directionIcon =
        isIncoming ? Icons.call_received : Icons.call_made;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
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
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 6,
        ),
        leading: CircleAvatar(
          backgroundColor: WebsColors.softGreen(context),
          child: Icon(icon, color: WebsColors.primaryGreen),
        ),
        title: Text(
          call.remoteName.isEmpty
              ? call.remotePhoneNumber
              : call.remoteName,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: WebsColors.textDark(context),
          ),
        ),
        subtitle: Row(
          children: [
            Icon(
              directionIcon,
              size: 16,
              color:
                  isMissed ? Colors.redAccent : WebsColors.primaryGreen,
            ),
            const SizedBox(width: 4),
            Text(
              _statusText(call),
              style: TextStyle(
                color: WebsColors.textLight(context),
              ),
            ),
          ],
        ),
        trailing: Text(
          _formatDate(call.startedAt),
          style: TextStyle(
            fontSize: 12,
            color: WebsColors.textLight(context),
          ),
        ),
      ),
    );
  }

  String _statusText(CallRecord call) {
    switch (call.status) {
      case CallStatus.ringing:
        return 'Incoming call';
      case CallStatus.calling:
        return 'Outgoing call';
      case CallStatus.connecting:
        return 'Connecting';
      case CallStatus.connected:
        return _formatDuration(call.durationSeconds);
      case CallStatus.ended:
        return _formatDuration(call.durationSeconds);
      case CallStatus.declined:
        return 'Declined';
      case CallStatus.missed:
        return 'Missed call';
      case CallStatus.failed:
        return 'Failed';
    }
  }

  String _formatDuration(int seconds) {
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    return '$minutes:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  String _formatDate(DateTime dateTime) {
    final local = dateTime.toLocal();
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
}