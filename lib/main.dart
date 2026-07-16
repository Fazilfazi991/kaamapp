import 'package:flutter/material.dart';

import 'app.dart';
import 'core/supabase/supabase_service.dart';
import 'features/notifications/push_notification_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SupabaseService.initialize();
  await KaamPushNotificationService.instance.initialize();
  // The welcome screen is deliberately the root for every launch. Session and
  // onboarding progress are evaluated only after the user chooses a journey.
  runApp(const KaamApp());
}
