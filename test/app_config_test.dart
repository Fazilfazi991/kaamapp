import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kaam_perfect_match/core/config/app_config.dart';

void main() {
  group('AppConfig Supabase validation', () {
    test('rejects placeholder Supabase values', () {
      dotenv.testLoad(
        fileInput: '''
SUPABASE_URL=https://your-project-ref.supabase.co
SUPABASE_ANON_KEY=your-supabase-anon-key
KAAM_USE_DEMO_FALLBACK=false
''',
      );

      expect(AppConfig.hasSupabaseCredentials, isFalse);
      expect(
        AppConfig.supabaseConfigurationIssues(),
        containsAll([
          'SUPABASE_URL still contains a placeholder value.',
          'SUPABASE_ANON_KEY still contains a placeholder value.',
        ]),
      );
    });

    test('accepts non-placeholder Supabase values', () {
      dotenv.testLoad(
        fileInput: '''
SUPABASE_URL=https://bhuhojzqxnvwbsypijac.supabase.co
SUPABASE_ANON_KEY=testpubliccredential
KAAM_USE_DEMO_FALLBACK=false
''',
      );

      expect(AppConfig.supabaseConfigurationIssues(), isEmpty);
      expect(AppConfig.hasSupabaseCredentials, isTrue);
    });
  });
}
