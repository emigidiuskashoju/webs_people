import 'package:flutter/material.dart';

import '../calls/audio_call_screen.dart';
import '../calls/services/call_service.dart';
import 'data/chat_repository.dart';
import 'models/chat_message.dart';

class ChatScreen extends StatefulWidget {
  final int currentUserId;
  final int userId;
  final String name;
  final String phoneNumber;

  const ChatScreen({
    super.key,
    required this.currentUserId,
    required this.userId,
    required this.name,
    required this.phoneNumber,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController =
      TextEditingController();

  final ScrollController _scrollController =
      ScrollController();

  final ChatRepository _repository =
      ChatRepository();

  final CallService _callService =
      CallService();

  List<ChatMessage> _messages = [];

  bool _isLoading = true;
  bool _isSending = false;
  bool _isStartingCall = false;

  String get _conversationId {
    return _repository.createConversationId(
      widget.currentUserId,
      widget.userId,
    );
  }

  @override
  void initState() {
    super.initState();

    _loadMessages();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();

    super.dispose();
  }

  Future<void> _loadMessages() async {
    try {
      final messages =
          await _repository.getConversation(
        _conversationId,
        currentUserId: widget.currentUserId,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _messages = messages;
        _isLoading = false;
      });

      _scrollToBottom();

      await _receiveMessages();

      await _markMessagesAsRead();

      await _syncReadReceipts();
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _receiveMessages() async {
    try {
      await _repository.receivePendingMessages(
        currentUserId: widget.currentUserId,
      );

      final messages =
          await _repository.getConversation(
        _conversationId,
        currentUserId: widget.currentUserId,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _messages = messages;
      });

      _scrollToBottom();

      await _markMessagesAsRead();

      await _syncReadReceipts();
    } catch (_) {
      // No Internet is not treated as a fatal chat error.
    }
  }

  Future<void> _markMessagesAsRead() async {
    try {
      await _repository.markConversationAsRead(
        conversationId: _conversationId,
        currentUserId: widget.currentUserId,
      );

      final messages =
          await _repository.getConversation(
        _conversationId,
        currentUserId: widget.currentUserId,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _messages = messages;
      });
    } catch (_) {
      // Keep local chat available.
    }
  }

  Future<void> _syncReadReceipts() async {
    try {
      final updatedCount =
          await _repository.syncReadReceipts();

      if (updatedCount == 0 || !mounted) {
        return;
      }

      final messages =
          await _repository.getConversation(
        _conversationId,
        currentUserId: widget.currentUserId,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _messages = messages;
      });
    } catch (_) {
      // Read receipt synchronization is non-fatal.
    }
  }

