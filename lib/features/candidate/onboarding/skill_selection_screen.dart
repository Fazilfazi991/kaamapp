import 'package:flutter/material.dart';

import '../../../core/constants/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/widgets/progress_stepper.dart';
import '../../../core/widgets/screen_scaffold.dart';
import '../../supabase_backend/kaam_backend.dart';
import 'work_preferences_screen.dart';

class PrimaryProfessionScreen extends StatefulWidget {
  const PrimaryProfessionScreen({super.key});
  @override
  State<PrimaryProfessionScreen> createState() =>
      _PrimaryProfessionScreenState();
}

class _PrimaryProfessionScreenState extends State<PrimaryProfessionScreen> {
  SkillSelectionDraft? draft;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    draft ??=
        ModalRoute.of(context)?.settings.arguments as SkillSelectionDraft?;
  }

  @override
  Widget build(BuildContext context) {
    final value = draft;
    if (value == null) {
      return const ScreenScaffold(
          title: 'Main Profession',
          showBack: true,
          children: [
            Text(
                'Your skill selection expired. Please choose your skills again.')
          ]);
    }
    return ScreenScaffold(title: 'Main Profession', showBack: true, children: [
      const ProgressStepper(current: 4, total: 5),
      const SizedBox(height: 22),
      const Text('What is your primary profession?',
          style: AppTextStyles.headline),
      const SizedBox(height: 8),
      const Text(
          'Choose the job you are most experienced in. Employers will see this first.',
          style: AppTextStyles.body),
      const SizedBox(height: 16),
      for (final skill in value.skills) ...[
        AppCard(
            onTap: () => setState(() => value.primarySkillId = skill.id),
            borderColor: value.primarySkillId == skill.id
                ? AppColors.primaryPink
                : AppColors.border,
            child: CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: value.primarySkillId == skill.id,
                activeColor: AppColors.primaryPink,
                title: Text(skill.name, style: AppTextStyles.label),
                onChanged: (_) =>
                    setState(() => value.primarySkillId = skill.id))),
        const SizedBox(height: 8)
      ],
      const SizedBox(height: 16),
      PrimaryButton(
          label: 'Continue',
          onPressed: value.primarySkillId == null
              ? null
              : () => Navigator.of(context)
                  .pushNamed(AppRoutes.skillDetails, arguments: value)),
    ]);
  }
}

class SkillDetailsScreen extends StatefulWidget {
  const SkillDetailsScreen({super.key});
  @override
  State<SkillDetailsScreen> createState() => _SkillDetailsScreenState();
}

