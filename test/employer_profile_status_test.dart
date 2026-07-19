import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kaam_perfect_match/features/supabase_backend/kaam_backend.dart';

void main() {
  group('employer company profile status payload', () {
    late final String backendSource;
    late final String employerRepositorySource;
    late final String candidateRepositorySource;
    late final String onboardingSource;
    late final String companySource;

    setUpAll(() {
      backendSource = File('lib/features/supabase_backend/kaam_backend.dart')
          .readAsStringSync();
      final employerStart = backendSource.indexOf('class EmployerRepository');
      final storageStart = backendSource.indexOf('class KaamStorageRepository');
      employerRepositorySource = backendSource.substring(
        employerStart,
        storageStart == -1 ? backendSource.length : storageStart,
      );
      final candidateStart =
          backendSource.indexOf('class CandidateProfileRepository');
      candidateRepositorySource =
          backendSource.substring(candidateStart, employerStart);
      onboardingSource = File(
        'lib/features/employer/onboarding/employer_onboarding_screens.dart',
      ).readAsStringSync();
      companySource = File(
        'lib/features/employer/company/employer_company_screens.dart',
      ).readAsStringSync();
    });

    test('live profile_status enum values exclude pending', () {
      expect(
        KaamProfileStatus.liveEnumValues,
        {'draft', 'active', 'paused', 'blocked'},
      );
      expect(KaamProfileStatus.isLiveEnumValue('pending'), isFalse);
      expect(
        KaamProfileStatus.isLiveEnumValue(KaamProfileStatus.employerOnboarding),
        isTrue,
      );
    });

    test('employer company save uses a valid enum-backed profile status', () {
      expect(KaamProfileStatus.employerOnboarding, KaamProfileStatus.active);
      expect(
        employerRepositorySource,
        contains('_bootstrapUserProfile(client, role: KaamRole.employer)'),
      );
      expect(employerRepositorySource, isNot(contains("'status': 'pending'")));
    });

    test('candidate onboarding still uses a valid enum-backed profile status',
        () {
      expect(KaamProfileStatus.candidateOnboarding, KaamProfileStatus.active);
      expect(
        candidateRepositorySource,
        contains('_bootstrapUserProfile(client, role: KaamRole.candidate)'),
      );
      expect(candidateRepositorySource, isNot(contains("'status': 'pending'")));
    });

    test(
        'employer onboarding continues to verification, not candidate dashboard',
        () {
      expect(
        onboardingSource,
        contains('AppRoutes.employerBusinessVerification'),
      );
      expect(
        onboardingSource,
        isNot(contains('AppRoutes.dashboard')),
      );
    });

    test('invalid database details are mapped to a safe company save message',
        () {
      final message = KaamSafeErrorMessages.employerCompanySaveMessage(
        StateError(
          'invalid input value for enum profile_status: "pending"',
        ),
      );

      expect(
        message,
        'We could not save your company details. Please try again.',
      );
      expect(message, isNot(contains('profile_status')));
      expect(message, isNot(contains('pending')));
      expect(
        onboardingSource,
        isNot(contains('Could not save company: \$error')),
      );
      expect(
        companySource,
        isNot(contains('Could not save company: \$error')),
      );
    });
  });
}
