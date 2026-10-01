import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/notifications/active_conversation.dart';
import '../../core/theme/webs_colors.dart';
import '../calls/audio_call_screen.dart';
import '../calls/services/call_service.dart';
import '../map/map_screen.dart';
import '../map/models/location_request.dart';
import '../map/services/location_request_service.dart';
import 'data/chat_repository.dart';
import 'models/chat_message.dart';

class ChatScreen extends StatefulWidget {
  final int currentUserId;
  final int userId;
  final String name;
  final String phoneNumber;
  final String? profilePhotoUrl;

  const ChatScreen({
    super.key,
    required this.currentUserId,
    required this.userId,
    required this.name,
    required this.phoneNumber,
    this.profilePhotoUrl,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ChatRepository _repository = ChatRepository();
  final CallService _callService = CallService();
  final LocationRequestService _locationRequestService =
      LocationRequestService();

  List<ChatMessage> _messages = [];
  List<LocationRequest> _locationRequests = [];
  Timer? _locationRequestTimer;

  bool _isLoading = true;
  bool _isSending = false;
  bool _isStartingCall = false;
  bool _isHandlingLocationRequest = false;

  String get _conversationId {
    return _repository.createConversationId(
      widget.currentUserId,
      widget.userId,
    );
  }

  @override
  void initState() {
    super.initState();
    ActiveConversation.instance.enter(_conversationId);
    _loadMessages();
    _loadLocationRequests();
    _locationRequestTimer = Timer.periodic(
      const Duration(seconds: 5),
      (_) => _loadLocationRequests(silent: true),
    );
  }

  @override
  void dispose() {
    ActiveConversation.instance.leave(_conversationId);
    _locationRequestTimer?.cancel();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // ===================================================================
  // Messages
  // ===================================================================

  Future<void> _loadMessages() async {
    try {
      final messages = await _repository.getConversation(
        _conversationId,
        currentUserId: widget.currentUserId,
      );
      if (!mounted) return;
      setState(() {
        _messages = messages;
        _isLoading = false;
      });
      _scrollToBottom();
      await _receiveMessages();
      await _markMessagesAsRead();
      await _syncReadReceipts();
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  Future<void> _receiveMessages() async {
    try {
      await _repository.receivePendingMessages(
        currentUserId: widget.currentUserId,
      );
      final messages = await _repository.getConversation(
        _conversationId,
        currentUserId: widget.currentUserId,
      );
      if (!mounted) return;
      setState(() => _messages = messages);
      _scrollToBottom();
      await _markMessagesAsRead();
      await _syncReadReceipts();
    } catch (_) {}
  }

  Future<void> _markMessagesAsRead() async {
    try {
      await _repository.markConversationAsRead(
        conversationId: _conversationId,
        currentUserId: widget.currentUserId,
      );
      final messages = await _repository.getConversation(
        _conversationId,
        currentUserId: widget.currentUserId,
      );
      if (!mounted) return;
      setState(() => _messages = messages);
    } catch (_) {}
  }

  Future<void> _syncReadReceipts() async {
    try {
      final updatedCount = await _repository.syncReadReceipts();
      if (updatedCount == 0 || !mounted) return;
      final messages = await _repository.getConversation(
        _conversationId,
        currentUserId: widget.currentUserId,
      );
      if (!mounted) return;
      setState(() => _messages = messages);
    } catch (_) {}
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _isSending) return;
    setState(() => _isSending = true);
    try {
      await _repository.createAndSendMessage(
        senderId: widget.currentUserId,
        recipientId: widget.userId,
        conversationId: _conversationId,
        text: text,
      );
      _messageController.clear();
      final messages = await _repository.getConversation(
        _conversationId,
        currentUserId: widget.currentUserId,
      );
      if (!mounted) return;
      setState(() => _messages = messages);
      _scrollToBottom();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Message could not be sent. It will remain available locally.',
          ),
        ),
      );
      final messages = await _repository.getConversation(
        _conversationId,
        currentUserId: widget.currentUserId,
      );
      if (!mounted) return;
      setState(() => _messages = messages);
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  Future<void> _retryMessage(ChatMessage message) async {
    try {
      await _repository.retryFailedMessage(message);
      final messages = await _repository.getConversation(
        _conversationId,
        currentUserId: widget.currentUserId,
      );
      if (!mounted) return;
      setState(() => _messages = messages);
      _scrollToBottom();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Message could not be retried.')),
      );
    }
  }

  // ===================================================================
  // Long-press actions: Copy / Delete
  // ===================================================================

  Future<void> _showMessageActions(ChatMessage message) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: WebsColors.surface(context),
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                child: Text(
                  message.text,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    color: WebsColors.textLight(sheetContext),
                  ),
                ),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(
                  Icons.copy_outlined,
                  color: WebsColors.primaryGreen,
                ),
                title: Text(
                  'Copy',
                  style: TextStyle(
                    color: WebsColors.textDark(sheetContext),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                onTap: () async {
                  Navigator.of(sheetContext).pop();
                  await _copyMessage(message);
                },
              ),
              ListTile(
                leading: const Icon(
                  Icons.delete_outline,
                  color: Colors.redAccent,
                ),
                title: const Text(
                  'Delete',
                  style: TextStyle(
                    color: Colors.redAccent,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                onTap: () async {
                  Navigator.of(sheetContext).pop();
                  await _deleteMessage(message);
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  Future<void> _copyMessage(ChatMessage message) async {
    await Clipboard.setData(ClipboardData(text: message.text));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Message copied.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _deleteMessage(ChatMessage message) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Delete message?'),
          content: const Text(
            'This will remove the message from this device.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              style: FilledButton.styleFrom(
                backgroundColor: Colors.redAccent,
              ),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirm != true) return;

    try {
      await _repository.deleteMessage(message);
      if (!mounted) return;

      setState(() {
        _messages = _messages
            .where((m) => m.localId != message.localId)
            .toList();
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Message deleted.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not delete: $e'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  // ===================================================================
  // Location requests
  // ===================================================================

  Future<void> _loadLocationRequests({bool silent = false}) async {
    try {
      final requests = await _locationRequestService.getConversationRequests(
        widget.userId,
      );
      if (!mounted) return;
      setState(() => _locationRequests = requests);
    } catch (_) {
      if (silent) return;
    }
  }

  Future<void> _acceptLocationRequest(LocationRequest request) async {
    if (_isHandlingLocationRequest) return;
    setState(() => _isHandlingLocationRequest = true);
    try {
      final updated = await _locationRequestService.acceptRequest(request.id);
      if (!mounted) return;
      setState(() {
        _locationRequests = _locationRequests
            .map((item) => item.id == updated.id ? updated : item)
            .toList();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Location sharing accepted.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_cleanError(e))),
      );
    } finally {
      if (mounted) setState(() => _isHandlingLocationRequest = false);
    }
  }

  Future<void> _denyLocationRequest(LocationRequest request) async {
    if (_isHandlingLocationRequest) return;
    setState(() => _isHandlingLocationRequest = true);
    try {
      final updated = await _locationRequestService.denyRequest(request.id);
      if (!mounted) return;
      setState(() {
        _locationRequests = _locationRequests
            .map((item) => item.id == updated.id ? updated : item)
            .toList();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Location request denied.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_cleanError(e))),
      );
    } finally {
      if (mounted) setState(() => _isHandlingLocationRequest = false);
    }
  }

  String _cleanError(Object error) {
    return error.toString().replaceFirst('Exception: ', '');
  }

  // ===================================================================
  // Audio call
  // ===================================================================

  Future<void> _startAudioCall() async {
    if (_isStartingCall) return;
    setState(() => _isStartingCall = true);
    try {
      final record = await _callService.startAudioCall(
        ownerUserId: widget.currentUserId,
        recipientId: widget.userId,
        recipientName: widget.name,
        recipientPhoneNumber: widget.phoneNumber,
      );
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => AudioCallScreen(
            callService: _callService,
            callRecord: record,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to start audio call: $e')),
      );
    } finally {
      if (mounted) setState(() => _isStartingCall = false);
    }
  }

  // ===================================================================
  // Helpers
  // ===================================================================

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  String _formatTime(DateTime dateTime) {
    final hour = dateTime.hour.toString().padLeft(2, '0');
    final minute = dateTime.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  // ===================================================================
  // Location request widgets
  // ===================================================================

  Widget _buildLocationRequestCard(LocationRequest request) {
    final isIncoming = request.ownerId == widget.currentUserId;
    final isOutgoing = request.requesterId == widget.currentUserId;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: WebsColors.border(context), width: 2),
        color: WebsColors.surface(context),
        boxShadow: [
          BoxShadow(
            color: WebsColors.shadow(context),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.location_on, color: WebsColors.primaryGreen),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Location Request',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: WebsColors.textDark(context),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            isIncoming
                ? '${widget.name} is requesting your current location.'
                : isOutgoing
                    ? 'You requested ${widget.name}\'s current location.'
                    : 'Location request',
            style: TextStyle(color: WebsColors.textDark(context)),
          ),
          const SizedBox(height: 10),
          _buildLocationRequestStatus(request, isIncoming),
        ],
      ),
    );
  }

  Widget _buildLocationRequestStatus(
    LocationRequest request,
    bool isIncoming,
  ) {
    switch (request.status) {
      case LocationRequestStatus.pending:
        if (isIncoming) {
          return Row(
            children: [
              Expanded(
                child: FilledButton(
                  onPressed: _isHandlingLocationRequest
                      ? null
                      : () => _acceptLocationRequest(request),
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
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton(
                  onPressed: _isHandlingLocationRequest
                      ? null
                      : () => _denyLocationRequest(request),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: WebsColors.primaryGreen),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Deny',
                    style: TextStyle(color: WebsColors.primaryGreen),
                  ),
                ),
              ),
            ],
          );
        }
        return Text(
          'Waiting for them to accept the request...',
          style: TextStyle(color: WebsColors.textLight(context)),
        );

      case LocationRequestStatus.accepted:
        return Row(
          children: [
            const Icon(
              Icons.check_circle,
              size: 20,
              color: WebsColors.primaryGreen,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Location sharing is active.',
                style: TextStyle(color: WebsColors.textDark(context)),
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => MapScreen(
                      currentUserId: widget.currentUserId,
                      userId: widget.userId,
                      name: widget.name,
                    ),
                  ),
                );
              },
              style: TextButton.styleFrom(
                foregroundColor: WebsColors.primaryGreen,
              ),
              child: const Text(
                'Open Map',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        );

      case LocationRequestStatus.denied:
        return Text(
          'This location request was denied.',
          style: TextStyle(color: WebsColors.textLight(context)),
        );

      case LocationRequestStatus.expired:
        return Text(
          'This location request has expired.',
          style: TextStyle(color: WebsColors.textLight(context)),
        );
    }
  }

  // ===================================================================
  // Message widgets
  // ===================================================================

  Widget _buildStatusIcon(
    MessageStatus status, {
    required Color color,
  }) {
    switch (status) {
      case MessageStatus.pending:
        return Icon(Icons.schedule, size: 13, color: color);

      case MessageStatus.sent:
        return Icon(Icons.check, size: 13, color: color);

      case MessageStatus.delivered:
        return Icon(Icons.done_all, size: 13, color: color);

      case MessageStatus.read:
        return const Icon(
          Icons.done_all,
          size: 13,
          color: Color(0xFF25D366),
        );

      case MessageStatus.failed:
        return const Icon(
          Icons.error_outline,
          size: 14,
          color: Colors.redAccent,
        );
    }
  }

  Widget _buildMessageBubble(ChatMessage message) {
    final isMine = message.isMine;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final bubbleColor = isMine
        ? (isDark ? const Color(0xFF2A2A2A) : const Color(0xFFE0E0E0))
        : WebsColors.softGreen(context);

    final textColor = isMine
        ? (isDark ? Colors.white : Colors.black87)
        : WebsColors.textDark(context);

    final timeColor = isMine
        ? (isDark
            ? Colors.white.withValues(alpha: 0.7)
            : Colors.black.withValues(alpha: 0.6))
        : WebsColors.textLight(context);

    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: GestureDetector(
        onLongPress: () => _showMessageActions(message),
        onTap: message.status == MessageStatus.failed
            ? () => _retryMessage(message)
            : null,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          constraints: const BoxConstraints(maxWidth: 300),
          decoration: BoxDecoration(
            color: bubbleColor,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Column(
            crossAxisAlignment:
                isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              Text(
                message.text,
                style: TextStyle(color: textColor, fontSize: 16),
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _formatTime(message.createdAt),
                    style: TextStyle(fontSize: 11, color: timeColor),
                  ),
                  if (isMine) ...[
                    const SizedBox(width: 5),
                    _buildStatusIcon(
                      message.status,
                      color: timeColor,
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(30),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: WebsColors.softGreen(context),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.chat_bubble_outline,
                size: 56,
                color: WebsColors.primaryGreen,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Start your conversation',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: WebsColors.textDark(context),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Messages are saved on your phone '
              'and delivered securely when possible.',
              textAlign: TextAlign.center,
              style: TextStyle(color: WebsColors.textLight(context)),
            ),
          ],
        ),
      ),
    );
  }

  // ===================================================================
  // Chat content
  // ===================================================================

  Widget _buildChatContent() {
    if (_messages.isEmpty && _locationRequests.isEmpty) {
      return _buildEmptyState();
    }

    final timeline = <_ChatTimelineItem>[
      ..._messages.map(
        (message) => _ChatTimelineItem.message(message),
      ),
      ..._locationRequests.map(
        (request) => _ChatTimelineItem.location(request),
      ),
    ];

    timeline.sort((a, b) {
      final at = a.timestamp;
      final bt = b.timestamp;

      if (at == null && bt == null) return 0;
      if (at == null) return -1;
      if (bt == null) return 1;

      return at.compareTo(bt);
    });

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.only(top: 12, bottom: 12),
      itemCount: timeline.length,
      itemBuilder: (context, index) {
        final item = timeline[index];

        switch (item.kind) {
          case _ChatTimelineKind.message:
            final message = item.message!;

            return RepaintBoundary(
              child: _buildMessageBubble(message),
            );

          case _ChatTimelineKind.location:
            final request = item.location!;

            return RepaintBoundary(
              child: _buildLocationRequestCard(request),
            );
        }
      },
    );
  }

  // ===================================================================
  // Composer
  // ===================================================================

  Widget _buildComposer() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            IconButton(
              tooltip: 'Open map',
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => MapScreen(
                      currentUserId: widget.currentUserId,
                      userId: widget.userId,
                      name: widget.name,
                    ),
                  ),
                );
              },
              icon: const Icon(
                Icons.map_outlined,
                color: WebsColors.primaryGreen,
              ),
            ),
            Expanded(
              child: TextField(
                controller: _messageController,
                minLines: 1,
                maxLines: 5,
                textInputAction: TextInputAction.newline,
                style: TextStyle(color: WebsColors.textDark(context)),
                decoration: InputDecoration(
                  hintText: 'Message...',
                  hintStyle: TextStyle(color: WebsColors.textLight(context)),
                  filled: true,
                  fillColor: WebsColors.softGreen(context),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: const BorderSide(
                      color: WebsColors.primaryGreen,
                      width: 2,
                    ),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 12,
                  ),
                ),
                onSubmitted: (_) => _sendMessage(),
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              onPressed: _isSending ? null : _sendMessage,
              icon: _isSending
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: WebsColors.primaryGreen,
                      ),
                    )
                  : const Icon(Icons.send, color: WebsColors.primaryGreen),
            ),
          ],
        ),
      ),
    );
  }

  // ===================================================================
  // Build
  // ===================================================================

  @override
  Widget build(BuildContext context) {
    // ------------------------------------------------------------
    // Theme-aware colors for the AppBar.
    //
    // The AppBar uses a transparent background (from the global
    // theme) and inherits the body's color. So we compute the
    // title text color based on the current brightness:
    //
    //   Light theme → dark text (black87)
    //   Dark theme  → light text (white)
    // ------------------------------------------------------------
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final appBarTextColor = isDark ? Colors.white : Colors.black87;
    final appBarSubTextColor = isDark
        ? Colors.white.withValues(alpha: 0.8)
        : Colors.black.withValues(alpha: 0.7);

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: WebsColors.softGreen(context),
              backgroundImage:
                  widget.profilePhotoUrl != null &&
                          widget.profilePhotoUrl!.isNotEmpty
                      ? NetworkImage(widget.profilePhotoUrl!)
                      : null,
              child: widget.profilePhotoUrl == null ||
                      widget.profilePhotoUrl!.isEmpty
                  ? Text(
                      widget.name.isNotEmpty
                          ? widget.name[0].toUpperCase()
                          : '?',
                      style: const TextStyle(
                        color: WebsColors.primaryGreen,
                        fontWeight: FontWeight.bold,
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    widget.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: appBarTextColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    widget.phoneNumber,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      color: appBarSubTextColor,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          _isStartingCall
              ? Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: appBarTextColor,
                    ),
                  ),
                )
              : IconButton(
                  tooltip: 'Audio call',
                  onPressed: _startAudioCall,
                  icon: const Icon(Icons.call),
                ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(
                      color: WebsColors.primaryGreen,
                    ),
                  )
                : _buildChatContent(),
          ),
          _buildComposer(),
        ],
      ),
    );
  }
}

// ===================================================================
// Timeline helpers
// ===================================================================

enum _ChatTimelineKind { message, location }

class _ChatTimelineItem {
  final _ChatTimelineKind kind;
  final ChatMessage? message;
  final LocationRequest? location;

  const _ChatTimelineItem.message(this.message)
      : kind = _ChatTimelineKind.message,
        location = null;

  const _ChatTimelineItem.location(this.location)
      : kind = _ChatTimelineKind.location,
        message = null;

  DateTime? get timestamp {
    switch (kind) {
      case _ChatTimelineKind.message:
        return message?.createdAt;

      case _ChatTimelineKind.location:
        return location?.createdAt;
    }
  }
}