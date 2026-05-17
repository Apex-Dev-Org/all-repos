import 'package:aithiya_mobile/features/chat/models/chat_attachment.dart';
import 'package:aithiya_mobile/features/chat/models/chat_message.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('ChatMessage JSON round-trip with attachments', () {
    final attachment = ChatAttachment(
      id: 'a1',
      name: 'doc.pdf',
      mimeType: 'application/pdf',
      sizeBytes: 1024,
      localPath: '/tmp/doc.pdf',
      kind: AttachmentKind.pdf,
    );
    final message = ChatMessage(
      id: 'm1',
      role: 'user',
      content: 'See attached',
      createdAt: DateTime.utc(2025, 1, 15, 12),
      citations: const ['c1'],
      attachments: [attachment],
    );

    final restored = ChatMessage.fromJson(message.toJson());

    expect(restored.id, message.id);
    expect(restored.role, message.role);
    expect(restored.content, message.content);
    expect(restored.createdAt.toIso8601String(), message.createdAt.toIso8601String());
    expect(restored.citations, message.citations);
    expect(restored.attachments.length, 1);
    expect(restored.attachments.first.id, attachment.id);
    expect(restored.attachments.first.name, attachment.name);
    expect(restored.attachments.first.mimeType, attachment.mimeType);
    expect(restored.attachments.first.sizeBytes, attachment.sizeBytes);
    expect(restored.attachments.first.localPath, attachment.localPath);
    expect(restored.attachments.first.kind, attachment.kind);
  });

  test('ChatMessage legacy JSON without attachments deserializes to empty list', () {
    final restored = ChatMessage.fromJson({
      'id': 'm2',
      'role': 'assistant',
      'content': 'Hi',
      'createdAt': '2025-01-01T00:00:00.000Z',
      'citations': <String>[],
    });
    expect(restored.attachments, isEmpty);
  });
}
