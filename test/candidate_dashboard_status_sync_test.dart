import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kaam_perfect_match/features/candidate/profile/candidate_profile_completion.dart';
import 'package:kaam_perfect_match/features/supabase_backend/kaam_backend.dart';

void main() {
  group('candidate dashboard status sync', () {
    late String dashboardSource;
    late String backendSource;
    late String completionSource;

    setUpAll(() {
      dashboardSource = File(
        'lib/features/candidate/dashboard/candidate_dashboard_screen.dart',
      ).readAsStringSync();
      backendSource = File(
        'lib/features/supabase_backend/kaam_backend.dart',
      ).readAsStringSync();
      completionSource = File(
        'lib/features/candidate/profile/candidate_profile_completion.dart',
      ).readAsStringSync();
    });

    test('approved passport and visa map to verified dashboard documents', () {
      final status = CandidateDashboardEligibilityStatus.fromLiveData(
        profile: _completeProfile(),
        identity: const CandidateIdentityDocumentData(
          passportFileUrl: 'front.jpg',
          passportBackFileUrl: 'back.jpg',
          passportStatus: 'approved',
          visaFileUrl: 'visa.jpg',
          visaStatus: 'approved',
        ),
        membership: const CandidateMembershipData(status: 'inactive'),
      );

      expect(status.passportVerified, isTrue);
      expect(status.visaVerified, isTrue);
      expect(status.documentsVerified, isTrue);
    });

    test(
      'candidate returned by employer visibility RPC shows visible state',
      () {
        final status = CandidateDashboardEligibilityStatus.fromLiveData(
          profile: const CandidateProfileData(isVisible: true),
          identity: const CandidateIdentityDocumentData(),
          membership: const CandidateMembershipData(status: 'inactive'),
          visibleToEmployersOverride: true,
        );

        expect(status.visibleToEmployers, isTrue);
        expect(status.profileComplete, isTrue);
        expect(status.documentsVerified, isTrue);
        expect(status.primaryActionLabel, 'View Profile');
        expect(status.profileStrengthPercentage, 75);
      },
    );

    test(
      'fully visible dashboard source does not show Complete Profile action',
      () {
        expect(
          dashboardSource,
          contains('Your profile is visible to employers'),
        );
        expect(dashboardSource, contains('primaryActionLabel'));
        expect(completionSource, contains('View Profile'));
        expect(dashboardSource, isNot(contains("live ? 'Complete Profile'")));
      },
    );

    test('pending and rejected documents map to review/action states', () {
      final pending = CandidateDashboardEligibilityStatus.fromLiveData(
        profile: _completeProfile(),
        identity: const CandidateIdentityDocumentData(
          passportFileUrl: 'front.jpg',
          passportBackFileUrl: 'back.jpg',
          passportStatus: 'under_review',
        ),
        membership: const CandidateMembershipData(),
      );
      expect(pending.underReview, isTrue);
      expect(pending.primaryActionLabel, 'View Documents');

      final rejected = CandidateDashboardEligibilityStatus.fromLiveData(
        profile: _completeProfile(),
        identity: const CandidateIdentityDocumentData(
          passportFileUrl: 'front.jpg',
          passportBackFileUrl: 'back.jpg',
          passportStatus: 'reupload_required',
        ),
        membership: const CandidateMembershipData(),
      );
      expect(rejected.actionRequired, isTrue);
      expect(rejected.primaryActionLabel, 'Update Documents');
    });

    test('dashboard refreshes live status on resume and notifications', () {
      expect(dashboardSource, contains('with WidgetsBindingObserver'));
      expect(dashboardSource, contains('didChangeAppLifecycleState'));
      expect(dashboardSource, contains('AppLifecycleState.resumed'));
      expect(dashboardSource, contains("pushNamed(AppRoutes.notifications)"));
      expect(dashboardSource, contains('then((_) => _reload())'));
      expect(dashboardSource, contains('visibleToEmployersFuture'));
    });

    test(
      'dashboard waits for fresh Supabase state instead of default hidden data',
      () {
        expect(dashboardSource, contains('CircularProgressIndicator'));
        expect(dashboardSource, contains('snapshot.hasError'));
        expect(
          dashboardSource,
          contains(
            'We could not refresh your profile status. Please try again.',
          ),
        );
      },
    );

    test(
      'backend uses candidate_visible_to_employers as employer-search source',
      () {
        expect(backendSource, contains('currentCandidateVisibleToEmployers'));
        expect(backendSource, contains('candidate_visible_to_employers'));
        expect(backendSource, contains('target_candidate_id'));
      },
    );

    test(
      'profile strength and dashboard card use centralized eligibility model',
      () {
        expect(
          completionSource,
          contains('CandidateDashboardEligibilityStatus'),
        );
        expect(completionSource, contains('profileStrengthPercentage'));
        expect(
          dashboardSource,
          contains('CandidateDashboardEligibilityStatus.fromLiveData'),
        );
        expect(
          dashboardSource,
          contains('CandidateProfileCompletion.calculate'),
        );
        expect(dashboardSource, contains('value: completion.percentage'));
        expect(dashboardSource, contains('eligibility.documentsVerified'));
      },
    );

    test('raw backend errors are not displayed in status UI', () {
      expect(dashboardSource, isNot(contains('snapshot.error.toString()')));
      expect(dashboardSource, isNot(contains('PostgrestException')));
    });
  });
}

CandidateProfileData _completeProfile() => const CandidateProfileData(
      nationality: 'India',
      currentCountry: 'UAE',
      currentCity: 'Dubai',
      preferredCountry: 'UAE',
      preferredCity: 'Dubai',
      jobCategories: ['Hospitality'],
      skills: ['Waiter'],
      headline: 'Waiter',
      availability: 'Immediate',
    );
