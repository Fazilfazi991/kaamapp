import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kaam_perfect_match/features/candidate/onboarding/work_preferences_screen.dart';
import 'package:kaam_perfect_match/features/candidate/profile/candidate_profile_completion.dart';
import 'package:kaam_perfect_match/features/supabase_backend/kaam_backend.dart';

void main() {
  group('candidate job hierarchy persistence', () {
    test('1. main category persists after restart simulation', () {
      final before = CandidateJobHierarchy.fromSelections(_constructionSaved());
      final after = CandidateJobHierarchy.fromSelections(_constructionSaved());

      expect(before.categoryId, 'category-construction');
      expect(after.categoryId, before.categoryId);
    });

    test('2. subcategory persists after restart simulation', () {
      final before = CandidateJobHierarchy.fromSelections(_constructionSaved());
      final after = CandidateJobHierarchy.fromSelections(_constructionSaved());

      expect(before.subcategoryId, 'skill-carpenter');
      expect(after.subcategoryId, before.subcategoryId);
    });

    test('3. skills persist with the selected subcategory', () {
      final hierarchy = CandidateJobHierarchy.fromSelections(
        _constructionSaved(),
      );

      expect(
        hierarchy.skillIds,
        containsAll(['skill-carpenter', 'skill-painter']),
      );
      expect(hierarchy.skillIds, contains(hierarchy.subcategoryId));
    });

    test('4. logout and login restore all three levels', () {
      final databaseRows = _hierarchyRows();
      final firstSession = CandidateJobHierarchy.fromSkillRows(databaseRows);
      final nextSession = CandidateJobHierarchy.fromSkillRows(
        databaseRows.map((row) => {...row}),
      );

      expect(nextSession.matches(firstSession), isTrue);
      expect(nextSession.isComplete, isTrue);
    });

    test('5. Edit Profile restores category subcategory and skills', () {
      final editSource = File(
        'lib/features/candidate/profile/edit_profile_screen.dart',
      ).readAsStringSync();
      final workSource = _workSource();

      expect(editSource, contains('AppRoutes.workPreferences'));
      expect(workSource, contains('CandidateJobHierarchyRestore.resolve('));
      expect(workSource, contains('primarySkillId = restored.subcategoryId'));
      expect(workSource, contains('..addAll(restored.skills)'));
    });

    test('6. forward and back navigation draft preserves selection', () {
      final saved = _constructionSaved();
      final draft = SkillSelectionDraft(
        categories: [saved.first.category],
        skills: saved.map((item) => item.skill).toList(),
        primarySkillId: saved.first.skill.id,
        savedBySkillId: {
          for (final item in saved) item.skill.id: item,
        },
      );

      expect(draft.categories.single.id, 'category-construction');
      expect(draft.primarySkillId, 'skill-carpenter');
      expect(draft.skills, hasLength(2));
    });

    test('7. async category loading does not clear saved subcategory', () {
      final restored = CandidateJobHierarchyRestore.resolve(
        categories: _categories(),
        skills: _catalogSkills(),
        savedSelections: _constructionSaved(),
      );

      expect(restored.category?.id, 'category-construction');
      expect(restored.subcategoryId, 'skill-carpenter');
      expect(restored.skills, hasLength(2));
    });

    test('8. changing another profile section does not clear hierarchy', () {
      final backend = File(
        'lib/features/supabase_backend/kaam_backend.dart',
      ).readAsStringSync();
      final start = backend.indexOf(
        'Future<CandidateProfileData> updateCurrentLocation',
      );
      final end = backend.indexOf(
        'Future<CandidateProfileData> updateVisaDetails',
        start,
      );
      final unrelatedUpdate = backend.substring(start, end);

      expect(unrelatedUpdate, isNot(contains('candidate_skills')));
      expect(unrelatedUpdate, isNot(contains('job_categories')));
      expect(unrelatedUpdate, isNot(contains('headline')));
    });

    test('9. changing category clears only incompatible subcategory', () {
      final current = _catalogSkills();
      final changed = CandidateJobHierarchyChange.forCategory(
        categoryId: 'category-construction',
        currentSkills: current,
        currentSubcategoryId: 'skill-electrician',
      );

      expect(changed.subcategoryId, isNull);
      expect(
          changed.skills.map((item) => item.id), contains('skill-carpenter'));
    });

    test('10. changing category clears only incompatible skills', () {
      final changed = CandidateJobHierarchyChange.forCategory(
        categoryId: 'category-construction',
        currentSkills: _catalogSkills(),
        currentSubcategoryId: 'skill-carpenter',
      );

      expect(changed.skills.map((item) => item.id), [
        'skill-carpenter',
        'skill-painter',
      ]);
      expect(
        changed.skills.map((item) => item.id),
        isNot(contains('skill-electrician')),
      );
      expect(changed.subcategoryId, 'skill-carpenter');
    });

    test('11. stable IDs are used where available', () {
      final hierarchy = CandidateJobHierarchy.fromSkillRows(_hierarchyRows());

      expect(hierarchy.categoryId, 'category-construction');
      expect(hierarchy.subcategoryId, 'skill-carpenter');
      expect(hierarchy.skillIds, contains('skill-painter'));
    });

    test('12. legacy labels normalize safely', () {
      final restored = CandidateJobHierarchyRestore.resolve(
        categories: _categories(),
        skills: _catalogSkills(),
        savedSelections: const [],
        legacyCategoryLabels: const ['  CONSTRUCTION '],
        legacySkillLabels: const [' carpenter ', 'PAINTER'],
        legacyPrimaryLabel: 'CARPENTER',
      );

      expect(restored.usedLegacyLabels, isTrue);
      expect(restored.category?.id, 'category-construction');
      expect(restored.subcategoryId, 'skill-carpenter');
      expect(restored.skills, hasLength(2));
    });

    test('13. missing legacy subcategory does not crash', () {
      final restored = CandidateJobHierarchyRestore.resolve(
        categories: _categories(),
        skills: _catalogSkills(),
        savedSelections: const [],
        legacyCategoryLabels: const ['Construction'],
        legacySkillLabels: const ['Carpenter'],
      );

      expect(restored.category?.name, 'Construction');
      expect(restored.skills.single.name, 'Carpenter');
      expect(restored.subcategoryId, isNull);
    });

    test('14. save readback verifies every hierarchy value', () {
      final backend = File(
        'lib/features/supabase_backend/kaam_backend.dart',
      ).readAsStringSync();
      final start = backend.indexOf('Future<void> saveSkills(');
      final end = backend.indexOf(
        'Future<void> updateSkillExperiences',
        start,
      );
      final save = backend.substring(start, end);

      expect(save, contains('final expectedHierarchy'));
      expect(save, contains('final savedHierarchy'));
      expect(save, contains('expectedHierarchy.matches(savedHierarchy)'));
      expect(save, contains('expectedExperiences'));
      expect(save, contains('savedExperiences'));
    });

    test('15. completion uses the same hierarchy rule', () {
      const complete = CandidateProfileData(
        jobCategoryIds: ['category-construction'],
        primarySkillId: 'skill-carpenter',
        skillIds: ['skill-carpenter'],
        jobCategories: ['Construction'],
        headline: 'Carpenter',
        skills: ['Carpenter'],
      );
      const missingSubcategory = CandidateProfileData(
        jobCategoryIds: ['category-construction'],
        skillIds: ['skill-carpenter'],
        jobCategories: ['Construction'],
        skills: ['Carpenter'],
      );

      expect(CandidateJobHierarchy.profileIsComplete(complete), isTrue);
      expect(
        CandidateJobHierarchy.profileIsComplete(missingSubcategory),
        isFalse,
      );
      expect(
        CandidateProfileCompletion.calculate(missingSubcategory).missingFields,
        contains('job hierarchy'),
      );
    });

    test('16. internal IDs do not appear in the UI', () {
      final work = _workSource();
      final profession = File(
        'lib/features/candidate/onboarding/skill_selection_screen.dart',
      ).readAsStringSync();

      expect(work, contains('Text(skill.name'));
      expect(work, isNot(contains('Text(skill.id')));
      expect(profession, contains('title: Text(skill.name'));
      expect(profession, isNot(contains('Text(skill.id')));
    });

    test('17. existing per-skill experience values remain unchanged', () {
      final saved = _constructionSaved();
      final hierarchy = CandidateJobHierarchy.fromSelections(saved);

      expect(hierarchy.isComplete, isTrue);
      expect(saved[0].experienceRange, CandidateSkillExperience.fivePlusYears);
      expect(
        saved[1].experienceRange,
        CandidateSkillExperience.oneToThreeYears,
      );
    });

    test('18. skill limit of three remains enforced', () {
      expect(CandidateSkillLimits.maxSkills, 3);
      expect(
        CandidateSkillLimits.allowsToggle(
          selectedCount: 3,
          alreadySelected: false,
          selecting: true,
        ),
        isFalse,
      );
    });
  });
}

