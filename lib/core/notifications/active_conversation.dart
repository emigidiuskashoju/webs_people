/// Tracks which conversation the user is currently looking at.
///
/// ChatScreen sets this on open and clears it on close. The chat
/// repository reads it before firing a notification, so we never
/// notify the user about a message in a chat they are already in.
///
/// This is intentionally simple: one conversation at a time.
/// Webs  only ever shows one chat full-screen, so a scalar
/// is enough.
class ActiveConversation {
  ActiveConversation._();

  static final ActiveConversation instance = ActiveConversation._();

  String? _conversationId;

  /// The conversation id currently on screen, or null.
  String? get current => _conversationId;

  /// Called by ChatScreen when it opens.
  void enter(String conversationId) {
    _conversationId = conversationId;
  }

  /// Called by ChatScreen when it closes.
  void leave(String conversationId) {
    // Only clear if this is still the current one — protects
    // against a fast open/close/open sequence.
    if (_conversationId == conversationId) {
      _conversationId = null;
    }
  }

  /// True if the given conversation is the one on screen.
  bool isActive(String conversationId) {
    return _conversationId == conversationId;
  }
}