import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../l10n/app_localizations.dart';
import '../../../config/theme.dart';
import '../models/chat_attachment.dart';
import '../models/chat_message.dart';
import 'citation_chip.dart';
import 'local_image.dart';

class MessageBubble extends StatelessWidget {
  const MessageBubble({super.key, required this.message});

  final ChatMessage message;

  bool get _isUser => message.role == 'user';

  void _onAttachmentTap(BuildContext context, ChatAttachment a) {
    final l10n = AppLocalizations.of(context)!;
    if (a.kind != AttachmentKind.image || a.localPath.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.attachmentPreviewUnavailable)),
      );
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (ctx) {
          final scheme = Theme.of(ctx).colorScheme;
          return Scaffold(
            backgroundColor: scheme.surface,
            appBar: AppBar(title: Text(a.name)),
            body: Center(
              child: InteractiveViewer(
                minScale: 0.25,
                maxScale: 4,
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: localImageFile(
                    a.localPath,
                    fit: BoxFit.contain,
                    width: MediaQuery.sizeOf(ctx).width,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final timeStr = DateFormat.Hm().format(message.createdAt.toLocal());

    if (_isUser) {
      return Align(
        alignment: Alignment.centerRight,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.sizeOf(context).width * 0.8,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                decoration: BoxDecoration(
                  color: AppColors.bubbleUser,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(16),
                    topRight: Radius.circular(16),
                    bottomLeft: Radius.circular(16),
                    bottomRight: Radius.circular(4),
                  ),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (message.attachments.isNotEmpty) ...[
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final a in message.attachments)
                            GestureDetector(
                              onTap: () => _onAttachmentTap(context, a),
                              child: _AttachmentBubbleTile(
                                attachment: a,
                                isUserBubble: true,
                              ),
                            ),
                        ],
                      ),
                      if (message.content.trim().isNotEmpty)
                        const SizedBox(height: 10),
                    ],
                    if (message.content.trim().isNotEmpty)
                      SelectableText(
                        message.content,
                        style: const TextStyle(color: Colors.white),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    timeStr,
                    style: TextStyle(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontSize: 11,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.check,
                    size: 14,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }

    // AI Bubble
    return Align(
      alignment: Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.85,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            CircleAvatar(
              radius: 16,
              backgroundColor: Colors.white,
              child: ClipOval(
                child: Padding(
                  padding: const EdgeInsets.all(4.0),
                  child: Image.asset(
                    'assets/images/aithiya_logo.png',
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.bubbleAi,
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(16),
                        topRight: Radius.circular(16),
                        bottomLeft: Radius.circular(4),
                        bottomRight: Radius.circular(16),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (message.attachments.isNotEmpty) ...[
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              for (final a in message.attachments)
                                GestureDetector(
                                  onTap: () => _onAttachmentTap(context, a),
                                  child: _AttachmentBubbleTile(
                                    attachment: a,
                                    isUserBubble: false,
                                  ),
                                ),
                            ],
                          ),
                          if (message.content.trim().isNotEmpty)
                            const SizedBox(height: 10),
                        ],
                        if (message.content.trim().isNotEmpty)
                          SelectableText(
                            message.content,
                            style: const TextStyle(color: Colors.black87),
                          ),
                        if (message.citations.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(
                            l10n.citationsLabel,
                            style: theme.textTheme.labelMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                          ...message.citations.map(
                            (c) => CitationChip(citation: c),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    timeStr,
                    style: TextStyle(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AttachmentBubbleTile extends StatelessWidget {
  const _AttachmentBubbleTile({
    required this.attachment,
    required this.isUserBubble,
  });

  final ChatAttachment attachment;
  final bool isUserBubble;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: BorderSide(
        color: isUserBubble ? Colors.white30 : Colors.black12,
      ),
    );

    if (attachment.kind == AttachmentKind.image &&
        attachment.localPath.isNotEmpty) {
      return Material(
        type: MaterialType.transparency,
        child: SizedBox(
          width: 88,
          height: 88,
          child: DecoratedBox(
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(10)),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: localImageFile(
                attachment.localPath,
                width: 88,
                height: 88,
                fit: BoxFit.cover,
              ),
            ),
          ),
        ),
      );
    }

    IconData icon;
    switch (attachment.kind) {
      case AttachmentKind.pdf:
        icon = Icons.picture_as_pdf_outlined;
        break;
      case AttachmentKind.document:
        icon = Icons.description_outlined;
        break;
      default:
        icon = Icons.insert_drive_file_outlined;
    }

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 220),
      child: InputDecorator(
        decoration: InputDecoration(
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 10,
            vertical: 8,
          ),
          border: border,
          enabledBorder: border,
          filled: false,
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: isUserBubble ? Colors.white : theme.colorScheme.primary,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                attachment.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: isUserBubble ? Colors.white : Colors.black87,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
