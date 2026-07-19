import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'app.dart';
import 'core/supabase/supabase_service.dart';
import 'features/notifications/push_notification_service.dart';
import 'features/supabase_backend/kaam_backend.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final startupConfigurationError = await _initializeStartupServices();
  // The welcome screen is deliberately the root for every launch. Session and
  // onboarding progress are evaluated only after the user chooses a journey.
  runApp(KaamApp(startupConfigurationError: startupConfigurationError));
}

Future<String?> _initializeStartupServices() async {
  try {
    await SupabaseService.initialize();
    final supabaseError = SupabaseService.startupConfigurationError;
    if (supabaseError != null) {
      return 'Supabase is not configured for this build.\n$supabaseError';
    }
    await KaamAuthSessionCoordinator.restorePersistentLogoutState();
    await KaamPushNotificationService.instance.initialize();
    final diagnostics = KaamPushNotificationService.instance.diagnostics;
    if (!diagnostics.firebaseInitialized) {
      return 'Firebase is not configured for this build.';
    }
  } on Object catch (error, stackTrace) {
    if (kDebugMode) {
      debugPrint('[Startup] App initialization failed: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
    return 'Startup configuration failed. Rebuild the app with valid local environment files.';
  }
  return null;
}
