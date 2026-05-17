import 'package:http/http.dart' as http;

import '../../../core/api/api_client.dart';
import '../chat_title_tokens.dart';
import '../models/chat_attachment.dart';
import '../models/chat_message.dart';
import '../models/chat_session.dart';
import 'chat_repository.dart';

class ChatBackendException implements Exception {
  const ChatBackendException(this.message);

  final String message;

  @override
  String toString() => message;
}

class RemoteChatRepository implements ChatRepository {
  RemoteChatRepository(this._api, {int ragTopK = 5, bool onlyInEffect = true})
    : _ragTopK = ragTopK,
      _onlyInEffect = onlyInEffect;

  static const _threadPageSize = 50;
  static const _messagePageSize = 200;
  static const _maxChatTotalBytes = 50 * 1024 * 1024;
  static const _allowedAttachmentMimeTypes = {
    'application/pdf',
    'image/png',
    'image/jpeg',
    'image/webp',
    'text/plain',
    'text/markdown',
    'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
  };

  final ApiClient _api;
  final int _ragTopK;
  final bool _onlyInEffect;

  @override
  Future<List<ChatSession>> listSessions() async {
    final response = await _api.get(
      '/threads',
      queryParameters: const {'limit': '$_threadPageSize', 'offset': '0'},
    );
    final rows = _requireList(response);
    return rows
        .whereType<Map<String, dynamic>>()
        .map((row) => _sessionFromThread(row))
        .toList();
  }

  @override
  Future<ChatSession?> getSession(String id) async {
    final thread = await _findThread(id);
    if (thread == null) return null;
    final messages = await _listMessages(id);
    return _sessionFromThread(thread, messages: messages);
  }

  @override
  Future<ChatSession> createSession() async {
    final response = await _api.postJson(
      '/threads',
      body: const {'title': ChatTitleTokens.internalNewChat},
    );
    return _sessionFromThread(_requireMap(response));
  }

  @override
  Future<void> deleteSession(String id) async {
    final response = await _api.delete('/threads/$id');
    if (response.statusCode < 200 || response.statusCode >= 300) {
      if (response.statusCode == 404) return;
      throw ChatBackendException(ApiClient.errorMessage(response));
    }
  }

