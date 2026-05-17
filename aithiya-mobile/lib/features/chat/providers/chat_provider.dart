import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/services/logger_service.dart';
import '../chat_title_tokens.dart';
import '../data/chat_repository.dart';
import '../models/chat_attachment.dart';
import '../models/chat_message.dart';
import '../models/chat_session.dart';

class ChatProvider extends ChangeNotifier {
  ChatProvider({required ChatRepository repository})
    : _repository = repository {
    _authSubscription = Supabase.instance.client.auth.onAuthStateChange.listen((
      _,
    ) {
      unawaited(_reload());
    });
    unawaited(_reload());
  }

  final ChatRepository _repository;
  late final StreamSubscription<AuthState> _authSubscription;

  List<ChatSession> _sessions = [];
  ChatSession? _active;
  bool _isSending = false;
  String? _errorMessage;

  List<ChatSession> get sessions => List.unmodifiable(_sessions);
  ChatSession? get activeSession => _active;
  bool get isSending => _isSending;
  String? get errorMessage => _errorMessage;

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  /// Loads sessions from storage and reconciles [_active]. Returns `false` on failure.
  Future<bool> _reload() async {
    try {
      if (Supabase.instance.client.auth.currentSession == null) {
        _sessions = const [];
        _active = null;
        notifyListeners();
        return true;
      }

      final list = await _repository.listSessions();
      if (_isSending || _shouldKeepLocalDraft()) {
        return true;
      }
      _sessions = list;
      final previousId = _active?.id;
      if (_sessions.isEmpty) {
        _active = _createLocalSession();
        _replaceActiveInList();
      } else if (previousId != null &&
          _sessions.any((s) => s.id == previousId)) {
        final selected = _sessions.firstWhere((s) => s.id == previousId);
        _active = await _repository.getSession(selected.id) ?? selected;
      } else {
        final selected = _sessions.first;
        _active = await _repository.getSession(selected.id) ?? selected;
      }
      _replaceActiveInList();
      notifyListeners();
      return true;
    } catch (e, st) {
      AppLogger.instance.error('Failed to load chat sessions', e, st);
      _active ??= _createLocalSession();
      _replaceActiveInList();
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<void> selectSession(String id) async {
    _errorMessage = null;
    notifyListeners();
    try {
      final session = await _repository.getSession(id);
      if (session != null) {
        _active = session;
        _replaceActiveInList();
        notifyListeners();
      }
    } catch (e, st) {
      AppLogger.instance.error('Failed to select chat session', e, st);
      _errorMessage = e.toString();
      notifyListeners();
    }
  }

  Future<void> newSession() async {
    _errorMessage = null;
    _active = _createLocalSession();
    _sessions = [
      _active!,
      ..._sessions.where((session) => !_isEmptyLocalDraft(session)),
    ];
    notifyListeners();
  }

  /// Deletes a thread on the backend and reconciles local state. Returns
  /// `true` on success, `false` (with [errorMessage] set) on failure.
  Future<bool> deleteSession(String id) async {
    _errorMessage = null;
    final wasActive = _active?.id == id;
    final previousSessions = _sessions;
    final previousActive = _active;

    _sessions = _sessions.where((s) => s.id != id).toList();
    if (wasActive) {
      if (_sessions.isNotEmpty) {
        _active = _sessions.first;
      } else {
        _active = _createLocalSession();
        _sessions = [_active!];
      }
    }
    notifyListeners();

    if (_isLocalSessionId(id)) {
      return true;
    }

    try {
      await _repository.deleteSession(id);
      if (wasActive && _active != null && !_isLocalSessionId(_active!.id)) {
        final hydrated = await _repository.getSession(_active!.id);
        if (hydrated != null) {
          _active = hydrated;
          _replaceActiveInList();
          notifyListeners();
        }
      }
      return true;
    } catch (e, st) {
      AppLogger.instance.error('Failed to delete chat session', e, st);
      _sessions = previousSessions;
      _active = previousActive;
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<void> refresh() async {
    _errorMessage = null;
    notifyListeners();
    await _reload();
  }

  Future<void> sendMessage(
    String text, {
    List<ChatAttachment> attachments = const [],
    required String languageCode,
  }) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;

    _errorMessage = null;
    notifyListeners();

    _active ??= _createLocalSession();
    _replaceActiveInList();

    final previousActive = _active!;
    final backendSessionId = _isLocalSessionId(previousActive.id)
        ? null
        : previousActive.id;
    final optimisticAt = DateTime.now().toUtc();
    final optimistic = ChatMessage(
      id: 'local-user-${optimisticAt.microsecondsSinceEpoch}',
      role: 'user',
      content: trimmed,
      createdAt: optimisticAt,
      attachments: attachments,
    );
    _active = previousActive.copyWith(
      title: _optimisticTitle(previousActive.title, trimmed),
      messages: [...previousActive.messages, optimistic],
      updatedAt: optimisticAt,
    );
    _replaceActiveInList();
    _sessions.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    _isSending = true;
    notifyListeners();
    try {
      final updated = await _repository.sendMessage(
        sessionId: backendSessionId,
        text: trimmed,
        attachments: attachments,
        languageCode: languageCode,
      );
      _replaceSentSession(previousActive.id, updated);
      _sessions.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    } catch (e, st) {
      AppLogger.instance.error('Failed to send chat message', e, st);
      _appendSendFailure(e.toString());
      _errorMessage = e.toString();
    } finally {
      _isSending = false;
      notifyListeners();
    }
  }

  void _replaceActiveInList() {
    final active = _active;
    if (active == null) return;
    final idx = _sessions.indexWhere((s) => s.id == active.id);
    if (idx < 0) {
      _sessions = [active, ..._sessions];
      return;
    }
    _sessions = [
      ..._sessions.sublist(0, idx),
      active,
      ..._sessions.sublist(idx + 1),
    ];
  }

  void _replaceSentSession(String previousId, ChatSession updated) {
    final next = [..._sessions];
    final updatedIdx = next.indexWhere((session) => session.id == updated.id);
    if (updatedIdx >= 0) {
      next[updatedIdx] = updated;
      final staleIdx = next.indexWhere(
        (session) => session.id == previousId && session.id != updated.id,
      );
      if (staleIdx >= 0) {
        next.removeAt(staleIdx);
      }
    } else {
      final previousIdx = next.indexWhere(
        (session) => session.id == previousId,
      );
      if (previousIdx >= 0) {
        next[previousIdx] = updated;
      } else {
        next.insert(0, updated);
      }
    }
    _sessions = next;
    _active = updated;
    _replaceActiveInList();
  }

  void _appendSendFailure(String message) {
    final active = _active;
    if (active == null) return;
    final failedAt = DateTime.now().toUtc();
    final failure = ChatMessage(
      id: 'local-error-${failedAt.microsecondsSinceEpoch}',
      role: 'assistant',
      content: 'Could not send message. $message',
      createdAt: failedAt,
    );
    _active = active.copyWith(
      messages: [...active.messages, failure],
      updatedAt: failedAt,
    );
    _replaceActiveInList();
  }

  bool _shouldKeepLocalDraft() {
    final active = _active;
    return active != null &&
        _isLocalSessionId(active.id) &&
        active.messages.isNotEmpty;
  }

  static ChatSession _createLocalSession() {
    final now = DateTime.now().toUtc();
    return ChatSession(
      id: 'local-thread-${now.microsecondsSinceEpoch}',
      title: ChatTitleTokens.internalNewChat,
      messages: const [],
      updatedAt: now,
    );
  }

  static bool _isLocalSessionId(String id) => id.startsWith('local-thread-');

  static bool _isEmptyLocalDraft(ChatSession session) {
    return _isLocalSessionId(session.id) && session.messages.isEmpty;
  }

  static String _optimisticTitle(String currentTitle, String text) {
    if (!ChatTitleTokens.isNewChatPlaceholder(currentTitle)) {
      return currentTitle;
    }
    return text.length > 48 ? '${text.substring(0, 48)}...' : text;
  }

  @override
  void dispose() {
    unawaited(_authSubscription.cancel());
    super.dispose();
  }
}
