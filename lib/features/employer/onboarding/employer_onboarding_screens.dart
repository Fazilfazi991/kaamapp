import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';

import '../../../core/constants/app_routes.dart';
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

class EmployerOnboardingOverviewScreen extends StatelessWidget {
  const EmployerOnboardingOverviewScreen({super.key});

  @override
  Widget build(BuildContext context) {
    const steps = [
      'Company Details',
      'Verification Documents',
      'Ready / Pending Review'
    ];
    return ScreenScaffold(
      title: 'Setup',
      showBack: true,
      children: [
        const Text('Set up your company profile',
            style: AppTextStyles.headline),
        const SizedBox(height: 10),
        const Text(
          'Verified companies get better candidate trust and higher response rates.',
          style: AppTextStyles.body,
        ),
        const SizedBox(height: 22),
        ...steps.map((step) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: AppCard(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle_outline_rounded,
                        color: AppColors.primaryPink),
                    const SizedBox(width: 12),
                    Expanded(child: Text(step, style: AppTextStyles.label)),
                  ],
                ),
              ),
            )),
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
  final industryController = TextEditingController();
  final companySizeController = TextEditingController();
  final locationController = TextEditingController();
  final branchController = TextEditingController();
  final contactNameController = TextEditingController();
  final contactRoleController = TextEditingController();
  final descriptionController = TextEditingController();
  final repository = const EmployerRepository();
  bool saving = false;
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    companyNameController.dispose();
    industryController.dispose();
    companySizeController.dispose();
    locationController.dispose();
    branchController.dispose();
    contactNameController.dispose();
    contactRoleController.dispose();
    descriptionController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final company = await repository.loadMyCompany();
      if (!mounted || company == null) return;
      companyNameController.text = company.companyName;
      industryController.text = company.industry;
      companySizeController.text = company.companySize;
      locationController.text = company.location;
      branchController.text = company.officeArea;
      contactNameController.text = company.contactPerson;
      contactRoleController.text = company.contactRole;
      descriptionController.text = company.description;
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

  Future<void> _continue() async {
    setState(() => saving = true);
    try {
      await repository.upsertCompanyProfile(
        companyName: companyNameController.text,
        industry: industryController.text,
        companySize: companySizeController.text,
        location: locationController.text,
        branch: branchController.text,
        contactName: contactNameController.text,
        contactRole: contactRoleController.text,
        description: descriptionController.text,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Company profile saved.')),
      );
      Navigator.of(context).pushNamed(AppRoutes.employerBusinessVerification);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text(KaamSafeErrorMessages.employerCompanySaveMessage(error)),
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
            hint: EmployerDummyData.companyName),
        const SizedBox(height: 12),
        AppTextField(
            controller: industryController,
            label: 'Industry',
            hint: 'Facilities, Hospitality, Retail'),
        const SizedBox(height: 12),
        AppTextField(
            controller: companySizeController,
            label: 'Company size',
            hint: '51-200 employees'),
        const SizedBox(height: 12),
        AppTextField(
            controller: locationController,
            label: 'Location',
            hint: 'Dubai, Sharjah, Abu Dhabi, Ajman'),
        const SizedBox(height: 12),
        AppTextField(
            controller: branchController,
            label: 'Office area / branch',
            hint: 'Al Quoz, Dubai'),
        const SizedBox(height: 12),
        AppTextField(
            controller: contactNameController,
            label: 'Contact person name',
            hint: 'Nadia Rahman'),
        const SizedBox(height: 12),
        AppTextField(
            controller: contactRoleController,
            label: 'Contact person role',
            hint: 'HR Manager'),
        const SizedBox(height: 12),
        AppTextField(
            controller: descriptionController,
            label: 'Company description',
            hint: 'Tell candidates about your company.',
            maxLines: 4),
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
      Navigator.of(context).pushNamed(AppRoutes.employerBusinessVerification);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text(KaamSafeErrorMessages.employerCompanySaveMessage(error)),
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
        const Text('What roles are you hiring for?',
            style: AppTextStyles.headline),
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
            options: salaryOptions),
        const SizedBox(height: 12),
        _GuidedPickerField(
            controller: locationController,
            label: 'Work location',
            options: locationOptions),
        const SizedBox(height: 12),
        _GuidedPickerField(
            controller: hoursController,
            label: 'Working hours',
            options: hoursOptions),
        const SizedBox(height: 12),
        _SwitchLine(
            label: 'Accommodation provided?',
            value: accommodation,
            onChanged: (v) => setState(() => accommodation = v)),
        _SwitchLine(
            label: 'Transport provided?',
            value: transport,
            onChanged: (v) => setState(() => transport = v)),
        _SwitchLine(
            label: 'Visa provided?',
            value: visa,
            onChanged: (v) => setState(() => visa = v)),
        _SwitchLine(
            label: 'Immediate hiring?',
            value: immediate,
            onChanged: (v) => setState(() => immediate = v)),
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

  Future<void> _upload(String key, String title,
      {bool publicFile = false}) async {
    setState(() => busyKey = key);
    try {
      final picked = await FilePicker.platform.pickFiles(withData: true);
      final file = picked?.files.single;
      final bytes = file?.bytes;
      if (file == null || bytes == null) return;
      final upload = publicFile
          ? await storage.uploadPublicFile(
              bytes: bytes, fileName: file.name, folder: key)
          : await storage.uploadPrivateFile(
              bytes: bytes, fileName: file.name, folder: key);
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
        const ProgressStepper(current: 2, total: 3),
        const SizedBox(height: 18),
        const Text('Verify your business', style: AppTextStyles.headline),
        const SizedBox(height: 8),
        const Text('Verification helps candidates trust your company.',
            style: AppTextStyles.body),
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
        const Text('Your documents are reviewed securely by Kaam.',
            style: AppTextStyles.muted),
        const SizedBox(height: 18),
        PrimaryButton(
          label: 'Submit Verification',
          onPressed: () => Navigator.of(context)
              .pushNamed(AppRoutes.employerProfileComplete),
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
          onPressed: () => Navigator.of(context)
              .pushNamed(AppRoutes.employerProfileComplete),
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
        const Icon(Icons.check_circle_rounded,
            color: AppColors.success, size: 72),
        const SizedBox(height: 18),
        const Text('Company profile ready', style: AppTextStyles.headline),
        const SizedBox(height: 8),
        const Text(
            'You can now discover candidates and send interest requests.',
            style: AppTextStyles.body),
        const SizedBox(height: 20),
        const AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              StatusBadge(
                  label: 'Verification: Pending Review',
                  color: AppColors.warning),
              SizedBox(height: 10),
              Text(
                  'Your company dashboard is ready while documents are reviewed.',
                  style: AppTextStyles.body),
            ],
          ),
        ),
        const SizedBox(height: 22),
        PrimaryButton(
          label: 'Go to Dashboard',
          onPressed: () => Navigator.of(context).pushNamedAndRemoveUntil(
              AppRoutes.employerDashboard, (route) => route.isFirst),
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
  const _SwitchLine(
      {required this.label, required this.value, required this.onChanged});

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
          const Icon(Icons.check_circle_rounded,
              color: AppColors.success, size: 18),
          const SizedBox(width: 8),
          Text(label, style: AppTextStyles.body),
        ],
      ),
    );
  }
}
