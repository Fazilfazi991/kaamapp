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
import '../profile/candidate_display_formatters.dart';

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
  final visaExpiryController = TextEditingController();
  final otherLanguageController = TextEditingController();
  final employmentStatusController = TextEditingController();
  final otherEmploymentStatusController = TextEditingController();
  final skillExperience = <String, String>{};
  final computerSkills = <String>{};
  final languages = <String>{};
  final drivingLicenses = <String>{};
  final errors = <String, String>{};
  String drivingSkill = 'No';
  List<CandidateSkillData> selectedSkills = const [];
  bool loading = true;
  bool loadFailed = false;
  bool saving = false;
  String visaExpiryValue = '';

  static final experienceOptions = CandidateSkillExperience.labels;

  static const availabilityOptions = [
    'Available Immediately',
    'Within 15 days',
    'Within 1 month',
    'Currently Working',
  ];

  static final visaOptions = CandidateVisaStatus.labels;
  static const computerOptions = [
    'MS Office',
    'Email',
    'Internet',
    'Data Entry',
  ];
  static const languageOptions = [
    'English',
    'Arabic',
    'Hindi',
    'Urdu',
    'Malayalam',
    'Tamil',
    'Other',
  ];
  static const drivingLicenseOptions = [
    'UAE Driving Licence',
    'India Driving Licence',
    'Other Country Driving Licence',
    'No Driving Licence',
  ];
  static const employmentStatusOptions = [
    'Currently Employed',
    'Unemployed',
    'Serving Notice Period',
    'Freelance / Self-employed',
    'Student',
    'Other',
  ];

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
    visaExpiryController.dispose();
    otherLanguageController.dispose();
    employmentStatusController.dispose();
    otherEmploymentStatusController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (mounted) {
      setState(() {
        loading = true;
        loadFailed = false;
      });
    }
    try {
      final profile = await repository.loadCurrentProfile();
      final savedSkills = await repository.loadMySkills();
      if (!mounted) return;
      selectedSkills =
          savedSkills.take(CandidateSkillLimits.maxSkills).toList();
      skillExperience.clear();
      for (final selection in selectedSkills) {
        final label = CandidateSkillExperience.labelFor(
          selection.experienceRange,
        );
        if (label.isNotEmpty) skillExperience[selection.skill.id] = label;
      }
      salaryController.text = profile.expectedSalaryMin?.toString() ?? '';
      availabilityController.text = profile.availability;
      currentCountryController.text = CandidateLocationOptions.normalizeCountry(
        profile.currentCountry,
      );
      emirateController.text =
          CandidateLocationOptions.normalizeRegionForCountry(
        currentCountryController.text,
        profile.currentCity,
      );
      visaStatusController.text = CandidateVisaStatus.labelFor(
        profile.visaStatus,
      );
      visaExpiryValue = profile.visaExpiryDate;
      visaExpiryController.text = CandidateVisaExpiry.displayDate(
        visaExpiryValue,
      );
      drivingLicenses
        ..clear()
        ..addAll(
          _normalizeDrivingLicenses(profile.drivingLicenses, profile.bio),
        );
      if (drivingLicenses.any((value) => value != 'No Driving Licence')) {
        drivingSkill = 'Yes';
      }
      employmentStatusController.text = profile.currentEmploymentStatus;
      otherEmploymentStatusController.text =
          profile.currentEmploymentStatusOther;
      languages
        ..clear()
        ..addAll(profile.languages.where(languageOptions.contains));
      final customLanguages = profile.languages
          .where((language) => !languageOptions.contains(language))
          .toList();
      if (customLanguages.isNotEmpty) {
        languages.add('Other');
        otherLanguageController.text = customLanguages.first;
      }
    } catch (error) {
      if (!mounted) return;
      loadFailed = true;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'We could not load your saved details. Please try again.',
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _continue() async {
    if (loading || loadFailed || saving) return;
    if (!_validate()) return;
    setState(() => saving = true);
    try {
      final savedLanguages = _savedLanguages();
      await repository.updateCurrentLocation(
        country: currentCountryController.text,
        region: emirateController.text,
      );
      await repository.updateSkillExperiences({
        for (final selection in selectedSkills)
          selection.skill.id: skillExperience[selection.skill.id] ?? '',
      });
      await repository.updateWorkProfile({
        'skills': CandidateSkillLimits.normalizeNames(
          selectedSkills.map((selection) => selection.skill.name),
        ),
        'languages': savedLanguages,
        'experience_years': _maxExperienceYears(),
        'expected_salary_min': parseFirstInt(salaryController.text),
        'expected_salary_max': parseFirstInt(salaryController.text),
        'availability': availabilityController.text.trim(),
        'driving_licenses': drivingLicenses.toList()..sort(),
        'current_employment_status': employmentStatusController.text.trim(),
        'current_employment_status_other':
            otherEmploymentStatusController.text.trim().isEmpty
                ? null
                : otherEmploymentStatusController.text.trim(),
        'bio': _summaryText(),
      });
      await repository.updateVisaDetails(
        selectedStatus: visaStatusController.text,
        expiryDate: visaExpiryValue,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Experience and preferences saved.')),
      );
      Navigator.of(context).pushNamed(AppRoutes.profileMedia);
    } catch (error) {
      if (!mounted) return;
      _message('We could not save your skill experience. Please try again.');
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  bool _validate() {
    final next = <String, String>{};
    if (selectedSkills.isEmpty) {
      next['skills'] = 'Select at least one skill.';
    }
    for (final selection in selectedSkills) {
      if (!CandidateSkillExperience.isValid(
        skillExperience[selection.skill.id],
      )) {
        next['experience_${selection.skill.id}'] =
            'Enter your years of experience.';
      }
    }
    if (salaryController.text.trim().isEmpty) {
      next['salary'] = 'Select your expected salary.';
    }
    if (availabilityController.text.trim().isEmpty) {
      next['availability'] = 'Select your availability.';
    }
    if (languages.isEmpty) {
      next['languages'] = 'Select at least one language.';
    }
    if (languages.contains('Other') &&
        otherLanguageController.text.trim().isEmpty) {
      next['other_language'] = 'Enter language.';
    }
    if (drivingSkill == 'Yes' && drivingLicenses.isEmpty) {
      next['driving'] = 'Choose your driving licence status.';
    }
    if (employmentStatusController.text.trim().isEmpty) {
      next['employment'] = 'Select your current employment status.';
    }
    if (employmentStatusController.text == 'Other' &&
        otherEmploymentStatusController.text.trim().isEmpty) {
      next['employment_other'] = 'Enter your current employment status.';
    }
    final locationError = CandidateLocationOptions.validationError(
      currentCountryController.text,
      emirateController.text,
    );
    if (locationError != null) {
      if (CandidateLocationOptions.normalizeCountry(
        currentCountryController.text,
      ).isEmpty) {
        next['current_country'] = locationError;
      } else {
        next['region'] = locationError;
      }
    }
    if (visaStatusController.text.trim().isEmpty) {
      next['visa'] = 'Select your visa status.';
    }
    final visaExpiryError = CandidateVisaExpiry.validationError(
      visaStatusController.text,
      visaExpiryValue,
    );
    if (visaExpiryError != null) {
      next['visa_expiry'] = visaExpiryError;
    }
    setState(
      () => errors
        ..clear()
        ..addAll(next),
    );
    return next.isEmpty;
  }

  List<String> _savedLanguages() {
    final values = <String>{
      ...languages.where((value) => value != 'Other'),
      if (languages.contains('Other') &&
          otherLanguageController.text.trim().isNotEmpty)
        titleCase(otherLanguageController.text),
    }.toList()
      ..sort();
    return values;
  }

  List<String> _normalizeDrivingLicenses(List<String> current, String bio) {
    final values = current.where(drivingLicenseOptions.contains).toList();
    if (values.isNotEmpty) return values;
    final match = RegExp(
      r'Driving license:\s*(.+)',
      caseSensitive: false,
    ).firstMatch(bio);
    final legacy = match?.group(1)?.trim();
    if (legacy == null || legacy.isEmpty) return const [];
    return switch (legacy) {
      'UAE' => const ['UAE Driving Licence'],
      'India' => const ['India Driving Licence'],
      'None' => const ['No Driving Licence'],
      _ => [legacy],
    };
  }

  String _summaryText() {
    final exp = selectedSkills
        .map(
          (selection) =>
              '${selection.skill.name}: ${skillExperience[selection.skill.id] ?? ''}',
        )
        .where((value) => !value.endsWith(': '))
        .join(', ');
    final parts = [
      if (exp.isNotEmpty) 'Skill experience: $exp',
      'Driving skill: $drivingSkill',
      if (drivingLicenses.isNotEmpty)
        'Driving license: ${drivingLicenses.join(', ')}',
      if (employmentStatusController.text.trim().isNotEmpty)
        'Current employment status: ${employmentStatusController.text.trim()}',
      if (computerSkills.isNotEmpty)
        'Computer skills: ${computerSkills.join(', ')}',
    ];
    return parts.join('\n');
  }

  num _maxExperienceYears() =>
      CandidateSkillExperience.aggregateYears(skillExperience.values);

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

  Future<void> _pickVisaExpiryDate() async {
    final now = DateTime.now();
    final firstDate = DateTime(now.year, now.month, now.day).add(
      const Duration(days: 1),
    );
    final lastDate = DateTime(now.year + 20, 12, 31);
    final savedDate = CandidateVisaExpiry.parse(visaExpiryValue);
    final initialDate = savedDate != null &&
            !savedDate.isBefore(
              DateTime.utc(firstDate.year, firstDate.month, firstDate.day),
            ) &&
            !savedDate.isAfter(
              DateTime.utc(lastDate.year, lastDate.month, lastDate.day),
            )
        ? DateTime(savedDate.year, savedDate.month, savedDate.day)
        : firstDate;
    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: firstDate,
      lastDate: lastDate,
      helpText: 'Select visa expiry date',
    );
    if (picked == null || !mounted) return;
    setState(() {
      visaExpiryValue = CandidateVisaExpiry.normalizeDate(picked);
      visaExpiryController.text = CandidateVisaExpiry.displayDate(
        visaExpiryValue,
      );
      errors.remove('visa_expiry');
    });
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
      side: BorderSide(
        color: selected ? AppColors.primaryPink : AppColors.border,
      ),
      labelStyle: TextStyle(
        color: selected ? AppColors.white : AppColors.secondaryText,
        fontWeight: FontWeight.w700,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const ScreenScaffold(
        title: 'Experience',
        showBack: true,
        children: [
          ProgressStepper(current: 4, total: 5),
          SizedBox(height: 22),
          LinearProgressIndicator(),
        ],
      );
    }
    if (loadFailed) {
      return ScreenScaffold(
        title: 'Experience',
        showBack: true,
        children: [
          const ProgressStepper(current: 4, total: 5),
          const SizedBox(height: 22),
          const Text(
            'We could not load your saved experience details.',
            style: AppTextStyles.body,
          ),
          const SizedBox(height: 16),
          PrimaryButton(label: 'Try Again', onPressed: _load),
        ],
      );
    }
    return ScreenScaffold(
      title: 'Experience',
      showBack: true,
      children: [
        const ProgressStepper(current: 4, total: 5),
        const SizedBox(height: 22),
        const Text(
          'Tell employers what you need',
          style: AppTextStyles.headline,
        ),
        const SizedBox(height: 8),
        const Text(
          'Add your experience, availability, visa, and salary expectation.',
          style: AppTextStyles.body,
        ),
        const SizedBox(height: 16),
        for (final selection in selectedSkills) ...[
          AppCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(selection.skill.name, style: AppTextStyles.title),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final option in experienceOptions)
                      _chip(
                        label: option,
                        selected: skillExperience[selection.skill.id] == option,
                        onTap: () => setState(
                          () => skillExperience[selection.skill.id] = option,
                        ),
                      ),
                  ],
                ),
                if (errors['experience_${selection.skill.id}'] != null) ...[
                  const SizedBox(height: 8),
                  _FieldError(
                    errors['experience_${selection.skill.id}']!,
                  ),
                ],
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
            _chip(
              label: 'Yes',
              selected: drivingSkill == 'Yes',
              onTap: () => setState(() {
                drivingSkill = 'Yes';
                drivingLicenses.remove('No Driving Licence');
              }),
            ),
            _chip(
              label: 'No',
              selected: drivingSkill == 'No',
              onTap: () => setState(() {
                drivingSkill = 'No';
                drivingLicenses
                  ..clear()
                  ..add('No Driving Licence');
                errors.remove('driving');
              }),
            ),
          ],
        ),
        if (drivingSkill == 'Yes') ...[
          const SizedBox(height: 10),
          const Text('Licence *', style: AppTextStyles.label),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final value in drivingLicenseOptions)
                _chip(
                  label: value,
                  selected: drivingLicenses.contains(value),
                  onTap: () => setState(() {
                    errors.remove('driving');
                    if (value == 'No Driving Licence') {
                      drivingLicenses
                        ..clear()
                        ..add(value);
                    } else {
                      drivingLicenses.remove('No Driving Licence');
                      drivingLicenses.contains(value)
                          ? drivingLicenses.remove(value)
                          : drivingLicenses.add(value);
                    }
                  }),
                ),
            ],
          ),
          if (errors['driving'] != null) ...[
            const SizedBox(height: 8),
            _FieldError(errors['driving']!),
          ],
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
                  computerSkills.contains(value)
                      ? computerSkills.remove(value)
                      : computerSkills.add(value);
                }),
              ),
          ],
        ),
        const SizedBox(height: 14),
        const Text('Languages *', style: AppTextStyles.label),
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
                  errors
                    ..remove('languages')
                    ..remove('other_language');
                  if (languages.contains(value)) {
                    languages.remove(value);
                    if (value == 'Other') otherLanguageController.clear();
                  } else {
                    languages.add(value);
                  }
                }),
              ),
          ],
        ),
        if (errors['languages'] != null) ...[
          const SizedBox(height: 8),
          _FieldError(errors['languages']!),
        ],
        if (languages.contains('Other')) ...[
          const SizedBox(height: 12),
          AppTextField(
            controller: otherLanguageController,
            label: 'Enter language *',
            hint: 'Language',
            errorText: errors['other_language'],
            onChanged: (_) => setState(() => errors.remove('other_language')),
          ),
        ],
        const SizedBox(height: 20),
        AppTextField(
          controller: salaryController,
          label: 'Salary expectation *',
          hint: 'AED per month',
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          errorText: errors['salary'],
          onChanged: (_) => setState(() => errors.remove('salary')),
        ),
        const SizedBox(height: 12),
        _PickerField(
          controller: availabilityController,
          label: 'Availability *',
          hint: 'Select availability',
          errorText: errors['availability'],
          onTap: () => _pickOption(
            title: 'Availability',
            options: availabilityOptions,
            current: availabilityController.text,
            onPick: (value) => setState(() {
              availabilityController.text = value;
              errors.remove('availability');
            }),
          ),
        ),
        const SizedBox(height: 12),
        _PickerField(
          controller: employmentStatusController,
          label: 'Current Employment Status *',
          hint: 'Select employment status',
          errorText: errors['employment'],
          onTap: () => _pickOption(
            title: 'Current Employment Status',
            options: employmentStatusOptions,
            current: employmentStatusController.text,
            onPick: (value) => setState(() {
              employmentStatusController.text = value;
              if (value != 'Other') otherEmploymentStatusController.clear();
              errors
                ..remove('employment')
                ..remove('employment_other');
            }),
          ),
        ),
        if (employmentStatusController.text == 'Other') ...[
          const SizedBox(height: 12),
          AppTextField(
            controller: otherEmploymentStatusController,
            label: 'Enter employment status *',
            hint: 'Current employment status',
            errorText: errors['employment_other'],
            onChanged: (_) => setState(() => errors.remove('employment_other')),
          ),
        ],
        const SizedBox(height: 12),
        _PickerField(
          controller: currentCountryController,
          label: 'Current country *',
          hint: 'UAE or India',
          errorText: errors['current_country'],
          onTap: () => _pickOption(
            title: 'Current country',
            options: CandidateLocationOptions.countries,
            current: currentCountryController.text,
            onPick: (value) => setState(() {
              if (currentCountryController.text != value) {
                emirateController.clear();
              }
              currentCountryController.text = value;
              errors
                ..remove('current_country')
                ..remove('region');
            }),
          ),
        ),
        if (CandidateLocationOptions.normalizeCountry(
          currentCountryController.text,
        ).isNotEmpty) ...[
          const SizedBox(height: 12),
          _PickerField(
            controller: emirateController,
            label: currentCountryController.text == 'India'
                ? 'State *'
                : 'Emirate *',
            hint: currentCountryController.text == 'India'
                ? 'Select state'
                : 'Select emirate',
            errorText: errors['region'],
            onTap: () => _pickOption(
              title: currentCountryController.text == 'India'
                  ? 'State'
                  : 'Emirate',
              options: CandidateLocationOptions.regionsForCountry(
                currentCountryController.text,
              ),
              current: emirateController.text,
              onPick: (value) => setState(() {
                emirateController.text = value;
                errors.remove('region');
              }),
            ),
          ),
        ],
        const SizedBox(height: 12),
        _PickerField(
          controller: visaStatusController,
          label: 'Visa status *',
          hint: 'Select visa status',
          errorText: errors['visa'],
          onTap: () => _pickOption(
            title: 'Visa status',
            options: visaOptions,
            current: visaStatusController.text,
            onPick: (value) => setState(() {
              visaStatusController.text = value;
              errors.remove('visa');
              errors.remove('visa_expiry');
            }),
          ),
        ),
        if (CandidateVisaExpiry.requiresExpiry(
          visaStatusController.text,
        )) ...[
          const SizedBox(height: 12),
          AppTextField(
            controller: visaExpiryController,
            label: 'Visa Expiry Date *',
            hint: 'Select date',
            errorText: errors['visa_expiry'],
            readOnly: true,
            suffixIcon: const Icon(Icons.calendar_month_outlined),
            onTap: _pickVisaExpiryDate,
          ),
        ],
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
    this.errorText,
  });

  final TextEditingController controller;
  final String label;
  final String hint;
  final VoidCallback onTap;
  final String? errorText;

  @override
  Widget build(BuildContext context) {
    return AppTextField(
      controller: controller,
      label: label,
      hint: hint,
      readOnly: true,
      suffixIcon: const Icon(Icons.keyboard_arrow_down_rounded),
      errorText: errorText,
      onTap: onTap,
    );
  }
}

class _FieldError extends StatelessWidget {
  const _FieldError(this.message);

  final String message;

  @override
  Widget build(BuildContext context) {
    return Text(
      message,
      style: AppTextStyles.muted.copyWith(color: AppColors.error),
    );
  }
}
