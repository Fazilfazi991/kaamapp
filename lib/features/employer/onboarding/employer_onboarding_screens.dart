import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';

import '../../../core/constants/app_routes.dart';
import '../../../core/supabase/supabase_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/widgets/progress_stepper.dart';
import '../../../core/widgets/screen_scaffold.dart';
import '../../../core/widgets/status_badge.dart';
import '../data/employer_dummy_data.dart';
import '../widgets/employer_widgets.dart';
import '../../supabase_backend/kaam_backend.dart';
import '../../taxonomy/taxonomy_repository.dart';
import '../widgets/employer_selector_fields.dart';

class EmployerOnboardingOverviewScreen extends StatelessWidget {
  const EmployerOnboardingOverviewScreen({super.key});

  @override
  Widget build(BuildContext context) {
    const steps = [
      'Company Details',
      'Ready to Hire',
    ];
    return ScreenScaffold(
      title: 'Setup',
      showBack: true,
      children: [
        const Text(
          'Set up your company profile',
          style: AppTextStyles.headline,
        ),
        const SizedBox(height: 10),
        const Text(
          'Complete your company details to start hiring. Verification is optional and managed separately.',
          style: AppTextStyles.body,
        ),
        const SizedBox(height: 22),
        ...steps.map(
          (step) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: AppCard(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Icon(
                    Icons.check_circle_outline_rounded,
                    color: AppColors.primaryPink,
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: Text(step, style: AppTextStyles.label)),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 14),
        PrimaryButton(
          label: 'Start Setup',
          onPressed: () =>
              Navigator.of(context).pushNamed(AppRoutes.employerCompanyDetails),
        ),
      ],
    );
  }
}

class CompanyDetailsScreen extends StatefulWidget {
  const CompanyDetailsScreen({super.key});

  @override
  State<CompanyDetailsScreen> createState() => _CompanyDetailsScreenState();
}

class _CompanyDetailsScreenState extends State<CompanyDetailsScreen> {
  final companyNameController = TextEditingController();
  final branchController = TextEditingController();
  final contactNameController = TextEditingController();
  final contactRoleOtherController = TextEditingController();
  final descriptionController = TextEditingController();
  final repository = const EmployerRepository();
  TaxonomyRepository? taxonomyRepository;
  EmployerCompanyData? existingCompany;
  List<TaxonomyIndustry> industries = const [];
  TaxonomyIndustry? selectedIndustry;
  StructuredOption? selectedCompanySize;
  StructuredOption? selectedContactRole;
  String? selectedEmirate;
  String? selectedArea;
  String? industryLoadError;
  String? contactRoleError;
  bool industriesLoading = false;
  bool industryExplicitlySelected = false;
  bool companySizeExplicitlySelected = false;
  bool contactRoleExplicitlySelected = false;
  bool emirateExplicitlySelected = false;
  bool areaExplicitlySelected = false;
  bool branchExplicitlyEdited = false;
  bool saving = false;
  bool loading = true;

  /*
  static const companySizeOptions = [
    StructuredOption(code: '1_10', label: '1–10'),
    StructuredOption(code: '11_25', label: '11–25'),
    StructuredOption(code: '26_50', label: '26–50'),
    StructuredOption(code: '51_100', label: '51–100'),
    StructuredOption(code: '101_250', label: '101–250'),
    StructuredOption(code: '251_500', label: '251–500'),
    StructuredOption(code: '500_plus', label: '500+'),
  ];
  static const contactRoleOptions = [
    StructuredOption(code: 'owner', label: 'Owner'),
    StructuredOption(code: 'founder', label: 'Founder'),
    StructuredOption(code: 'co_founder', label: 'Co-Founder'),
    StructuredOption(code: 'managing_director', label: 'Managing Director'),
    StructuredOption(code: 'director', label: 'Director'),
    StructuredOption(code: 'general_manager', label: 'General Manager'),
    StructuredOption(code: 'hr_manager', label: 'HR Manager'),
    StructuredOption(code: 'hr_executive', label: 'HR Executive'),
    StructuredOption(code: 'recruitment_manager', label: 'Recruitment Manager'),
    StructuredOption(code: 'recruiter', label: 'Recruiter'),
    StructuredOption(code: 'operations_manager', label: 'Operations Manager'),
    StructuredOption(
        code: 'operations_executive', label: 'Operations Executive'),
    StructuredOption(code: 'admin_manager', label: 'Admin Manager'),
    StructuredOption(code: 'administrator', label: 'Administrator'),
    StructuredOption(code: 'supervisor', label: 'Supervisor'),
    StructuredOption(code: 'pro', label: 'PRO'),
    StructuredOption(code: 'other', label: 'Other'),
  ];
  */

