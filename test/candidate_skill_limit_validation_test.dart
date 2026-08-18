import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kaam_perfect_match/features/supabase_backend/kaam_backend.dart';

void main() {
  group('candidate fourth-skill validation visibility', () {
    late final String workPreferencesSource;
    late final String editProfileSource;
    late final String experienceSource;
    late final String completionSource;
    late final String backendSource;

    setUpAll(() {
      workPreferencesSource = File(
        'lib/features/candidate/onboarding/work_preferences_screen.dart',
      ).readAsStringSync();
      editProfileSource = File(
        'lib/features/candidate/profile/edit_profile_screen.dart',
      ).readAsStringSync();
      experienceSource = File(
        'lib/features/candidate/onboarding/skills_experience_screen.dart',
      ).readAsStringSync();
      completionSource = File(
        'lib/features/candidate/profile/candidate_profile_completion.dart',
      ).readAsStringSync();
      backendSource = File(
        'lib/features/supabase_backend/kaam_backend.dart',
      ).readAsStringSync();
    });

    bool toggle(List<String> selected, String skill) {
      final alreadySelected = selected.contains(skill);
      final selecting = !alreadySelected;
      if (!CandidateSkillLimits.allowsToggle(
        selectedCount: selected.length,
        alreadySelected: alreadySelected,
        selecting: selecting,
      )) {
        return false;
      }
      alreadySelected ? selected.remove(skill) : selected.add(skill);
      return true;
    }

    test('1 first skill can be selected', () {
      final selected = <String>[];
      expect(toggle(selected, 'Mason'), isTrue);
      expect(selected, ['Mason']);
    });

    test('2 second skill can be selected', () {
      final selected = ['Mason'];
      expect(toggle(selected, 'Carpenter'), isTrue);
      expect(selected, ['Mason', 'Carpenter']);
    });

    test('3 third skill can be selected', () {
      final selected = ['Mason', 'Carpenter'];
      expect(toggle(selected, 'Electrician'), isTrue);
      expect(selected, ['Mason', 'Carpenter', 'Electrician']);
    });

    test('4 fourth skill is rejected', () {
      final selected = ['Mason', 'Carpenter', 'Electrician'];
      expect(toggle(selected, 'Plumber'), isFalse);
      expect(selected, isNot(contains('Plumber')));
    });

    test('5 existing three remain selected after fourth-skill attempt', () {
      final selected = ['Mason', 'Carpenter', 'Electrician'];
      final before = List<String>.of(selected);
      toggle(selected, 'Plumber');
      expect(selected, before);
    });

    test('6 validation is rendered inline on the active modal screen', () {
      final pickerStart = workPreferencesSource.indexOf(
        'Future<void> _pickSkills()',
      );
      final pickerEnd = workPreferencesSource.indexOf(
        'void _continue()',
        pickerStart,
      );
      final pickerBody = workPreferencesSource.substring(
        pickerStart,
        pickerEnd,
      );
      expect(pickerBody, contains('if (limitError != null)'));
      expect(pickerBody, contains('CandidateSkillLimits.maxMessage'));
      expect(pickerBody, contains('liveRegion: true'));
    });

    test('7 limit feedback is not attached to the covered route messenger', () {
      final pickerStart = workPreferencesSource.indexOf(
        'Future<void> _pickSkills()',
      );
      final pickerEnd = workPreferencesSource.indexOf(
        'void _continue()',
        pickerStart,
      );
      final pickerBody = workPreferencesSource.substring(
        pickerStart,
        pickerEnd,
      );
      expect(pickerBody, contains('showModalBottomSheet<List<SkillData>>'));
      expect(pickerBody, isNot(contains('ScaffoldMessenger.of(context)')));
      expect(pickerBody, isNot(contains('SnackBar(')));
    });

    test('8 repeated fourth-skill taps keep one stable inline message', () {
      expect(workPreferencesSource, contains('if (limitError == null)'));
      expect(workPreferencesSource, contains('String? limitError;'));
      expect(
        workPreferencesSource,
        isNot(contains('ScaffoldMessenger.of(context).showSnackBar(\n'
            '                                    SnackBar')),
      );
    });

    test('9 deselecting one skill clears validation state', () {
      final selected = ['Mason', 'Carpenter', 'Electrician'];
      expect(toggle(selected, 'Carpenter'), isTrue);
      expect(selected, ['Mason', 'Electrician']);
      expect(workPreferencesSource, contains('limitError = null'));
    });

    test('10 a different skill can be selected after deselection', () {
      final selected = ['Mason', 'Carpenter', 'Electrician'];
      toggle(selected, 'Carpenter');
      expect(toggle(selected, 'Plumber'), isTrue);
      expect(selected, ['Mason', 'Electrician', 'Plumber']);
    });

    test('11 Edit Profile routes Skills through the same selection screen', () {
      expect(
        editProfileSource,
        contains(
          'CandidateProfileSection.skills =>\n'
          '                              AppRoutes.workPreferences',
        ),
      );
    });

    test('12 onboarding uses the centralized maximum', () {
      expect(CandidateSkillLimits.maxSkills, 3);
      expect(
        CandidateSkillLimits.maxMessage,
        'You can select a maximum of 3 skills.',
      );
      expect(
        workPreferencesSource,
        contains('CandidateSkillLimits.allowsToggle('),
      );
      expect(
        experienceSource,
        contains('CandidateSkillLimits.maxSkills'),
      );
      expect(completionSource, contains('CandidateSkillLimits.isValidCount'));
    });

    test('13 save payloads cannot contain more than three skills', () {
      expect(
        CandidateSkillLimits.normalizeNames(['a', 'b', 'c', 'd']),
        ['a', 'b', 'c'],
      );
      expect(backendSource, contains("safeValues.containsKey('skills')"));
      expect(
        backendSource,
        contains("safeValues['skills'] = CandidateSkillLimits.normalizeNames"),
      );
      expect(
        backendSource,
        contains('selections.length > CandidateSkillLimits.maxSkills'),
      );
    });

    test('14 legacy records with more than three load safely', () {
      final profile = CandidateProfileData.fromRows(
        profile: null,
        candidate: const {
          'skills': ['Mason', 'Carpenter', 'Electrician', 'Plumber'],
        },
      );
      expect(profile.skills, ['Mason', 'Carpenter', 'Electrician']);
      expect(
        backendSource,
        contains('selections.take(CandidateSkillLimits.maxSkills).toList()'),
      );
    });

    test('15 fourth-skill rejection does not navigate', () {
      final selected = ['Mason', 'Carpenter', 'Electrician'];
      expect(toggle(selected, 'Plumber'), isFalse);
      final rejectionStart = workPreferencesSource.indexOf(
        'if (!CandidateSkillLimits.allowsToggle(',
      );
      final rejectionEnd = workPreferencesSource.indexOf(
        'setSheetState(() {',
        rejectionStart + 10,
      );
      final rejectionBody = workPreferencesSource.substring(
        rejectionStart,
        rejectionEnd,
      );
      expect(rejectionBody, contains('return;'));
      expect(rejectionBody, isNot(contains('Navigator')));
    });

    test('16 validation and selected state are accessible', () {
      expect(workPreferencesSource, contains('Semantics('));
      expect(workPreferencesSource, contains('liveRegion: true'));
      expect(workPreferencesSource, contains('selected: selected'));
      expect(workPreferencesSource, contains('Icons.check_circle_rounded'));
      expect(workPreferencesSource, contains('Icons.info_outline_rounded'));
    });
  });
}
