import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kaam_perfect_match/core/constants/app_routes.dart';
import 'package:kaam_perfect_match/features/notifications/notification_models.dart';
import 'package:kaam_perfect_match/features/supabase_backend/kaam_backend.dart';

void main() {
  group('notification deep links', () {
    test('rejects external URLs and falls back safely', () {
      expect(
        KaamNotificationDeepLinks.routeFor(
          role: KaamRole.candidate,
          type: 'new_message',
          actionRoute: 'https://example.com/phish',
        ),
        AppRoutes.chatList,
      );
      expect(
        KaamNotificationDeepLinks.routeFor(
          role: KaamRole.employer,
          type: 'unknown',
          actionRoute: '//example.com',
        ),
        AppRoutes.employerNotifications,
      );
    });

    test('rejects wrong-role routes', () {
      expect(
        KaamNotificationDeepLinks.routeFor(
          role: KaamRole.candidate,
          type: 'unknown',
          actionRoute: AppRoutes.employerMatches,
        ),
        AppRoutes.notifications,
      );
    });

    test('maps known route keys to role-specific screens', () {
      expect(
        KaamNotificationDeepLinks.routeFor(
          role: KaamRole.candidate,
          type: 'match_created',
        ),
        AppRoutes.matches,
      );
      expect(
        KaamNotificationDeepLinks.routeFor(
          role: KaamRole.employer,
          type: 'new_message',
        ),
        AppRoutes.employerChatList,
      );
      expect(
        KaamNotificationDeepLinks.routeFor(
          role: KaamRole.candidate,
          type: 'candidate_document_approved',
        ),
        AppRoutes.documentsUpload,
      );
      expect(
        KaamNotificationDeepLinks.routeFor(
          role: KaamRole.employer,
          type: 'employer_document_approved',
        ),
        AppRoutes.employerVerificationStatus,
      );
    });
  });

  group('push payload safety', () {
    test('removes sensitive fields from payloads', () {
      final safe = KaamPushPayloadSafety.sanitize({
        'notification_id': 'n1',
        'message_body': 'private text',
        'passport_number': 'P123',
        'match_id': 'm1',
        'signed_url': 'https://signed',
      });

      expect(safe, {'notification_id': 'n1', 'match_id': 'm1'});
    });
  });

  group('notification migration', () {
    final migration = File('supabase/013_notification_foundation.sql');

    test('defines central tables and RLS policies', () {
      final sql = migration.readAsStringSync();
      expect(sql, contains('create table if not exists public.notifications'));
      expect(
          sql, contains('create table if not exists public.user_push_devices'));
      expect(
          sql,
          contains(
              'create table if not exists public.notification_preferences'));
      expect(
          sql,
          contains(
              'alter table public.notifications enable row level security'));
      expect(sql, contains('user_push_devices_insert_own'));
      expect(sql, contains('notification_preferences_update_own_or_admin'));
    });

    test('covers token lifecycle and event dedupe rules', () {
      final sql = migration.readAsStringSync();
      expect(sql, contains('unique(fcm_token)'));
      expect(sql, contains('notifications_recipient_dedupe_idx'));
      expect(sql, contains('notify_interest_request_created'));
      expect(sql, contains('notify_match_created'));
      expect(sql, contains('notify_chat_message_created'));
      expect(sql, contains('notify_candidate_document_reviewed'));
      expect(sql, contains('notify_employer_document_reviewed'));
      expect(sql, contains('notify_company_reviewed'));
      expect(sql, contains('candidate_document_approved'));
      expect(sql, contains('employer_document_approved'));
      expect(
        sql,
        isNot(contains(
            'grant execute on function public.create_notification(uuid, text, text, text, text, jsonb, text, text, uuid) to authenticated')),
      );
    });
  });

  test('Dart notification registry only exposes supported foundation types',
      () {
    expect(
        KaamNotificationTypes.supported,
        containsPair('candidate_document_approved',
            KaamNotificationType.candidateDocumentApproved));
    expect(
        KaamNotificationTypes.supported,
        containsPair('employer_document_approved',
            KaamNotificationType.employerDocumentApproved));
    expect(
        KaamNotificationTypes.supported, isNot(contains('profile_incomplete')));
    expect(KaamNotificationTypes.supported, isNot(contains('report_received')));
    expect(KaamNotificationTypes.supported,
        isNot(contains('membership_expiring')));
    expect(
      KaamNotificationTypes.supported,
      containsPair('general_announcement',
          KaamNotificationType.generalAnnouncement),
    );
    expect(
      KaamNotificationTypes.supported,
      containsPair('urgent_alert', KaamNotificationType.urgentAlert),
    );
  });

  test('edge function does not expose server secrets in client code', () {
    final source = File('supabase/functions/send-push-notification/index.ts')
        .readAsStringSync();
    expect(source, contains('FIREBASE_SERVICE_ACCOUNT_JSON'));
    expect(
        source, contains('https://www.googleapis.com/auth/firebase.messaging'));
    expect(source, isNot(contains('private_key_id:')));
    expect(source, contains('candidate_document_approved'));
    expect(source, contains('employer_document_approved'));
    expect(source, isNot(contains('profile_incomplete')));
  });
}
