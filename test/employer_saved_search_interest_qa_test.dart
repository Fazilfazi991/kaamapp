import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('employer saved/search/interests QA fixes', () {
    late final String searchSource;
    late final String widgetSource;
    late final String backendSource;
    late final String migrationSource;
    late final String interestSource;

    setUpAll(() {
      searchSource = File(
        'lib/features/employer/search/employer_search_screens.dart',
      ).readAsStringSync();
      widgetSource = File(
        'lib/features/employer/widgets/employer_widgets.dart',
      ).readAsStringSync();
      backendSource = File(
        'lib/features/supabase_backend/kaam_backend.dart',
      ).readAsStringSync();
      interestSource = File(
        'lib/features/employer/interests/employer_interest_screens.dart',
      ).readAsStringSync();
      migrationSource = File(
        'supabase/022_employer_saved_recently_viewed.sql',
      ).readAsStringSync();
    });

    test('Saved Candidates is a real tab and screen', () {
      expect(widgetSource, contains("label: 'Saved'"));
      expect(widgetSource, contains('AppRoutes.employerSavedCandidates'));
      expect(searchSource, contains('repository.savedCandidates()'));
      expect(searchSource, isNot(contains('saved-candidate list is disabled')));
      expect(searchSource, contains('No saved candidates yet'));
    });

    test('bookmark state toggles save and remove through Supabase source', () {
      expect(widgetSource, contains('removeSavedCandidate(candidateId)'));
      expect(widgetSource, contains('saveCandidate(candidateId)'));
      expect(widgetSource, contains('Icons.bookmark_rounded'));
      expect(widgetSource, contains('Icons.bookmark_border_rounded'));
      expect(widgetSource, contains('Removed from saved candidates.'));
      expect(widgetSource, contains('setState(() => saved = previous)'));
    });

    test('saved candidates persist with owner-scoped table access', () {
      expect(backendSource, contains("from('saved_candidates')"));
      expect(backendSource, contains("onConflict: 'employer_id,candidate_id'"));
      expect(backendSource, contains("eq('employer_id', user.id)"));
      expect(backendSource, contains('savedCandidateIds'));
    });

    test(
      'recently viewed persists and deduplicates by employer and candidate',
      () {
        expect(searchSource, contains('_RecentlyViewedCandidates'));
        expect(backendSource, contains('recordCandidateView'));
        expect(backendSource, contains("from('employer_candidate_views')"));
        expect(
          backendSource,
          contains("onConflict: 'employer_id,candidate_id'"),
        );
        expect(
          migrationSource,
          contains('primary key (employer_id, candidate_id)'),
        );
        expect(migrationSource, contains('viewed_at timestamptz'));
        expect(migrationSource, contains('employer_id = auth.uid()'));
        expect(migrationSource, isNot(contains('using (true)')));
        expect(migrationSource, isNot(contains('with check (true)')));
      },
    );

    test(
      'interest request loading avoids fragile nested relationship aliases',
      () {
        expect(backendSource, contains('_employerInterestSelect'));
        expect(backendSource, contains("from('public_candidate_search')"));
        expect(
          backendSource,
          isNot(
            contains(
              'candidate_profiles(headline,current_city,current_country',
            ),
          ),
        );
        expect(backendSource, contains('structured_request_load_failed'));
        expect(interestSource, contains('Could not load interests'));
        expect(interestSource, contains('Retry'));
        expect(interestSource, isNot(contains('snapshot.error')));
      },
    );

    test('location filters are hierarchical and All Locations is not sent', () {
      expect(searchSource, contains('locationCountry'));
      expect(searchSource, contains('All Locations'));
      expect(searchSource, contains('All Emirates'));
      expect(searchSource, contains('All States'));
      expect(searchSource, contains('CandidateLocationOptions.uaeEmirates'));
      expect(searchSource, contains('CandidateLocationOptions.indianStates'));
      expect(searchSource, isNot(contains("'Both'")));
      expect(
        searchSource,
        contains('List<String> _effectiveLocationFilters()'),
      );
    });

    test(
      'canonical role selector replaces obsolete category skill filters',
      () {
        expect(searchSource, contains("label: 'Job Role'"));
        expect(searchSource, contains('showJobRoleSearchSheet'));
        expect(searchSource, isNot(contains('categorySkills')));
        expect(searchSource, isNot(contains('catalogSkills')));
      },
    );

    test('More Filters exposed controls are connected to query filters', () {
      expect(searchSource, contains("title: 'Experience'"));
      expect(searchSource, contains("title: 'Visa status'"));
      expect(searchSource, contains("title: 'Availability'"));
      expect(searchSource, contains("title: 'Nationality'"));
      expect(searchSource, contains("title: 'Languages'"));
      expect(backendSource, contains('effectiveExperiences'));
      expect(backendSource, contains('effectiveVisaStatuses'));
      expect(backendSource, contains('effectiveAvailabilities'));
      expect(backendSource, contains('effectiveNationalities'));
      expect(backendSource, contains('effectiveLanguages'));
    });
  });
}
