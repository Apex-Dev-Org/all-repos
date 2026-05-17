/// Classifies an attachment for display and routing to the backend.
enum AttachmentKind { image, pdf, document, other }

AttachmentKind attachmentKindFromString(String? raw) {
  if (raw == null || raw.isEmpty) return AttachmentKind.other;
  for (final v in AttachmentKind.values) {
    if (v.name == raw) return v;
  }
  return AttachmentKind.other;
}

/// Local file attachment metadata persisted with chat messages.
class ChatAttachment {
  const ChatAttachment({
    required this.id,
    required this.name,
    required this.mimeType,
    required this.sizeBytes,
    required this.localPath,
    required this.kind,
  });

  final String id;
  final String name;
  final String mimeType;
  final int sizeBytes;

  /// Absolute path on device (mock pipeline); uploads will stream from here.
  final String localPath;
  final AttachmentKind kind;

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'mimeType': mimeType,
    'sizeBytes': sizeBytes,
    'localPath': localPath,
    'kind': kind.name,
  };

  factory ChatAttachment.fromJson(Map<String, dynamic> json) {
    return ChatAttachment(
      id: json['id'] as String,
      name: json['name'] as String,
      mimeType: json['mimeType'] as String? ?? 'application/octet-stream',
      sizeBytes: (json['sizeBytes'] as num?)?.toInt() ?? 0,
      localPath: json['localPath'] as String,
      kind: attachmentKindFromString(json['kind'] as String?),
    );
  }

  ChatAttachment copyWith({
    String? id,
    String? name,
    String? mimeType,
    int? sizeBytes,
    String? localPath,
    AttachmentKind? kind,
  }) {
    return ChatAttachment(
      id: id ?? this.id,
      name: name ?? this.name,
      mimeType: mimeType ?? this.mimeType,
      sizeBytes: sizeBytes ?? this.sizeBytes,
      localPath: localPath ?? this.localPath,
      kind: kind ?? this.kind,
    );
  }

  /// Infers kind from lowercase file name extension.
  static AttachmentKind kindFromFilename(String filename) {
    final lower = filename.toLowerCase();
    if (lower.endsWith('.jpg') ||
        lower.endsWith('.jpeg') ||
        lower.endsWith('.png') ||
        lower.endsWith('.gif') ||
        lower.endsWith('.webp') ||
        lower.endsWith('.heic')) {
      return AttachmentKind.image;
    }
    if (lower.endsWith('.pdf')) return AttachmentKind.pdf;
    if (lower.endsWith('.doc') ||
        lower.endsWith('.docx') ||
        lower.endsWith('.txt') ||
        lower.endsWith('.md') ||
        lower.endsWith('.markdown')) {
      return AttachmentKind.document;
    }
    return AttachmentKind.other;
  }
}