  Future<void> _sendMessage() async {
    final text =
        _messageController.text.trim();

    if (text.isEmpty || _isSending) {
      return;
    }

    setState(() {
      _isSending = true;
    });

    try {
      await _repository.createAndSendMessage(
        senderId: widget.currentUserId,
        recipientId: widget.userId,
        conversationId: _conversationId,
        text: text,
      );

      _messageController.clear();

      final messages =
          await _repository.getConversation(
        _conversationId,
        currentUserId: widget.currentUserId,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _messages = messages;
      });

      _scrollToBottom();
    } catch (_) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Message could not be sent. It will remain available locally.',
          ),
        ),
      );

      final messages =
          await _repository.getConversation(
        _conversationId,
        currentUserId: widget.currentUserId,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _messages = messages;
      });
    } finally {
      if (!mounted) {
        return;
      }

      setState(() {
        _isSending = false;
      });
    }
  }

  Future<void> _retryMessage(
    ChatMessage message,
  ) async {
    try {
      await _repository.retryFailedMessage(
        message,
      );

      final messages =
          await _repository.getConversation(
        _conversationId,
        currentUserId: widget.currentUserId,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _messages = messages;
      });

      _scrollToBottom();
    } catch (_) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Message could not be retried.',
          ),
        ),
      );
    }
  }

  Future<void> _startAudioCall() async {
    if (_isStartingCall) {
      return;
    }

    setState(() {
      _isStartingCall = true;
    });

    try {
      final record =
          await _callService.startAudioCall(
        ownerUserId:
            widget.currentUserId,
        recipientId:
            widget.userId,
        recipientName:
            widget.name,
        recipientPhoneNumber:
            widget.phoneNumber,
      );

      if (!mounted) {
        return;
      }

      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => AudioCallScreen(
            callService:
                _callService,
            callRecord:
                record,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Unable to start audio call: $e',
          ),
        ),
      );
    } finally {
      if (!mounted) {
        return;
      }

      setState(() {
        _isStartingCall = false;
      });
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback(
      (_) {
        if (!_scrollController.hasClients) {
          return;
        }

        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(
            milliseconds: 250,
          ),
          curve: Curves.easeOut,
        );
      },
    );
  }

  String _formatTime(
    DateTime dateTime,
  ) {
    final hour = dateTime.hour
        .toString()
        .padLeft(2, '0');

    final minute = dateTime.minute
        .toString()
        .padLeft(2, '0');

    return '$hour:$minute';
  }

  Widget _buildMessageBubble(
    ChatMessage message,
  ) {
    final isMine = message.isMine;

    final colorScheme =
        Theme.of(context).colorScheme;

    final bubbleColor = isMine
        ? colorScheme.primary
        : colorScheme.surfaceContainerHighest;

    final textColor = isMine
        ? colorScheme.onPrimary
        : colorScheme.onSurfaceVariant;

    final timeColor = isMine
        ? colorScheme.onPrimary.withValues(
            alpha: 0.75,
          )
        : colorScheme.onSurfaceVariant.withValues(
            alpha: 0.70,
          );

    return Align(
      alignment: isMine
          ? Alignment.centerRight
          : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 4,
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 10,
        ),
        constraints: const BoxConstraints(
          maxWidth: 300,
        ),
        decoration: BoxDecoration(
          color: bubbleColor,
          borderRadius:
              BorderRadius.circular(18),
        ),
        child: Column(
          crossAxisAlignment: isMine
              ? CrossAxisAlignment.end
              : CrossAxisAlignment.start,
          children: [
            Text(
              message.text,
              style: TextStyle(
                color: textColor,
                fontSize: 16,
              ),
            ),
            const SizedBox(
              height: 4,
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _formatTime(
                    message.createdAt,
                  ),
                  style: TextStyle(
                    fontSize: 11,
                    color: timeColor,
                  ),
                ),
                if (isMine) ...[
                  const SizedBox(
                    width: 5,
                  ),
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
    );
  }

  Widget _buildStatusIcon(
    MessageStatus status, {
    required Color color,
  }) {
    switch (status) {
      case MessageStatus.pending:
        return Icon(
          Icons.schedule,
          size: 13,
          color: color,
        );

      case MessageStatus.sent:
        return Icon(
          Icons.check,
          size: 13,
          color: color,
        );

      case MessageStatus.delivered:
        return Icon(
          Icons.done_all,
          size: 13,
          color: color,
        );

      case MessageStatus.read:
        return Icon(
          Icons.done_all,
          size: 13,
          color: color,
        );

      case MessageStatus.failed:
        return Icon(
          Icons.error_outline,
          size: 14,
          color: color,
        );
    }
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(30),
        child: Column(
          mainAxisAlignment:
              MainAxisAlignment.center,
          children: [
            Icon(
              Icons.chat_bubble_outline,
              size: 60,
              color: Theme.of(context)
                  .colorScheme
                  .primary,
            ),
            const SizedBox(
              height: 16,
            ),
            Text(
              'Start your conversation',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium,
            ),
            const SizedBox(
              height: 8,
            ),
            Text(
              'Messages are saved on your phone '
              'and delivered securely when possible.',
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageList() {
    if (_messages.isEmpty) {
      return _buildEmptyState();
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.only(
        top: 12,
        bottom: 12,
      ),
      itemCount: _messages.length,
      itemBuilder: (
        context,
        index,
      ) {
        final message =
            _messages[index];

        return GestureDetector(
          onTap: message.status ==
                  MessageStatus.failed
              ? () => _retryMessage(
                    message,
                  )
              : null,
          child: _buildMessageBubble(
            message,
          ),
        );
      },
    );
  }

  Widget _buildComposer() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          8,
          6,
          8,
          6,
        ),
        child: Row(
          crossAxisAlignment:
              CrossAxisAlignment.end,
          children: [
            Expanded(
              child: TextField(
                controller:
                    _messageController,
                minLines: 1,
                maxLines: 5,
                textInputAction:
                    TextInputAction.newline,
                decoration: InputDecoration(
                  hintText:
                      'Message...',
                  border:
                      OutlineInputBorder(
                    borderRadius:
                        BorderRadius.circular(
                      24,
                    ),
                  ),
                  contentPadding:
                      const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 12,
                  ),
                ),
                onSubmitted: (_) {
                  _sendMessage();
                },
              ),
            ),
            const SizedBox(
              width: 8,
            ),
            IconButton(
              onPressed: _isSending
                  ? null
                  : _sendMessage,
              icon: _isSending
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child:
                          CircularProgressIndicator(
                        strokeWidth: 2,
                      ),
                    )
                  : const Icon(
                      Icons.send,
                    ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(
    BuildContext context,
  ) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            Text(widget.name),
            Text(
              widget.phoneNumber,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall,
            ),
          ],
        ),
        actions: [
          _isStartingCall
              ? const Padding(
                  padding:
                      EdgeInsets.symmetric(
                    horizontal: 16,
                  ),
                  child: SizedBox(
                    width: 22,
                    height: 22,
                    child:
                        CircularProgressIndicator(
                      strokeWidth: 2,
                    ),
                  ),
                )
              : IconButton(
                  tooltip: 'Audio call',
                  onPressed:
                      _startAudioCall,
                  icon: const Icon(
                    Icons.call,
                  ),
                ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _isLoading
                ? const Center(
                    child:
                        CircularProgressIndicator(),
                  )
                : _buildMessageList(),
          ),
          _buildComposer(),
        ],
      ),
    );
  }
}