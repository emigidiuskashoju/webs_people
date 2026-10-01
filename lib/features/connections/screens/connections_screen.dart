import 'package:flutter/material.dart';

import '/core/theme/webs_colors.dart';
import '/core/widgets/webs_background.dart';
import '../models/connection_request.dart';
import '../services/connection_api_service.dart';

class ConnectionsScreen extends StatefulWidget {
  const ConnectionsScreen({super.key});

  @override
  State<ConnectionsScreen> createState() => _ConnectionsScreenState();
}

class _ConnectionsScreenState extends State<ConnectionsScreen> {
  final ConnectionApiService _service = ConnectionApiService();
  List<ConnectionRequest> _connections = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadConnections();
  }

  Future<void> _loadConnections() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final connections = await _service.getConnections();
      if (!mounted) return;
      setState(() {
        _connections = connections;
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
      appBar: AppBar(title: const Text('My Connections')),
      body: WebsBackground(child: SafeArea(child: _buildBody())),
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
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: WebsColors.softGreen(context),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.error_outline,
                  size: 56,
                  color: WebsColors.primaryGreen,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: TextStyle(color: WebsColors.textLight(context)),
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: _loadConnections,
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
                child: const Text('Try Again'),
              ),
            ],
          ),
        ),
      );
    }

    if (_connections.isEmpty) {
      return RefreshIndicator(
        color: WebsColors.primaryGreen,
        onRefresh: _loadConnections,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            SizedBox(height: MediaQuery.of(context).size.height * 0.3),
            Icon(
              Icons.people_outline,
              size: 80,
              color: WebsColors.softGreen(context),
            ),
            const SizedBox(height: 16),
            Center(
              child: Text(
                'You have no connections yet.',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
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
      onRefresh: _loadConnections,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 100, 16, 24),
        itemCount: _connections.length,
        itemBuilder: (context, index) {
          final connection = _connections[index];
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
                child: const Icon(
                  Icons.person,
                  color: WebsColors.primaryGreen,
                ),
              ),
              title: Text(
                'Connection',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: WebsColors.textDark(context),
                ),
              ),
              subtitle: Text(
                'User ${connection.senderId} ↔ User ${connection.receiverId}',
                style: TextStyle(color: WebsColors.textLight(context)),
              ),
              trailing: const Icon(
                Icons.check_circle_outline,
                color: WebsColors.primaryGreen,
              ),
            ),
          );
        },
      ),
    );
  }
}