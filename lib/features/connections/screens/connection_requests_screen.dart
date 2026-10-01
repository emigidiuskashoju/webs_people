import 'package:flutter/material.dart';

import '/core/theme/webs_colors.dart';
import '/core/widgets/webs_background.dart';
import '../models/connection_request.dart';
import '../services/connection_api_service.dart';

class ConnectionRequestsScreen extends StatefulWidget {
  const ConnectionRequestsScreen({super.key});

  @override
  State<ConnectionRequestsScreen> createState() =>
      _ConnectionRequestsScreenState();
}

class _ConnectionRequestsScreenState extends State<ConnectionRequestsScreen> {
  final ConnectionApiService _service = ConnectionApiService();
  List<ConnectionRequest> _requests = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadRequests();
  }

  Future<void> _loadRequests() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final requests = await _service.getPendingRequests();
      if (!mounted) return;
      setState(() {
        _requests = requests;
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

  Future<void> _accept(ConnectionRequest request) async {
    try {
      await _service.acceptRequest(request.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Connection request accepted.')),
      );
      await _loadRequests();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    }
  }

  Future<void> _reject(ConnectionRequest request) async {
    try {
      await _service.rejectRequest(request.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Connection request rejected.')),
      );
      await _loadRequests();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      appBar: AppBar(title: const Text('Connection Requests')),
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
                onPressed: _loadRequests,
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

    if (_requests.isEmpty) {
      return RefreshIndicator(
        color: WebsColors.primaryGreen,
        onRefresh: _loadRequests,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            SizedBox(height: MediaQuery.of(context).size.height * 0.3),
            Icon(
              Icons.person_add_outlined,
              size: 80,
              color: WebsColors.softGreen(context),
            ),
            const SizedBox(height: 16),
            Center(
              child: Text(
                'No connection requests.',
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
      onRefresh: _loadRequests,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 100, 16, 24),
        itemCount: _requests.length,
        itemBuilder: (context, index) {
          final request = _requests[index];
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
              border: Border.all(
                color: WebsColors.border(context),
                width: 2,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Connection request',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: WebsColors.textDark(context),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'User ID: ${request.senderId}',
                  style: TextStyle(color: WebsColors.textLight(context)),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => _reject(request),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: WebsColors.primaryGreen),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'Reject',
                          style: TextStyle(color: WebsColors.primaryGreen),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        onPressed: () => _accept(request),
                        style: FilledButton.styleFrom(
                          backgroundColor: WebsColors.primaryGreen,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text('Accept'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}