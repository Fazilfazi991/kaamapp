import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'app.dart';
import 'core/supabase/supabase_service.dart';
import 'features/notifications/push_notification_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await _initializeSupabaseSafely();
  // The welcome screen is deliberately the root for every launch. Session and
  // onboarding progress are evaluated only after the user chooses a journey.
  runApp(const KaamApp());
  unawaited(KaamPushNotificationService.instance.initialize());
}

Future<void> _initializeSupabaseSafely() async {
  try {
    await SupabaseService.initialize();
  } on Object catch (error, stackTrace) {
    if (kDebugMode) {
      debugPrint('[Startup] Supabase initialization failed: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }
}
