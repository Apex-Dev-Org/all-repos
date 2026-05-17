import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';

import '../io/blob_url_util.dart';
import '../models/chat_attachment.dart';

/// Picked attachment exceeds per-file size limits.
class AttachmentTooLarge implements Exception {
  AttachmentTooLarge(this.maxBytes);

  /// Configured ceiling in bytes (e.g. [AttachmentPickerService.maxBytesPerFileDefault]).
  final int maxBytes;

  @override
  String toString() => 'AttachmentTooLarge(${maxBytes}B)';
}

/// User cancelled picking or picker failed.
class AttachmentPickFailed implements Exception {
  AttachmentPickFailed([this.message = 'Pick failed']);

  final String message;

  @override
  String toString() => message;
}

/// Typed like [VoiceInputPermissionDenied]; reserved for picker permission issues.
class AttachmentPermissionDenied implements Exception {
  AttachmentPermissionDenied([
    this.message = 'Camera or storage permission denied',
  ]);

  final String message;

  @override
  String toString() => message;
}

/// Picks attachments for composer; validates size before returning.
class AttachmentPickerService {
  AttachmentPickerService({
    ImagePicker? imagePicker,
    Uuid? uuid,
    int maxBytesPerFile = maxBytesPerFileDefault,
  }) : _picker = imagePicker ?? ImagePicker(),
       _uuid = uuid ?? const Uuid(),
       _maxBytes = maxBytesPerFile;

  /// Default per-file ceiling (25 MB).
  static const int maxBytesPerFileDefault = 25 * 1024 * 1024;

  final ImagePicker _picker;
  final Uuid _uuid;
  final int _maxBytes;

  /// Single photo from device camera.
  Future<List<ChatAttachment>> pickFromCamera() async {
    XFile? x;
    try {
      x = await _picker.pickImage(source: ImageSource.camera, imageQuality: 85);
    } catch (e, st) {
      Error.throwWithStackTrace(AttachmentPickFailed(e.toString()), st);
    }
    if (x == null) return [];

    await _enforceLimit(x.path);

    final name = x.name.isNotEmpty
        ? x.name
        : 'camera_${DateTime.now().millisecondsSinceEpoch}.jpg';

    final len = await XFile(x.path).length();
    return [
      ChatAttachment(
        id: _uuid.v4(),
        name: name,
        mimeType: _mimeForFilename(name),
        sizeBytes: len,
        localPath: x.path,
        kind: ChatAttachment.kindFromFilename(name),
      ),
    ];
  }

  /// Up to [maxCount] images from gallery.
  Future<List<ChatAttachment>> pickFromGallery({required int maxCount}) async {
    if (maxCount <= 0) return [];
    List<XFile> files;
    try {
      // image_picker's `limit` must be >= 2; for single-image gallery picks
      // we use `pickImage(gallery)` instead, otherwise the platform-interface
      // throws ArgumentError("limit cannot be lower than 2").
      if (maxCount < 2) {
        final single = await _picker.pickImage(
          source: ImageSource.gallery,
          imageQuality: 85,
        );
        files = single == null ? <XFile>[] : <XFile>[single];
      } else {
        files = await _picker.pickMultiImage(imageQuality: 85, limit: maxCount);
      }
    } catch (e, st) {
      Error.throwWithStackTrace(AttachmentPickFailed(e.toString()), st);
    }

    final clipped = files.length > maxCount
        ? files.sublist(0, maxCount)
        : [...files];

    final out = <ChatAttachment>[];
    for (final x in clipped) {
      await _enforceLimit(x.path);
      final name = x.name.isNotEmpty ? x.name : '${_uuid.v4()}.jpg';
      final len = await XFile(x.path).length();
      out.add(
        ChatAttachment(
          id: _uuid.v4(),
          name: name,
          mimeType: _mimeForFilename(name),
          sizeBytes: len,
          localPath: x.path,
          kind: ChatAttachment.kindFromFilename(name),
        ),
      );
    }
    return out;
  }

  /// Documents accepted by the backend: PDF, DOCX, plain text, and markdown.
  Future<List<ChatAttachment>> pickDocuments({required int maxCount}) async {
    if (maxCount <= 0) return [];
    FilePickerResult? result;
    try {
      result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['pdf', 'docx', 'txt', 'md', 'markdown'],
        allowMultiple: true,
        withData: kIsWeb,
      );
    } catch (e, st) {
      Error.throwWithStackTrace(AttachmentPickFailed(e.toString()), st);
    }
    if (result == null || result.files.isEmpty) return [];

    final out = <ChatAttachment>[];
    for (final p in result.files) {
      if (out.length >= maxCount) break;

      if (kIsWeb) {
        final bytes = p.bytes;
        if (bytes == null || bytes.isEmpty) {
          continue;
        }
        if (bytes.length > _maxBytes) {
          throw AttachmentTooLarge(_maxBytes);
        }
        final name = (p.name.isNotEmpty) ? p.name : 'attachment_${_uuid.v4()}';
        final mime = _mimeForFilename(name);
        final url = createBlobObjectUrl(bytes, mime);
        out.add(
          ChatAttachment(
            id: _uuid.v4(),
            name: name,
            mimeType: mime,
            sizeBytes: bytes.length,
            localPath: url,
            kind: ChatAttachment.kindFromFilename(name),
          ),
        );
        continue;
      }

      final path = p.path;
      if (path == null || path.isEmpty) {
        continue;
      }

      final name = (p.name.isNotEmpty)
          ? p.name
          : path.split('/').last.split(r'\').last;

      final reported = p.size;
      await _enforceLimit(
        path,
        pickerReportedBytes: reported > 0 ? reported : null,
      );

      final length = reported > 0 ? reported : await XFile(path).length();

      out.add(
        ChatAttachment(
          id: _uuid.v4(),
          name: name,
          mimeType: _mimeForFilename(name),
          sizeBytes: length,
          localPath: path,
          kind: ChatAttachment.kindFromFilename(name),
        ),
      );
    }
    return out;
  }

  Future<void> _enforceLimit(String path, {int? pickerReportedBytes}) async {
    final len = pickerReportedBytes != null && pickerReportedBytes > 0
        ? pickerReportedBytes
        : await XFile(path).length();
    if (len > _maxBytes) {
      throw AttachmentTooLarge(_maxBytes);
    }
  }

  static String _mimeForFilename(String name) {
    final lower = name.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.gif')) return 'image/gif';
    if (lower.endsWith('.webp')) return 'image/webp';
    if (lower.endsWith('.heic')) return 'image/heic';
    if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) {
      return 'image/jpeg';
    }
    if (lower.endsWith('.pdf')) return 'application/pdf';
    if (lower.endsWith('.doc')) return 'application/msword';
    if (lower.endsWith('.docx')) {
      return 'application/vnd.openxmlformats-officedocument.'
          'wordprocessingml.document';
    }
    if (lower.endsWith('.md') || lower.endsWith('.markdown')) {
      return 'text/markdown';
    }
    if (lower.endsWith('.txt')) return 'text/plain';
    return 'application/octet-stream';
  }
}
