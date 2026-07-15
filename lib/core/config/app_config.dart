import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class AppConfig {
  const AppConfig._();

  static String get supabaseUrl => _read('SUPABASE_URL');
  static String get supabaseAnonKey => _read('SUPABASE_ANON_KEY');
  static String get qaCandidateEmail => _read('QA_CANDIDATE_EMAIL');
  static String get qaEmployerEmail => _read('QA_EMPLOYER_EMAIL');
  static String get qaAdminEmail => _read('QA_ADMIN_EMAIL');
  static String get ocrEdgeFunction => _read('OCR_EDGE_FUNCTION');
  static int get emailOtpLength {
    final parsed = int.tryParse(_read('EMAIL_OTP_LENGTH'));
    if (parsed == null || parsed < 6 || parsed > 10) return 6;
    return parsed;
  }

  static String get envFile {
    const fromDefine = String.fromEnvironment('KAAM_ENV_FILE');
    return fromDefine.trim().isEmpty ? '.env' : fromDefine;
  }

  static bool get qaModeEnabled {
    final value = _read('QA_MODE').toLowerCase();
    final requested = value == 'true' || value == '1';
    const internalQa = bool.fromEnvironment('KAAM_INTERNAL_QA');
    return requested && (kDebugMode || internalQa);
  }

  static bool get useDemoFallback {
    final value = _read('KAAM_USE_DEMO_FALLBACK').toLowerCase();
    return value.isEmpty || value == 'true' || value == '1';
  }

  static bool get hasSupabaseCredentials {
    return supabaseUrl.startsWith('https://') &&
        supabaseAnonKey.isNotEmpty &&
        !supabaseUrl.contains('your-project-ref') &&
        !supabaseAnonKey.contains('your-supabase-anon-key');
  }

  static String _read(String key) {
    final fromDefine = switch (key) {
      'SUPABASE_URL' => const String.fromEnvironment('SUPABASE_URL'),
      'SUPABASE_ANON_KEY' => const String.fromEnvironment('SUPABASE_ANON_KEY'),
      'KAAM_USE_DEMO_FALLBACK' => const String.fromEnvironment('KAAM_USE_DEMO_FALLBACK'),
      'QA_MODE' => const String.fromEnvironment('QA_MODE'),
      'QA_CANDIDATE_EMAIL' => const String.fromEnvironment('QA_CANDIDATE_EMAIL'),
      'QA_EMPLOYER_EMAIL' => const String.fromEnvironment('QA_EMPLOYER_EMAIL'),
      'QA_ADMIN_EMAIL' => const String.fromEnvironment('QA_ADMIN_EMAIL'),
      'EMAIL_OTP_LENGTH' => const String.fromEnvironment('EMAIL_OTP_LENGTH'),
      'OCR_EDGE_FUNCTION' => const String.fromEnvironment('OCR_EDGE_FUNCTION'),
      _ => '',
    };
    if (fromDefine.isNotEmpty) return fromDefine;
    return dotenv.maybeGet(key) ?? _compatRead(key);
  }

  static String _compatRead(String key) {
    return switch (key) {
      'SUPABASE_URL' => dotenv.maybeGet('NEXT_PUBLIC_SUPABASE_URL') ?? '',
      'SUPABASE_ANON_KEY' => dotenv.maybeGet('NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY') ?? '',
      _ => '',
    };
  }

  static String debugModeLabel() {
    if (hasSupabaseCredentials) return 'supabase';
    if (useDemoFallback) return 'demo-fallback';
    return 'missing-config';
  }
}
