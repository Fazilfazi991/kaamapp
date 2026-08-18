import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late final String onboardingSource;
  late final String companySource;
  late final String backendSource;

  setUpAll(() {
    onboardingSource = File(
      'lib/features/employer/onboarding/employer_onboarding_screens.dart',
    ).readAsStringSync();
    companySource = File(
      'lib/features/employer/company/employer_company_screens.dart',
    ).readAsStringSync();
    backendSource = File(
      'lib/features/supabase_backend/kaam_backend.dart',
    ).readAsStringSync();
  });

  test('normal employer onboarding bypasses verification documents', () {
    final start = onboardingSource.indexOf('Future<void> _continue() async');
    final end = onboardingSource.indexOf('  @override\n  Widget build', start);
    final companyContinue = onboardingSource.substring(start, end);

    expect(companyContinue, contains('AppRoutes.employerProfileComplete'));
    expect(
      companyContinue,
      isNot(contains('AppRoutes.employerBusinessVerification')),
    );
  });

  test('verification screen is retained only as an optional document surface',
      () {
    expect(onboardingSource, contains('Optional business documents'));
    expect(
        onboardingSource, contains('does not affect access to employer tools'));
    expect(onboardingSource, contains('recordVerificationDocument'));
  });

  test('unverified employers receive a non-blocking trust status', () {
    expect(companySource, contains("'Not verified'"));
    expect(companySource, contains('candidate search remain available'));
    expect(companySource, isNot(contains('Documents under review')));
  });

  test('historical verification document data remains readable', () {
    expect(companySource, contains('listMyDocuments'));
    expect(backendSource, contains("from('verification_documents')"));
  });
}
