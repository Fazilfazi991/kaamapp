import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('candidate Basic Details persistence', () {
    late final String basicDetailsSource;
    late final String backendSource;

    setUpAll(() {
      basicDetailsSource = File(
        'lib/features/candidate/onboarding/basic_details_screen.dart',
      ).readAsStringSync();
      backendSource = File(
        'lib/features/supabase_backend/kaam_backend.dart',
      ).readAsStringSync();
    });

    String methodBody(String source, String signature, String nextSignature) {
      final start = source.indexOf(signature);
      expect(start, isNonNegative, reason: '$signature should exist');
      final end = source.indexOf(nextSignature, start + signature.length);
      expect(end, isNonNegative, reason: '$nextSignature should follow');
      return source.substring(start, end);
    }

    test('Basic Details save awaits the backend before navigating', () {
      final continueBody = methodBody(
        basicDetailsSource,
        'Future<void> _continue()',
        '''
  Future<void> _pickOption''',
      );
      final saveIndex = continueBody.indexOf(
        'await repository.upsertBasicProfile',
      );
      final navigationIndex = continueBody.indexOf(
        'Navigator.of(context).pushNamed',
      );

      expect(saveIndex, isNonNegative);
      expect(navigationIndex, isNonNegative);
      expect(saveIndex, lessThan(navigationIndex));
      expect(continueBody, contains('if (loading || loadFailed || saving)'));
      expect(continueBody, contains('setState(() => saving = true)'));
      expect(
        continueBody,
        contains('We could not save your location. Please try again.'),
      );
    });

    test('onboarding advances while profile editing returns to its overview',
        () {
      expect(
        basicDetailsSource,
        contains('enum BasicDetailsEntryMode { onboarding, profileEdit }'),
      );
      expect(
        basicDetailsSource,
        contains('Navigator.of(context).pop(true)'),
      );
      expect(
        basicDetailsSource,
        contains('Navigator.of(context).pushNamed(AppRoutes.workPreferences)'),
      );
      final editProfileSource = File(
        'lib/features/candidate/profile/edit_profile_screen.dart',
      ).readAsStringSync();
      expect(editProfileSource, contains('AppRoutes.editBasicDetails'));
      expect(editProfileSource,
          contains('if (changed == true && mounted) _refresh()'));
    });

    test('navigation does not continue from the save-failure path', () {
      final continueBody = methodBody(
        basicDetailsSource,
        'Future<void> _continue()',
        '''
  Future<void> _pickOption''',
      );
      final catchBody = continueBody.substring(continueBody.indexOf('catch'));

      expect(catchBody, isNot(contains('Navigator.of(context).pushNamed')));
      expect(catchBody, isNot(contains('PostgrestException')));
      expect(
        catchBody,
        contains('We could not save your location. Please try again.'),
      );
    });

    test(
      'saved profile values populate controllers after a fresh screen load',
      () {
        final loadBody = methodBody(
          basicDetailsSource,
          'Future<void> _load()',
          '''
  Future<void> _continue''',
        );

        expect(loadBody, contains('repository.loadCurrentProfile()'));
        expect(loadBody, contains('repository.loadIdentityDocuments()'));
        expect(loadBody, contains('fullNameController.text'));
        expect(loadBody, contains('profile.fullName'));
        expect(loadBody, contains('phoneController.text = profile.phone'));
        expect(loadBody, contains('nationalityController.text'));
        expect(loadBody, contains('profile.nationality'));
        expect(loadBody, contains('profile.currentCountry'));
        expect(loadBody, contains('profile.currentCity'));
        expect(loadBody, contains('loadFailed = true'));
      },
    );

    test(
      'candidate profile section saves use auth user ID and update only',
      () {
        final saveBody = methodBody(
          backendSource,
          'Future<CandidateProfileData> upsertBasicProfile({',
          'Future<CandidateProfileData> updateWorkProfile',
        );

        expect(saveBody, contains('final user = _requireUser(client)'));
        expect(saveBody, contains('_bootstrapUserProfile'));
        expect(
          saveBody,
          contains('_ensureCandidateProfileRow(client, user.id)'),
        );
        expect(saveBody, contains(".eq('id', user.id)"));
        expect(saveBody, contains(".from('candidate_profiles')"));
        expect(saveBody, contains('.update({'));
        expect(saveBody, isNot(contains(".from('candidate_profiles').upsert")));
        expect(saveBody, isNot(contains(".eq('email'")));
      },
    );

    test('Basic Details update does not clear unrelated candidate fields', () {
      final saveBody = methodBody(
        backendSource,
        'Future<CandidateProfileData> upsertBasicProfile({',
        'Future<CandidateProfileData> updateWorkProfile',
      );

      for (final field in [
        'profile_photo_url',
        'profile_photo_file_name',
        'resume_url',
        'resume_file_name',
        'resume_file_size',
        'driving_license',
        'driving_licenses',
        'current_employment_status',
        'current_employment_status_other',
        'passport_file_url',
        'passport_back_file_url',
      ]) {
        expect(saveBody, isNot(contains(field)));
      }
    });

    test('existing candidate profile row is reused instead of duplicated', () {
      final ensureBody = methodBody(
        backendSource,
        'Future<void> _ensureCandidateProfileRow(',
        'String _safePostgrestCode',
      );

      expect(ensureBody, contains(".select('id')"));
      expect(ensureBody, contains(".eq('id', userId)"));
      expect(ensureBody, contains('if (existing != null)'));
      expect(ensureBody, contains(".insert({'id': userId})"));
      expect(ensureBody, contains("error.code == '23505'"));
    });

    test('logout does not reset or overwrite candidate profile data', () {
      final signOutBody = methodBody(
        backendSource,
        'Future<void> signOut()',
        'class QaToolsRepository',
      );

      expect(signOutBody, contains('beginExplicitLogout'));
      expect(signOutBody, contains('auth'));
      expect(signOutBody, contains('signOut('));
      expect(signOutBody, contains('SignOutScope.global'));
      expect(signOutBody, contains('finishExplicitLogout'));
      expect(signOutBody, isNot(contains('candidate_profiles')));
      expect(signOutBody, isNot(contains('updateWorkProfile')));
      expect(signOutBody, isNot(contains('upsertBasicProfile')));
      expect(signOutBody, isNot(contains('qa_reset')));
    });

    test(
      'partial non-basic candidate updates also preserve existing fields',
      () {
        final workBody = methodBody(
          backendSource,
          'Future<CandidateProfileData> updateWorkProfile',
          'Future<void> saveSkills',
        );
        final documentBody = methodBody(
          backendSource,
          'Future<CandidateIdentityDocumentData> saveIdentityDocuments(',
          'Future<List<CandidateDocumentVersionData>> loadDocumentVersions',
        );

        expect(
          workBody,
          contains(".from('candidate_profiles')\n        .update(safeValues)"),
        );
        expect(workBody, contains('CandidateSkillLimits.normalizeNames'));
        expect(workBody, isNot(contains(".from('candidate_profiles').upsert")));
        // Identity documents are now persisted by the server RPC, which
        // consumes the validated file records atomically.
        expect(
          documentBody,
          contains("rpc('submit_candidate_identity_documents'"),
        );
        expect(documentBody, contains("'p_candidate_fields': candidateValues"));
        expect(
          documentBody,
          isNot(contains(".from('candidate_profiles').upsert")),
        );
      },
    );

    test('onboarding resume is resolved from Supabase profile state', () {
      final routeBody = methodBody(
        backendSource,
        'Future<KaamAuthRouteResult> resolvePostOtpDestination({',
        'Future<void> signOut() async',
      );

      expect(routeBody, contains(".from('profiles')"));
      expect(routeBody, contains(".eq('id', user.id)"));
      expect(routeBody, contains(".from('candidate_profiles')"));
      expect(routeBody, contains('current_country'));
      expect(routeBody, contains('preferred_country'));
      expect(routeBody, contains('_candidateOnboardingComplete(candidate)'));
      expect(routeBody, contains('candidateDashboard'));
      expect(routeBody, contains('candidateOnboarding'));
      expect(routeBody, contains('onboarding_resume_step_resolved'));
    });

    test('safe debug logs avoid private Basic Details values', () {
      final debugBody = methodBody(
        backendSource,
        'void _debugCandidateProfile({',
        'String? _nullable',
      );

      expect(debugBody, contains('kDebugMode'));
      expect(debugBody, contains('fields.join'));
      expect(debugBody, contains('safeErrorCode'));
      expect(debugBody, isNot(contains('phone')));
      expect(debugBody, isNot(contains('email')));
      expect(debugBody, isNot(contains('dateOfBirth')));
      expect(debugBody, isNot(contains('address')));
    });
  });
}
