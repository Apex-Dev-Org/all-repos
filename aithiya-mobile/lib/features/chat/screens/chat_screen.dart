import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../l10n/app_localizations.dart';
import '../../../shared/locale_resolution.dart';
import '../../../shared/widgets/background_scaffold.dart';
import '../../subscription/providers/subscription_provider.dart';
import '../models/chat_attachment.dart';
import '../providers/chat_provider.dart';
import '../services/attachment_picker_service.dart';
import '../services/camera_availability.dart';
import '../services/voice_input_service.dart';
import '../widgets/chat_history_drawer.dart';
import '../widgets/message_bubble.dart';
import '../widgets/local_image.dart';
import '../widgets/chat_top_bar.dart';

enum _VoicePhase { idle, recording, transcribing }

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final _voice = VoiceInputService();
  final _attachments = AttachmentPickerService();
  final List<ChatAttachment> _pendingAttachments = [];

  _VoicePhase _voicePhase = _VoicePhase.idle;

  @override
  void dispose() {
    unawaited(_voice.dispose());
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _appendTranscript(String text) {
    final t = text.trim();
    if (t.isEmpty) return;
    final cur = _controller.text;
    if (cur.trim().isEmpty) {
      _controller.text = t;
    } else if (!cur.endsWith(' ') && !cur.endsWith('\n')) {
      _controller.text = '$cur $t';
    } else {
      _controller.text = '$cur$t';
    }
    _controller.selection = TextSelection.collapsed(
      offset: _controller.text.length,
    );
  }

  String? _sttLanguageCode(BuildContext context) {
    final code = Localizations.localeOf(context).languageCode;
    return {'en', 'si'}.contains(code) ? code : null;
  }

  void _showVoiceError(
    ScaffoldMessengerState messenger,
    AppLocalizations l10n,
    Object e,
  ) {
    final msg = switch (e) {
      VoiceInputPermissionDenied _ => l10n.voicePermissionDenied,
      VoiceInputMissingApiKey _ => l10n.voiceMissingApiKey,
      VoiceInputEmptyTranscript _ => l10n.voiceEmptyTranscript,
      VoiceInputApiException e => e.message,
      _ => l10n.voiceTranscriptionErrorGeneric,
    };
    messenger.showSnackBar(SnackBar(content: Text(msg)));
  }

  void _showAttachmentError(
    ScaffoldMessengerState messenger,
    AppLocalizations l10n,
    Object e,
  ) {
    final msg = switch (e) {
      AttachmentTooLarge _ => l10n.attachmentTooLarge,
      AttachmentPickFailed e =>
        e.message.isEmpty ? l10n.attachmentPickFailed : e.message,
      _ => l10n.attachmentPickFailed,
    };
    messenger.showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _onMicPressed(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final l10n = AppLocalizations.of(context);
    if (l10n == null) return;

    if (_voicePhase == _VoicePhase.transcribing) return;

    if (_voicePhase == _VoicePhase.recording) {
      final langCode = _sttLanguageCode(context);
      setState(() => _voicePhase = _VoicePhase.transcribing);
      try {
        final text = await _voice.stop(languageCode: langCode);
        if (!mounted) return;
        _appendTranscript(text);
      } catch (e) {
        if (!mounted) return;
        _showVoiceError(messenger, l10n, e);
      } finally {
        if (mounted) setState(() => _voicePhase = _VoicePhase.idle);
      }
      return;
    }

    try {
      await _voice.start();
      if (!mounted) return;
      setState(() => _voicePhase = _VoicePhase.recording);
    } catch (e) {
      if (!mounted) return;
      _showVoiceError(messenger, l10n, e);
      setState(() => _voicePhase = _VoicePhase.idle);
    }
  }

  int _remainingSlots(SubscriptionProvider sub) =>
      sub.maxAttachmentsPerMessage - _pendingAttachments.length;

  Future<void> _openAttachSheet(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final l10n = AppLocalizations.of(context)!;
    final sub = context.read<SubscriptionProvider>();
    if (_remainingSlots(sub) <= 0) {
      final msg = sub.tier == SubscriptionTier.free
          ? l10n.attachmentLimitReachedFree
          : l10n.attachmentLimitReachedPro;
      messenger.showSnackBar(SnackBar(content: Text(msg)));
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        final sheetL10n = AppLocalizations.of(ctx)!;
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: Text(
                  sheetL10n.attachSheetTitle,
                  style: Theme.of(ctx).textTheme.titleMedium,
                ),
              ),
              ListTile(
                leading: const Icon(Icons.photo_camera_outlined),
                title: Text(sheetL10n.attachFromCamera),
                onTap: () {
                  Navigator.pop(ctx);
                  unawaited(_pickCamera(context, sub));
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: Text(sheetL10n.attachFromGallery),
                onTap: () {
                  Navigator.pop(ctx);
                  unawaited(_pickGallery(context, sub));
                },
              ),
              ListTile(
                leading: const Icon(Icons.attach_file_rounded),
                title: Text(sheetL10n.attachDocument),
                onTap: () {
                  Navigator.pop(ctx);
                  unawaited(_pickDocuments(context, sub));
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  Future<void> _pickCamera(
    BuildContext context,
    SubscriptionProvider sub,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final l10n = AppLocalizations.of(context)!;
    if (_remainingSlots(sub) <= 0) return;
    final hasCamera = await hasCameraDevice();
    if (!mounted) return;
    if (!hasCamera) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.attachmentNoCamera)));
      return;
    }
    try {
      final list = await _attachments.pickFromCamera();
      if (!mounted || list.isEmpty) return;
      setState(() => _pendingAttachments.add(list.first));
    } catch (e) {
      if (!mounted) return;
      _showAttachmentError(messenger, l10n, e);
    }
  }

  Future<void> _pickGallery(
    BuildContext context,
    SubscriptionProvider sub,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final l10n = AppLocalizations.of(context)!;
    final n = _remainingSlots(sub);
    if (n <= 0) return;
    try {
      final list = await _attachments.pickFromGallery(maxCount: n);
      if (!mounted || list.isEmpty) return;
      setState(() {
        for (final a in list) {
          if (_pendingAttachments.length >= sub.maxAttachmentsPerMessage) break;
          _pendingAttachments.add(a);
        }
      });
    } catch (e) {
      if (!mounted) return;
      _showAttachmentError(messenger, l10n, e);
    }
  }

  Future<void> _pickDocuments(
    BuildContext context,
    SubscriptionProvider sub,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final l10n = AppLocalizations.of(context)!;
    final n = _remainingSlots(sub);
    if (n <= 0) return;
    try {
      final list = await _attachments.pickDocuments(maxCount: n);
      if (!mounted || list.isEmpty) return;
      setState(() {
        for (final a in list) {
          if (_pendingAttachments.length >= sub.maxAttachmentsPerMessage) break;
          _pendingAttachments.add(a);
        }
      });
    } catch (e) {
      if (!mounted) return;
      _showAttachmentError(messenger, l10n, e);
    }
  }

  Widget _pendingStrip(BuildContext context) {
    if (_pendingAttachments.isEmpty) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      height: 76,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.only(bottom: 8),
        itemCount: _pendingAttachments.length,
        separatorBuilder: (context, index) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final a = _pendingAttachments[i];
          final innerBottomPad = a.kind == AttachmentKind.image ? 28.0 : 8.0;
          return Material(
            color: scheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              width: 120,
              child: Stack(
                children: [
                  Padding(
                    padding: EdgeInsets.fromLTRB(8, 8, 8, innerBottomPad),
                    child: Align(
                      alignment: Alignment.center,
                      child: a.kind == AttachmentKind.image
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: AspectRatio(
                                aspectRatio: 1,
                                child: localImageFile(
                                  a.localPath,
                                  fit: BoxFit.cover,
                                  width: double.infinity,
                                  height: double.infinity,
                                ),
                              ),
                            )
                          : Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Icon(
                                  a.kind == AttachmentKind.pdf
                                      ? Icons.picture_as_pdf_outlined
                                      : Icons.description_outlined,
                                  size: 24,
                                  color: scheme.primary,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    a.name,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    textAlign: TextAlign.start,
                                    style: Theme.of(
                                      context,
                                    ).textTheme.labelSmall,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                  Positioned(
                    top: 0,
                    right: 0,
                    child: IconButton(
                      iconSize: 20,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints.tightFor(
                        width: 32,
                        height: 32,
                      ),
                      visualDensity: VisualDensity.compact,
                      icon: Icon(Icons.close, color: scheme.onSurfaceVariant),
                      onPressed: () {
                        setState(() => _pendingAttachments.removeAt(i));
                      },
                    ),
                  ),
                  if (a.kind == AttachmentKind.image)
                    Positioned(
                      left: 8,
                      right: 8,
                      bottom: 8,
                      child: Text(
                        a.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                    ),
                ],
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
    final chat = context.watch<ChatProvider>();
    final theme = Theme.of(context);
    context.watch<SubscriptionProvider>();
    final messages = chat.activeSession?.messages ?? const [];
    _scrollToEnd();

    final textTrimmed = _controller.text.trim();
    final canSend =
        !chat.isSending &&
        _voicePhase != _VoicePhase.transcribing &&
        textTrimmed.isNotEmpty;

    return BackgroundScaffold(
      variant: BackgroundVariant.plain,
      appBar: const ChatTopBar(),
      drawer: ChatHistoryDrawer(
        sessions: chat.sessions,
        activeSessionId: chat.activeSession?.id,
        onSelect: (id) {
          Navigator.of(context).pop();
          unawaited(context.read<ChatProvider>().selectSession(id));
        },
        onNewChat: () {
          Navigator.of(context).pop();
          unawaited(context.read<ChatProvider>().newSession());
        },
        onDelete: (session) =>
            context.read<ChatProvider>().deleteSession(session.id),
      ),
      body: Column(
        children: [
          Expanded(
            child: messages.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        l10n.chatEmptyStateBody,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 16,
                    ),
                    itemCount: messages.length,
                    itemBuilder: (context, i) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: MessageBubble(message: messages[i]),
                      );
                    },
                  ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _pendingStrip(context),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(32),
                      border: Border.all(color: Colors.black12),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 4,
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        IconButton(
                          tooltip: l10n.attachTooltip,
                          onPressed:
                              chat.isSending ||
                                  _voicePhase == _VoicePhase.transcribing
                              ? null
                              : () => unawaited(_openAttachSheet(context)),
                          icon: const Icon(
                            Icons.attach_file_rounded,
                            color: Colors.black54,
                          ),
                        ),
                        Expanded(
                          child: TextField(
                            controller: _controller,
                            enabled: _voicePhase != _VoicePhase.transcribing,
                            minLines: 1,
                            maxLines: 5,
                            textAlignVertical: TextAlignVertical.center,
                            textInputAction: TextInputAction.send,
                            onSubmitted: (_) =>
                                canSend ? unawaited(_send(context)) : null,
                            onChanged: (_) => setState(() {}),
                            style: const TextStyle(color: Colors.black87),
                            decoration: InputDecoration(
                              isDense: true,
                              hintText: l10n.chatHintDescribeWhatHappened,
                              hintStyle: const TextStyle(color: Colors.black38),
                              border: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              focusedBorder: InputBorder.none,
                              fillColor: Colors.transparent,
                              filled: false,
                              contentPadding: const EdgeInsets.symmetric(
                                vertical: 12,
                              ),
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip: l10n.voiceInputTooltip,
                          style: _voicePhase == _VoicePhase.recording
                              ? IconButton.styleFrom(
                                  foregroundColor: theme.colorScheme.error,
                                )
                              : null,
                          onPressed:
                              chat.isSending ||
                                  _voicePhase == _VoicePhase.transcribing
                              ? null
                              : () => _onMicPressed(context),
                          icon: switch (_voicePhase) {
                            _VoicePhase.transcribing => const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                            _VoicePhase.recording => const Icon(
                              Icons.stop_circle,
                              color: Colors.red,
                            ),
                            _VoicePhase.idle => const Icon(
                              Icons.mic_none_rounded,
                              color: Colors.black54,
                            ),
                          },
                        ),
                        Container(
                          margin: const EdgeInsets.only(right: 4),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: canSend || chat.isSending
                                ? const Color(0xFF2563EB)
                                : Colors.black12,
                          ),
                          child: IconButton(
                            onPressed: canSend
                                ? () => unawaited(_send(context))
                                : null,
                            icon: chat.isSending
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(
                                    Icons.send_rounded,
                                    color: Colors.white,
                                    size: 18,
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 8, bottom: 8),
                    child: Text(
                      l10n.legalDisclaimerFull,
                      textAlign: TextAlign.center,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontSize: MediaQuery.sizeOf(context).width < 360
                            ? 9
                            : 10,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _send(BuildContext context) async {
    final textSnap = _controller.text;
    final trimmed = textSnap.trim();
    if (trimmed.isEmpty) return;

    final chatProv = context.read<ChatProvider>();
    final languageCode = effectiveAppLanguageCode(context);
    final messenger = ScaffoldMessenger.of(context);

    if (_voicePhase == _VoicePhase.recording) {
      await _voice.cancel();
      if (!mounted) return;
      setState(() => _voicePhase = _VoicePhase.idle);
    }

    final toSend = List<ChatAttachment>.from(_pendingAttachments);
    _controller.clear();
    setState(() => _pendingAttachments.clear());

    await chatProv.sendMessage(
      textSnap,
      attachments: toSend,
      languageCode: languageCode,
    );

    if (mounted && chatProv.errorMessage != null) {
      final error = chatProv.errorMessage!;
      messenger.showSnackBar(SnackBar(content: Text(error)));
    }
  }
}