  @override
  void initState() {
    super.initState();
    final client = SupabaseService.maybeClient;
    if (client != null) taxonomyRepository = TaxonomyRepository(client);
    _load();
    _loadIndustries();
  }

  @override
  void dispose() {
    companyNameController.dispose();
    branchController.dispose();
    contactNameController.dispose();
    contactRoleOtherController.dispose();
    descriptionController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final company = await repository.loadMyCompany();
      if (!mounted || company == null) return;
      existingCompany = company;
      if (industries.isNotEmpty) {
        selectedIndustry = _matchIndustry(company, industries);
      }
      companyNameController.text = company.companyName;
      branchController.text = company.branchName ?? company.officeArea;
      contactNameController.text = company.contactPerson;
      descriptionController.text = company.description;
      selectedCompanySize = _optionForCode(
        EmployerCompanyOptions.companySizes,
        company.companySizeCode,
      );
      selectedCompanySize ??= _optionForLabel(
          EmployerCompanyOptions.companySizes, company.companySize);
      selectedContactRole = _optionForCode(
        EmployerCompanyOptions.contactRoles,
        company.contactRoleCode,
      );
      selectedContactRole ??= _optionForLabel(
          EmployerCompanyOptions.contactRoles, company.contactRole);
      if (selectedContactRole?.code == 'other' ||
          (selectedContactRole == null &&
              company.contactRole.trim().isNotEmpty)) {
        selectedContactRole =
            _optionForCode(EmployerCompanyOptions.contactRoles, 'other');
        contactRoleOtherController.text =
            company.contactRoleOther ?? company.contactRole;
      } else {
        contactRoleOtherController.text = company.contactRoleOther ?? '';
      }
      selectedEmirate = _validEmirate(company.companyEmirate) ??
          _validEmirate(company.location);
      final storedArea = company.companyArea;
      if (storedArea != null &&
          selectedEmirate != null &&
          CandidateLocationOptions.isValidAreaForEmirate(
            selectedEmirate!,
            storedArea,
          )) {
        selectedArea =
            CandidateLocationOptions.areasForEmirate(selectedEmirate!)
                .firstWhere(
                    (area) => area.toLowerCase() == storedArea.toLowerCase());
      } else {
        selectedArea = storedArea;
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not load company: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _loadIndustries() async {
    final taxonomy = taxonomyRepository;
    if (taxonomy == null) {
      if (mounted) {
        setState(() => industryLoadError = 'Industry catalog is unavailable.');
      }
      return;
    }
    setState(() {
      industriesLoading = true;
      industryLoadError = null;
    });
    try {
      final loaded = await taxonomy.getIndustries();
      if (!mounted) return;
      setState(() {
        industries = loaded;
        selectedIndustry = _matchIndustry(existingCompany, loaded);
        if (loaded.isEmpty) industryLoadError = 'No industries are available.';
      });
    } catch (_) {
      if (mounted) {
        setState(() => industryLoadError = 'Unable to load industries.');
      }
    } finally {
      if (mounted) setState(() => industriesLoading = false);
    }
  }

  TaxonomyIndustry? _matchIndustry(
    EmployerCompanyData? company,
    List<TaxonomyIndustry> options,
  ) {
    if (company == null) return null;
    for (final option in options) {
      if (option.id == company.industryId ||
          option.name.toLowerCase() == company.industry.trim().toLowerCase()) {
        return option;
      }
    }
    return null;
  }

  StructuredOption? _optionForCode(
    List<StructuredOption> options,
    String? code,
  ) =>
      options.where((option) => option.code == code).firstOrNull;

  StructuredOption? _optionForLabel(
    List<StructuredOption> options,
    String value,
  ) =>
      options
          .where((option) =>
              option.label.toLowerCase() == value.trim().toLowerCase())
          .firstOrNull;

  String? _validEmirate(String? value) {
    final normalized = CandidateLocationOptions.normalizeRegionForCountry(
      'UAE',
      value ?? '',
    );
    return normalized.isEmpty ? null : normalized;
  }

  String get _industryDisplay =>
      selectedIndustry?.name ?? existingCompany?.industry ?? '';
  String get _companySizeDisplay =>
      selectedCompanySize?.label ?? existingCompany?.companySize ?? '';
  String get _contactRoleDisplay {
    if (selectedContactRole?.code == 'other') {
      return contactRoleOtherController.text.trim().isEmpty
          ? 'Other'
          : contactRoleOtherController.text.trim();
    }
    return selectedContactRole?.label ?? existingCompany?.contactRole ?? '';
  }

  String get _emirateDisplay =>
      selectedEmirate ?? existingCompany?.location ?? '';

  Future<void> _continue() async {
    if (selectedContactRole?.code == 'other' &&
        contactRoleOtherController.text.trim().isEmpty) {
      setState(() => contactRoleError = 'Specify the contact person role.');
      return;
    }
    setState(() => saving = true);
    try {
      final company = existingCompany;
      final selectedRoleIsOther = selectedContactRole?.code == 'other';
      await repository.upsertCompanyProfile(
        companyName: companyNameController.text,
        industry: _industryDisplay,
        companySize: _companySizeDisplay,
        location: emirateExplicitlySelected
            ? (selectedEmirate ?? '')
            : (company?.location ?? selectedEmirate ?? ''),
        branch: branchController.text,
        contactName: contactNameController.text,
        contactRole: _contactRoleDisplay,
        description: descriptionController.text,
        industryId: industryExplicitlySelected
            ? selectedIndustry?.id
            : company?.industryId,
        companySizeCode: companySizeExplicitlySelected
            ? selectedCompanySize?.code
            : company?.companySizeCode,
        contactRoleCode: contactRoleExplicitlySelected
            ? selectedContactRole?.code
            : company?.contactRoleCode,
        contactRoleOther: contactRoleExplicitlySelected
            ? (selectedRoleIsOther
                ? contactRoleOtherController.text.trim()
                : '')
            : company?.contactRoleOther,
        companyEmirate: emirateExplicitlySelected
            ? selectedEmirate
            : company?.companyEmirate,
        companyArea:
            areaExplicitlySelected ? selectedArea : company?.companyArea,
        branchName: branchExplicitlyEdited
            ? branchController.text
            : company?.branchName,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Company profile saved.')));
      Navigator.of(context).pushNamed(AppRoutes.employerProfileComplete);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            KaamSafeErrorMessages.employerCompanySaveMessage(error),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ScreenScaffold(
      title: 'Company Details',
      showBack: true,
      children: [
        const ProgressStepper(current: 1, total: 3),
        const SizedBox(height: 18),
        if (loading) const LinearProgressIndicator(),
        if (loading) const SizedBox(height: 12),
        AppTextField(
          controller: companyNameController,
          label: 'Company name',
          hint: EmployerDummyData.companyName,
        ),
        const SizedBox(height: 12),
        SelectionField(
          label: 'Industry',
          value: _industryDisplay,
          hint: 'Select industry',
          errorText: industryLoadError,
          loading: industriesLoading,
          enabled: !industriesLoading,
          onTap: industries.isEmpty
              ? _loadIndustries
              : () async {
                  final picked =
                      await showSearchSelectionSheet<TaxonomyIndustry>(
                    context: context,
                    title: 'Select Industry',
                    options: industries,
                    label: (industry) => industry.name,
                    selected: selectedIndustry,
                  );
                  if (picked != null && mounted) {
                    setState(() {
                      selectedIndustry = picked;
                      industryExplicitlySelected = true;
                    });
                  }
                },
        ),
        if (industryLoadError != null) ...[
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
                onPressed: _loadIndustries,
                child: const Text('Retry industries')),
          ),
        ],
        const SizedBox(height: 12),
        SelectionField(
          label: 'Company size',
          value: _companySizeDisplay,
          hint: 'Select company size',
          onTap: () async {
            final picked = await showSearchSelectionSheet<StructuredOption>(
              context: context,
              title: 'Select Company Size',
              options: EmployerCompanyOptions.companySizes,
              label: (option) => option.label,
              selected: selectedCompanySize,
            );
            if (picked != null && mounted) {
              setState(() {
                selectedCompanySize = picked;
                companySizeExplicitlySelected = true;
              });
            }
          },
        ),
        const SizedBox(height: 12),
        SelectionField(
          label: 'Emirate',
          value: _emirateDisplay,
          hint: 'Select emirate',
          onTap: () async {
            final picked = await showSearchSelectionSheet<String>(
              context: context,
              title: 'Select Emirate',
              options: CandidateLocationOptions.uaeEmirates,
              label: (value) => value,
              selected: selectedEmirate,
            );
            if (picked != null && mounted) {
              setState(() {
                final retainedArea = retainedAreaForEmirateChange(
                  nextEmirate: picked,
                  currentArea: selectedArea,
                );
                selectedEmirate = picked;
                if (retainedArea == null) selectedArea = null;
                emirateExplicitlySelected = true;
                if (retainedArea == null) areaExplicitlySelected = true;
              });
            }
          },
        ),
        const SizedBox(height: 12),
        SelectionField(
          label: 'Area',
          value: selectedArea ?? '',
          hint: selectedEmirate == null
              ? 'Select an emirate first'
              : 'Select area',
          enabled: selectedEmirate != null,
          onTap: selectedEmirate == null
              ? null
              : () async {
                  final picked = await showSearchSelectionSheet<String>(
                    context: context,
                    title: 'Select Area',
                    options: CandidateLocationOptions.areasForEmirate(
                        selectedEmirate!),
                    label: (value) => value,
                    selected: selectedArea,
                  );
                  if (picked != null && mounted) {
                    setState(() {
                      selectedArea = picked;
                      areaExplicitlySelected = true;
                    });
                  }
                },
        ),
        const SizedBox(height: 12),
        AppTextField(
          controller: branchController,
          label: 'Branch name (optional)',
          hint: 'Al Quoz Branch',
          onChanged: (_) => branchExplicitlyEdited = true,
        ),
        const SizedBox(height: 12),
        AppTextField(
          controller: contactNameController,
          label: 'Contact person name',
          hint: 'Nadia Rahman',
        ),
        const SizedBox(height: 12),
        SelectionField(
          label: 'Contact person role',
          value: _contactRoleDisplay,
          hint: 'Select contact role',
          errorText: contactRoleError,
          onTap: () async {
            final picked = await showSearchSelectionSheet<StructuredOption>(
              context: context,
              title: 'Select Contact Role',
              options: EmployerCompanyOptions.contactRoles,
              label: (option) => option.label,
              selected: selectedContactRole,
            );
            if (picked != null && mounted) {
              setState(() {
                selectedContactRole = picked;
                contactRoleExplicitlySelected = true;
                contactRoleError = null;
                if (picked.code != 'other') contactRoleOtherController.clear();
              });
            }
          },
        ),
        if (selectedContactRole?.code == 'other') ...[
          const SizedBox(height: 12),
          AppTextField(
            controller: contactRoleOtherController,
            label: 'Specify role',
            hint: 'CMO',
            errorText: contactRoleError,
            inputFormatters: [LengthLimitingTextInputFormatter(100)],
            onChanged: (_) {
              if (contactRoleError != null) {
                setState(() => contactRoleError = null);
              }
            },
          ),
        ],
        const SizedBox(height: 12),
        AppTextField(
          controller: descriptionController,
          label: 'Company description',
          hint: 'Tell candidates about your company.',
          maxLines: 4,
        ),
        const SizedBox(height: 22),
        PrimaryButton(
          label: saving ? 'Saving...' : 'Continue',
          onPressed: saving ? null : _continue,
        ),
      ],
    );
  }
}

class LegacyDisabledEmployerHiringSetupScreen extends StatefulWidget {
  const LegacyDisabledEmployerHiringSetupScreen({super.key});

  @override
  State<LegacyDisabledEmployerHiringSetupScreen> createState() =>
      _LegacyDisabledEmployerHiringSetupScreenState();
}

class _LegacyDisabledEmployerHiringSetupScreenState
    extends State<LegacyDisabledEmployerHiringSetupScreen> {
  static const roles = [
    'Cleaner',
    'Driver',
    'Housekeeping',
    'Security',
    'Sales',
    'Office Staff',
    'Technician',
    'Hospitality',
    'Construction',
    'Delivery Rider',
    'Warehouse Helper',
    'Restaurant Staff',
    'Domestic Worker',
    'Other',
  ];
  static const salaryOptions = [
    'AED 1000 - 1500',
    'AED 1500 - 2000',
    'AED 2000 - 2500',
    'AED 2500 - 3000',
    'AED 3000+',
    'Negotiable',
    'Other',
  ];
  static const locationOptions = [
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
  static const hoursOptions = [
    '8 hours',
    '9 hours',
    '10 hours',
    '12 hours',
    'Flexible',
    'Other',
  ];

  final Set<String> selectedRoles = {};
  final otherRoleController = TextEditingController();
  final openingsController = TextEditingController();
  final salaryController = TextEditingController();
  final locationController = TextEditingController();
  final hoursController = TextEditingController();
  final repository = const EmployerRepository();
  bool accommodation = true;
  bool transport = true;
  bool visa = false;
  bool immediate = true;
  bool saving = false;
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    otherRoleController.dispose();
    openingsController.dispose();
    salaryController.dispose();
    locationController.dispose();
    hoursController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final existing = await repository.loadMyCompany();
      if (!mounted || existing == null) return;
      for (final role in existing.hiringNeeds) {
        if (roles.contains(role)) {
          selectedRoles.add(role);
        } else if (role.trim().isNotEmpty) {
          selectedRoles.add('Other');
          otherRoleController.text = [
            otherRoleController.text,
            role,
          ].where((value) => value.trim().isNotEmpty).join(', ');
        }
      }
      final details = _hiringDetails(existing.description);
      openingsController.text = details['Openings'] ?? '';
      salaryController.text = details['Salary'] ?? '';
      locationController.text = details['Location'] ?? existing.location;
      hoursController.text = details['Hours'] ?? '';
      accommodation = _yes(details['Accommodation'], fallback: accommodation);
      transport = _yes(details['Transport'], fallback: transport);
      visa = _yes(details['Visa'], fallback: visa);
      immediate = _yes(details['Immediate'], fallback: immediate);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not load hiring needs: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _continue() async {
    final openings = int.tryParse(openingsController.text.trim());
    if (openings == null || openings < 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter at least 1 opening.')),
      );
      return;
    }

    final hiringRoles = _selectedHiringRoles();
    if (hiringRoles.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Choose at least one hiring role.')),
      );
      return;
    }

    setState(() => saving = true);
    try {
      final existing = await repository.loadMyCompany();
      final aboutCompany = _aboutCompany(existing?.description ?? '');
      await repository.upsertCompanyProfile(
        companyName: existing?.companyName ?? '',
        industry: existing?.industry ?? '',
        companySize: existing?.companySize ?? '',
        location: existing?.location ?? locationController.text,
        branch: existing?.officeArea ?? '',
        contactName: existing?.contactPerson ?? '',
        contactRole: existing?.contactRole ?? '',
        description: [
          aboutCompany,
          'Legacy Requirement Details:',
          'Roles: ${hiringRoles.join(', ')}',
          'Openings: ${openingsController.text}',
          'Salary: ${salaryController.text}',
          'Location: ${locationController.text}',
          'Hours: ${hoursController.text}',
          'Accommodation: ${accommodation ? 'Yes' : 'No'}',
          'Transport: ${transport ? 'Yes' : 'No'}',
          'Visa: ${visa ? 'Yes' : 'No'}',
          'Immediate: ${immediate ? 'Yes' : 'No'}',
        ].where((line) => line.trim().isNotEmpty).join('\n'),
        hiringNeeds: hiringRoles,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Requirement details saved.')),
      );
      Navigator.of(context).pushNamed(AppRoutes.employerProfileComplete);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            KaamSafeErrorMessages.employerCompanySaveMessage(error),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  List<String> _selectedHiringRoles() {
    final values = selectedRoles.where((role) => role != 'Other').toList();
    if (selectedRoles.contains('Other') &&
        otherRoleController.text.trim().isNotEmpty) {
      values.addAll(splitCsv(otherRoleController.text));
    }
    return values;
  }

  String _aboutCompany(String description) {
    final marker = description.indexOf('Legacy Requirement Details:');
    return (marker == -1 ? description : description.substring(0, marker))
        .trim();
  }

  Map<String, String> _hiringDetails(String description) {
    final marker = description.indexOf('Legacy Requirement Details:');
    if (marker == -1) return const {};
    final details = <String, String>{};
    for (final line in description.substring(marker).split('\n').skip(1)) {
      final divider = line.indexOf(':');
      if (divider == -1) continue;
      final key = line.substring(0, divider).trim();
      final value = line.substring(divider + 1).trim();
      if (key.isNotEmpty && value.isNotEmpty) details[key] = value;
    }
    return details;
  }

  bool _yes(String? value, {required bool fallback}) {
    if (value == null || value.trim().isEmpty) return fallback;
    return value.toLowerCase().startsWith('y');
  }

  @override
  Widget build(BuildContext context) {
    return ScreenScaffold(
      title: 'Requirement Setup',
      showBack: true,
      children: [
        const ProgressStepper(current: 2, total: 4),
        const SizedBox(height: 18),
        if (loading) const LinearProgressIndicator(),
        if (loading) const SizedBox(height: 12),
        const Text(
          'What roles are you hiring for?',
          style: AppTextStyles.headline,
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: roles.map((role) {
            final active = selectedRoles.contains(role);
            return FilterChip(
              label: Text(role),
              selected: active,
              onSelected: (_) => setState(() {
                active ? selectedRoles.remove(role) : selectedRoles.add(role);
              }),
            );
          }).toList(),
        ),
        if (selectedRoles.contains('Other')) ...[
          const SizedBox(height: 12),
          AppTextField(
            controller: otherRoleController,
            label: 'Enter hiring role',
            hint: 'Mason, nanny, merchandiser',
          ),
        ],
        const SizedBox(height: 18),
        AppTextField(
          controller: openingsController,
          label: 'Number of openings',
          hint: '5',
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        ),
        const SizedBox(height: 12),
        _GuidedPickerField(
          controller: salaryController,
          label: 'Salary range',
          options: salaryOptions,
        ),
        const SizedBox(height: 12),
        _GuidedPickerField(
          controller: locationController,
          label: 'Work location',
          options: locationOptions,
        ),
        const SizedBox(height: 12),
        _GuidedPickerField(
          controller: hoursController,
          label: 'Working hours',
          options: hoursOptions,
        ),
        const SizedBox(height: 12),
        _SwitchLine(
          label: 'Accommodation provided?',
          value: accommodation,
          onChanged: (v) => setState(() => accommodation = v),
        ),
        _SwitchLine(
          label: 'Transport provided?',
          value: transport,
          onChanged: (v) => setState(() => transport = v),
        ),
        _SwitchLine(
          label: 'Visa provided?',
          value: visa,
          onChanged: (v) => setState(() => visa = v),
        ),
        _SwitchLine(
          label: 'Immediate hiring?',
          value: immediate,
          onChanged: (v) => setState(() => immediate = v),
        ),
        const SizedBox(height: 18),
        PrimaryButton(
          label: saving ? 'Saving...' : 'Continue',
          onPressed: saving ? null : _continue,
        ),
      ],
    );
  }
}

class BusinessVerificationScreen extends StatefulWidget {
  const BusinessVerificationScreen({super.key});

  @override
  State<BusinessVerificationScreen> createState() =>
      _BusinessVerificationScreenState();
}

class _BusinessVerificationScreenState
    extends State<BusinessVerificationScreen> {
  final storage = const KaamStorageRepository();
  final employer = const EmployerRepository();
  String? busyKey;

  Future<void> _upload(
    String key,
    String title, {
    bool publicFile = false,
  }) async {
    setState(() => busyKey = key);
    try {
      final picked = await FilePicker.platform.pickFiles(withData: true);
      final file = picked?.files.single;
      final bytes = file?.bytes;
      if (file == null || bytes == null) return;
      final upload = publicFile
          ? await storage.uploadPublicFile(
              bytes: bytes,
              fileName: file.name,
              folder: key,
            )
          : await storage.uploadPrivateFile(
              bytes: bytes,
              fileName: file.name,
              folder: key,
            );
      final company = await employer.loadMyCompany();
      if (key == 'company-logo') {
        await employer.updateCompanyLogo(upload.publicUrl ?? upload.path);
      } else {
        await storage.recordVerificationDocument(
          documentType: key,
          upload: upload,
          companyId: company?.id,
        );
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$title uploaded: ${upload.displayName}')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not upload $title: $error')),
      );
    } finally {
      if (mounted) setState(() => busyKey = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ScreenScaffold(
      title: 'Verification',
      showBack: true,
      children: [
        const ProgressStepper(current: 2, total: 2),
        const SizedBox(height: 18),
        const Text('Optional business documents',
            style: AppTextStyles.headline),
        const SizedBox(height: 8),
        const Text(
          'You can provide documents for an optional KAAM trust review. This does not affect access to employer tools.',
          style: AppTextStyles.body,
        ),
        const SizedBox(height: 18),
        UploadDocumentCard(
          title: busyKey == 'trade-license'
              ? 'Uploading trade license...'
              : 'Trade license',
          onTap: () => _upload('trade-license', 'Trade license'),
        ),
        const SizedBox(height: 10),
        UploadDocumentCard(
          title: busyKey == 'company-logo'
              ? 'Uploading company logo...'
              : 'Company logo',
          onTap: () =>
              _upload('company-logo', 'Company logo', publicFile: true),
        ),
        const SizedBox(height: 10),
        UploadDocumentCard(
          title: busyKey == 'office-photo'
              ? 'Uploading office photo...'
              : 'Office photo',
          optional: true,
          onTap: () =>
              _upload('office-photo', 'Office photo', publicFile: true),
        ),
        const SizedBox(height: 10),
        UploadDocumentCard(
          title: busyKey == 'authorization-letter'
              ? 'Uploading authorization letter...'
              : 'Authorization letter',
          optional: true,
          onTap: () => _upload('authorization-letter', 'Authorization letter'),
        ),
        const SizedBox(height: 18),
        const AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Verification benefits', style: AppTextStyles.title),
              SizedBox(height: 10),
              _Benefit(label: 'Verified badge'),
              _Benefit(label: 'Higher candidate trust'),
              _Benefit(label: 'Better response rate'),
              _Benefit(label: 'Safer hiring experience'),
            ],
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          'Your documents are reviewed securely by Kaam.',
          style: AppTextStyles.muted,
        ),
        const SizedBox(height: 18),
        PrimaryButton(
          label: 'Return to profile setup',
          onPressed: () => Navigator.of(
            context,
          ).pushNamed(AppRoutes.employerProfileComplete),
        ),
      ],
    );
  }
}

class EmployerRulesScreen extends StatefulWidget {
  const EmployerRulesScreen({super.key});

