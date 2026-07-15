import 'package:flutter_test/flutter_test.dart';
import 'package:kaam_perfect_match/features/candidate/documents/identity_document_ocr_service.dart';

void main() {
  test('parses normalized passport OCR response', () {
    final result = PassportExtractionResult.fromResponse({
      'success': true,
      'data': {
        'full_name': 'Example Name',
        'passport_number': 'N1234567',
        'nationality': 'IND',
        'date_of_birth': '1996-05-12',
        'gender': 'M',
        'issue_date': '2026-05-10',
        'expiry_date': '2036-05-09',
        'place_of_birth': 'KERALA',
        'country_of_issue': 'IND',
      },
    });

    expect(result.fullName, 'Example Name');
    expect(result.passportNumber, 'N1234567');
    expect(result.toIdentityFields()['dob'], '1996-05-12');
    expect(result.toIdentityFields()['passport_expiry_date'], '2036-05-09');
  });

  test('parses common alternate OCR keys', () {
    final result = PassportExtractionResult.fromResponse({
      'data': {
        'holder_name': 'Alt Name',
        'documentNumber': 'A7654321',
        'birth_date': '12/05/1996',
        'expiration_date': '09/05/2036',
        'sex': 'F',
        'issuing_country': 'IND',
      },
    });

    expect(result.fullName, 'Alt Name');
    expect(result.passportNumber, 'A7654321');
    expect(result.gender, 'F');
    expect(result.toIdentityFields()['dob'], '1996-05-12');
  });

  test('parses two-line passport MRZ', () {
    final result = PassportExtractionResult.fromResponse({
      'data': {
        'mrz_text':
            'P<INDDOE<<JOHN<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<\nN1234567<7IND9605121M3605097<<<<<<<<<<<<<<04',
      },
    });

    expect(result.firstName, 'John');
    expect(result.lastName, 'Doe');
    expect(result.passportNumber, 'N1234567');
    expect(result.nationality, 'IND');
    expect(result.toIdentityFields()['dob'], '1996-05-12');
    expect(result.toIdentityFields()['passport_expiry_date'], '2036-05-09');
  });

  test('empty response is safe', () {
    final result = PassportExtractionResult.fromResponse({});
    expect(result.hasAnyData, isFalse);
    expect(result.toIdentityFields()['passport_number'], '');
  });
}
