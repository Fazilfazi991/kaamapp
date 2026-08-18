import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/constants/app_routes.dart';
import '../../../core/supabase/supabase_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/widgets/screen_scaffold.dart';
import '../../../core/widgets/secondary_button.dart';
import '../../../core/widgets/section_header.dart';
import '../../../core/widgets/status_badge.dart';
import '../../supabase_backend/kaam_backend.dart';
import '../../taxonomy/taxonomy_repository.dart';
import '../models/employer_models.dart';
import '../widgets/employer_selector_fields.dart';
import '../widgets/employer_taxonomy_search_sheets.dart';
import '../widgets/employer_widgets.dart';

class HiringRequirementsScreen extends StatefulWidget {
  const HiringRequirementsScreen({super.key});

  @override
  State<HiringRequirementsScreen> createState() =>
      _HiringRequirementsScreenState();
}

class _HiringRequirementsScreenState extends State<HiringRequirementsScreen> {
  final repository = const EmployerRepository();
  late Future<List<EmployerHiringRequirement>> requirementsFuture =
      repository.hiringRequirements();

  void _reload() {
    setState(() => requirementsFuture = repository.hiringRequirements());
  }

  @override
  Widget build(BuildContext context) {
    return ScreenScaffold(
      title: 'Hiring Requirements',
      showBack: true,
      bottomNavigationBar: const EmployerBottomNav(currentIndex: 1),
      children: [
        PrimaryButton(
          label: 'Add Hiring Requirement',
          icon: Icons.add_rounded,
          onPressed: () => Navigator.of(context)
              .pushNamed(AppRoutes.employerAddHiringRequirement)
              .then((_) => _reload()),
        ),
        const SizedBox(height: 18),
        FutureBuilder<List<EmployerHiringRequirement>>(
          future: requirementsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return EmptyState(
                icon: Icons.error_outline,
                title: 'Could not load hiring requirements',
                message:
                    'We couldn\'t load your hiring requirements. Please try again.',
                action: SecondaryButton(label: 'Retry', onPressed: _reload),
              );
            }
            final items = snapshot.data ?? const <EmployerHiringRequirement>[];
            if (items.isEmpty) {
              return const EmptyState(
                icon: Icons.work_outline,
                title: 'No hiring requirements yet',
                message: 'Add roles when you are ready to hire.',
              );
            }
            return Column(
              children: items
                  .map(
                    (item) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _RequirementCard(
                        requirement: item,
                        onChanged: _reload,
                      ),
                    ),
                  )
                  .toList(),
            );
          },
        ),
      ],
    );
  }
}

class AddHiringRequirementScreen extends StatefulWidget {
  const AddHiringRequirementScreen({super.key});

  @override
  State<AddHiringRequirementScreen> createState() =>
      _AddHiringRequirementScreenState();
}

