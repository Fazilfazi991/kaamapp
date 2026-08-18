import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final upload =
      File('lib/features/candidate/onboarding/documents_upload_screen.dart')
          .readAsStringSync();
  final dashboard =
      File('lib/features/candidate/dashboard/candidate_dashboard_screen.dart')
          .readAsStringSync();

  test('dashboard document management uses an explicit non-onboarding mode',
      () {
    expect(upload, contains('enum CandidateDocumentEntryMode'));
    expect(upload, contains('CandidateDocumentEntryMode.dashboard'));
    expect(upload, contains('if (isOnboarding) const _OnboardingProgress()'));
    expect(upload, contains("title: isOnboarding ? 'KAAM' : 'Documents'"));
    expect(
        upload, contains("label: continuing ? 'Continuing...' : 'Continue'"));
    expect(upload, contains("child: const Text('Done')"));
    expect(upload,
        contains('CandidateDocumentsResult(documentChanged: documentChanged)'));
    expect(dashboard, contains('const CandidateDocumentEntryArgs.dashboard()'));
  });
}
