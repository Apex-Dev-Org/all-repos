import 'dart:convert';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/widgets.dart' show Locale;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../../l10n/app_localizations.dart';
import '../chat_title_tokens.dart';
import '../io/attachment_fs.dart';
import '../models/chat_attachment.dart';
import '../models/chat_message.dart';
import '../models/chat_session.dart';
import 'chat_repository.dart';

class MockChatRepository implements ChatRepository {
  MockChatRepository(this._prefs);

  final SharedPreferences _prefs;
  final _uuid = const Uuid();

  static const _keyPrefix = 'chat_sessions_v1_';

  String _storageKey() {
    final id = Supabase.instance.client.auth.currentUser?.id ?? 'anonymous';
    return '$_keyPrefix$id';
  }

  Future<List<ChatSession>> _readAll() async {
    final raw = _prefs.getString(_storageKey());
    if (raw == null || raw.isEmpty) return [];
    final decoded = jsonDecode(raw) as List<dynamic>;
    return decoded
        .map((e) => ChatSession.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> _writeAll(List<ChatSession> sessions) async {
    final encoded = jsonEncode(sessions.map((s) => s.toJson()).toList());
    await _prefs.setString(_storageKey(), encoded);
  }

  List<ChatSession> _sorted(List<ChatSession> sessions) {
    final copy = [...sessions]
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return copy;
  }

  static String _suffixFromFilename(String filename) {
    final i = filename.lastIndexOf('.');
    return i >= 0 ? filename.substring(i) : '';
  }

  /// Copies files into app documents on native platforms; unchanged on web.
  Future<List<ChatAttachment>> _persistAttachmentsCopy(
    List<ChatAttachment> attachments,
    String sessionId,
  ) async {
    if (attachments.isEmpty) return attachments;

    String? baseDir;
    if (!kIsWeb) {
      final docs = await getApplicationDocumentsDirectory();
      baseDir = '${docs.path}/attachments/$sessionId';
    }

    final out = <ChatAttachment>[];
    for (final a in attachments) {
      if (baseDir != null && a.localPath.isNotEmpty) {
        final destName = '${_uuid.v4()}${_suffixFromFilename(a.name)}';
        final newPath = await persistAttachmentCopy(
          sourcePath: a.localPath,
          destinationDirPath: baseDir,
          destinationFileName: destName,
        );
        out.add(a.copyWith(localPath: newPath));
      } else {
        out.add(a);
      }
    }
    return out;
  }

  static String _titleFromMessage(
    String trimmed,
    List<ChatAttachment> attachments,
  ) {
    if (trimmed.isNotEmpty) {
      return trimmed.length > 48 ? '${trimmed.substring(0, 48)}…' : trimmed;
    }
    if (attachments.isEmpty) return ChatTitleTokens.internalNewChat;
    final n = attachments.first.name;
    return n.length > 48 ? '${n.substring(0, 48)}…' : n;
  }

  @override
  Future<List<ChatSession>> listSessions() async {
    return _sorted(await _readAll());
  }

  @override
  Future<ChatSession?> getSession(String id) async {
    final all = await _readAll();
    try {
      return all.firstWhere((s) => s.id == id);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<ChatSession> createSession() async {
    final sessions = await _readAll();
    final session = ChatSession(
      id: _uuid.v4(),
      title: ChatTitleTokens.internalNewChat,
      messages: const [],
      updatedAt: DateTime.now().toUtc(),
    );
    final next = [session, ...sessions];
    await _writeAll(next);
    return session;
  }

  @override
  Future<void> deleteSession(String id) async {
    final sessions = await _readAll();
    final next = sessions.where((s) => s.id != id).toList();
    if (next.length == sessions.length) return;
    await _writeAll(next);
  }

  @override
  Future<ChatSession> sendMessage({
    required String? sessionId,
    required String text,
    List<ChatAttachment> attachments = const [],
    required String languageCode,
  }) async {
    final l10n = lookupAppLocalizations(Locale(languageCode));
    final trimmed = text.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError('Message text cannot be empty');
    }

    var sessions = await _readAll();
    final effectiveSessionId = sessionId ?? _uuid.v4();
    final idx = sessions.indexWhere((s) => s.id == sessionId);
    if (idx < 0 && sessionId != null) {
      throw StateError('Chat session not found');
    }

    var session = idx >= 0
        ? sessions[idx]
        : ChatSession(
            id: effectiveSessionId,
            title: ChatTitleTokens.internalNewChat,
            messages: const [],
            updatedAt: DateTime.now().toUtc(),
          );
    final persisted = await _persistAttachmentsCopy(
      attachments,
      effectiveSessionId,
    );

    final userMessage = ChatMessage(
      id: _uuid.v4(),
      role: 'user',
      content: trimmed,
      createdAt: DateTime.now().toUtc(),
      attachments: persisted,
    );

    var title = session.title;
    if (ChatTitleTokens.isNewChatPlaceholder(title) || title.trim().isEmpty) {
      title = _titleFromMessage(trimmed, persisted);
    }

    session = session.copyWith(
      messages: [...session.messages, userMessage],
      title: title,
      updatedAt: DateTime.now().toUtc(),
    );
    if (idx >= 0) {
      sessions[idx] = session;
    } else {
      sessions = [session, ...sessions];
    }
    await _writeAll(sessions);

    await Future<void>.delayed(const Duration(milliseconds: 800));

    final leadIn = l10n.mockAttachmentIntro(persisted.length);
    final reply = _mockReply(l10n, trimmed);
    final assistantMessage = ChatMessage(
      id: _uuid.v4(),
      role: 'assistant',
      content: leadIn + reply.text,
      createdAt: DateTime.now().toUtc(),
      citations: reply.citations,
    );

    sessions = await _readAll();
    final j = sessions.indexWhere((s) => s.id == effectiveSessionId);
    if (j < 0) throw StateError('Chat session disappeared');
    session = sessions[j];
    session = session.copyWith(
      messages: [...session.messages, assistantMessage],
      updatedAt: DateTime.now().toUtc(),
    );
    sessions[j] = session;
    await _writeAll(sessions);
    return session;
  }

  /// Keyword-based **mock** answers with illustrative citations only.
  ({String text, List<String> citations}) _mockReply(
    AppLocalizations l10n,
    String userText,
  ) {
    final t = userText.toLowerCase();
    if (t.contains('rent') ||
        t.contains('tenancy') ||
        t.contains('landlord') ||
        t.contains('tenant') ||
        t.contains('කුලී') ||
        t.contains('வாடகை') ||
        t.contains('குத்தகை')) {
      return (text: l10n.mockReplyRent, citations: [l10n.mockCitationRent]);
    }

    if (t.contains('labor') ||
        t.contains('labour') ||
        t.contains('employ') ||
        t.contains('wage') ||
        t.contains('termination') ||
        t.contains('සේව') ||
        t.contains('වැටුප') ||
        t.contains('வேலை') ||
        t.contains('சம்பளம்')) {
      return (
        text: l10n.mockReplyEmployment,
        citations: [l10n.mockCitationEmployment],
      );
    }

    if (t.contains('traffic') ||
        t.contains('motor') ||
        t.contains('driving') ||
        t.contains('license') ||
        t.contains('licence') ||
        t.contains('මාර්ග') ||
        t.contains('බලපත්') ||
        t.contains('சாலை') ||
        t.contains('உரிமம்')) {
      return (
        text: l10n.mockReplyTraffic,
        citations: [l10n.mockCitationTraffic],
      );
    }

    return (text: l10n.mockReplyGeneric, citations: <String>[]);
  }
}
