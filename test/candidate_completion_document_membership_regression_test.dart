import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('candidate completion, documents, and membership regressions', () {
    late final String dashboard;
    late final String profile;
    late final String editProfile;
    late final String documents;
    late final String widgets;
    late final String completion;
    late final String backend;

    setUpAll(() {
      dashboard = File(
              'lib/features/candidate/dashboard/candidate_dashboard_screen.dart')
          .readAsStringSync();
      profile =
          File('lib/features/candidate/profile/candidate_profile_screen.dart')
              .readAsStringSync();
      editProfile =
          File('lib/features/candidate/profile/edit_profile_screen.dart')
              .readAsStringSync();
      documents =
          File('lib/features/candidate/onboarding/documents_upload_screen.dart')
              .readAsStringSync();
      widgets =
          File('lib/core/widgets/candidate_widgets.dart').readAsStringSync();
      completion = File(
              'lib/features/candidate/profile/candidate_profile_completion.dart')
          .readAsStringSync();
      backend = File('lib/features/supabase_backend/kaam_backend.dart')
          .readAsStringSync();
    });

    test('dashboard, profile, and edit profile use centralized completion', () {
      expect(dashboard, contains('value: completion.percentage'));
      expect(profile, contains('CandidateProfileCompletion.calculate'));
      expect(editProfile, contains('CandidateProfileCompletion.calculate'));
      expect(
          completion, contains('CandidateSectionCompletionState.underReview'));
      expect(completion,
          contains('CandidateSectionCompletionState.actionRequired'));
    });

    test('document step keeps a state-aware Continue action visible', () {
      expect(documents,
          contains("label: continuing ? 'Continuing...' : 'Continue'"));
      expect(documents,
          contains('Upload and save passport front and back to continue.'));
      expect(documents, contains('pendingReview == null'));
      expect(documents,
          contains('Navigator.of(context).pushNamed(AppRoutes.basicDetails)'));
    });

    test('membership badge is derived from persisted membership state', () {
      expect(widgets, contains('class CandidateMembershipBadge'));
      expect(widgets, contains('CandidateMembershipPresentation.resolve'));
      expect(widgets, contains('presentation.secondaryLabel'));
      expect(backend, contains("secondaryLabel: 'Test Membership'"));
      expect(dashboard, contains('CandidateMembershipBadge('));
      expect(profile,
          contains('CandidateMembershipBadge(membership: membership)'));
      expect(editProfile, contains('CandidateMembershipBadge('));
    });
  });
}
