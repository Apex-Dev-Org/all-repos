import 'dart:typed_data';

/// Only used when [kIsWeb] in the picker; VM/Android/iOS use file paths instead.
String createBlobObjectUrl(Uint8List bytes, String mimeType) {
  throw StateError('createBlobObjectUrl is web-only');
}