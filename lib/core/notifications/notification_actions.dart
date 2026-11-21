import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../network/api_endpoints.dart';
import '../storage/auth_storage.dart';

/// Separator used in the message-notification payload
/// (conversationId | senderId | senderName | serverMessageId).
const String kMsgPayloadSep = '\u001F';

/// SharedPreferences key holding replies sent from a notification that
/// the app must still record in the local chat history on next open.
const String kPendingOutboundKey = 'webs_pending_outbound_replies';

/// Handles the "Reply" and "Mark as read" notification buttons.
///
/// Runs in the foreground AND in the background isolate, so it does raw
/// HTTP with the stored token instead of using app services.
@pragma('vm:entry-point')
Future<void> handleWebsNotificationAction(NotificationResponse response) async {
  final actionId = response.actionId;
  if (actionId != 'msg_reply' && actionId != 'msg_read') return;

  final parts = (response.payload ?? '').split(kMsgPayloadSep);
  if (parts.length < 4) return;

  final conversationId = parts[0];
  final senderId = int.tryParse(parts[1]) ?? 0;
  final serverMessageId = int.tryParse(parts[3]) ?? 0;

  try {
    final token = await AuthStorage().getToken();
    if (token == null || token.isEmpty) return;

    final headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'Authorization': 'Bearer $token',
    };

    if (actionId == 'msg_read') {
      if (serverMessageId > 0) {
        await http
            .post(
              Uri.parse(
                '${ApiEndpoints.baseUrl}${ApiEndpoints.markMessageRead(serverMessageId)}',
              ),
              headers: headers,
            )
            .timeout(const Duration(seconds: 12));
      }
      await _cancel(conversationId);
      return;
    }

    // msg_reply
    final text = response.input?.trim() ?? '';
    if (text.isEmpty || senderId <= 0) return;

    final clientId = const Uuid().v4();
    final res = await http
        .post(
          Uri.parse('${ApiEndpoints.baseUrl}${ApiEndpoints.sendMessage}'),
          headers: headers,
          body: jsonEncode({
            'recipient_id': senderId,
            'client_message_id': clientId,
            'message': text,
            'type': 'text',
          }),
        )
        .timeout(const Duration(seconds: 15));

    if (res.statusCode >= 200 && res.statusCode < 300) {
      // Remember it so the app writes it into the chat history on open
      // (the background isolate cannot touch the chat database safely).
      await _queueOutbound(
        conversationId: conversationId,
        recipientId: senderId,
        clientId: clientId,
        text: text,
      );
    }
    await _cancel(conversationId);
  } catch (e) {
    debugPrint('NOTIF-ACTION: failed: $e');
  }
}

Future<void> _cancel(String conversationId) async {
  try {
    await FlutterLocalNotificationsPlugin().cancel(conversationId.hashCode);
  } catch (_) {}
}

Future<void> _queueOutbound({
  required String conversationId,
  required int recipientId,
  required String clientId,
  required String text,
}) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(kPendingOutboundKey) ?? <String>[];
    list.add(jsonEncode({
      'conversation_id': conversationId,
      'recipient_id': recipientId,
      'client_id': clientId,
      'text': text,
      'created_at': DateTime.now().toIso8601String(),
    }));
    await prefs.setStringList(kPendingOutboundKey, list);
  } catch (_) {}
}
