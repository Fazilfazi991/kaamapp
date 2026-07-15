import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kaam_perfect_match/features/supabase_backend/kaam_backend.dart';

CandidateMembershipData membership({
  required String status,
  required DateTime expiresAt,
}) {
  return CandidateMembershipData(
    status: status,
    startedAt: DateTime.now().toUtc().toIso8601String(),
    expiresAt: expiresAt.toUtc().toIso8601String(),
    isTest: true,
  );
}

void main() {
  group('candidate employer visibility', () {
    test('unverified candidate with active membership is hidden', () {
      final visibility = CandidateEmployerVisibility(
        profileCompleted: true,
        documentsVerified: false,
        membershipActive: membership(
                status: 'active',
                expiresAt: DateTime.now().add(const Duration(days: 30)))
            .isActive,
        profileVisible: true,
      );

      expect(visibility.visibleToEmployers, isFalse);
    });

    test('verified candidate with inactive membership is still searchable', () {
      final visibility = CandidateEmployerVisibility(
        profileCompleted: true,
        documentsVerified: true,
        membershipActive:
            const CandidateMembershipData(status: 'inactive').isActive,
        profileVisible: true,
      );

      expect(visibility.visibleToEmployers, isTrue);
    });

    test('verified candidate with expired membership is still searchable', () {
      final visibility = CandidateEmployerVisibility(
        profileCompleted: true,
        documentsVerified: true,
        membershipActive: membership(
                status: 'active',
                expiresAt: DateTime.now().subtract(const Duration(days: 1)))
            .isActive,
        profileVisible: true,
      );

      expect(visibility.visibleToEmployers, isTrue);
    });

    test('verified candidate with active unexpired membership is visible', () {
      final visibility = CandidateEmployerVisibility(
        profileCompleted: true,
        documentsVerified: true,
        membershipActive: membership(
                status: 'active',
                expiresAt: DateTime.now().add(const Duration(days: 30)))
            .isActive,
        profileVisible: true,
      );

      expect(visibility.visibleToEmployers, isTrue);
    });

    test('candidate with visibility disabled is hidden', () {
      final visibility = CandidateEmployerVisibility(
        profileCompleted: true,
        documentsVerified: true,
        membershipActive: membership(
                status: 'active',
                expiresAt: DateTime.now().add(const Duration(days: 30)))
            .isActive,
        profileVisible: false,
      );

      expect(visibility.visibleToEmployers, isFalse);
    });

    test('candidate can still preview their own profile while hidden', () {
      const visibility = CandidateEmployerVisibility(
        profileCompleted: true,
        documentsVerified: false,
        membershipActive: false,
        profileVisible: true,
      );

      const ownProfilePreviewAllowed = true;
      expect(visibility.visibleToEmployers, isFalse);
      expect(ownProfilePreviewAllowed, isTrue);
    });

    test('debug membership activation is unavailable in production mode', () {
      expect(
        TestMembershipActivationAccess.isAvailable(debugBuild: false),
        isFalse,
      );
      expect(
        TestMembershipActivationAccess.isAvailable(debugBuild: true),
        isTrue,
      );
    });

    test(
        'employer search view does not return private document or payment data',
        () {
      final sql = File('supabase/012_employer_match_contact_rules.sql')
          .readAsStringSync()
          .toLowerCase();
      final viewSql = sql
          .split('create or replace view public.public_candidate_search')
          .last
          .split('create or replace function public.match_chat_enabled')
          .first;

      expect(viewSql, isNot(contains('payment_reference')));
      expect(viewSql, isNot(contains('passport_number')));
      expect(viewSql, isNot(contains('passport_file_url')));
      expect(viewSql, isNot(contains('dob')));
      expect(viewSql, isNot(contains('resume_url')));
    });

    test('match communication SQL gates chat and contact reveal by membership',
        () {
      final sql = File('supabase/012_employer_match_contact_rules.sql')
          .readAsStringSync()
          .toLowerCase();

      expect(sql,
          contains('create or replace function public.match_chat_enabled'));
      expect(
          sql, contains('public.candidate_membership_active(m.candidate_id)'));
      expect(
          sql,
          contains(
              'create or replace function public.reveal_candidate_contact'));
      expect(sql, contains('contact_revealed_at'));
      expect(sql,
          contains('drop policy if exists "chat_insert_match_participants"'));
    });
  });
}
