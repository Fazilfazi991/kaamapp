import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kaam_perfect_match/features/supabase_backend/kaam_backend.dart';

void main() {
  group('candidate visa status persistence', () {
    late final String experienceSource;
    late final String backendSource;
    late final String editProfileSource;

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
    });

    test('legacy and normalized values resolve to one stable value', () {
      for (final value in ['Visit Visa', 'visit visa', 'visit_visa']) {
        expect(CandidateVisaStatus.normalize(value), 'visit_visa');
        expect(CandidateVisaStatus.labelFor(value), 'Visit Visa');
      }
      expect(CandidateVisaStatus.normalize('Canceled Visa'), 'cancelled_visa');
      expect(CandidateVisaStatus.normalize('Not Applicable'), 'no_visa');
      expect(CandidateVisaStatus.normalize(null), isEmpty);
    });

    test('candidate profile maps the database visa field', () {
      final profile = CandidateProfileData.fromRows(
        profile: null,
        candidate: {'visa_status': 'Employment Visa'},
      );

      expect(profile.visaStatus, 'employment_visa');
      expect(
        backendSource,
        contains("candidate?['visa_status'] as String?"),
      );
    });

    test('saved visa is restored into the form after a fresh load', () {
      expect(
        experienceSource,
        contains('repository.loadCurrentProfile()'),
      );
      expect(
        experienceSource,
        contains('CandidateVisaStatus.labelFor('),
      );
      expect(experienceSource, contains('profile.visaStatus'));
      expect(
        experienceSource,
        isNot(contains("visaStatusController.text = '';")),
      );
    });

    test('empty defaults cannot write over a loaded visa status', () {
      expect(
        experienceSource,
        isNot(contains("'visa_status': visaStatusController.text.trim()")),
      );
      expect(
        experienceSource,
        contains('await repository.updateVisaDetails('),
      );
      expect(
          experienceSource, contains('if (loading || loadFailed || saving)'));
    });

    test('visa save is auth-scoped, partial, awaited, and read back', () {
      final start = backendSource.indexOf(
        'Future<CandidateProfileData> updateVisaDetails({',
      );
      final end = backendSource.indexOf(
        'Future<List<SkillCategoryData>> loadSkillCategories()',
        start,
      );
      expect(start, isNonNegative);
      expect(end, greaterThan(start));
      final body = backendSource.substring(start, end);

      expect(body, contains("'visa_status': normalized"));
      expect(body, contains(".eq('id', user.id)"));
      expect(body, contains('final saved = await loadCurrentProfile()'));
      expect(body, contains('saved.visaStatus != normalized'));
      expect(body, contains('throw StateError'));
      for (final unrelatedField in [
        'full_name',
        'skills',
        'experience_years',
        'driving_licenses',
        'profile_photo_url',
        'resume_url',
        'onboarding',
      ]) {
        expect(body, isNot(contains("'$unrelatedField'")));
      }
    });

    test('selected visa status is sent through the dedicated backend save', () {
      expect(
        experienceSource,
        contains('await repository.updateVisaDetails('),
      );
      expect(
        backendSource,
        contains('CandidateVisaStatus.normalize(selectedStatus)'),
      );
    });

    test('successful save reloads the persisted row before returning', () {
      final saveIndex = backendSource.indexOf(
        "'visa_status': normalized",
      );
      final readbackIndex = backendSource.indexOf(
        'final saved = await loadCurrentProfile()',
        saveIndex,
      );
      final returnIndex = backendSource.indexOf('return saved;', readbackIndex);

      expect(saveIndex, isNonNegative);
      expect(readbackIndex, greaterThan(saveIndex));
      expect(returnIndex, greaterThan(readbackIndex));
    });

    test('save failure blocks navigation and repeated taps', () {
      final saveIndex = experienceSource.indexOf(
        'await repository.updateVisaDetails(',
      );
      final navigationIndex = experienceSource.indexOf(
        'Navigator.of(context).pushNamed',
        saveIndex,
      );
      expect(saveIndex, isNonNegative);
      expect(navigationIndex, greaterThan(saveIndex));
      expect(
          experienceSource, contains('onPressed: saving ? null : _continue'));
      expect(
        experienceSource,
        contains(
          'We could not save your skill experience. Please try again.',
        ),
      );
    });

    test('null and unknown existing values load safely', () {
      expect(
        CandidateProfileData.fromRows(
          profile: null,
          candidate: {'visa_status': null},
        ).visaStatus,
        isEmpty,
      );
      expect(CandidateVisaStatus.labelFor('legacy permit'), 'Legacy Permit');
      expect(CandidateVisaStatus.isSupported('legacy permit'), isFalse);
    });

    test('changing visa status does not include unrelated profile fields', () {
      final start = backendSource.indexOf(
        'Future<CandidateProfileData> updateVisaDetails({',
      );
      final end = backendSource.indexOf(
        'Future<List<SkillCategoryData>> loadSkillCategories()',
        start,
      );
      final body = backendSource.substring(start, end);

      expect(
        RegExp(r"'visa_status': normalized").allMatches(body).length,
        1,
      );
      expect(body, isNot(contains("'bio'")));
      expect(body, isNot(contains("'skills'")));
    });

    test('other partial profile updates do not erase visa status', () {
      final start = backendSource.indexOf(
        'Future<CandidateProfileData> updateWorkProfile(',
      );
      final end = backendSource.indexOf(
        'Future<CandidateProfileData> updateVisaDetails({',
        start,
      );
      final body = backendSource.substring(start, end);

      expect(
        body,
        contains(".from('candidate_profiles')\n        .update(safeValues)"),
      );
      expect(body, contains('Map<String, dynamic>.from(values)'));
      expect(body, isNot(contains("'visa_status':")));
    });

    test('Edit Profile and onboarding use the same persisted visa source', () {
      expect(
        editProfileSource,
        contains('AppRoutes.skillsExperience'),
      );
      expect(
        experienceSource,
        contains('repository.loadCurrentProfile()'),
      );
      expect(
        experienceSource,
        contains('await repository.updateVisaDetails'),
      );
    });

    test('logout does not update or clear candidate profile fields', () {
      final start = backendSource.indexOf('Future<void> signOut() async');
      final end = backendSource.indexOf('class QaToolsRepository', start);
      final body = backendSource.substring(start, end);

      expect(body, contains('signOut('));
      expect(body, isNot(contains('candidate_profiles')));
      expect(body, isNot(contains('updateVisaDetails')));
    });
  });
}
