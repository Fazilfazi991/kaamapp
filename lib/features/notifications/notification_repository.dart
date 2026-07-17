import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/supabase/supabase_service.dart';
import 'notification_models.dart';

class KaamNotificationRepository {
  const KaamNotificationRepository();

  SupabaseClient get _client => SupabaseService.client;

  Future<List<KaamNotification>> loadNotifications({
    bool unreadOnly = false,
  }) async {
    final user = _requireUser();
    var query = _client
        .from('notifications')
        .select(
            'id,type,title,body,status,read_at,created_at,action_route,data')
        .eq('recipient_id', user.id);
    if (unreadOnly) query = query.eq('status', 'unread');
    final rows = await query.order('created_at', ascending: false).limit(100);
    return rows
        .map((row) => KaamNotification.fromRow(Map<String, dynamic>.from(row)))
        .toList();
  }

  Future<int> unreadCount() async {
    final user = _requireUser();
    final rows = await _client
        .from('notifications')
        .select('id')
        .eq('recipient_id', user.id)
        .eq('status', 'unread');
    return rows.length;
  }

  Future<void> markRead(String notificationId) async {
    final user = _requireUser();
    await _client
        .from('notifications')
        .update({
          'status': 'read',
          'read_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', notificationId)
        .eq('recipient_id', user.id);
  }

  Future<void> markAllRead() async {
    final user = _requireUser();
    await _client
        .from('notifications')
        .update({
          'status': 'read',
          'read_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('recipient_id', user.id)
        .eq('status', 'unread');
  }

  Future<KaamNotificationPreferences> loadPreferences() async {
    final user = _requireUser();
    final row = await _client
        .from('notification_preferences')
        .select()
        .eq('user_id', user.id)
        .maybeSingle();
    return KaamNotificationPreferences.fromRow(row);
  }

  Future<void> savePreferences(KaamNotificationPreferences preferences) async {
    final user = _requireUser();
    await _client
        .from('notification_preferences')
        .upsert(preferences.toRow(user.id), onConflict: 'user_id');
  }

  Future<void> registerDeviceToken({
    required String fcmToken,
    String platform = 'android',
    String? deviceId,
    String? appVersion,
  }) async {
    final token = fcmToken.trim();
    if (token.isEmpty) return;
    final user = _requireUser();
    await _client.from('user_push_devices').upsert({
      'user_id': user.id,
      'platform': platform,
      'fcm_token': token,
      'device_id': deviceId,
      'app_version': appVersion,
      'is_active': true,
      'last_seen_at': DateTime.now().toUtc().toIso8601String(),
    }, onConflict: 'fcm_token');
  }

  Future<void> deactivateDeviceToken(String? fcmToken) async {
    final token = fcmToken?.trim();
    if (token == null || token.isEmpty) return;
    final user = _client.auth.currentUser;
    if (user == null) return;
    await _client
        .from('user_push_devices')
        .update({'is_active': false})
        .eq('user_id', user.id)
        .eq('fcm_token', token);
  }

  Future<bool?> currentDeviceActive(String? fcmToken) async {
    final token = fcmToken?.trim();
    if (token == null || token.isEmpty) return null;
    final user = _client.auth.currentUser;
    if (user == null) return null;
    final row = await _client
        .from('user_push_devices')
        .select('is_active')
        .eq('user_id', user.id)
        .eq('fcm_token', token)
        .maybeSingle();
    if (row == null) return null;
    return row['is_active'] as bool? ?? false;
  }

  User _requireUser() {
    final user = SupabaseService.maybeClient?.auth.currentUser;
    if (user == null) throw StateError('Sign in to manage notifications.');
    return user;
  }
}
