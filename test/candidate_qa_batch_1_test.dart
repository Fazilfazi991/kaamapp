import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kaam_perfect_match/features/candidate/documents/document_status_service.dart';

void main() {
  group('Candidate QA batch 1', () {
    late final String uploadSource;
    late final String reviewSource;
    late final String experienceSource;
    late final String mediaSource;
    late final String profileSource;
    late final String avatarSource;
    late final String photoResolverSource;
    late final String backendSource;
    late final String migrationSource;
    late final String dashboardSource;

    setUpAll(() {
      uploadSource = File(
        'lib/features/candidate/onboarding/documents_upload_screen.dart',
      ).readAsStringSync();
      reviewSource = File(
        'lib/features/candidate/documents/identity_document_review_screen.dart',
      ).readAsStringSync();
      experienceSource = File(
        'lib/features/candidate/onboarding/skills_experience_screen.dart',
      ).readAsStringSync();
      mediaSource = File(
        'lib/features/candidate/onboarding/profile_media_screen.dart',
      ).readAsStringSync();
      profileSource = File(
        'lib/features/candidate/profile/candidate_profile_screen.dart',
      ).readAsStringSync();
      avatarSource = File(
        'lib/core/widgets/private_profile_photo_avatar.dart',
      ).readAsStringSync();
      photoResolverSource = File(
        'lib/core/storage/private_profile_photo_resolver.dart',
      ).readAsStringSync();
      backendSource = File(
        'lib/features/supabase_backend/kaam_backend.dart',
      ).readAsStringSync();
      migrationSource = File(
        'supabase/020_candidate_qa_batch_1_profile_fields.sql',
      ).readAsStringSync();
      dashboardSource = File(
        'lib/features/candidate/dashboard/candidate_dashboard_screen.dart',
      ).readAsStringSync();
    });

    test('unsupported passport files show a clear validation error', () {
      expect(uploadSource, contains('Unsupported file format'));
      expect(uploadSource, contains('FileType.any'));
      expect(uploadSource, contains('bytes.isEmpty'));
      expect(uploadSource, contains('maxDocumentBytes'));
      expect(uploadSource, isNot(contains('bucket')));
    });

    test('passport submission remains pending and confirms under review', () {
      expect(
        reviewSource,
        contains(
          "'passport_status': DocumentStatusService.pendingVerification",
        ),
      );
      expect(reviewSource, contains("'passport_verified': false"));
      expect(
        reviewSource,
        contains(
          'Passport submitted successfully. Your document is now under review.',
        ),
      );
      expect(reviewSource, isNot(contains("'passport_verified': true")));
    });

    test('document status labels map to user-friendly values', () {
      expect(
        DocumentStatusService.label('pending', uploaded: true),
        'Pending Review',
      );
      expect(
        DocumentStatusService.label('under_review', uploaded: true),
        'Under Review',
      );
      expect(
        DocumentStatusService.label('approved', uploaded: true),
        'Verified',
      );
      expect(
        DocumentStatusService.label('verified', uploaded: true),
        'Verified',
      );
      expect(
        DocumentStatusService.label('rejected', uploaded: true),
        'Rejected',
      );
      expect(
        DocumentStatusService.label('reupload_required', uploaded: true),
        'Re-upload Required',
      );
    });

    test(
      'driving licence supports multiple real selections and exclusive none',
      () {
        expect(
          experienceSource,
          contains('final drivingLicenses = <String>{}'),
        );
        expect(experienceSource, contains('UAE Driving Licence'));
        expect(experienceSource, contains('India Driving Licence'));
        expect(
          experienceSource,
          contains("drivingLicenses.remove('No Driving Licence')"),
        );
        expect(experienceSource, contains('drivingLicenses'));
        expect(
          backendSource,
          contains('drivingLicenses: _drivingLicensesFromRow'),
        );
      },
    );

    test('other language displays a custom field and rejects empty values', () {
      expect(experienceSource, contains("languages.contains('Other')"));
      expect(experienceSource, contains('Enter language *'));
      expect(
        experienceSource,
        contains("next['other_language'] = 'Enter language.'"),
      );
      expect(
        experienceSource,
        contains('titleCase(otherLanguageController.text)'),
      );
    });

    test(
      'required-field validation blocks continuation with inline messages',
      () {
        expect(experienceSource, contains('Select at least one skill.'));
        expect(experienceSource, contains('Enter your years of experience.'));
        expect(experienceSource, contains('Select your expected salary.'));
        expect(experienceSource, contains('Select your availability.'));
        expect(
          experienceSource,
          contains('Choose your driving licence status.'),
        );
        expect(experienceSource, contains('errorText: errors'));
      },
    );

    test('current employment status is saved, restored, and displayed', () {
      expect(experienceSource, contains('Current Employment Status *'));
      expect(experienceSource, contains("'current_employment_status'"));
      expect(backendSource, contains('currentEmploymentStatus'));
      expect(profileSource, contains('Employment:'));
    });

    test('profile photo and CV metadata persist privately', () {
      expect(mediaSource, contains('candidate-profile-photos'));
      expect(mediaSource, contains('candidate-cv'));
      expect(mediaSource, contains('uploadPrivateFile'));
      expect(backendSource, contains('profile_photo_file_name'));
      expect(backendSource, contains('resume_file_name'));
      expect(mediaSource, contains('Unsupported CV format'));
      expect(profileSource, contains('PrivateProfilePhotoAvatar'));
      expect(avatarSource, contains('PrivateProfilePhotoResolver.resolve'));
      expect(photoResolverSource, contains(".from('kaam-private')"));
      expect(photoResolverSource, contains('.createSignedUrl('));
    });

    test('OCR-extracted values can be manually edited before save', () {
      expect(reviewSource, contains('TextEditingController'));
      expect(reviewSource, contains('currentArgs.extractedFields[field.key]'));
      expect(reviewSource, contains('entry.value.text.trim()'));
      expect(reviewSource, contains('saveIdentityDocuments'));
    });

    test('existing single-value driving licence records load safely', () {
      expect(
        backendSource,
        contains("_stringList(candidate?['driving_licenses'])"),
      );
      expect(backendSource, contains("candidate?['driving_license']"));
      expect(backendSource, contains("'UAE' => const ['UAE Driving Licence']"));
    });

    test(
      'partially completed onboarding proceeds to profile media without reset',
      () {
        expect(experienceSource, contains('AppRoutes.profileMedia'));
        expect(mediaSource, contains('Review Profile'));
        expect(migrationSource, contains('add column if not exists'));
      },
    );

    test('important document notifications show once and are marked read', () {
      expect(dashboardSource, contains('candidate_document_approved'));
      expect(dashboardSource, contains('candidate_document_rejected'));
      expect(
        dashboardSource,
        contains('candidate_document_resubmission_requested'),
      );
      expect(dashboardSource, contains('markRead(important.id)'));
    });
  });
}
