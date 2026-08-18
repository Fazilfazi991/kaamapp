import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../supabase/supabase_service.dart';

enum KaamEnvironment { development, staging, production }

/// Public values only. Never put credentials or tokens in remote configuration.
class AppRemoteConfig {
  const AppRemoteConfig(this._values);

  static const defaults = AppRemoteConfig({
    'maintenance_mode': false,
    'maintenance_title': 'We’ll be back soon',
    'maintenance_message':
        'KAAM is undergoing scheduled maintenance. Please try again shortly.',
    'minimum_supported_version': '',
    'latest_available_version': '',
    'force_update_enabled': false,
    'flexible_update_enabled': true,
    'feature_google_sign_in': true,
    'feature_push_notifications': true,
    'feature_candidate_registration': true,
    'feature_employer_registration': true,
    'maximum_candidate_skills': 20,
    'candidate_membership_price_aed': 0,
    'support_whatsapp_number': '',
    'announcement_enabled': false,
    'announcement_title': '',
    'announcement_message': '',
  });

  final Map<String, Object?> _values;

  bool get maintenanceMode => boolValue('maintenance_mode');
  String get maintenanceTitle => stringValue('maintenance_title');
  String get maintenanceMessage => stringValue('maintenance_message');
  String get minimumSupportedVersion =>
      stringValue('minimum_supported_version');
  String get latestAvailableVersion => stringValue('latest_available_version');
  bool get forceUpdateEnabled => boolValue('force_update_enabled');
  bool get flexibleUpdateEnabled => boolValue('flexible_update_enabled');
  bool boolValue(String key) => _values[key] is bool
      ? _values[key]! as bool
      : defaults._values[key] as bool? ?? false;
  int intValue(String key) => _values[key] is int
      ? _values[key]! as int
      : defaults._values[key] as int? ?? 0;
  String stringValue(String key) => _values[key] is String
      ? _values[key]! as String
      : defaults._values[key] as String? ?? '';
  Map<String, Object?> toJson() => Map.unmodifiable(_values);

  AppRemoteConfig merge(Map<String, Object?> incoming) =>
      AppRemoteConfig({..._values, ...incoming});

  static AppRemoteConfig fromJson(Map<String, Object?> values) {
    final accepted = <String, Object?>{};
    for (final entry in values.entries) {
      final expected = defaults._values[entry.key];
      if (expected != null && entry.value.runtimeType == expected.runtimeType) {
        accepted[entry.key] = entry.value;
      }
    }
    return defaults.merge(accepted);
  }
}

class AppRemoteConfigService extends ChangeNotifier {
  static const _maximumCacheAge = Duration(days: 7);
  AppRemoteConfigService({
    KaamEnvironment? environment,
    Future<SharedPreferences> Function()? preferences,
    Duration timeout = const Duration(seconds: 3),
  })  : _environment = environment ?? _environmentFromDefine(),
        _preferences = preferences ?? SharedPreferences.getInstance,
        _timeout = timeout;

  final KaamEnvironment _environment;
  final Future<SharedPreferences> Function() _preferences;
  final Duration _timeout;
  AppRemoteConfig _config = AppRemoteConfig.defaults;
  bool _refreshing = false;
  AppRemoteConfig get config => _config;
  bool get isRefreshing => _refreshing;
  String get _cacheKey => 'kaam_remote_config_${_environment.name}';

  Future<void> initialize() async {
    await _loadCache();
    unawaited(refresh());
  }

  Future<void> refresh() async {
    if (_refreshing) {
      return;
    }
    _refreshing = true;
    notifyListeners();
    try {
      final client = SupabaseService.maybeClient;
      if (client == null) {
        return;
      }
      final rows = await client
          .from('app_config')
          .select('config_key, config_value')
          .eq('environment', _environment.name)
          .inFilter('platform', const ['android', 'all'])
          .eq('enabled', true)
          .timeout(_timeout);
      final values = <String, Object?>{};
      for (final row in rows as List<dynamic>) {
        final map = row as Map<String, dynamic>;
        final value = map['config_value'];
        if (value is bool || value is int || value is String) {
          values[map['config_key'] as String] = value;
        }
      }
      _config = AppRemoteConfig.fromJson(values);
      await _saveCache();
    } on Object catch (error) {
      if (kDebugMode) {
        debugPrint('[RemoteConfig] refresh failed: ${error.runtimeType}');
      }
    } finally {
      _refreshing = false;
      notifyListeners();
    }
  }

  Future<void> _loadCache() async {
    try {
      final raw = (await _preferences()).getString(_cacheKey);
      if (raw == null) {
        return;
      }
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        final cachedValues = decoded['values'];
        final fetchedAt =
            DateTime.tryParse(decoded['fetchedAt'] as String? ?? '');
        if (cachedValues is Map<String, dynamic> &&
            fetchedAt != null &&
            DateTime.now().toUtc().difference(fetchedAt.toUtc()) <=
                _maximumCacheAge) {
          _config = AppRemoteConfig.fromJson(cachedValues);
        }
      }
    } on Object {
      // Invalid local state must never prevent startup.
    }
  }

  Future<void> _saveCache() async {
    try {
      await (await _preferences()).setString(
        _cacheKey,
        jsonEncode({
          'fetchedAt': DateTime.now().toUtc().toIso8601String(),
          'values': _config.toJson(),
        }),
      );
    } on Object {
      // Cache writes are optional.
    }
  }

  static KaamEnvironment _environmentFromDefine() {
    const value =
        String.fromEnvironment('KAAM_ENVIRONMENT', defaultValue: 'production');
    for (final environment in KaamEnvironment.values) {
      if (environment.name == value) {
        return environment;
      }
    }
    return KaamEnvironment.production;
  }
}

class SemanticVersion implements Comparable<SemanticVersion> {
  const SemanticVersion(this.major, this.minor, this.patch);
  final int major;
  final int minor;
  final int patch;
  static SemanticVersion? tryParse(String value) {
    final match =
        RegExp(r'^v?(\d+)\.(\d+)\.(\d+)(?:[-+].*)?$').firstMatch(value.trim());
    if (match == null) {
      return null;
    }
    return SemanticVersion(
        int.parse(match[1]!), int.parse(match[2]!), int.parse(match[3]!));
  }

  @override
  int compareTo(SemanticVersion other) => major != other.major
      ? major.compareTo(other.major)
      : minor != other.minor
          ? minor.compareTo(other.minor)
          : patch.compareTo(other.patch);
}