  @override
  State<EmployerRulesScreen> createState() => _EmployerRulesScreenState();
}

class _EmployerRulesScreenState extends State<EmployerRulesScreen> {
  final checks = <String, bool>{
    'I understand candidate phone/email is hidden before match': true,
    'I will not misuse candidate information': true,
    'I understand chat opens only after candidate accepts': true,
    'I agree to Kaam hiring rules': true,
  };

  @override
  Widget build(BuildContext context) {
    return ScreenScaffold(
      title: 'Privacy Rules',
      showBack: true,
      children: [
        const ProgressStepper(current: 4, total: 4),
        const SizedBox(height: 18),
        const Text('Respect candidate privacy', style: AppTextStyles.headline),
        const SizedBox(height: 16),
        AppCard(
          child: Column(
            children: checks.entries.map((entry) {
              return CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: entry.value,
                onChanged: (value) =>
                    setState(() => checks[entry.key] = value ?? false),
                title: Text(entry.key, style: AppTextStyles.body),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 20),
        PrimaryButton(
          label: 'Complete Setup',
          onPressed: () => Navigator.of(
            context,
          ).pushNamed(AppRoutes.employerProfileComplete),
        ),
      ],
    );
  }
}

class EmployerProfileCompleteScreen extends StatelessWidget {
  const EmployerProfileCompleteScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ScreenScaffold(
      title: 'Profile Ready',
      children: [
        const Icon(
          Icons.check_circle_rounded,
          color: AppColors.success,
          size: 72,
        ),
        const SizedBox(height: 18),
        const Text('Company profile ready', style: AppTextStyles.headline),
        const SizedBox(height: 8),
        const Text(
          'You can now discover candidates and send interest requests.',
          style: AppTextStyles.body,
        ),
        const SizedBox(height: 20),
        const AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              StatusBadge(
                label: 'Verification: Not verified',
                color: AppColors.warning,
              ),
              SizedBox(height: 10),
              Text(
                'Your company dashboard is ready. Verification is an optional KAAM trust status.',
                style: AppTextStyles.body,
              ),
            ],
          ),
        ),
        const SizedBox(height: 22),
        PrimaryButton(
          label: 'Go to Dashboard',
          onPressed: () => Navigator.of(context).pushNamedAndRemoveUntil(
            AppRoutes.employerDashboard,
            (route) => route.isFirst,
          ),
        ),
      ],
    );
  }
}

class _GuidedPickerField extends StatelessWidget {
  const _GuidedPickerField({
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
          return;
        }
        controller.text = value;
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

class _Benefit extends StatelessWidget {
  const _Benefit({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          const Icon(
            Icons.check_circle_rounded,
            color: AppColors.success,
            size: 18,
          ),
          const SizedBox(width: 8),
          Text(label, style: AppTextStyles.body),
        ],
      ),
    );
  }
}
