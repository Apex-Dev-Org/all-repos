import '../models/chat_attachment.dart';
import '../models/chat_session.dart';

/// Contract for chat persistence and answering. Swap implementations when the
/// FastAPI backend is ready.
abstract class ChatRepository {
  Future<List<ChatSession>> listSessions();

  Future<ChatSession?> getSession(String id);

  Future<ChatSession> createSession();

  Future<void> deleteSession(String id);

  /// Appends the user message and assistant reply to the session.
  Future<ChatSession> sendMessage({
    required String? sessionId,
    required String text,
    List<ChatAttachment> attachments = const [],
    required String languageCode,
  });
}
