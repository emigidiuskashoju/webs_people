import 'package:flutter/widgets.dart';

/// Holds back notification taps until the main (chats) screen is on
/// screen.
///
/// When a notification starts the app, the tap arrives while the
/// splash screen is still showing. Opening the chat then was the
/// bug: a moment later the start-up code replaced it with the chats
/// list. Now the tap waits here and the chat opens on top of the
/// chats screen, so Back returns to the list (like WhatsApp).
class NotificationTapGate {
  NotificationTapGate._();
  static final NotificationTapGate instance = NotificationTapGate._();

  // How many MainNavigationScreens are alive. A count, not a flag:
  // when one replaces another, the old one's dispose can run after
  // the new one is ready.
  int _readyScreens = 0;
  String? _pending;

  /// Opens a conversation; set by the app at start-up.
  void Function(String conversationId)? opener;

  bool get isReady => _readyScreens > 0;

  /// Called for every tap. Opens now, or later when ready.
  void open(String conversationId) {
    if (!isReady || opener == null) {
      _pending = conversationId; // the latest tap wins
      return;
    }
    opener!(conversationId);
  }

  /// Called by MainNavigationScreen after its first frame.
  void markReady() {
    _readyScreens++;
    final pending = _pending;
    _pending = null;
    if (pending != null && opener != null) opener!(pending);
  }

  /// Called when MainNavigationScreen goes away (e.g. logout).
  void markNotReady() {
    if (_readyScreens > 0) _readyScreens--;
  }

  /// For screens that want to run this after their first frame.
  void markReadyAfterFirstFrame() {
    WidgetsBinding.instance.addPostFrameCallback((_) => markReady());
  }
}
