import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'app.dart';
import 'core/supabase/supabase_service.dart';
import 'core/remote_config/app_remote_config.dart';
import 'features/notifications/push_notification_service.dart';
import 'features/supabase_backend/kaam_backend.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final startupConfigurationError = await _initializeStartupServices();
  final remoteConfig = AppRemoteConfigService();
  // Cache/network failures are deliberately non-fatal and never delay first paint.
  unawaited(remoteConfig.initialize());
  runApp(KaamApp(
    startupConfigurationError: startupConfigurationError,
    remoteConfig: remoteConfig,
  ));
  WidgetsBinding.instance.addPostFrameCallback((_) {
    unawaited(_initializeDeferredServices());
  });
}

Future<String?> _initializeStartupServices() async {
  try {
    await SupabaseService.initialize();
    final supabaseError = SupabaseService.startupConfigurationError;
    if (supabaseError != null) {
      return 'Supabase is not configured for this build.\n$supabaseError';
    }
    await KaamAuthSessionCoordinator.restorePersistentLogoutState();
  } on Object catch (error, stackTrace) {
    if (kDebugMode) {
      debugPrint('[Startup] App initialization failed: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
    return 'Startup configuration failed. Rebuild the app with valid local environment files.';
  }
  return null;
}

Future<void> _initializeDeferredServices() async {
  try {
    await KaamPushNotificationService.instance.initialize();
  } on Object catch (error, stackTrace) {
    if (kDebugMode) {
      debugPrint('[Startup] Deferred push initialization failed: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }
}
