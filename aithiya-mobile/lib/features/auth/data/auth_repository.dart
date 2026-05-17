import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../config/env.dart';

class AuthRepository {
  AuthRepository(this._client);

  final SupabaseClient _client;

  Session? get currentSession => _client.auth.currentSession;

  User? get currentUser => _client.auth.currentUser;

  Stream<AuthState> get onAuthStateChange => _client.auth.onAuthStateChange;

  Future<AuthResponse> signInWithEmail({
    required String email,
    required String password,
  }) {
    return _client.auth.signInWithPassword(email: email, password: password);
  }

  Future<AuthResponse> signUpWithEmail({
    required String email,
    required String password,
    String? displayName,
  }) {
    return _client.auth.signUp(
      email: email,
      password: password,
      emailRedirectTo: _authRedirectUrl,
      data: displayName != null && displayName.isNotEmpty
          ? {'full_name': displayName}
          : null,
    );
  }

  /// Google sign-in through Supabase OAuth. Supabase owns the provider
  /// credentials; the app only needs a callback URL.
  Future<void> signInWithGoogle() async {
    final launched = await _client.auth.signInWithOAuth(
      OAuthProvider.google,
      redirectTo: _authRedirectUrl,
    );
    if (!launched) {
      throw AuthException(
        'Could not open Google sign-in. Check your browser and redirect URL configuration.',
      );
    }
  }

  Future<void> signOut() async {
    await _client.auth.signOut();
  }

  Future<void> sendPasswordReset(String email) {
    return _client.auth.resetPasswordForEmail(email);
  }

  Future<void> updateDisplayName(String name) async {
    await _client.auth.updateUser(UserAttributes(data: {'full_name': name}));
  }

  String get _authRedirectUrl {
    if (!kIsWeb) return Env.authRedirectUrl;

    final base = Uri.base;
    return '${base.scheme}://${base.authority}/';
  }
}
