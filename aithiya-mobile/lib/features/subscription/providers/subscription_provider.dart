import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/api/api_client.dart';
import '../../../core/services/logger_service.dart';

enum SubscriptionTier { free, pro, ultra }

class SubscriptionProvider extends ChangeNotifier {
  SubscriptionProvider(this._prefs, {required ApiClient apiClient})
    : _apiClient = apiClient {
    final raw = _prefs.getString(_prefsKey);
    _tier = _tierFromString(raw);
    _status = _prefs.getString(_statusPrefsKey);

    _authSubscription = Supabase.instance.client.auth.onAuthStateChange.listen((
      _,
    ) {
      unawaited(refresh());
    });
    unawaited(refresh());
  }

  static const _prefsKey = 'subscription_tier_v1';
  static const _statusPrefsKey = 'subscription_status_v1';

  final SharedPreferences _prefs;
  final ApiClient _apiClient;
  late final StreamSubscription<AuthState> _authSubscription;

  SubscriptionTier _tier = SubscriptionTier.free;
  String? _status;
  bool _isLoading = false;
  String? _errorMessage;

  SubscriptionTier get tier => _tier;
  String? get status => _status;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isPaid => _tier != SubscriptionTier.free && _status == 'active';

  /// Free: 1 attachment per send; paid plans: 5 per send.
  int get maxAttachmentsPerMessage => isPaid ? 5 : 1;

  Future<void> refresh() async {
    if (Supabase.instance.client.auth.currentSession == null) {
      await _applyBackendPlan(SubscriptionTier.free, null);
      _errorMessage = null;
      _isLoading = false;
      notifyListeners();
      return;
    }

    _isLoading = true;
    notifyListeners();

    try {
      final response = await _apiClient.get('/auth/me');
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception(ApiClient.errorMessage(response));
      }

      final decoded = response.body.isEmpty ? null : jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('Backend profile response was invalid.');
      }

      await _applyBackendPlan(
        _tierFromString(decoded['plan']?.toString()),
        _statusFromString(decoded['subscription_status']?.toString()),
      );
      _errorMessage = null;
    } catch (e, st) {
      AppLogger.instance.error('Failed to sync subscription plan', e, st);
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _applyBackendPlan(SubscriptionTier tier, String? status) async {
    _tier = tier;
    _status = status;
    await _prefs.setString(_prefsKey, _tierToString(tier));
    if (status == null || status.isEmpty) {
      await _prefs.remove(_statusPrefsKey);
    } else {
      await _prefs.setString(_statusPrefsKey, status);
    }
  }

  static SubscriptionTier _tierFromString(String? value) {
    switch (value?.toLowerCase().trim()) {
      case 'pro':
        return SubscriptionTier.pro;
      case 'ultra':
        return SubscriptionTier.ultra;
      default:
        return SubscriptionTier.free;
    }
  }

  static String? _statusFromString(String? value) {
    final normalized = value?.toLowerCase().trim();
    switch (normalized) {
      case 'pending':
      case 'active':
      case 'on_hold':
      case 'cancelled':
      case 'expired':
      case 'failed':
        return normalized;
      default:
        return null;
    }
  }

  static String _tierToString(SubscriptionTier tier) {
    switch (tier) {
      case SubscriptionTier.free:
        return 'free';
      case SubscriptionTier.pro:
        return 'pro';
      case SubscriptionTier.ultra:
        return 'ultra';
    }
  }

  @override
  void dispose() {
    unawaited(_authSubscription.cancel());
    super.dispose();
  }
}
