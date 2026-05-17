import 'dart:convert';
import 'dart:io' show File;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';

import '../../../config/env.dart';

/// Microphone or OS permission was denied for recording.
class VoiceInputPermissionDenied implements Exception {
  VoiceInputPermissionDenied([this.message = 'Microphone permission denied']);
  final String message;
  @override
  String toString() => message;
}

/// [ELEVENLABS_API_KEY] is missing from `.env`.
class VoiceInputMissingApiKey implements Exception {
  VoiceInputMissingApiKey(
      [this.message = 'ELEVENLABS_API_KEY is not configured']);
  final String message;
  @override
  String toString() => message;
}

/// The transcription API returned no usable text.
class VoiceInputEmptyTranscript implements Exception {
  VoiceInputEmptyTranscript([this.message = 'Empty transcription']);
  final String message;
  @override
  String toString() => message;
}

/// ElevenLabs or network error during transcription.
class VoiceInputApiException implements Exception {
  VoiceInputApiException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Records audio locally and transcribes via ElevenLabs Speech-to-Text (Scribe).
///
/// TODO(security): CRITICAL - For local testing ONLY. Do not release this to production!
/// The current implementation embeds the ELEVENLABS_API_KEY directly in the app.
/// Best Practice: Before publishing, you MUST proxy this transcription request 
/// through a secure backend (e.g., a Supabase Edge Function or dedicated server). 
/// Your backend should hold the ElevenLabs API key and handle the request to 
/// prevent malicious users from extracting your key from the app binary.
class VoiceInputService {
  VoiceInputService() : _recorder = AudioRecorder();

  final AudioRecorder _recorder;
  String? _currentPath;

  /// Starts recording.
  ///
  /// On native platforms the recording is written to a temporary AAC file.
  /// On Flutter web `path_provider` and `dart:io` are unavailable, so the
  /// `record` plugin uses `MediaRecorder` and returns a blob URL on stop().
  Future<void> start() async {
    final status = await Permission.microphone.request();
    if (!status.isGranted) {
      throw VoiceInputPermissionDenied();
    }

    if (kIsWeb) {
      _currentPath = null;
      // Browsers' MediaRecorder commonly produces webm/opus; let the plugin
      // pick the supported MIME type. `path` is required by the API but
      // ignored for the web implementation.
      await _recorder.start(
        const RecordConfig(encoder: AudioEncoder.opus),
        path: '',
      );
      return;
    }

    final dir = await getTemporaryDirectory();
    final path =
        '${dir.path}/aithiya_${DateTime.now().millisecondsSinceEpoch}.m4a';
    _currentPath = path;

    await _recorder.start(
      const RecordConfig(encoder: AudioEncoder.aacLc),
      path: path,
    );
  }

  /// Stops recording, uploads audio to ElevenLabs, returns transcript text.
  ///
  /// [languageCode] should be a short ISO code (`en`, `si`) when known;
  /// pass `null` for automatic language detection.
  Future<String> stop({String? languageCode}) async {
    final stoppedPath = await _recorder.stop();
    final filePath = stoppedPath ?? _currentPath;
    _currentPath = null;

    if (filePath == null || filePath.isEmpty) {
      throw VoiceInputApiException('Recording file not found');
    }

    final apiKey = Env.elevenLabsApiKey;
    if (apiKey.isEmpty) {
      await _safeDelete(filePath);
      throw VoiceInputMissingApiKey();
    }

    try {
      final uri = Uri.parse('https://api.elevenlabs.io/v1/speech-to-text');
      final request = http.MultipartRequest('POST', uri)
        ..headers['xi-api-key'] = apiKey
        ..fields['model_id'] = 'scribe_v1'
        ..fields['tag_audio_events'] = 'false'
        ..fields['diarize'] = 'false';

      if (languageCode != null &&
          languageCode.isNotEmpty &&
          {'en', 'si'}.contains(languageCode)) {
        request.fields['language_code'] = languageCode;
      }

      request.files.add(await _buildMultipartFile(filePath));

      final streamed = await request.send();
      final response = await http.Response.fromStream(streamed);

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw VoiceInputApiException(
          'Transcription failed (${response.statusCode}): ${response.body}',
        );
      }

      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        throw VoiceInputApiException('Unexpected transcription response');
      }

      final text = decoded['text'] as String?;
      final trimmed = text?.trim() ?? '';
      if (trimmed.isEmpty) {
        throw VoiceInputEmptyTranscript();
      }
      return trimmed;
    } finally {
      await _safeDelete(filePath);
    }
  }

  /// Builds a multipart file from either a native file path or a web blob URL.
  Future<http.MultipartFile> _buildMultipartFile(String filePath) async {
    if (kIsWeb) {
      // On web, `record` returns a `blob:` URL; fetch it to get bytes.
      final blobResponse = await http.get(Uri.parse(filePath));
      if (blobResponse.statusCode < 200 || blobResponse.statusCode >= 300) {
        throw VoiceInputApiException(
          'Could not read recorded audio blob (${blobResponse.statusCode})',
        );
      }
      return http.MultipartFile.fromBytes(
        'file',
        blobResponse.bodyBytes,
        filename: 'recording.webm',
      );
    }

    if (!File(filePath).existsSync()) {
      throw VoiceInputApiException('Recording file not found');
    }
    return http.MultipartFile.fromPath(
      'file',
      filePath,
      filename: 'recording.m4a',
    );
  }

  /// Discard recording without transcribing.
  Future<void> cancel() async {
    final stoppedPath = await _recorder.stop();
    final path = stoppedPath ?? _currentPath;
    _currentPath = null;
    if (path != null) {
      await _safeDelete(path);
    }
  }

  Future<void> dispose() async {
    await cancel();
    await _recorder.dispose();
  }

  Future<void> _safeDelete(String path) async {
    if (kIsWeb) return;
    try {
      final f = File(path);
      if (await f.exists()) {
        await f.delete();
      }
    } catch (_) {}
  }
}
