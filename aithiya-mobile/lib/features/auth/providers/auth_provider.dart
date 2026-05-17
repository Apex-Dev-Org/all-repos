import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/api/api_client.dart';
import '../../../core/services/logger_service.dart';
import '../data/auth_repository.dart';

enum AuthStatus { unknown, authenticated, unauthenticated }

enum SignUpResult { signedIn, emailConfirmationRequired }

class AuthProvider extends ChangeNotifier {
  AuthProvider({required AuthRepository repository, ApiClient? apiClient})
    : _repository = repository,
      _apiClient = apiClient {
    _subscription = _repository.onAuthStateChange.listen((data) {
      _applySession(data.session);
    });
    _applySession(_repository.currentSession);
  }

  final AuthRepository _repository;
  final ApiClient? _apiClient;
  late final StreamSubscription<AuthState> _subscription;
  Map<String, dynamic>? _backendProfile;

  /// Latest payload from `GET /api/v1/auth/me`, or `null` if unavailable.
  Map<String, dynamic>? get backendProfile => _backendProfile;

  AuthStatus _status = AuthStatus.unknown;
  User? _user;
  String? _errorMessage;
  bool _isBusy = false;

  AuthStatus get status => _status;
  User? get user => _user;
  String? get errorMessage => _errorMessage;
  bool get isBusy => _isBusy;

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  void _applySession(Session? session) {
    if (session != null) {
      _status = AuthStatus.authenticated;
      _user = session.user;
      unawaited(_syncBackendProfile());
    } else {
      _status = AuthStatus.unauthenticated;
      _user = null;
      _backendProfile = null;
    }
    notifyListeners();
  }

  /// Verifies that the FastAPI backend recognizes the Supabase JWT by hitting
  /// `GET /api/v1/auth/me`. Non-blocking and never throws to the UI; we only
  /// log failures so that an offline backend does not break sign-in.
  Future<void> _syncBackendProfile() async {
    final api = _apiClient;
    if (api == null) return;
    try {
      final response = await api.get('/auth/me');
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final decoded = response.body.isNotEmpty ? jsonDecode(response.body) : null;
        if (decoded is Map<String, dynamic>) {
          _backendProfile = decoded;
          notifyListeners();
        }
      } else {
        AppLogger.instance.warning(
          'Backend /auth/me check failed: HTTP ${response.statusCode}',
        );
      }
    } catch (e, st) {
      AppLogger.instance.error('Backend /auth/me check threw', e, st);
    }
  }

  Future<void> signInWithEmail({
    required String email,
    required String password,
  }) async {
    _errorMessage = null;
    _isBusy = true;
    notifyListeners();
    try {
      final response = await _repository.signInWithEmail(
        email: email,
        password: password,
      );
      if (response.session != null) {
        _applySession(response.session);
      }
    } on AuthException catch (e) {
      _errorMessage = e.message;
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isBusy = false;
      notifyListeners();
    }
  }

  Future<SignUpResult?> signUpWithEmail({
    required String email,
    required String password,
    String? displayName,
  }) async {
    _errorMessage = null;
    _isBusy = true;
    notifyListeners();
    try {
      final response = await _repository.signUpWithEmail(
        email: email,
        password: password,
        displayName: displayName,
      );
      if (response.session != null) {
        _applySession(response.session);
        return SignUpResult.signedIn;
      }
      if (response.user != null) {
        _applySession(null);
        return SignUpResult.emailConfirmationRequired;
      }
      _errorMessage = 'Could not create account. Please try again.';
      return null;
    } on AuthException catch (e, st) {
      AppLogger.instance.error('Sign up failed (AuthException)', e, st);
      _errorMessage = e.message;
      return null;
    } catch (e, st) {
      AppLogger.instance.error('Sign up failed', e, st);
      _errorMessage = e.toString();
      return null;
    } finally {
      _isBusy = false;
      notifyListeners();
    }
  }

  Future<void> signInWithGoogle() async {
    _errorMessage = null;
    _isBusy = true;
    notifyListeners();
    try {
      await _repository.signInWithGoogle();
    } on AuthException catch (e, st) {
      AppLogger.instance.error('Google sign-in failed (AuthException)', e, st);
      _errorMessage = e.message;
    } catch (e, st) {
      AppLogger.instance.error('Google sign-in failed', e, st);
      _errorMessage = e.toString();
    } finally {
      _isBusy = false;
      notifyListeners();
    }
  }

  Future<void> signOut() async {
    _errorMessage = null;
    _isBusy = true;
    notifyListeners();
    try {
      await _repository.signOut();
    } catch (e, st) {
      AppLogger.instance.error('Sign out failed', e, st);
      _errorMessage = e.toString();
    } finally {
      _isBusy = false;
      notifyListeners();
    }
  }

  Future<void> sendPasswordReset(String email) async {
    _errorMessage = null;
    _isBusy = true;
    notifyListeners();
    try {
      await _repository.sendPasswordReset(email);
    } on AuthException catch (e, st) {
      AppLogger.instance.error('Password reset failed', e, st);
      _errorMessage = e.message;
    } catch (e, st) {
      AppLogger.instance.error('Password reset failed', e, st);
      _errorMessage = e.toString();
    } finally {
      _isBusy = false;
      notifyListeners();
    }
  }

  Future<void> updateDisplayName(String name) async {
    _errorMessage = null;
    _isBusy = true;
    notifyListeners();
    try {
      await _repository.updateDisplayName(name);
      _user = _repository.currentUser;
    } on AuthException catch (e, st) {
      AppLogger.instance.error('Update display name failed', e, st);
      _errorMessage = e.message;
    } catch (e, st) {
      AppLogger.instance.error('Update display name failed', e, st);
      _errorMessage = e.toString();
    } finally {
      _isBusy = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    unawaited(_subscription.cancel());
    super.dispose();
  }
}