class _SkillDetailsScreenState extends State<SkillDetailsScreen> {
  final repository = const CandidateProfileRepository();
  SkillSelectionDraft? draft;
  final details = <String, _SkillDetail>{};
  bool saving = false;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    draft ??=
        ModalRoute.of(context)?.settings.arguments as SkillSelectionDraft?;
    if (draft != null && details.isEmpty) {
      for (final skill in draft!.skills) {
        details[skill.id] = _SkillDetail();
      }
    }
  }

  Future<void> _save() async {
    final value = draft!;
    final primary = details[value.primarySkillId]!;
    if (value.skills.isEmpty ||
        value.skills.length > CandidateSkillLimits.maxSkills) {
      _message(CandidateSkillLimits.maxMessage);
      return;
    }
    if (primary.experience.isEmpty || primary.level.isEmpty) {
      _message('Add experience and skill level for your main profession.');
      return;
    }
    setState(() => saving = true);
    try {
      await repository.saveSkills(selections: [
        for (final skill in value.skills)
          CandidateSkillData(
              skill: skill,
              category: value.categories
                  .firstWhere((category) => category.id == skill.categoryId),
              isPrimary: skill.id == value.primarySkillId,
              experienceRange: details[skill.id]!.experience,
              skillLevel: details[skill.id]!.level,
              uaeExperienceRange: details[skill.id]!.uaeExperience,
              availability: details[skill.id]!.availability,
              certificateTypes: details[skill.id]!.certificates,
              otherCertificateName: details[skill.id]!.otherCertificate)
      ]);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Your skills were saved.')));
      Navigator.of(context).pushNamedAndRemoveUntil(AppRoutes.skillsExperience,
          (route) => route.settings.name == AppRoutes.basicDetails);
    } catch (error) {
      if (mounted) _message('Could not save your skills: $error');
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  void _message(String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  @override
  Widget build(BuildContext context) {
    final value = draft;
    if (value == null) {
      return const ScreenScaffold(
          title: 'Skill Details',
          showBack: true,
          children: [
            Text(
                'Your skill selection expired. Please choose your skills again.')
          ]);
    }
    return ScreenScaffold(title: 'Skill Details', showBack: true, children: [
      const ProgressStepper(current: 4, total: 5),
      const SizedBox(height: 18),
      const Text('Tell us about your skills', style: AppTextStyles.headline),
      const SizedBox(height: 8),
      const Text('Add details for each job you selected.',
          style: AppTextStyles.body),
      const SizedBox(height: 16),
      for (final skill in value.skills) ...[
        _SkillDetailCard(
            skill: skill,
            isPrimary: skill.id == value.primarySkillId,
            value: details[skill.id]!,
            onChanged: () => setState(() {})),
        const SizedBox(height: 10)
      ],
      const SizedBox(height: 16),
      PrimaryButton(
          label: saving ? 'Saving...' : 'Save skills',
          onPressed: saving ? null : _save),
    ]);
  }
}

class _SkillDetail {
  String experience = '';
  String level = '';
  String uaeExperience = '';
  String availability = '';
  final certificates = <String>[];
  String otherCertificate = '';
}

class _SkillDetailCard extends StatelessWidget {
  const _SkillDetailCard(
      {required this.skill,
      required this.isPrimary,
      required this.value,
      required this.onChanged});
  final SkillData skill;
  final bool isPrimary;
  final _SkillDetail value;
  final VoidCallback onChanged;
  static const experience = [
    'Fresher',
    'Less than 1 year',
    '1-2 years',
    '3-5 years',
    '6-10 years',
    'More than 10 years'
  ];
  static const levels = [
    'Beginner',
    'Intermediate',
    'Experienced',
    'Expert',
    'Supervisor / Foreman'
  ];
  static const uae = [
    'No UAE experience',
    'Less than 1 year',
    '1-2 years',
    '3-5 years',
    'More than 5 years'
  ];
  static const availability = [
    'Immediately Available',
    'Within 7 Days',
    'Within 30 Days',
    'Currently Employed'
  ];
  static const certificates = [
    'No Certificate',
    'Trade Certificate',
    'Diploma',
    'Government Licence',
    'UAE Licence',
    'Other Certificate'
  ];
  @override
  Widget build(BuildContext context) => AppCard(
          child: ExpansionTile(
              initiallyExpanded: isPrimary,
              tilePadding: EdgeInsets.zero,
              title: Text(skill.name, style: AppTextStyles.title),
              subtitle: isPrimary ? const Text('Main profession') : null,
              children: [
            _Select(
                label: 'Experience${isPrimary ? ' *' : ''}',
                value: value.experience,
                options: experience,
                onChanged: (v) {
                  value.experience = v ?? '';
                  onChanged();
                }),
            _Select(
                label: 'Skill level${isPrimary ? ' *' : ''}',
                value: value.level,
                options: levels,
                onChanged: (v) {
                  value.level = v ?? '';
                  onChanged();
                }),
            _Select(
                label: 'UAE experience',
                value: value.uaeExperience,
                options: uae,
                onChanged: (v) {
                  value.uaeExperience = v ?? '';
                  onChanged();
                }),
            _Select(
                label: 'Availability',
                value: value.availability,
                options: availability,
                onChanged: (v) {
                  value.availability = v ?? '';
                  onChanged();
                }),
            const Align(
                alignment: Alignment.centerLeft,
                child: Text('Certificates', style: AppTextStyles.label)),
            Wrap(spacing: 6, runSpacing: 6, children: [
              for (final item in certificates)
                FilterChip(
                    label: Text(item),
                    selected: value.certificates.contains(item),
                    onSelected: (selected) {
                      selected
                          ? value.certificates.add(item)
                          : value.certificates.remove(item);
                      onChanged();
                    })
            ]),
            if (value.certificates.contains('Other Certificate'))
              TextFormField(
                  initialValue: value.otherCertificate,
                  decoration:
                      const InputDecoration(labelText: 'Other certificate'),
                  onChanged: (text) => value.otherCertificate = text.trim()),
          ]));
}

class _Select extends StatelessWidget {
  const _Select(
      {required this.label,
      required this.value,
      required this.options,
      required this.onChanged});
  final String label, value;
  final List<String> options;
  final ValueChanged<String?> onChanged;
  @override
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: DropdownButtonFormField<String>(
          initialValue: value.isEmpty ? null : value,
          isExpanded: true,
          decoration: InputDecoration(labelText: label),
          items: options
              .map((item) => DropdownMenuItem(value: item, child: Text(item)))
              .toList(),
          onChanged: onChanged));
}
