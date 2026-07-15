import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/constants/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/widgets/progress_stepper.dart';
import '../../../core/widgets/screen_scaffold.dart';
import '../../supabase_backend/kaam_backend.dart';

class SkillsExperienceScreen extends StatefulWidget {
  const SkillsExperienceScreen({super.key});

  @override
  State<SkillsExperienceScreen> createState() => _SkillsExperienceScreenState();
}

class _SkillsExperienceScreenState extends State<SkillsExperienceScreen> {
  final repository = const CandidateProfileRepository();
  final salaryController = TextEditingController();
  final availabilityController = TextEditingController();
  final currentCountryController = TextEditingController();
  final emirateController = TextEditingController();
  final visaStatusController = TextEditingController();
  final skillExperience = <String, String>{};
  final computerSkills = <String>{};
  final languages = <String>{};
  String drivingSkill = 'No';
  String drivingLicense = 'None';
  List<String> selectedSkills = const [];
  bool loading = true;
  bool saving = false;

  static const experienceOptions = [
    'Fresher',
    'Less than 1 year',
    '1-3 years',
    '3-5 years',
    '5+ years',
  ];

  static const availabilityOptions = [
    'Available Immediately',
    'Within 15 days',
    'Within 1 month',
    'Currently Working',
  ];

  static const countryOptions = ['UAE', 'India', 'Other'];
  static const emirateOptions = ['Dubai', 'Abu Dhabi', 'Sharjah', 'Ajman', 'Ras Al Khaimah', 'Fujairah', 'Umm Al Quwain'];
  static const visaOptions = [
    'Employment Visa',
    'Visit Visa',
    'Cancelled Visa',
    'Own Visa',
    'No Visa',
    'Outside UAE',
  ];
  static const computerOptions = ['MS Office', 'Email', 'Internet', 'Data Entry'];
  static const languageOptions = ['English', 'Arabic', 'Hindi', 'Urdu', 'Malayalam', 'Tamil', 'Other'];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    salaryController.dispose();
    availabilityController.dispose();
    currentCountryController.dispose();
    emirateController.dispose();
    visaStatusController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final profile = await repository.loadCurrentProfile();
      if (!mounted) return;
      selectedSkills = profile.skills.take(3).toList();
      for (final skill in selectedSkills) {
        skillExperience[skill] = _experienceLabel(profile.experienceYears);
      }
      salaryController.text = profile.expectedSalaryMin?.toString() ?? '';
      availabilityController.text = profile.availability;
      currentCountryController.text = profile.currentCity == 'India' ? 'India' : 'UAE';
      emirateController.text = profile.currentCity;
      visaStatusController.text = '';
      languages
        ..clear()
        ..addAll(profile.languages.where(languageOptions.contains));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not load experience details: $error')),
      );
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _continue() async {
    if (selectedSkills.isEmpty) {
      _message('Go back and select your work skills first.');
      return;
    }
    if (skillExperience.length < selectedSkills.length) {
      _message('Select experience for each skill.');
      return;
    }
    if (salaryController.text.trim().isEmpty) {
      _message('Add your expected monthly salary.');
      return;
    }
    if (availabilityController.text.trim().isEmpty) {
      _message('Select your availability.');
      return;
    }
    if (currentCountryController.text.trim().isEmpty) {
      _message('Select your current country.');
      return;
    }
    if (visaStatusController.text.trim().isEmpty) {
      _message('Select your visa status.');
      return;
    }
    setState(() => saving = true);
    try {
      final allSkills = {
        ...selectedSkills,
        if (drivingSkill == 'Yes') 'Driving',
        ...computerSkills,
      }.toList()
        ..sort();
      await repository.updateWorkProfile({
        'skills': allSkills,
        'languages': languages.toList()..sort(),
        'experience_years': _maxExperienceYears(),
        'expected_salary_min': parseFirstInt(salaryController.text),
        'expected_salary_max': parseFirstInt(salaryController.text),
        'availability': availabilityController.text.trim(),
        'current_country': currentCountryController.text.trim(),
        'current_city': currentCountryController.text == 'UAE'
            ? emirateController.text.trim()
            : currentCountryController.text.trim(),
        'visa_status': visaStatusController.text.trim(),
        'bio': _summaryText(),
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Experience and preferences saved.')),
      );
      Navigator.of(context).pushNamed(AppRoutes.profileComplete);
    } catch (error) {
      if (!mounted) return;
      _message('Could not save experience: $error');
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  String _summaryText() {
    final exp = skillExperience.entries.map((entry) => '${entry.key}: ${entry.value}').join(', ');
    final parts = [
      if (exp.isNotEmpty) 'Skill experience: $exp',
      'Driving skill: $drivingSkill',
      if (drivingLicense != 'None') 'Driving license: $drivingLicense',
      if (computerSkills.isNotEmpty) 'Computer skills: ${computerSkills.join(', ')}',
    ];
    return parts.join('\n');
  }

  num _maxExperienceYears() {
    var max = 0;
    for (final value in skillExperience.values) {
      max = switch (value) {
        'Less than 1 year' => max < 1 ? 1 : max,
        '1-3 years' => max < 3 ? 3 : max,
        '3-5 years' => max < 5 ? 5 : max,
        '5+ years' => max < 6 ? 6 : max,
        _ => max,
      };
    }
    return max;
  }

  String _experienceLabel(num? years) {
    if (years == null || years == 0) return 'Fresher';
    if (years < 1) return 'Less than 1 year';
    if (years <= 3) return '1-3 years';
    if (years <= 5) return '3-5 years';
    return '5+ years';
  }

  Future<void> _pickOption({
    required String title,
    required List<String> options,
    required ValueChanged<String> onPick,
    String current = '',
  }) async {
    final value = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            Text(title, style: AppTextStyles.title),
            const SizedBox(height: 12),
            for (final option in options)
              ListTile(
                title: Text(option),
                trailing: current == option ? const Icon(Icons.check) : null,
                onTap: () => Navigator.of(context).pop(option),
              ),
          ],
        ),
      ),
    );
    if (value != null) onPick(value);
  }

  void _message(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Widget _chip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
      checkmarkColor: AppColors.white,
      selectedColor: AppColors.primaryPink,
      backgroundColor: AppColors.elevatedCard,
      side: BorderSide(color: selected ? AppColors.primaryPink : AppColors.border),
      labelStyle: TextStyle(
        color: selected ? AppColors.white : AppColors.secondaryText,
        fontWeight: FontWeight.w700,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ScreenScaffold(
      title: 'Experience',
      showBack: true,
      children: [
        const ProgressStepper(current: 4, total: 5),
        const SizedBox(height: 22),
        const Text('Tell employers what you need', style: AppTextStyles.headline),
        const SizedBox(height: 8),
        const Text('Add your experience, availability, visa, and salary expectation.',
            style: AppTextStyles.body),
        const SizedBox(height: 16),
        if (loading) const LinearProgressIndicator(),
        if (loading) const SizedBox(height: 12),
        for (final skill in selectedSkills) ...[
          AppCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(skill, style: AppTextStyles.title),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final option in experienceOptions)
                      _chip(
                        label: option,
                        selected: skillExperience[skill] == option,
                        onTap: () => setState(() => skillExperience[skill] = option),
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
        ],
        const SizedBox(height: 10),
        const Text('Additional Skills', style: AppTextStyles.title),
        const SizedBox(height: 10),
        const Text('Do you have driving skills?', style: AppTextStyles.label),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [
            _chip(label: 'Yes', selected: drivingSkill == 'Yes', onTap: () => setState(() => drivingSkill = 'Yes')),
            _chip(label: 'No', selected: drivingSkill == 'No', onTap: () => setState(() => drivingSkill = 'No')),
          ],
        ),
        if (drivingSkill == 'Yes') ...[
          const SizedBox(height: 10),
          const Text('License', style: AppTextStyles.label),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              for (final value in ['UAE', 'India', 'None'])
                _chip(label: value, selected: drivingLicense == value, onTap: () => setState(() => drivingLicense = value)),
            ],
          ),
        ],
        const SizedBox(height: 14),
        const Text('Computer Skills', style: AppTextStyles.label),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final value in computerOptions)
              _chip(
                label: value,
                selected: computerSkills.contains(value),
                onTap: () => setState(() {
                  computerSkills.contains(value) ? computerSkills.remove(value) : computerSkills.add(value);
                }),
              ),
          ],
        ),
        const SizedBox(height: 14),
        const Text('Languages', style: AppTextStyles.label),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final value in languageOptions)
              _chip(
                label: value,
                selected: languages.contains(value),
                onTap: () => setState(() {
                  languages.contains(value) ? languages.remove(value) : languages.add(value);
                }),
              ),
          ],
        ),
        const SizedBox(height: 20),
        AppTextField(
          controller: salaryController,
          label: 'Salary expectation',
          hint: 'AED per month',
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        ),
        const SizedBox(height: 12),
        _PickerField(
          controller: availabilityController,
          label: 'Availability',
          hint: 'Select availability',
          onTap: () => _pickOption(
            title: 'Availability',
            options: availabilityOptions,
            current: availabilityController.text,
            onPick: (value) => setState(() => availabilityController.text = value),
          ),
        ),
        const SizedBox(height: 12),
        _PickerField(
          controller: currentCountryController,
          label: 'Current country',
          hint: 'UAE, India, or Other',
          onTap: () => _pickOption(
            title: 'Current country',
            options: countryOptions,
            current: currentCountryController.text,
            onPick: (value) => setState(() {
              currentCountryController.text = value;
              if (value != 'UAE') emirateController.clear();
            }),
          ),
        ),
        if (currentCountryController.text == 'UAE') ...[
          const SizedBox(height: 12),
          _PickerField(
            controller: emirateController,
            label: 'Emirate',
            hint: 'Select emirate',
            onTap: () => _pickOption(
              title: 'Emirate',
              options: emirateOptions,
              current: emirateController.text,
              onPick: (value) => setState(() => emirateController.text = value),
            ),
          ),
        ],
        const SizedBox(height: 12),
        _PickerField(
          controller: visaStatusController,
          label: 'Visa status',
          hint: 'Select visa status',
          onTap: () => _pickOption(
            title: 'Visa status',
            options: visaOptions,
            current: visaStatusController.text,
            onPick: (value) => setState(() => visaStatusController.text = value),
          ),
        ),
        const SizedBox(height: 24),
        PrimaryButton(
          label: saving ? 'Saving...' : 'Finish Profile',
          onPressed: saving ? null : _continue,
        ),
      ],
    );
  }
}

class _PickerField extends StatelessWidget {
  const _PickerField({
    required this.controller,
    required this.label,
    required this.hint,
    required this.onTap,
  });

  final TextEditingController controller;
  final String label;
  final String hint;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppTextField(
      controller: controller,
      label: label,
      hint: hint,
      readOnly: true,
      suffixIcon: const Icon(Icons.keyboard_arrow_down_rounded),
      onTap: onTap,
    );
  }
}
