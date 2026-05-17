import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Typed accessors for `.env` values (see [.env.example](.env.example)).
class Env {
  Env._();

  static String get supabaseUrl => dotenv.env['SUPABASE_URL']?.trim() ?? '';

  static String get supabaseAnonKey =>
      dotenv.env['SUPABASE_ANON_KEY']?.trim() ?? '';

  /// OAuth callback URL used by Supabase Auth to return to the app.
  static String get authRedirectUrl {
    final raw = dotenv.env['AUTH_REDIRECT_URL']?.trim();
    return raw == null || raw.isEmpty ? 'aithiya://auth-callback' : raw;
  }

  /// FastAPI backend root URL, without the version prefix.
  ///
  /// `10.0.2.2` lets the Android emulator reach a backend running on the host
  /// machine. Override this in `.env` for iOS simulator, physical devices, or
  /// hosted environments.
  static String get apiBaseUrl {
    final raw = dotenv.env['API_BASE_URL']?.trim();
    return raw == null || raw.isEmpty ? 'http://10.0.2.2:8000' : raw;
  }

  static String get apiV1Prefix {
    final raw = dotenv.env['API_V1_PREFIX']?.trim();
    return raw == null || raw.isEmpty ? '/api/v1' : raw;
  }

  /// ElevenLabs API key for speech-to-text (batch Scribe).
  ///
  /// TODO(security): Do not ship production keys in the client; proxy via your backend.
  static String get elevenLabsApiKey =>
      dotenv.env['ELEVENLABS_API_KEY']?.trim() ?? '';
}
