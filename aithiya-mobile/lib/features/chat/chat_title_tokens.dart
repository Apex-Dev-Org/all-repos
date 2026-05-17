/// Persisted placeholder for a session that has no user-chosen title yet.
/// Older builds stored the literal English `'New chat'`.
abstract final class ChatTitleTokens {
  static const internalNewChat = '__aithiya_new_chat__';

  static bool isNewChatPlaceholder(String title) =>
      title == internalNewChat || title == 'New chat';
}
