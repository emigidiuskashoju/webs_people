import 'package:flutter/material.dart';

import '../../core/theme/webs_colors.dart';
import '../../shared/widgets/webs_background.dart';
import '../devices/services/device_command_service.dart';
import 'models/recovery_device.dart';

class CommandScreen extends StatefulWidget {
  final RecoveryDevice device;
  const CommandScreen({super.key, required this.device});

  @override
  State<CommandScreen> createState() => _CommandScreenState();
}

class _CommandScreenState extends State<CommandScreen> {
  final DeviceCommandService _service = DeviceCommandService();
  List<Map<String, dynamic>> _commands = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadCommands();
  }

  Future<void> _loadCommands() async {
    setState(() => _loading = true);
    try {
      final commands = await _service.getPendingCommands(
        deviceId: widget.device.id,
      );
      if (!mounted) return;
      setState(() {
        _commands = commands;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unable to load commands: $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      appBar: securityAppBar(title: 'Commands'),
      body: WebsBackground(child: _buildBody()),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: WebsColors.primaryGreen),
      );
    }

    if (_commands.isEmpty) {
      return RefreshIndicator(
        color: WebsColors.primaryGreen,
        onRefresh: _loadCommands,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            SizedBox(height: MediaQuery.of(context).size.height * 0.3),
            Icon(
              Icons.terminal,
              size: 80,
              color: WebsColors.softGreen(context),
            ),
            const SizedBox(height: 16),
            Center(
              child: Text(
                'No pending commands.',
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
      onRefresh: _loadCommands,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 100, 16, 16),
        itemCount: _commands.length,
        itemBuilder: (context, i) => _buildCommandCard(_commands[i]),
      ),
    );
  }

  Widget _buildCommandCard(Map<String, dynamic> command) {
    final commandName = command['command']?.toString() ?? 'Unknown';
    final status = command['status']?.toString() ?? 'unknown';
    final commandId = command['id']?.toString() ?? '';

    Color statusColor;
    Color statusBgColor;
    IconData statusIcon;

    switch (status.toLowerCase()) {
      case 'completed':
      case 'sent':
      case 'executed':
        statusColor = WebsColors.primaryGreen;
        statusBgColor = WebsColors.softGreen(context);
        statusIcon = Icons.check_circle;
        break;
      case 'failed':
      case 'error':
        statusColor = Colors.redAccent;
        statusBgColor = const Color(0xFFFFEBEE);
        statusIcon = Icons.error;
        break;
      default:
        statusColor = Colors.orange.shade800;
        statusBgColor = const Color(0xFFFFF3E0);
        statusIcon = Icons.hourglass_top;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
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
        border: Border.all(color: WebsColors.border(context), width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: statusBgColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.terminal, color: statusColor, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  commandName,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: WebsColors.textDark(context),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: WebsColors.softGreen(context),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '#$commandId',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: WebsColors.textLight(context),
                  ),
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
              color: statusBgColor,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(statusIcon, size: 14, color: statusColor),
                const SizedBox(width: 6),
                Text(
                  status.toUpperCase(),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: statusColor,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}