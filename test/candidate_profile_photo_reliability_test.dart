import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kaam_perfect_match/core/storage/private_profile_photo_resolver.dart';
import 'package:kaam_perfect_match/core/widgets/private_profile_photo_avatar.dart';
import 'package:kaam_perfect_match/features/supabase_backend/kaam_backend.dart';

void main() {
  const candidateId = '11111111-1111-4111-8111-111111111111';
  const photoPath = '$candidateId/candidate-profile-photos/profile_1000.jpg';
  const replacementPath =
      '$candidateId/candidate-profile-photos/profile_2000.jpg';

  group('candidate profile photo reliability', () {
    late final String avatarSource;
    late final String mediaSource;
    late final String dashboardSource;
    late final String profileSource;
    late final String editProfileSource;
    late final String profilePreviewSource;
    late final String employerWidgetSource;
    late final String employerSearchSource;
    late final String employerInterestSource;
    late final String employerMatchSource;
    late final String employerChatSource;
    late final String backendSource;
    late final String migrationSource;

    setUpAll(() {
      avatarSource = File(
        'lib/core/widgets/private_profile_photo_avatar.dart',
      ).readAsStringSync();
      mediaSource = File(
        'lib/features/candidate/onboarding/profile_media_screen.dart',
      ).readAsStringSync();
      dashboardSource = File(
        'lib/features/candidate/dashboard/candidate_dashboard_screen.dart',
      ).readAsStringSync();
      profileSource = File(
        'lib/features/candidate/profile/candidate_profile_screen.dart',
      ).readAsStringSync();
      editProfileSource = File(
        'lib/features/candidate/profile/edit_profile_screen.dart',
      ).readAsStringSync();
      profilePreviewSource = File(
        'lib/features/candidate/onboarding/profile_complete_screen.dart',
      ).readAsStringSync();
      employerWidgetSource = File(
        'lib/features/employer/widgets/employer_widgets.dart',
      ).readAsStringSync();
      employerSearchSource = File(
        'lib/features/employer/search/employer_search_screens.dart',
      ).readAsStringSync();
      employerInterestSource = File(
        'lib/features/employer/interests/employer_interest_screens.dart',
      ).readAsStringSync();
      employerMatchSource = File(
        'lib/features/employer/matches/employer_match_screens.dart',
      ).readAsStringSync();
      employerChatSource = File(
        'lib/features/employer/chat/employer_chat_screens.dart',
      ).readAsStringSync();
      backendSource = File(
        'lib/features/supabase_backend/kaam_backend.dart',
      ).readAsStringSync();
      migrationSource = File(
        'supabase/migrations/023_candidate_profile_photo_employer_read.sql',
      ).readAsStringSync();
    });

    setUp(PrivateProfilePhotoResolver.clear);
    tearDown(PrivateProfilePhotoResolver.clear);

    test('1 candidate dashboard uses the shared avatar widget', () {
      expect(dashboardSource, contains('PrivateProfilePhotoAvatar('));
      expect(dashboardSource, contains('profilePhotoUrl'));
    });

    test('2 candidate profile uses the shared avatar widget', () {
      expect(profileSource, contains('PrivateProfilePhotoAvatar('));
    });

    test('3 edit profile and profile preview use the shared avatar', () {
      expect(editProfileSource, contains('PrivateProfilePhotoAvatar('));
      expect(profilePreviewSource, contains('PrivateProfilePhotoAvatar('));
    });

    test('4 employer search cards use the shared avatar widget', () {
      expect(employerSearchSource, contains('CandidateMiniProfileCard('));
      expect(employerWidgetSource, contains('PrivateProfilePhotoAvatar('));
    });

    test('5 employer candidate detail uses the shared avatar widget', () {
      expect(employerSearchSource, contains('path: candidate.profilePhotoUrl'));
      expect(employerSearchSource, contains('candidate.candidateProfileId'));
    });

    test('6 saved candidates reuse the shared candidate card', () {
      final savedStart = employerSearchSource.indexOf(
        'class SavedCandidatesScreen',
      );
      final recentStart = employerSearchSource.indexOf(
        'class _RecentlyViewedCandidates',
      );
      final savedBody = employerSearchSource.substring(savedStart, recentStart);
      expect(savedBody, contains('CandidateMiniProfileCard('));
    });

    test('7 recently viewed reuses the shared candidate card', () {
      final recentStart = employerSearchSource.indexOf(
        'class _RecentlyViewedCandidates',
      );
      expect(
        employerSearchSource.substring(recentStart),
        contains('CandidateMiniProfileCard('),
      );
      expect(employerSearchSource.substring(recentStart),
          contains('candidate: candidate'));
    });

    test('8 interest cards and details use the shared avatar', () {
      expect(employerWidgetSource, contains('request.candidatePhotoUrl'));
      expect(employerInterestSource, contains('request.candidatePhotoUrl'));
    });

    test('9 match and chat headers use the shared avatar', () {
      expect(employerWidgetSource, contains('match.profilePhotoUrl'));
      expect(employerMatchSource, contains('match.profilePhotoUrl'));
      expect(employerChatSource, contains('match?.profilePhotoUrl'));
    });

    test('10 a private path is never passed directly to Image.network', () {
      expect(mediaSource, isNot(contains('Image.network(')));
      expect(avatarSource, contains('Image.network(\n              signedUrl'));
      expect(avatarSource,
          isNot(contains('Image.network(\n              widget.path')));
    });

    test('11 candidate owner photo path resolves through one signer', () async {
      var calls = 0;
      final result = await PrivateProfilePhotoResolver.resolve(
        photoPath,
        candidateId: candidateId,
        signer: (_) async {
          calls++;
          return 'https://signed.example/photo';
        },
      );
      expect(result, 'https://signed.example/photo');
      expect(calls, 1);
    });

    test('12 eligible employer policy and public view expose only the path',
        () {
      expect(migrationSource, contains('candidate_visible_to_employers'));
      expect(migrationSource, contains('to authenticated'));
      expect(backendSource, contains(".from('public_candidate_search')"));
      expect(backendSource, contains('profile_photo_url'));
    });

    test('13 employer access excludes unrelated private documents', () {
      expect(
        migrationSource,
        contains("(storage.foldername(name))[2] = 'candidate-profile-photos'"),
      );
      expect(migrationSource, isNot(contains('candidate-cv')));
      expect(migrationSource, isNot(contains('candidate-documents')));
      expect(
        PrivateProfilePhotoResolver.isCandidatePhotoPath(
          '$candidateId/candidate-documents/passport/file.jpg',
        ),
        isFalse,
      );
    });

    testWidgets('14 missing photo displays initials', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: PrivateProfilePhotoAvatar(path: '', initials: 'PE'),
          ),
        ),
      );
      expect(find.text('PE'), findsOneWidget);
    });

    testWidgets('15 invalid private path falls back without a network image', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: PrivateProfilePhotoAvatar(
              path: 'https://example.com/persisted-signed-url',
              initials: 'C',
            ),
          ),
        ),
      );
      expect(find.text('C'), findsOneWidget);
      expect(find.byType(Image), findsNothing);
    });

    test('16 signed URL cache refreshes after its safe expiry', () async {
      var calls = 0;
      final start = DateTime.utc(2026, 7, 31, 10);
      Future<String> signer(String _) async => 'signed-${++calls}';
      expect(
        await PrivateProfilePhotoResolver.resolve(
          photoPath,
          now: start,
          signer: signer,
        ),
        'signed-1',
      );
      expect(
        await PrivateProfilePhotoResolver.resolve(
          photoPath,
          now: start.add(const Duration(minutes: 7)),
          signer: signer,
        ),
        'signed-1',
      );
      expect(
        await PrivateProfilePhotoResolver.resolve(
          photoPath,
          now: start.add(const Duration(minutes: 9)),
          signer: signer,
        ),
        'signed-2',
      );
    });

    test('17 replacing a photo invalidates the old and new cache keys',
        () async {
      await PrivateProfilePhotoResolver.resolve(
        photoPath,
        signer: (_) async => 'old-signed',
      );
      await PrivateProfilePhotoResolver.resolve(
        replacementPath,
        signer: (_) async => 'new-signed',
      );
      PrivateProfilePhotoResolver.replace(photoPath, replacementPath);
      expect(PrivateProfilePhotoResolver.hasCachedPath(photoPath), isFalse);
      expect(
        PrivateProfilePhotoResolver.hasCachedPath(replacementPath),
        isFalse,
      );
      expect(mediaSource, contains('localPhotoBytes = bytes'));
    });

    test('18 removing a photo clears shared avatar state', () async {
      await PrivateProfilePhotoResolver.resolve(
        photoPath,
        signer: (_) async => 'signed',
      );
      PrivateProfilePhotoResolver.replace(photoPath, '');
      expect(PrivateProfilePhotoResolver.hasCachedPath(photoPath), isFalse);
      expect(mediaSource, contains("updateProfilePhoto('')"));
      expect(mediaSource, contains('localPhotoBytes = null'));
    });

    test('19 restart simulation restores the stable private path', () {
      final restored = CandidateProfileData.fromRows(
        profile: null,
        candidate: const {
          'profile_photo_url': photoPath,
          'profile_photo_file_name': 'profile.jpg',
        },
      );
      expect(restored.profilePhotoUrl, photoPath);
      expect(restored.profilePhotoFileName, 'profile.jpg');
    });

    test('20 logout login clears cache then reloads database metadata', () {
      expect(backendSource, contains('PrivateProfilePhotoResolver.clear()'));
      expect(
        backendSource,
        contains("candidate?['profile_photo_url'] as String? ?? ''"),
      );
      expect(mediaSource, contains('repository.loadCurrentProfile()'));
    });

    test('21 signed URLs are not stored permanently', () {
      final updateStart = backendSource.indexOf(
        'Future<CandidateProfileData> updateProfilePhoto(',
      );
      final updateEnd = backendSource.indexOf(
        'Future<CandidateProfileData> updateResumePath(',
        updateStart,
      );
      final updateBody = backendSource.substring(updateStart, updateEnd);
      expect(updateBody, contains("'profile_photo_url': path"));
      expect(updateBody, isNot(contains('signed')));
      expect(mediaSource, isNot(contains('signedPhotoUrlFuture')));
    });

    test('22 photo changes update only photo metadata fields', () {
      final updateStart = backendSource.indexOf(
        'Future<CandidateProfileData> updateProfilePhoto(',
      );
      final updateEnd = backendSource.indexOf(
        'Future<CandidateProfileData> updateResumePath(',
        updateStart,
      );
      final updateBody = backendSource.substring(updateStart, updateEnd);
      expect(updateBody, contains("'profile_photo_url': path"));
      expect(updateBody, contains("'profile_photo_file_name'"));
      for (final unrelated in [
        'resume_url',
        'skills',
        'passport',
        'visa_status',
        'membership',
      ]) {
        expect(updateBody, isNot(contains(unrelated)));
      }
    });
  });
}
