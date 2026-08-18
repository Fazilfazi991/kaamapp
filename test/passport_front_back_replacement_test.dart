import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kaam_perfect_match/features/candidate/onboarding/documents_upload_screen.dart';
import 'package:kaam_perfect_match/features/supabase_backend/kaam_backend.dart';

void main() {
  group('passport front and back replacement regression', () {
    late final String uploadSource;
    late final String reviewSource;
    late final String backendSource;
    late final String adminDataSource;
    late final String adminTypesSource;
    late final String adminPageSource;
    late final String adminPreviewSource;
    late final String storagePolicySource;
    late final String validationMigration;

    setUpAll(() {
      uploadSource = File(
        'lib/features/candidate/onboarding/documents_upload_screen.dart',
      ).readAsStringSync();
      reviewSource = File(
        'lib/features/candidate/documents/identity_document_review_screen.dart',
      ).readAsStringSync();
      backendSource = File(
        'lib/features/supabase_backend/kaam_backend.dart',
      ).readAsStringSync();
      adminDataSource = File(
        'web/src/features/admin/server/data.ts',
      ).readAsStringSync();
      adminTypesSource = File(
        'web/src/features/admin/types/index.ts',
      ).readAsStringSync();
      adminPageSource = File(
        'web/src/app/admin/candidate-documents/[documentId]/page.tsx',
      ).readAsStringSync();
      adminPreviewSource = File(
        'web/src/app/admin/candidate-documents/preview/[documentId]/route.ts',
      ).readAsStringSync();
      storagePolicySource =
          File('supabase/001_kaam_initial_schema.sql').readAsStringSync();
      validationMigration =
          File('supabase/027_identity_document_validation.sql')
              .readAsStringSync();
    });

    test('1 front and back have separate upload controls', () {
      expect(uploadSource, contains("'Upload \$title'"));
      expect(uploadSource, contains("'Replace \$sideLabel'"));
      expect(uploadSource, contains("'Passport Front'"));
      expect(uploadSource, contains("'Passport Back'"));
    });

    test('2 uploaded front preview is visible', () {
      expect(uploadSource, contains('passportFrontPreviewBytes'));
      expect(uploadSource, contains('Image.memory('));
    });

    test('3 uploaded back preview is visible', () {
      expect(uploadSource, contains('passportBackPreviewBytes'));
      expect(uploadSource, contains('Image.network('));
    });

    test('4 replace front updates only the front upload state', () {
      expect(passportStorageDocumentType(isFront: true), 'passport');
      expect(passportStorageDocumentType(isFront: false), 'passport-back');
      expect(
        uploadSource,
        contains(
            'passportStorageDocumentType(isFront: side == _PassportSide.front)'),
      );
    });

    test('5 replace back stages only the back upload for server submission',
        () {
      expect(uploadSource, contains('passportBackUpload = upload'));
      expect(uploadSource, contains('ocr.validatePassportBack('));
      expect(uploadSource,
          isNot(contains("'passport_back_file_url': upload.path")));
    });

    test('6 replacing front preserves the saved back path', () {
      expect(uploadSource, contains('identity.passportBackFileUrl'));
      expect(reviewSource, contains("'passport_back_file_url'"));
    });

    test('7 server submission carries both saved passport paths', () {
      expect(backendSource, contains("'p_front_path': frontPath"));
      expect(backendSource, contains("'p_back_path': backPath"));
    });

    test('8 local replacement preview appears before private upload', () {
      final preview = uploadSource.indexOf('Uint8List.fromList(picked.bytes)');
      final upload =
          uploadSource.indexOf('storage.uploadCandidateIdentityDocument(');
      expect(preview, greaterThan(-1));
      expect(preview, lessThan(upload));
    });

    test('9 failed front replacement restores the old front', () {
      expect(uploadSource, contains('_restorePassportSide('));
      expect(
        uploadSource,
        contains(
          'We could not replace the passport front. Please try again.',
        ),
      );
    });

    test('10 failed back replacement restores the old back', () {
      expect(
        uploadSource,
        contains(
          'We could not replace the passport back. Please try again.',
        ),
      );
    });

    test('11 a failed upload keeps the prior active preview state', () {
      expect(uploadSource, contains('_restorePassportSide('));
      expect(uploadSource, contains('pendingReview = previousPendingReview'));
    });

    test('12 front replacement triggers the passport OCR source', () {
      expect(
        uploadSource,
        contains('if (side == _PassportSide.front)'),
      );
      expect(uploadSource, contains('extraction = await ocr.extract('));
    });

    test('13 server submission retains extracted passport data as evidence',
        () {
      expect(backendSource, contains("'p_fields': {"));
      expect(validationMigration, contains("'original_extraction'"));
      expect(validationMigration, contains("p_fields->>'passport_number'"));
    });

    test('14 latest version stores both paths', () {
      expect(
          validationMigration,
          contains(
              "jsonb_build_object('front', p_front_path, 'back', p_back_path"));
      expect(adminDataSource, contains('file_paths'));
    });

    test('15 either replacement resets review status and increments version',
        () {
      expect(validationMigration,
          contains('coalesce(v_existing.passport_version, 0) + 1'));
      expect(
        validationMigration,
        contains("passport_status = 'pending_verification'"),
      );
    });

    test('16 both persisted images restore after a new model load', () {
      final restored = CandidateIdentityDocumentData.fromRow({
        'passport_file_url': 'candidate/front/new.jpg',
        'passport_back_file_url': 'candidate/back/old.jpg',
      });
      expect(restored.hasPassport, isTrue);
      expect(restored.passportFileUrl, 'candidate/front/new.jpg');
      expect(restored.passportBackFileUrl, 'candidate/back/old.jpg');
    });

    test('17 logout and login restoration uses database paths', () {
      expect(
        backendSource,
        contains("passportFileUrl: row?['passport_file_url']"),
      );
      expect(
        backendSource,
        contains("passportBackFileUrl: row?['passport_back_file_url']"),
      );
      expect(uploadSource, contains('await profiles.loadIdentityDocuments()'));
    });

    test('18 admin receives and renders both current paths', () {
      expect(adminTypesSource, contains('passport_back_file_url'));
      expect(adminTypesSource, contains('file_paths?:'));
      expect(adminPageSource, contains('Current Passport Front'));
      expect(adminPageSource, contains('Current Passport Back'));
      expect(adminPreviewSource, contains('document.file_paths?.back'));
    });

    test('19 employers cannot read private passport objects', () {
      expect(storagePolicySource, contains('kaam_private_owner_read'));
      expect(storagePolicySource, contains("bucket_id = 'kaam-private'"));
      expect(
        storagePolicySource,
        contains("(storage.foldername(name))[1] = auth.uid()::text"),
      );
      expect(storagePolicySource, isNot(contains('kaam_private_employer')));
    });

    test('20 raw storage and Supabase errors are not shown', () {
      expect(uploadSource, contains('} catch (_) {'));
      expect(uploadSource, isNot(contains('error.toString()')));
      expect(uploadSource, isNot(contains('PostgrestException')));
    });
  });
}