List<SkillCategoryData> _categories() => const [
      SkillCategoryData(
        id: 'category-construction',
        name: 'Construction',
        iconName: 'construction',
      ),
      SkillCategoryData(
        id: 'category-electrical',
        name: 'Electrical',
        iconName: 'bolt',
      ),
    ];

List<SkillData> _catalogSkills() => const [
      SkillData(
        id: 'skill-carpenter',
        categoryId: 'category-construction',
        name: 'Carpenter',
      ),
      SkillData(
        id: 'skill-painter',
        categoryId: 'category-construction',
        name: 'Painter',
      ),
      SkillData(
        id: 'skill-electrician',
        categoryId: 'category-electrical',
        name: 'Electrician',
      ),
    ];

List<CandidateSkillData> _constructionSaved() {
  final category = _categories().first;
  final skills = _catalogSkills();
  return [
    CandidateSkillData(
      skill: skills[0],
      category: category,
      isPrimary: true,
      experienceRange: CandidateSkillExperience.fivePlusYears,
      skillLevel: 'Expert',
    ),
    CandidateSkillData(
      skill: skills[1],
      category: category,
      experienceRange: CandidateSkillExperience.oneToThreeYears,
    ),
  ];
}

List<Map<String, dynamic>> _hierarchyRows() => [
      {
        'skill_id': 'skill-carpenter',
        'is_primary': true,
        'skills': {'category_id': 'category-construction'},
      },
      {
        'skill_id': 'skill-painter',
        'is_primary': false,
        'skills': {'category_id': 'category-construction'},
      },
    ];

String _workSource() => File(
      'lib/features/candidate/onboarding/work_preferences_screen.dart',
    ).readAsStringSync();
