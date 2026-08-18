import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kaam_perfect_match/features/supabase_backend/kaam_backend.dart';

void main() {
  group('candidate salary formatting', () {
    test('formats a real range with grouping and no repeated currency', () {
      expect(
        formatCandidateSalary(minimum: 2800, maximum: 3200),
        'AED 2,800–3,200',
      );
    });

    test('collapses equal minimum and maximum into one value', () {
      expect(
        formatCandidateSalary(minimum: 3000, maximum: 3000),
        'AED 3,000',
      );
    });

    test('handles one-sided and missing salary data safely', () {
      expect(formatCandidateSalary(maximum: 3500), 'AED 3,500');
      expect(formatCandidateSalary(minimum: 2500), 'AED 2,500');
      expect(formatCandidateSalary(), 'Not specified');
    });
  });

  test('salary filter keeps candidates whose expectation overlaps the range',
      () {
    const filters = EmployerCandidateSearchFilters(
      minimumSalary: 2500,
      maximumSalary: 3500,
    );
    final matching = <String, dynamic>{
      'expected_salary_min': 2800,
      'expected_salary_max': 3200,
    };
    final outside = <String, dynamic>{
      'expected_salary_min': 4000,
      'expected_salary_max': 4500,
    };
    expect(EmployerCandidateSearchMatcher.matches(matching, filters), isTrue);
    expect(EmployerCandidateSearchMatcher.matches(outside, filters), isFalse);
  });

  group('native matching UI contract', () {
    late String searchSource;
    late String interestSource;
    late String backendSource;

    setUpAll(() {
      searchSource = File(
        'lib/features/employer/search/employer_search_screens.dart',
      ).readAsStringSync();
      interestSource = File(
        'lib/features/employer/interests/employer_interest_screens.dart',
      ).readAsStringSync();
      backendSource = File(
        'lib/features/supabase_backend/kaam_backend.dart',
      ).readAsStringSync();
    });

    test('filter selection starts the real matching search', () {
      expect(searchSource, contains("'Find Candidates'"));
      expect(searchSource, contains("'Start Matching'"));
      expect(searchSource, contains('_search(collapseFilters: true)'));
      expect(searchSource, contains('EmployerCandidateSearchFilters('));
    });

    test('candidate actions stay labeled and guarded', () {
      expect(searchSource, contains("label: 'Pass'"));
      expect(searchSource, contains("'Save'"));
      expect(searchSource, contains("label: 'View Profile'"));
      expect(searchSource, contains("label: 'Show Interest'"));
      expect(searchSource, contains('candidateActionInProgress'));
      expect(searchSource, contains("Text('Candidate passed.')"));
      expect(searchSource, contains("'Candidate saved.'"));
    });

    test('active candidate content scrolls independently of a sticky action dock',
        () {
      expect(searchSource, contains('class _CandidateActionDock'));
      expect(searchSource, contains("label: 'Candidate actions'"));
      expect(
        searchSource,
        contains("PageStorageKey('matching-candidate-content')"),
      );
      expect(searchSource, contains('child: ClipRect('));
      expect(searchSource, contains('Expanded(child: pass)'));
      expect(searchSource, contains('Expanded(child: save)'));
      expect(searchSource, contains('Expanded(child: viewProfile)'));
      expect(searchSource, contains('constraints.maxWidth < 300'));
    });

    test('empty, loading, and repository error states are explicit', () {
      expect(searchSource, contains('const _CandidateSkeletonCard()'));
      expect(searchSource, contains("title: 'No strong matches yet'"));
      expect(searchSource, contains("title: 'Could not load candidates'"));
      expect(searchSource, contains("label: 'Try Again'"));
    });

    test('match percentages remain hidden without a production algorithm', () {
      expect(searchSource, isNot(contains('% Match')));
      expect(searchSource, isNot(contains('matchScore')));
    });

    test('interest creation is duplicate-safe and uses existing route', () {
      expect(searchSource, contains('AppRoutes.employerSendInterest'));
      expect(interestSource, contains('InterestAlreadySentException'));
      expect(interestSource, contains('Interest already sent.'));
      expect(backendSource, contains("select('id')"));
      expect(backendSource, contains("error.code == '23505'"));
    });
  });
}
