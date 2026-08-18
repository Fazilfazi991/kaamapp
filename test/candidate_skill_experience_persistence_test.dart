import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kaam_perfect_match/features/candidate/profile/candidate_profile_completion.dart';
import 'package:kaam_perfect_match/features/supabase_backend/kaam_backend.dart';

void main() {
  group('candidate skill-specific experience persistence', () {
    late final String backendSource;
    late final String workPreferencesSource;
    late final String skillDetailsSource;
    late final String experienceSource;
    late final String editProfileSource;

    setUpAll(() {
      backendSource = File(
        'lib/features/supabase_backend/kaam_backend.dart',
      ).readAsStringSync();
      workPreferencesSource = File(
        'lib/features/candidate/onboarding/work_preferences_screen.dart',
      ).readAsStringSync();
      skillDetailsSource = File(
        'lib/features/candidate/onboarding/skill_selection_screen.dart',
      ).readAsStringSync();
      experienceSource = File(
        'lib/features/candidate/onboarding/skills_experience_screen.dart',
      ).readAsStringSync();
      editProfileSource = File(
        'lib/features/candidate/profile/edit_profile_screen.dart',
      ).readAsStringSync();
    });

    test('1 one skill keeps its own experience', () {
      final values = CandidateSkillExperience.normalizeBySkillId({
        'carpenter-id': '5+ years',
      });
      expect(values, {'carpenter-id': CandidateSkillExperience.fivePlusYears});
    });

    test('2 two skills can have different experience values', () {
      final values = CandidateSkillExperience.normalizeBySkillId({
        'carpenter-id': '5+ years',
        'painter-id': '1–3 years',
      });
      expect(values['carpenter-id'], CandidateSkillExperience.fivePlusYears);
      expect(values['painter-id'], CandidateSkillExperience.oneToThreeYears);
    });

    test('3 three skills can all have different values', () {
      final values = CandidateSkillExperience.normalizeBySkillId({
        'carpenter-id': '5+ years',
        'painter-id': '1–3 years',
        'mason-id': 'Less than 1 year',
      });
      expect(values.values.toSet(), hasLength(3));
    });

    test('4 changing one skill does not change the others', () {
      final values = <String, String>{
        'carpenter-id': CandidateSkillExperience.fivePlusYears,
        'painter-id': CandidateSkillExperience.oneToThreeYears,
      };
      values['painter-id'] = CandidateSkillExperience.lessThanOneYear;
      expect(values['carpenter-id'], CandidateSkillExperience.fivePlusYears);
      expect(values['painter-id'], CandidateSkillExperience.lessThanOneYear);
    });

    test('5 save payload contains each stable skill-value pair', () {
      expect(backendSource, contains("'skill_id': entry.key"));
      expect(backendSource, contains("'experience_range': entry.value"));
      expect(backendSource, contains("onConflict: 'candidate_id,skill_id'"));
      expect(experienceSource, contains('selection.skill.id:'));
    });

    test('6 readback verifies every saved pair', () {
      expect(
        CandidateSkillExperience.mappingsMatch(
          {
            'a': 'Fresher',
            'b': '3–5 years',
          },
          {
            'b': CandidateSkillExperience.threeToFiveYears,
            'a': CandidateSkillExperience.fresher,
          },
        ),
        isTrue,
      );
      expect(backendSource, contains("stage: 'readback_mismatch'"));
      expect(
          backendSource, contains('Skill experience readback did not match'));
    });

    test('7 restart restores each skill from structured rows', () {
      final profile = CandidateProfileData.fromRows(
        profile: null,
        candidate: const {
          'skills': ['Carpenter', 'Painter'],
        },
        skillExperiences: const {
          'carpenter-id': '5+ years',
          'painter-id': 'Less than 1 year',
        },
      );
      expect(profile.skillExperiences, {
        'carpenter-id': CandidateSkillExperience.fivePlusYears,
        'painter-id': CandidateSkillExperience.lessThanOneYear,
      });
      expect(experienceSource, contains('repository.loadMySkills()'));
    });

    test('8 logout and login reloads database rows, not aggregate years', () {
      expect(backendSource, contains(".from('candidate_skills')"));
      expect(backendSource, contains(".from('candidate_skills')"));
      expect(
        backendSource,
        contains(
          ".select('skill_id,is_primary,experience_range,skills(category_id)')",
        ),
      );
      expect(
        experienceSource,
        isNot(contains('_experienceLabel(profile.experienceYears)')),
      );
    });

    test('9 Edit Profile uses the same shared load and save flows', () {
      expect(
        editProfileSource,
        contains('CandidateProfileSection.skills =>'),
      );
      expect(editProfileSource, contains('AppRoutes.workPreferences'));
      expect(
        editProfileSource,
        contains('CandidateProfileSection.experience =>'),
      );
      expect(editProfileSource, contains('AppRoutes.skillsExperience'));
      expect(experienceSource, contains('updateSkillExperiences'));
    });

    test('10 adding a skill does not copy another experience', () {
      expect(
        CandidateSkillExperience.labelFor(null),
        isEmpty,
      );
      expect(
        skillDetailsSource,
        contains('draft!.savedBySkillId[skill.id]'),
      );
      expect(skillDetailsSource, contains('if (saved == null)'));
    });

    test('11 removing a skill preserves remaining values', () {
      final values = <String, String>{
        'a': CandidateSkillExperience.fresher,
        'b': CandidateSkillExperience.oneToThreeYears,
        'c': CandidateSkillExperience.fivePlusYears,
      }..remove('b');
      expect(values, {
        'a': CandidateSkillExperience.fresher,
        'c': CandidateSkillExperience.fivePlusYears,
      });
      expect(workPreferencesSource, contains('savedBySkillId[skill.id]'));
    });

    test('12 reordering skills preserves experience by skill ID', () {
      const values = {
        'a': CandidateSkillExperience.fresher,
        'b': CandidateSkillExperience.fivePlusYears,
      };
      final reorderedIds = ['b', 'a'];
      expect(
        reorderedIds.map((id) => values[id]).toList(),
        [
          CandidateSkillExperience.fivePlusYears,
          CandidateSkillExperience.fresher
        ],
      );
    });

    test('13 legacy experience labels normalize safely', () {
      for (final value in ['1-3 years', '1 – 3 years', '1 to 3 years']) {
        expect(
          CandidateSkillExperience.normalize(value),
          CandidateSkillExperience.oneToThreeYears,
          reason: value,
        );
      }
      expect(
        CandidateSkillExperience.normalize('FRESHER'),
        CandidateSkillExperience.fresher,
      );
    });

    test('14 malformed values never silently become 1–3 years', () {
      expect(CandidateSkillExperience.normalize('several years'), isEmpty);
      expect(CandidateSkillExperience.labelFor('unexpected'), isEmpty);
      expect(
        CandidateSkillExperience.aggregateYears(['unexpected']),
        0,
      );
    });

    test('15 generic profile updates cannot overwrite skill experience', () {
      final start = backendSource.indexOf(
        'Future<CandidateProfileData> updateWorkProfile(',
      );
      final end = backendSource.indexOf(
        'Future<CandidateProfileData> updateVisaDetails({',
        start,
      );
      final body = backendSource.substring(start, end);
      expect(body, contains(".from('candidate_profiles')"));
      expect(body, isNot(contains('experience_range')));
      expect(body, isNot(contains(".from('candidate_skills')")));
    });

    test('16 completion requires valid experience for every selected skill',
        () {
      final incomplete = CandidateProfileCompletion.calculate(
        const CandidateProfileData(
          skills: ['Carpenter', 'Painter'],
          languages: ['English'],
          skillExperiences: {'carpenter-id': 'fresher'},
        ),
      );
      final complete = CandidateProfileCompletion.calculate(
        const CandidateProfileData(
          skills: ['Carpenter', 'Painter'],
          languages: ['English'],
          skillExperiences: {
            'carpenter-id': 'fresher',
            'painter-id': 'five_plus_years',
          },
        ),
      );
      expect(
        incomplete.sections[CandidateProfileSection.skills]!.state,
        CandidateSectionCompletionState.incomplete,
      );
      expect(
        complete.sections[CandidateProfileSection.skills]!.state,
        CandidateSectionCompletionState.complete,
      );
    });
  });
}
