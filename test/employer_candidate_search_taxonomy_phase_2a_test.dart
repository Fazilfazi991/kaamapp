import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kaam_perfect_match/features/supabase_backend/kaam_backend.dart';

void main() {
  const candidateRow = {
    'full_name': 'Amina Khan',
    'headline': 'Porotta Maker',
    'current_city': 'Dubai',
    'preferred_city': 'Dubai',
    'current_country': 'UAE',
    'preferred_country': 'UAE',
    'availability': 'Available',
    'bio': '',
    'job_categories': ['Kitchen'],
    'skills': ['Porotta Maker'],
    'languages': ['English'],
  };

  test('canonical role label uses the existing compatible text-search path',
      () {
    const filters = EmployerCandidateSearchFilters(query: 'Porotta Maker');
    expect(
        EmployerCandidateSearchMatcher.matches(candidateRow, filters), isTrue);
  });

  test(
      'unmapped canonical role does not pretend to be an exact candidate match',
      () {
    const filters =
        EmployerCandidateSearchFilters(query: 'Unmapped Canonical Role');
    expect(
        EmployerCandidateSearchMatcher.matches(candidateRow, filters), isFalse);
  });

  test('non-role candidate search filters remain intact', () {
    const filters = EmployerCandidateSearchFilters(
      query: 'Porotta Maker',
      locations: ['Dubai'],
      languages: ['English'],
    );
    expect(
        EmployerCandidateSearchMatcher.matches(candidateRow, filters), isTrue);
  });

  test(
      'Employer Candidate Search has no obsolete fallback role/category catalog',
      () {
    final source =
        File('lib/features/employer/search/employer_search_screens.dart')
            .readAsStringSync();
    expect(source, contains('showJobRoleSearchSheet'));
    expect(source, contains('TaxonomyRepository'));
    expect(source, contains('selectedJobRole'));
    expect(source, contains('legacyRoleFilter'));
    expect(source, contains('selectedJobRole = null'));
    expect(source, isNot(contains('categorySkills')));
    expect(source, isNot(contains("'Warehouse Helper'")));
  });
}
