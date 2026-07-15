import 'package:flutter_test/flutter_test.dart';
import 'package:kaam_perfect_match/features/supabase_backend/kaam_backend.dart';

Map<String, dynamic> candidateRow({
  String nationality = 'Indian',
  String availability = 'Available Immediately',
  List<String> languages = const ['English'],
  List<String> skills = const ['Mason'],
  bool verified = true,
}) {
  return {
    'full_name': 'Candidate',
    'headline': 'Mason',
    'current_city': 'Dubai',
    'current_country': 'UAE',
    'preferred_city': 'Dubai',
    'preferred_country': 'UAE',
    'availability': availability,
    'nationality': nationality,
    'languages': languages,
    'skills': skills,
    'job_categories': const ['Construction'],
    'experience_years': 3,
    'is_verified': verified,
  };
}

void main() {
  group('multi-select employer filters', () {
    test('selecting two availability options keeps both selected', () {
      final group = MultiSelectFilterGroup();
      group.toggle('Available Immediately');
      group.toggle('Within 15 days');
      expect(group.selected,
          containsAll(['Available Immediately', 'Within 15 days']));
    });

    test('selecting three nationalities keeps all three selected', () {
      final group = MultiSelectFilterGroup();
      group.toggle('Indian');
      group.toggle('Pakistani');
      group.toggle('Bangladeshi');
      expect(
          group.selected, containsAll(['Indian', 'Pakistani', 'Bangladeshi']));
    });

    test('selecting multiple languages keeps all selected', () {
      final group = MultiSelectFilterGroup(['English', 'Hindi', 'Arabic']);
      expect(group.selected.length, 3);
    });

    test('tapping a selected chip deselects only that chip', () {
      final group = MultiSelectFilterGroup(['English', 'Hindi', 'Arabic']);
      group.toggle('Hindi');
      expect(group.selected, containsAll(['English', 'Arabic']));
      expect(group.selected, isNot(contains('Hindi')));
    });

    test('clear filters clears every selected filter', () {
      final groups = [
        MultiSelectFilterGroup(['A']),
        MultiSelectFilterGroup(['B']),
        MultiSelectFilterGroup(['C']),
      ];
      for (final group in groups) {
        group.clear();
      }
      expect(groups.every((group) => group.selected.isEmpty), isTrue);
    });

    test('verified profile remains a boolean toggle', () {
      const filters = EmployerCandidateSearchFilters(verifiedOnly: true);
      expect(filters.verifiedOnly, isTrue);
    });

    test('backend query uses OR within one filter category', () {
      const filters = EmployerCandidateSearchFilters(
        nationalities: ['Indian', 'Pakistani'],
      );
      expect(EmployerCandidateSearchMatcher.matches(candidateRow(), filters),
          isTrue);
    });

    test('backend query uses AND between separate filter categories', () {
      const filters = EmployerCandidateSearchFilters(
        nationalities: ['Indian'],
        languages: ['Arabic'],
      );
      expect(EmployerCandidateSearchMatcher.matches(candidateRow(), filters),
          isFalse);
    });

    test('array fields such as skills and languages use overlap logic', () {
      const filters = EmployerCandidateSearchFilters(
        skills: ['Carpenter', 'Mason'],
        languages: ['Hindi', 'English'],
      );
      expect(EmployerCandidateSearchMatcher.matches(candidateRow(), filters),
          isTrue);
    });

    test('no-filter search returns candidates normally', () {
      const filters = EmployerCandidateSearchFilters();
      expect(filters.isEmpty, isTrue);
      expect(EmployerCandidateSearchMatcher.matches(candidateRow(), filters),
          isTrue);
    });
  });

  test('candidate skill limit is three', () {
    expect(CandidateSkillLimits.maxSkills, 3);
    expect(CandidateSkillLimits.maxMessage,
        'You can select a maximum of 3 skills.');
  });
}
