import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/app_config.dart';

class SupabaseService {
  const SupabaseService._();

  static bool _initialized = false;
  static Future<void>? _sessionRecovery;

  static bool get isEnabled => _initialized && AppConfig.hasSupabaseCredentials;

  static SupabaseClient? get maybeClient {
    if (!isEnabled) return null;
    return Supabase.instance.client;
  }

  static SupabaseClient get client => Supabase.instance.client;

  static Future<void> initialize() async {
    await _loadEnv();
    final host = Uri.tryParse(AppConfig.supabaseUrl)?.host ?? 'invalid';
    debugPrint('[Supabase] Connected project host: $host');
    debugPrint('[Build] mode=${_buildModeLabel()}');
    debugPrint('Kaam demo fallback: ${AppConfig.useDemoFallback}');

    if (!AppConfig.hasSupabaseCredentials) {
      if (kDebugMode) {
        debugPrint(
            'Kaam running without Supabase credentials: ${AppConfig.debugModeLabel()}');
      }
      return;
    }

    await Supabase.initialize(
      url: AppConfig.supabaseUrl,
      publishableKey: AppConfig.supabaseAnonKey,
      authOptions: const FlutterAuthClientOptions(
        authFlowType: AuthFlowType.pkce,
        autoRefreshToken: true,
      ),
      realtimeClientOptions: const RealtimeClientOptions(
        eventsPerSecond: 10,
      ),
    );
    _initialized = true;
    _sessionRecovery = _observeInitialSession();
  }

  static Future<void> waitForSessionRecovery() async {
    await _sessionRecovery;
  }

  static Future<void> _observeInitialSession() async {
    final client = Supabase.instance.client;
    try {
      final event = await client.auth.onAuthStateChange
          .firstWhere((state) => state.event == AuthChangeEvent.initialSession)
          .timeout(const Duration(seconds: 3));
      if (kDebugMode) {
        debugPrint(
            '[Auth] event=${event.event.name} initialSession=${event.session != null} userIdPresent=${event.session?.user.id.isNotEmpty == true}');
      }
    } on TimeoutException {
      if (kDebugMode) debugPrint('[Auth] initial session recovery timed out');
    }
  }

  static Future<void> _loadEnv() async {
    try {
      await dotenv.load(fileName: AppConfig.envFile);
    } on Object {
      if (kDebugMode) {
        debugPrint(
            '.env not loaded. Use --dart-define or add a safe .env with public Supabase config.');
      }
    }
  }

  static String _buildModeLabel() {
    if (kReleaseMode) return 'release';
    if (kProfileMode) return 'profile';
    return 'debug';
  }
}
