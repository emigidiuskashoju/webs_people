import 'package:flutter/material.dart';

import '../models/connection_request.dart';
import '../services/connection_api_service.dart';

class ConnectionsScreen
    extends StatefulWidget {
  const ConnectionsScreen({
    super.key,
  });

  @override
  State<ConnectionsScreen> createState() =>
      _ConnectionsScreenState();
}

class _ConnectionsScreenState
    extends State<ConnectionsScreen> {
  final ConnectionApiService _service =
      ConnectionApiService();

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
      final connections =
          await _service.getConnections();

      if (!mounted) {
        return;
      }

      setState(() {
        _connections = connections;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'My Connections',
        ),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.error_outline,
                size: 50,
              ),
              const SizedBox(height: 12),
              Text(
                _error!,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _loadConnections,
                child: const Text(
                  'Try Again',
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_connections.isEmpty) {
      return RefreshIndicator(
        onRefresh: _loadConnections,
        child: ListView(
          children: const [
            SizedBox(height: 180),
            Center(
              child: Text(
                'You have no connections yet.',
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadConnections,
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: _connections.length,
        itemBuilder: (context, index) {
          final connection =
              _connections[index];

          return Card(
            child: ListTile(
              leading: const CircleAvatar(
                child: Icon(
                  Icons.person,
                ),
              ),
              title: Text(
                'Connection',
              ),
              subtitle: Text(
                'User ${connection.senderId} ↔ '
                'User ${connection.receiverId}',
              ),
              trailing: const Icon(
                Icons.check_circle_outline,
              ),
            ),
          );
        },
      ),
    );
  }
}