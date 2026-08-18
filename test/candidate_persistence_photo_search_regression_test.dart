import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('candidate persistence, photo, and employer search regressions', () {
    late final String backendSource;
    late final String dashboardSource;
    late final String profileSource;
    late final String employerWidgetsSource;
    late final String searchSource;
    late final String avatarSource;
    late final String photoResolverSource;
    late final String photoPolicySource;

    setUpAll(() {
      backendSource = File(
        'lib/features/supabase_backend/kaam_backend.dart',
      ).readAsStringSync();
      dashboardSource = File(
        'lib/features/candidate/dashboard/candidate_dashboard_screen.dart',
      ).readAsStringSync();
      profileSource = File(
        'lib/features/candidate/profile/candidate_profile_screen.dart',
      ).readAsStringSync();
      employerWidgetsSource = File(
        'lib/features/employer/widgets/employer_widgets.dart',
      ).readAsStringSync();
      searchSource = File(
        'lib/features/employer/search/employer_search_screens.dart',
      ).readAsStringSync();
      avatarSource = File(
        'lib/core/widgets/private_profile_photo_avatar.dart',
      ).readAsStringSync();
      photoResolverSource = File(
        'lib/core/storage/private_profile_photo_resolver.dart',
      ).readAsStringSync();
      photoPolicySource = File(
        'supabase/023_candidate_profile_photo_employer_read.sql',
      ).readAsStringSync();
    });

    String methodBody(String source, String signature, String nextSignature) {
      final start = source.indexOf(signature);
      expect(start, isNonNegative, reason: '$signature should exist');
      final end = source.indexOf(nextSignature, start + signature.length);
      expect(end, isNonNegative, reason: '$nextSignature should follow');
      return source.substring(start, end);
    }

    test('Basic Details save verifies persisted data before navigation', () {
      final saveBody = methodBody(
        backendSource,
        'Future<CandidateProfileData> upsertBasicProfile({',
        'Future<CandidateProfileData> updateWorkProfile',
      );

      expect(saveBody, contains('final saved = await loadCurrentProfile()'));
      expect(saveBody, contains('_savedBasicProfileMatches'));
      expect(saveBody, contains('readback_mismatch'));
      expect(saveBody,
          contains("throw StateError('Basic Details were not saved.')"));
      expect(saveBody, contains('return saved'));
    });

    test('login recovers registered users with missing profile rows safely',
        () {
      final verifyBody = methodBody(
        backendSource,
        'Future<KaamAuthRouteResult> verifyOtp({',
        'Future<KaamStoredProfile?> _storedProfile()',
      );
      final recoveryBody = methodBody(
        backendSource,
        'Future<KaamStoredProfile?> _recoverMissingStoredProfile()',
        'Future<KaamRole?> currentBackendRole()',
      );

      expect(verifyBody, contains('await _recoverMissingStoredProfile()'));
      expect(verifyBody.indexOf('_recoverMissingStoredProfile'),
          lessThan(verifyBody.indexOf('KaamAccountNotFoundException')));
      expect(recoveryBody, contains(".from('candidate_profiles')"));
      expect(recoveryBody, contains(".from('employer_companies')"));
      expect(recoveryBody, contains(".eq('id', user.id)"));
      expect(recoveryBody, contains(".eq('owner_id', user.id)"));
      expect(recoveryBody, contains('_bootstrapUserProfile'));
      expect(recoveryBody, contains('missing_profile_recovered'));
    });

    test('private candidate photos use signed URLs on dashboard and profile',
        () {
      expect(avatarSource, contains('PrivateProfilePhotoResolver.resolve'));
      expect(photoResolverSource, contains(".from('kaam-private')"));
      expect(photoResolverSource, contains('.createSignedUrl('));
      expect(photoResolverSource, contains('_cache[trimmed]'));
      expect(dashboardSource, contains('PrivateProfilePhotoAvatar'));
      expect(dashboardSource, contains('profile?.profilePhotoUrl'));
      expect(profileSource, contains('PrivateProfilePhotoAvatar'));
      expect(profileSource, contains('profile.profilePhotoUrl'));
    });

    test('employer candidate cards do not treat private paths as public URLs',
        () {
      final avatarBody = methodBody(
        employerWidgetsSource,
        'class _CandidateAvatar extends StatelessWidget',
        'class CandidatePrivacyNoticeCard',
      );

      expect(avatarBody, contains('PrivateProfilePhotoAvatar'));
      expect(avatarBody, contains('candidate.profilePhotoUrl'));
      expect(avatarBody, isNot(contains('Image.network')));
      expect(avatarBody, isNot(contains('final url =')));
    });

    test('employer search starts compact and opens native matching review', () {
      expect(searchSource, contains('showJobRoleSearchSheet'));
      expect(searchSource, contains('selectedJobRole'));
      expect(searchSource, contains('final resultsKey = GlobalKey()'));
      expect(searchSource, contains('Scrollable.ensureVisible'));
      expect(searchSource, contains('searchSubmitted = true'));
      expect(searchSource, contains("'Match Candidates'"));
      expect(searchSource, contains('candidateIndex + 1'));
      expect(searchSource, contains('const _CandidateSkeletonCard()'));
      expect(searchSource, isNot(contains('categorySkills')));
    });

    test('photo storage migration keeps private documents private', () {
      expect(photoPolicySource, contains('kaam-private'));
      expect(photoPolicySource, contains('candidate-profile-photos'));
      expect(photoPolicySource, contains('candidate_visible_to_employers'));
      expect(photoPolicySource, contains('to authenticated'));
      expect(photoPolicySource, isNot(contains('bucket_id = true')));
      expect(photoPolicySource, isNot(contains('to anon')));
      expect(
        photoPolicySource,
        isNot(
            contains("(storage.foldername(name))[2] = 'candidate-documents'")),
      );
      expect(
        photoPolicySource,
        isNot(contains("(storage.foldername(name))[2] = 'passport'")),
      );
      expect(
        photoPolicySource,
        isNot(contains("(storage.foldername(name))[2] = 'resume'")),
      );
    });
  });
}
