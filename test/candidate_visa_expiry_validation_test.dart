import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kaam_perfect_match/features/candidate/profile/candidate_profile_completion.dart';
import 'package:kaam_perfect_match/features/supabase_backend/kaam_backend.dart';

void main() {
  group('candidate visa expiry visibility and validation', () {
    final today = DateTime.utc(2026, 7, 31);
    late final String experienceSource;
    late final String backendSource;
    late final String editProfileSource;
    late final String profileSource;
    late final String completionSource;
    late final String migrationSource;

    setUpAll(() {
      experienceSource = File(
        'lib/features/candidate/onboarding/skills_experience_screen.dart',
      ).readAsStringSync();
      backendSource = File(
        'lib/features/supabase_backend/kaam_backend.dart',
      ).readAsStringSync();
      editProfileSource = File(
        'lib/features/candidate/profile/edit_profile_screen.dart',
      ).readAsStringSync();
      profileSource = File(
        'lib/features/candidate/profile/candidate_profile_screen.dart',
      ).readAsStringSync();
      completionSource = File(
        'lib/features/candidate/profile/candidate_profile_completion.dart',
      ).readAsStringSync();
      migrationSource = File(
        'supabase/migrations/20260731000400_candidate_profile_visa_expiry.sql',
      ).readAsStringSync();
    });

    test('Employment Visa shows the shared expiry field', () {
      expect(CandidateVisaExpiry.requiresExpiry('Employment Visa'), isTrue);
      expect(experienceSource, contains('Visa Expiry Date *'));
      expect(
        experienceSource,
        contains('CandidateVisaExpiry.requiresExpiry('),
      );
    });

    test('Visit Visa shows the expiry field', () {
      expect(CandidateVisaExpiry.requiresExpiry('Visit Visa'), isTrue);
      expect(CandidateVisaExpiry.requiresExpiry('visit_visa'), isTrue);
    });

    test('No Visa hides the expiry field', () {
      expect(CandidateVisaExpiry.requiresExpiry('No Visa'), isFalse);
      expect(
        CandidateVisaExpiry.validationError(
          'No Visa',
          'corrupted date',
          today: today,
        ),
        isNull,
      );
    });

    test('Outside UAE hides the expiry field', () {
      expect(CandidateVisaExpiry.requiresExpiry('Outside UAE'), isFalse);
    });

    test('missing required expiry blocks continuation', () {
      expect(
        CandidateVisaExpiry.validationError(
          'Employment Visa',
          '',
          today: today,
        ),
        'Select your visa expiry date.',
      );
      expect(
        experienceSource,
        contains("next['visa_expiry'] = visaExpiryError"),
      );
    });

    test('valid future date normalizes and is sent to the save method', () {
      final future = DateTime.utc(2027, 8, 9);
      expect(
        CandidateVisaExpiry.validationError(
          'Visit Visa',
          '2027-08-09',
          today: today,
        ),
        isNull,
      );
      expect(CandidateVisaExpiry.normalizeDate(future), '2027-08-09');
      expect(CandidateVisaExpiry.displayDate('2027-08-09'), '9 Aug 2027');
      expect(experienceSource, contains('expiryDate: visaExpiryValue'));
    });

    test('invalid and impossible dates are rejected safely', () {
      for (final value in [
        '31/07/2027',
        '2027-02-29',
        'not-a-date',
        '2027-13-01',
      ]) {
        expect(CandidateVisaExpiry.parse(value), isNull);
        expect(
          CandidateVisaExpiry.validationError(
            'Employment Visa',
            value,
            today: today,
          ),
          'Select a valid visa expiry date.',
        );
      }
    });

    test('expired date is rejected with actionable copy', () {
      expect(
        CandidateVisaExpiry.validationError(
          'Visit Visa',
          '2026-07-30',
          today: today,
        ),
        'This visa has expired. Please update your visa status or expiry date.',
      );
    });

    test("today's date counts as expired", () {
      expect(
        CandidateVisaExpiry.validationError(
          'Own Visa',
          '2026-07-31',
          today: today,
        ),
        'This visa has expired. Please update your visa status or expiry date.',
      );
    });

    test('saved expiry reloads after a fresh screen construction', () {
      final profile = CandidateProfileData.fromRows(
        profile: null,
        candidate: {
          'visa_status': 'employment_visa',
          'visa_expiry_date': '2027-07-31',
        },
      );
      expect(profile.visaExpiryDate, '2027-07-31');
      expect(experienceSource, contains('profile.visaExpiryDate'));
      expect(
        experienceSource,
        contains('CandidateVisaExpiry.displayDate('),
      );
    });

    test('logout and login reload from the same Supabase profile field', () {
      expect(
        backendSource,
        contains("candidate?['visa_expiry_date'] as String? ?? ''"),
      );
      final signOutStart =
          backendSource.indexOf('Future<void> signOut() async');
      final signOutEnd = backendSource.indexOf(
        'class QaToolsRepository',
        signOutStart,
      );
      final signOutBody = backendSource.substring(signOutStart, signOutEnd);
      expect(signOutBody, isNot(contains('visa_expiry_date')));
      expect(signOutBody, isNot(contains('candidate_profiles')));
    });

    test('Edit Profile uses the same conditional screen and helper', () {
      expect(editProfileSource, contains('AppRoutes.skillsExperience'));
      expect(experienceSource, contains('CandidateVisaExpiry.requiresExpiry'));
    });

    test('changing to No Visa does not validate a hidden date', () {
      expect(
        CandidateVisaExpiry.validationError(
          'No Visa',
          '2020-01-01',
          today: today,
        ),
        isNull,
      );
      expect(
        backendSource,
        contains(
          'final normalizedExpiry = CandidateVisaExpiry.requiresExpiry(normalized)',
        ),
      );
    });

    test('partial visa update preserves unrelated profile fields', () {
      final start = backendSource.indexOf(
        'Future<CandidateProfileData> updateVisaDetails({',
      );
      final end = backendSource.indexOf(
        'Future<List<SkillCategoryData>> loadSkillCategories()',
        start,
      );
      final body = backendSource.substring(start, end);
      expect(body, contains("'visa_status': normalized"));
      expect(body, contains("'visa_expiry_date': normalizedExpiry"));
      for (final field in [
        'skills',
        'experience_years',
        'driving_licenses',
        'profile_photo_url',
        'resume_url',
        'membership',
      ]) {
        expect(body, isNot(contains("'$field'")));
      }
    });

    test('malformed legacy expiry does not crash or display', () {
      final profile = CandidateProfileData.fromRows(
        profile: null,
        candidate: {
          'visa_status': 'employment_visa',
          'visa_expiry_date': '2026-99-99',
        },
      );
      expect(profile.visaExpiryDate, '2026-99-99');
      expect(CandidateVisaExpiry.displayDate(profile.visaExpiryDate), isEmpty);
      expect(profileSource, contains('CandidateVisaExpiry.displayDate('));
    });

    test('completion uses the same conditional expiry rule', () {
      final expired = CandidateProfileCompletion.calculate(
        const CandidateProfileData(
          visaStatus: CandidateVisaStatus.employmentVisa,
          visaExpiryDate: '2020-01-01',
        ),
      );
      final noVisa = CandidateProfileCompletion.calculate(
        const CandidateProfileData(
          visaStatus: CandidateVisaStatus.noVisa,
        ),
      );
      expect(
        expired.sections[CandidateProfileSection.experience]!.missingFields,
        contains('valid visa expiry date'),
      );
      expect(
        noVisa.sections[CandidateProfileSection.experience]!.missingFields,
        isNot(contains('valid visa expiry date')),
      );
      expect(
          completionSource, contains('CandidateVisaExpiry.isValidForStatus'));
    });

    test('far-future dates are rejected and picker is bounded', () {
      expect(
        CandidateVisaExpiry.validationError(
          'Employment Visa',
          '2047-01-01',
          today: today,
        ),
        'Select a visa expiry date within the next 20 years.',
      );
      expect(experienceSource, contains('DateTime(now.year + 20, 12, 31)'));
      expect(experienceSource, contains('showDatePicker('));
    });

    test('migration uses a profile-level date without changing RLS', () {
      expect(migrationSource, contains('public.candidate_profiles'));
      expect(migrationSource, contains('visa_expiry_date date'));
      expect(migrationSource, isNot(contains('alter policy')));
      expect(migrationSource, isNot(contains('create policy')));
    });
  });
}
