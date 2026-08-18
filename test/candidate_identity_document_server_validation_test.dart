import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final migration = File(
    'supabase/027_identity_document_validation.sql',
  ).readAsStringSync();
  final edgeFunction = File(
    'supabase/functions/passport-ocr/index.ts',
  ).readAsStringSync();
  final uploadScreen = File(
    'lib/features/candidate/onboarding/documents_upload_screen.dart',
  ).readAsStringSync();
  final reviewScreen = File(
    'lib/features/candidate/documents/identity_document_review_screen.dart',
  ).readAsStringSync();

  test('server stores immutable validation evidence before submission', () {
    expect(migration, contains('candidate_document_validations'));
    expect(migration, contains('file_hash text not null'));
    expect(migration, contains("status in ('accepted', 'rejected')"));
    expect(migration, contains('expires_at timestamptz not null'));
    expect(migration, contains('consumed_at timestamptz'));
  });

  test('server submission requires both independently validated passport sides',
      () {
    expect(migration, contains('Passport front and back are required'));
    expect(migration, contains("document_type = 'passport_back'"));
    expect(migration,
        contains('Passport front and back cannot use the same file'));
    expect(migration, contains('submit_candidate_identity_documents'));
  });

  test('direct document writes are blocked outside the submission RPC', () {
    expect(migration, contains('enforce_identity_document_submission'));
    expect(
        migration, contains('candidate_documents_require_server_validation'));
    expect(migration, contains("app.identity_document_submission"));
  });

  test('edge validation hashes private storage bytes and fails closed', () {
    expect(edgeFunction, contains('crypto.subtle.digest("SHA-256"'));
    expect(edgeFunction,
        contains('Validation service is temporarily unavailable'));
    expect(edgeFunction, contains('result.status === "accepted"'));
    expect(edgeFunction, contains('mrz_not_detected'));
  });

  test(
      'client validates both passport sides before review and no manual fallback',
      () {
    expect(uploadScreen, contains('validatePassportBack'));
    expect(
        uploadScreen, contains('IdentityDocumentImageQuality.rejectionReason'));
    expect(
        uploadScreen, isNot(contains('You can enter the details manually.')));
  });

  test('extracted fields are locked unless a reasoned correction is recorded',
      () {
    expect(reviewScreen, contains('Correct an extracted value'));
    expect(reviewScreen, contains("label: 'Reason for correction'"));
    expect(reviewScreen, contains('readOnly: !correctionMode'));
  });
}