  @override
  Future<ChatSession> sendMessage({
    required String? sessionId,
    required String text,
    List<ChatAttachment> attachments = const [],
    required String languageCode,
  }) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) {
      throw const ChatBackendException(
        'Message is required. Describe what you want to ask.',
      );
    }

    _validateAttachments(attachments);

    final fields = {
      'message': trimmed,
      'rag_top_k': _ragTopK.toString(),
      'only_in_effect': _onlyInEffect.toString(),
    };
    final backendThreadId = _stringOrNull(sessionId);
    if (backendThreadId != null) {
      fields['thread_id'] = backendThreadId;
    }

    final response = await _api.multipart(
      '/chat',
      fields: fields,
      files: [
        for (final attachment in attachments)
          ApiUploadFile(
            fieldName: 'files',
            filePath: attachment.localPath,
            filename: attachment.name,
            mimeType: attachment.mimeType,
          ),
      ],
    );

    final body = _requireMap(response);
    final threadId = _stringOrNull(body['thread_id']) ?? backendThreadId;
    if (threadId == null) {
      throw const ChatBackendException(
        'Backend response is missing thread id.',
      );
    }
    final userMessageId = _stringOrNull(body['user_message_id']);
    final refreshed = await getSession(threadId);
    if (refreshed != null) {
      final titled = await _ensureThreadTitle(refreshed, trimmed, attachments);
      return _mergeLocalAttachments(
        titled,
        userMessageId: userMessageId,
        attachments: attachments,
      );
    }

    return _sessionFromChatResponse(
      body,
      fallbackThreadId: threadId,
      userText: trimmed,
      attachments: attachments,
    );
  }

  Future<ChatSession> _ensureThreadTitle(
    ChatSession session,
    String userText,
    List<ChatAttachment> attachments,
  ) async {
    if (!ChatTitleTokens.isNewChatPlaceholder(session.title)) return session;

    final title = _titleFromMessage(userText, attachments);
    if (ChatTitleTokens.isNewChatPlaceholder(title)) return session;

    try {
      final response = await _api.patchJson(
        '/threads/${session.id}',
        body: {'title': title},
      );
      final row = _requireMap(response);
      return session.copyWith(
        title: _stringOrNull(row['title']) ?? title,
        updatedAt: _dateTimeOrNow(row['updated_at']),
      );
    } catch (_) {
      return session.copyWith(title: title);
    }
  }

  Future<Map<String, dynamic>?> _findThread(String id) async {
    final response = await _api.get(
      '/threads',
      queryParameters: const {'limit': '$_threadPageSize', 'offset': '0'},
    );
    final rows = _requireList(response);
    for (final row in rows.whereType<Map<String, dynamic>>()) {
      if (row['id'] == id) return row;
    }
    return null;
  }

  Future<List<ChatMessage>> _listMessages(String threadId) async {
    final response = await _api.get(
      '/threads/$threadId/messages',
      queryParameters: const {'limit': '$_messagePageSize', 'offset': '0'},
    );
    final rows = _requireList(response);
    return rows.whereType<Map<String, dynamic>>().map(_messageFromRow).toList();
  }

  ChatSession _mergeLocalAttachments(
    ChatSession session, {
    required String? userMessageId,
    required List<ChatAttachment> attachments,
  }) {
    if (userMessageId == null || attachments.isEmpty) return session;
    return session.copyWith(
      messages: [
        for (final message in session.messages)
          message.id == userMessageId && message.role == 'user'
              ? message.copyWith(attachments: attachments)
              : message,
      ],
    );
  }

  ChatSession _sessionFromThread(
    Map<String, dynamic> row, {
    List<ChatMessage> messages = const [],
  }) {
    return ChatSession(
      id: _requiredString(row['id'], 'thread id'),
      title: _stringOrNull(row['title']) ?? ChatTitleTokens.internalNewChat,
      messages: messages,
      updatedAt: _dateTimeOrNow(row['updated_at'] ?? row['created_at']),
    );
  }

  ChatSession _sessionFromChatResponse(
    Map<String, dynamic> body, {
    required String fallbackThreadId,
    required String userText,
    required List<ChatAttachment> attachments,
  }) {
    final now = DateTime.now().toUtc();
    final answer = _stringOrNull(body['answer']) ?? '';
    return ChatSession(
      id: fallbackThreadId,
      title: _titleFromMessage(userText, attachments),
      updatedAt: now,
      messages: [
        ChatMessage(
          id: _stringOrNull(body['user_message_id']) ?? 'local-user',
          role: 'user',
          content: userText,
          createdAt: now,
          attachments: attachments,
        ),
        ChatMessage(
          id: _stringOrNull(body['assistant_message_id']) ?? 'local-assistant',
          role: 'assistant',
          content: answer,
          createdAt: now,
          citations: _citationsFromSources(body['sources']),
        ),
      ],
    );
  }

  ChatMessage _messageFromRow(Map<String, dynamic> row) {
    final role = _stringOrNull(row['role']) ?? 'assistant';
    final sources = row['sources'];
    return ChatMessage(
      id: _requiredString(row['id'], 'message id'),
      role: role,
      content: _stringOrNull(row['content']) ?? '',
      createdAt: _dateTimeOrNow(row['created_at']),
      citations: role == 'assistant'
          ? _citationsFromSources(sources)
          : const [],
      attachments: role == 'user' ? _attachmentsFromSources(sources) : const [],
    );
  }

  void _validateAttachments(List<ChatAttachment> attachments) {
    var totalBytes = 0;
    for (final attachment in attachments) {
      if (!_allowedAttachmentMimeTypes.contains(attachment.mimeType)) {
        throw ChatBackendException(
          'Unsupported attachment type for ${attachment.name}.',
        );
      }
      if (attachment.localPath.isEmpty) {
        throw ChatBackendException(
          'Could not read attachment ${attachment.name}. Please attach it again.',
        );
      }
      totalBytes += attachment.sizeBytes;
    }
    if (totalBytes > _maxChatTotalBytes) {
      throw const ChatBackendException(
        'Attachments are too large. Send up to 50 MB per message.',
      );
    }
  }

  List<String> _citationsFromSources(Object? sources) {
    if (sources is! List) return const [];
    final citations = <String>[];
    for (final source in sources) {
      if (source is String && source.trim().isNotEmpty) {
        citations.add(source.trim());
        continue;
      }
      if (source is! Map) continue;
      final title = _stringOrNull(source['title']);
      final excerpt = _stringOrNull(source['content_excerpt']);
      final docId = _stringOrNull(source['doc_id']);
      final parts = <String>[];
      if (title != null) parts.add(title);
      if (excerpt != null) parts.add(_truncate(excerpt));
      if (parts.isNotEmpty) {
        citations.add(parts.join(': '));
      } else if (docId != null) {
        citations.add(docId);
      }
    }
    return citations;
  }

  List<ChatAttachment> _attachmentsFromSources(Object? sources) {
    if (sources is! List) return const [];
    final attachments = <ChatAttachment>[];
    for (var i = 0; i < sources.length; i++) {
      final source = sources[i];
      if (source is! Map) continue;
      final filename = _stringOrNull(source['filename']);
      if (filename == null) continue;
      final mimeType =
          _stringOrNull(source['mime_type']) ?? _mimeTypeFromFilename(filename);
      final sizeBytes = source['size'] is num
          ? (source['size'] as num).toInt()
          : 0;
      attachments.add(
        ChatAttachment(
          id: 'server-$i-$filename',
          name: filename,
          mimeType: mimeType,
          sizeBytes: sizeBytes,
          localPath: '',
          kind: ChatAttachment.kindFromFilename(filename),
        ),
      );
    }
    return attachments;
  }

  List<dynamic> _requireList(http.Response response) {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ChatBackendException(ApiClient.errorMessage(response));
    }
    final decoded = ApiClient.decodeJson(response);
    if (decoded is List) return decoded;
    if (decoded is Map<String, dynamic> && decoded['items'] is List) {
      return decoded['items'] as List;
    }
    throw const ChatBackendException('Backend response was not a list.');
  }

  Map<String, dynamic> _requireMap(http.Response response) {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ChatBackendException(ApiClient.errorMessage(response));
    }
    final decoded = ApiClient.decodeJson(response);
    if (decoded is Map<String, dynamic>) return decoded;
    throw const ChatBackendException('Backend response was not an object.');
  }

  static String _titleFromMessage(
    String trimmed,
    List<ChatAttachment> attachments,
  ) {
    if (trimmed.isNotEmpty) {
      return trimmed.length > 48 ? '${trimmed.substring(0, 48)}...' : trimmed;
    }
    if (attachments.isEmpty) return ChatTitleTokens.internalNewChat;
    final filename = attachments.first.name;
    return filename.length > 48 ? '${filename.substring(0, 48)}...' : filename;
  }

  static String _requiredString(Object? value, String label) {
    final parsed = _stringOrNull(value);
    if (parsed == null) {
      throw ChatBackendException('Backend response is missing $label.');
    }
    return parsed;
  }

  static String? _stringOrNull(Object? value) {
    if (value is! String) return null;
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  static DateTime _dateTimeOrNow(Object? value) {
    if (value is String) {
      final parsed = DateTime.tryParse(value);
      if (parsed != null) return parsed.toUtc();
    }
    return DateTime.now().toUtc();
  }

  static String _truncate(String value, [int maxLength = 180]) {
    final trimmed = value.trim();
    if (trimmed.length <= maxLength) return trimmed;
    return '${trimmed.substring(0, maxLength - 3)}...';
  }

  static String _mimeTypeFromFilename(String filename) {
    final lower = filename.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.webp')) return 'image/webp';
    if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) return 'image/jpeg';
    if (lower.endsWith('.pdf')) return 'application/pdf';
    if (lower.endsWith('.md') || lower.endsWith('.markdown')) {
      return 'text/markdown';
    }
    if (lower.endsWith('.txt')) return 'text/plain';
    if (lower.endsWith('.docx')) {
      return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
    }
    return 'application/octet-stream';
  }
}
