import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../chat_title_tokens.dart';
import '../models/chat_session.dart';

String _sessionDrawerTitle(BuildContext context, String storedTitle) {
  final l10n = AppLocalizations.of(context)!;
  if (ChatTitleTokens.isNewChatPlaceholder(storedTitle)) {
    return l10n.newChat;
  }
  return storedTitle;
}

class ChatHistoryDrawer extends StatefulWidget {
  const ChatHistoryDrawer({
    super.key,
    required this.sessions,
    required this.activeSessionId,
    required this.onSelect,
    required this.onNewChat,
    required this.onDelete,
  });

  final List<ChatSession> sessions;
  final String? activeSessionId;
  final void Function(String sessionId) onSelect;
  final VoidCallback onNewChat;
  final Future<bool> Function(ChatSession session) onDelete;

  @override
  State<ChatHistoryDrawer> createState() => _ChatHistoryDrawerState();
}

class _ChatHistoryDrawerState extends State<ChatHistoryDrawer> {
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    final filtered = widget.sessions.where((s) {
      final display = _sessionDrawerTitle(context, s.title);
      return display.toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();

    return Drawer(
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
              child: Text(
                l10n.drawerRecentChats,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                controller: _searchController,
                onChanged: (v) => setState(() => _searchQuery = v),
                decoration: InputDecoration(
                  hintText: l10n.drawerSearchHint,
                  prefixIcon: const Icon(Icons.search, size: 20),
                  filled: true,
                  fillColor: theme.colorScheme.surfaceContainerHighest
                      .withValues(alpha: 0.5),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(vertical: 0),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView.builder(
                itemCount: filtered.length + 1,
                itemBuilder: (context, i) {
                  if (i == 0) {
                    return ListTile(
                      leading: const Icon(Icons.add_comment_outlined),
                      title: Text(l10n.newChat),
                      onTap: widget.onNewChat,
                    );
                  }
                  final s = filtered[i - 1];
                  final selected = s.id == widget.activeSessionId;
                  return ListTile(
                    selected: selected,
                    title: Text(
                      _sessionDrawerTitle(context, s.title),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: selected
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.more_vert, size: 20),
                      tooltip: l10n.chatHistoryMoreActions,
                      onPressed: () => _showActionsForSession(context, s),
                    ),
                    onTap: () => widget.onSelect(s.id),
                    onLongPress: () => _showActionsForSession(context, s),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showActionsForSession(
    BuildContext context,
    ChatSession session,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final action = await showModalBottomSheet<_DrawerAction>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                child: Text(
                  _sessionDrawerTitle(sheetContext, session.title),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(sheetContext).textTheme.titleMedium,
                ),
              ),
              ListTile(
                leading: Icon(
                  Icons.delete_outline,
                  color: theme.colorScheme.error,
                ),
                title: Text(
                  l10n.chatHistoryDelete,
                  style: TextStyle(color: theme.colorScheme.error),
                ),
                onTap: () =>
                    Navigator.of(sheetContext).pop(_DrawerAction.delete),
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
    if (action != _DrawerAction.delete) return;
    if (!context.mounted) return;
    await _confirmAndDelete(context, session);
  }

  Future<void> _confirmAndDelete(
    BuildContext context,
    ChatSession session,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(l10n.chatHistoryDeleteConfirmTitle),
          content: Text(l10n.chatHistoryDeleteConfirmBody),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(l10n.dialogCancel),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: theme.colorScheme.error,
                foregroundColor: theme.colorScheme.onError,
              ),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(l10n.dialogDelete),
            ),
          ],
        );
      },
    );
    if (confirmed != true) return;
    final ok = await widget.onDelete(session);
    if (!mounted) return;
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          ok ? l10n.chatHistoryDeleteSuccess : l10n.chatHistoryDeleteError,
        ),
      ),
    );
  }
}

enum _DrawerAction { delete }