class _AddHiringRequirementScreenState
    extends State<AddHiringRequirementScreen> {
  static const salaries = [
    'AED 1000 - 1500',
    'AED 1500 - 2000',
    'AED 2000 - 2500',
    'AED 2500 - 3000',
    'AED 3000+',
    'Negotiable',
    'Other',
  ];
  static const locations = [
    'Dubai',
    'Abu Dhabi',
    'Sharjah',
    'Ajman',
    'Ras Al Khaimah',
    'Fujairah',
    'Umm Al Quwain',
    'Anywhere in UAE',
    'Other',
  ];
  static const hours = [
    '8 hours',
    '9 hours',
    '10 hours',
    '12 hours',
    'Flexible',
    'Other',
  ];

  final repository = const EmployerRepository();
  final openingsController = TextEditingController(text: '1');
  final customRoleController = TextEditingController();
  final salaryController = TextEditingController();
  final locationController = TextEditingController();
  final hoursController = TextEditingController();
  final descriptionController = TextEditingController();
  TaxonomyRepository? taxonomyRepository;
  TaxonomyRole? selectedRole;
  final selectedSkills = <String, CompetencySkill>{};
  List<CompetencySkill> suggestedSkills = const [];
  String legacyRole = '';
  String? roleError;
  String? suggestedSkillsError;
  bool loadingSuggestedSkills = false;
  bool roleExplicitlySelected = false;
  bool initialized = false;
  bool accommodation = false;
  bool transport = false;
  bool visa = false;
  bool immediate = false;
  bool saving = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)?.settings.arguments;
    if (!initialized) {
      initialized = true;
      final client = SupabaseService.maybeClient;
      if (client != null) taxonomyRepository = TaxonomyRepository(client);
    }
    if (args is EmployerHiringRequirement && legacyRole.isEmpty) {
      legacyRole = args.role;
      customRoleController.text = args.customRole;
      openingsController.text = args.openings.toString();
      salaryController.text = args.salaryRange;
      locationController.text = args.workLocation;
      hoursController.text = args.workingHours;
      descriptionController.text = args.description;
      accommodation = args.accommodationProvided;
      transport = args.transportProvided;
      visa = args.visaProvided;
      immediate = args.immediateJoining;
      _hydrateExistingTaxonomy(args);
    }
  }

  Future<void> _hydrateExistingTaxonomy(
    EmployerHiringRequirement requirement,
  ) async {
    final taxonomy = taxonomyRepository;
    if (taxonomy == null) return;
    try {
      final role = requirement.jobRoleId == null
          ? await taxonomy.findRoleByExactName(requirement.role)
          : await taxonomy.role(requirement.jobRoleId!);
      final skills = await taxonomy.skillsByIds(requirement.competencySkillIds);
      if (!mounted) return;
      setState(() {
        selectedRole = role;
        selectedSkills
          ..clear()
          ..addEntries(skills.map((skill) => MapEntry(skill.id, skill)));
      });
      if (role != null) _loadSuggestedSkills(role.id);
    } catch (_) {
      // Legacy values remain usable if catalog resolution is temporarily down.
    }
  }

  Future<void> _loadSuggestedSkills(String roleId) async {
    final taxonomy = taxonomyRepository;
    if (taxonomy == null) return;
    setState(() {
      loadingSuggestedSkills = true;
      suggestedSkillsError = null;
    });
    try {
      final skills = await taxonomy.suggestedSkills(roleId);
      if (!mounted || selectedRole?.id != roleId) return;
      setState(() => suggestedSkills = skills);
    } catch (_) {
      if (mounted && selectedRole?.id == roleId) {
        setState(
            () => suggestedSkillsError = 'Unable to load suggested skills.');
      }
    } finally {
      if (mounted && selectedRole?.id == roleId) {
        setState(() => loadingSuggestedSkills = false);
      }
    }
  }

  String get _roleDisplay => selectedRole?.name ?? legacyRole;

  @override
  void dispose() {
    openingsController.dispose();
    customRoleController.dispose();
    salaryController.dispose();
    locationController.dispose();
    hoursController.dispose();
    descriptionController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final openings = int.tryParse(openingsController.text.trim());
    final args = ModalRoute.of(context)?.settings.arguments;
    final existing = args is EmployerHiringRequirement ? args : null;
    if (existing == null && selectedRole == null) {
      _message('Select a job role.');
      return;
    }
    if (openings == null || openings < 1) {
      _message('Enter at least 1 opening.');
      return;
    }
    if (salaryController.text.trim().isEmpty ||
        locationController.text.trim().isEmpty ||
        hoursController.text.trim().isEmpty) {
      _message('Select salary, location, and working hours.');
      return;
    }

    setState(() => saving = true);
    try {
      await repository.saveHiringRequirement(
        EmployerHiringRequirement(
          id: existing?.id,
          role: _roleDisplay,
          jobRoleId:
              roleExplicitlySelected ? selectedRole?.id : existing?.jobRoleId,
          competencySkillIds: selectedSkills.keys.toList(),
          customRole: existing?.customRole ?? '',
          openings: openings,
          salaryRange: salaryController.text.trim(),
          workLocation: locationController.text.trim(),
          workingHours: hoursController.text.trim(),
          accommodationProvided: accommodation,
          transportProvided: transport,
          visaProvided: visa,
          immediateJoining: immediate,
          description: descriptionController.text.trim(),
          status: existing?.status ?? 'active',
        ),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Hiring requirement saved.')),
      );
      Navigator.of(context).pop();
    } catch (error) {
      _message(
        'Could not save hiring requirement. Please retry; skills may need syncing.',
      );
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  void _message(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    return ScreenScaffold(
      title: 'Add Hiring Requirement',
      showBack: true,
      children: [
        const SectionHeader(title: 'Job role'),
        const SizedBox(height: 10),
        SelectionField(
          label: 'Job Role *',
          value: _roleDisplay,
          hint: 'Search or select job role',
          errorText: roleError,
          onTap: () async {
            final taxonomy = taxonomyRepository;
            if (taxonomy == null) {
              setState(() => roleError = 'Unable to load job roles.');
              return;
            }
            final picked = await showJobRoleSearchSheet(
              context: context,
              selected: selectedRole,
              search: (query) => taxonomy.searchRoles(query, limit: 20),
            );
            if (picked != null && mounted) {
              setState(() {
                selectedRole = picked;
                legacyRole = picked.name;
                roleExplicitlySelected = true;
                roleError = null;
              });
              _loadSuggestedSkills(picked.id);
            }
          },
        ),
        if (selectedRole != null) ...[
          const SizedBox(height: 12),
          Text(
            '${selectedRole!.category} • ${selectedRole!.industry}',
            style: AppTextStyles.muted,
          ),
        ],
        const SizedBox(height: 18),
        AppTextField(
          controller: openingsController,
          label: 'Number of openings',
          hint: '1',
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        ),
        const SizedBox(height: 12),
        _PickerField(
          controller: salaryController,
          label: 'Salary range',
          options: salaries,
        ),
        const SizedBox(height: 12),
        _PickerField(
          controller: locationController,
          label: 'Work location',
          options: locations,
        ),
        const SizedBox(height: 12),
        _PickerField(
          controller: hoursController,
          label: 'Working hours',
          options: hours,
        ),
        const SizedBox(height: 14),
        _SwitchLine(
          label: 'Accommodation provided',
          value: accommodation,
          onChanged: (v) => setState(() => accommodation = v),
        ),
        _SwitchLine(
          label: 'Transport provided',
          value: transport,
          onChanged: (v) => setState(() => transport = v),
        ),
        _SwitchLine(
          label: 'Visa provided',
          value: visa,
          onChanged: (v) => setState(() => visa = v),
        ),
        _SwitchLine(
          label: 'Immediate joining needed',
          value: immediate,
          onChanged: (v) => setState(() => immediate = v),
        ),
        const SizedBox(height: 12),
        AppTextField(
          controller: descriptionController,
          label: 'Notes / description optional',
          hint: 'Add shift, duties, or interview notes',
          maxLines: 4,
        ),
        const SizedBox(height: 20),
        const SectionHeader(title: 'Skills'),
        const SizedBox(height: 10),
        if (selectedSkills.isNotEmpty) ...[
          const Text('Selected Skills', style: AppTextStyles.label),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: selectedSkills.values
                .map(
                  (skill) => InputChip(
                    label: Text(skill.name),
                    onDeleted: () =>
                        setState(() => selectedSkills.remove(skill.id)),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 14),
        ],
        if (selectedRole != null) ...[
          const Text('Suggested Skills', style: AppTextStyles.label),
          const SizedBox(height: 8),
          if (loadingSuggestedSkills) const LinearProgressIndicator(),
          if (suggestedSkillsError != null)
            TextButton(
              onPressed: () => _loadSuggestedSkills(selectedRole!.id),
              child: Text('$suggestedSkillsError Retry'),
            ),
          if (!loadingSuggestedSkills && suggestedSkillsError == null)
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: suggestedSkills
                  .map(
                    (skill) => FilterChip(
                      label: Text(skill.name),
                      selected: selectedSkills.containsKey(skill.id),
                      onSelected: (selected) => setState(() {
                        if (selected) {
                          selectedSkills[skill.id] = skill;
                        } else {
                          selectedSkills.remove(skill.id);
                        }
                      }),
                    ),
                  )
                  .toList(),
            ),
          const SizedBox(height: 12),
        ],
        OutlinedButton.icon(
          icon: const Icon(Icons.add_rounded),
          label: const Text('Add skills'),
          onPressed: () async {
            final taxonomy = taxonomyRepository;
            if (taxonomy == null) {
              _message('Unable to load skills.');
              return;
            }
            final picked = await showCompetencySkillSearchSheet(
              context: context,
              selected: selectedSkills.values,
              search: taxonomy.searchSkills,
            );
            if (picked != null && mounted) {
              setState(() {
                selectedSkills
                  ..clear()
                  ..addEntries(
                      picked.map((skill) => MapEntry(skill.id, skill)));
              });
            }
          },
        ),
        const SizedBox(height: 22),
        PrimaryButton(
          label: saving ? 'Saving...' : 'Save Hiring Requirement',
          onPressed: saving ? null : _save,
        ),
        const SizedBox(height: 10),
        SecondaryButton(
          label: 'Cancel',
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }
}

class _RequirementCard extends StatelessWidget {
  const _RequirementCard({required this.requirement, required this.onChanged});

  final EmployerHiringRequirement requirement;
  final VoidCallback onChanged;

  Future<void> _setStatus(BuildContext context, String status) async {
    try {
      await const EmployerRepository().updateHiringRequirementStatus(
        requirement.id ?? '',
        status,
      );
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Requirement marked $status.')));
      onChanged();
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not update requirement: $error')),
      );
    }
  }

  Future<void> _delete(BuildContext context) async {
    try {
      await const EmployerRepository().deleteHiringRequirement(
        requirement.id ?? '',
      );
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Hiring requirement deleted.')),
      );
      onChanged();
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not delete requirement: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  requirement.displayRole,
                  style: AppTextStyles.title,
                ),
              ),
              StatusBadge(label: requirement.status, color: AppColors.warning),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '${requirement.openings} openings • ${requirement.workLocation}',
            style: AppTextStyles.body,
          ),
          Text(
            '${requirement.salaryRange} • ${requirement.workingHours}',
            style: AppTextStyles.muted,
          ),
          const SizedBox(height: 8),
          Text(
            'Accommodation: ${requirement.accommodationProvided ? 'Yes' : 'No'} • Transport: ${requirement.transportProvided ? 'Yes' : 'No'} • Visa: ${requirement.visaProvided ? 'Yes' : 'No'}',
            style: AppTextStyles.muted,
          ),
          if (requirement.description.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(requirement.description, style: AppTextStyles.body),
          ],
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              SecondaryButton(
                label: 'Edit',
                onPressed: () => Navigator.of(context)
                    .pushNamed(
                      AppRoutes.employerAddHiringRequirement,
                      arguments: requirement,
                    )
                    .then((_) => onChanged()),
              ),
              SecondaryButton(
                label: requirement.status == 'active' ? 'Pause' : 'Activate',
                onPressed: () => _setStatus(
                  context,
                  requirement.status == 'active' ? 'paused' : 'active',
                ),
              ),
              SecondaryButton(
                label: 'Close',
                onPressed: () => _setStatus(context, 'closed'),
              ),
              SecondaryButton(
                label: 'Delete',
                onPressed: () => _delete(context),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PickerField extends StatelessWidget {
  const _PickerField({
    required this.controller,
    required this.label,
    required this.options,
  });

  final TextEditingController controller;
  final String label;
  final List<String> options;

  @override
  Widget build(BuildContext context) {
    return AppTextField(
      controller: controller,
      label: label,
      hint: options.first,
      readOnly: false,
      suffixIcon: const Icon(Icons.expand_more_rounded),
      onTap: () async {
        final value = await showModalBottomSheet<String>(
          context: context,
          showDragHandle: true,
          builder: (context) => SafeArea(
            child: ListView(
              shrinkWrap: true,
              children: options
                  .map(
                    (option) => ListTile(
                      title: Text(option),
                      onTap: () => Navigator.of(context).pop(option),
                    ),
                  )
                  .toList(),
            ),
          ),
        );
        if (value == null) return;
        if (value == 'Other') {
          controller.clear();
        } else {
          controller.text = value;
        }
      },
    );
  }
}

class _SwitchLine extends StatelessWidget {
  const _SwitchLine({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      value: value,
      onChanged: onChanged,
      title: Text(label, style: AppTextStyles.body),
    );
  }
}
