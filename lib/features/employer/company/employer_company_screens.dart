import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../../core/constants/app_assets.dart';
import '../../../core/constants/app_routes.dart';
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
import '../../../core/widgets/verified_badge.dart';
import '../../supabase_backend/kaam_backend.dart';
import '../data/employer_dummy_data.dart';
import '../models/employer_models.dart';
import '../widgets/employer_widgets.dart';

class CompanyProfileScreen extends StatefulWidget {
  const CompanyProfileScreen({super.key});

  @override
  State<CompanyProfileScreen> createState() => _CompanyProfileScreenState();
}

class _CompanyProfileScreenState extends State<CompanyProfileScreen> {
  final repository = const EmployerRepository();
  final auth = const KaamAuthRepository();
  late Future<EmployerCompanyData?> companyFuture = repository.loadMyCompany();
  late Future<List<EmployerHiringRequirement>> requirementsFuture =
      repository.hiringRequirements();

  Future<void> _refresh() async {
    setState(() {
      companyFuture = repository.loadMyCompany();
      requirementsFuture = repository.hiringRequirements();
    });
    await Future.wait([companyFuture, requirementsFuture]);
  }

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Are you sure you want to log out?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Logout')),
        ],
      ),
    );
    if (confirmed != true) return;
    await auth.signOut();
    if (!mounted) return;
    Navigator.of(context)
        .pushNamedAndRemoveUntil(AppRoutes.roleSelection, (_) => false);
  }

  @override
  Widget build(BuildContext context) {
    return ScreenScaffold(
      title: 'Company Profile',
      bottomNavigationBar: const EmployerBottomNav(currentIndex: 4),
      actions: [
        IconButton(
            icon: const Icon(Icons.refresh_rounded), onPressed: _refresh),
        Padding(
          padding: const EdgeInsets.only(right: 12),
          child: Image.asset(AppAssets.logo, width: 72, fit: BoxFit.contain),
        ),
      ],
      children: [
        FutureBuilder<EmployerCompanyData?>(
          future: companyFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return EmptyState(
                icon: Icons.error_outline,
                title: 'Could not load company',
                message: snapshot.error.toString(),
                action: PrimaryButton(label: 'Retry', onPressed: _refresh),
              );
            }
            final company = snapshot.data;
            if (company == null) {
              return EmptyState(
                icon: Icons.business_outlined,
                title: 'Company profile not created',
                message: 'Save company details before browsing candidates.',
                action: PrimaryButton(
                  label: 'Create Company Profile',
                  onPressed: () => Navigator.of(context)
                      .pushNamed(AppRoutes.employerCompanyDetails),
                ),
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 8),
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _CompanyLogo(
                            logoUrl: company.logoUrl,
                            initials: _initials(company.companyName),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(_titleCase(company.companyName),
                                    style: AppTextStyles.title),
                                const SizedBox(height: 8),
                                VerifiedBadge(pending: !company.isVerified),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      _InfoLine(
                          label: 'Industry',
                          value: _titleCase(_dash(company.industry))),
                      _InfoLine(
                          label: 'Location',
                          value: _titleCase(_dash(company.location))),
                      _InfoLine(
                          label: 'Company size',
                          value: _dash(company.companySize)),
                      _InfoLine(
                          label: 'Contact person',
                          value: _contactLine(company)),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                const SectionHeader(title: 'About company'),
                const SizedBox(height: 10),
                AppCard(
                    child: Text(
                        company.description.trim().isEmpty
                            ? 'Not set'
                            : company.description.trim(),
                        style: AppTextStyles.body)),
                const SizedBox(height: 18),
                const SectionHeader(title: 'Hiring Requirements'),
                const SizedBox(height: 10),
                _HiringRequirementsPreview(
                  requirementsFuture: requirementsFuture,
                  onRefresh: _refresh,
                ),
                const SizedBox(height: 18),
                const SectionHeader(title: 'Documents status'),
                const SizedBox(height: 10),
                const AppCard(
                    child: StatusBadge(
                        label: 'Documents under review',
                        color: AppColors.warning)),
                const SizedBox(height: 22),
                PrimaryButton(
                  label: 'Edit Company Profile',
                  onPressed: () => Navigator.of(context)
                      .pushNamed(AppRoutes.employerEditCompanyProfile),
                ),
                const SizedBox(height: 10),
                SecondaryButton(
                  label: 'View Verification',
                  onPressed: () => Navigator.of(context)
                      .pushNamed(AppRoutes.employerVerificationStatus),
                ),
                const SizedBox(height: 10),
                SecondaryButton(
                  label: 'Settings',
                  onPressed: () => Navigator.of(context)
                      .pushNamed(AppRoutes.employerSettings),
                ),
                const SizedBox(height: 10),
                SecondaryButton(
                  label: 'Logout',
                  onPressed: _logout,
                ),
              ],
            );
          },
        ),
      ],
    );
  }

  String _dash(String value) => value.trim().isEmpty ? 'Not set' : value.trim();

  String _contactLine(EmployerCompanyData company) {
    final name = _titleCase(company.contactPerson.trim());
    final role = _titleCase(company.contactRole.trim());
    if (name.isEmpty && role.isEmpty) return 'Not set';
    if (role.isEmpty) return name;
    if (name.isEmpty) return role;
    return '$name, $role';
  }

  String _initials(String value) {
    final parts = value
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();
    if (parts.isEmpty) return 'K';
    return parts.take(2).map((part) => part[0].toUpperCase()).join();
  }

  String _titleCase(String value) {
    if (value.isEmpty || value == 'Not set') return value;
    return value
        .split(RegExp(r'\s+'))
        .map((word) => word.isEmpty
            ? word
            : '${word[0].toUpperCase()}${word.substring(1).toLowerCase()}')
        .join(' ');
  }
}

class _InfoLine extends StatelessWidget {
  const _InfoLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text('$label: $value', style: AppTextStyles.body),
    );
  }
}

class _CompanyLogo extends StatelessWidget {
  const _CompanyLogo({required this.logoUrl, required this.initials});

  final String logoUrl;
  final String initials;

  @override
  Widget build(BuildContext context) {
    Widget fallback() => Container(
          width: 60,
          height: 60,
          alignment: Alignment.center,
          decoration: const BoxDecoration(
            color: AppColors.elevatedCard,
            shape: BoxShape.circle,
          ),
          child: Text(initials, style: AppTextStyles.title),
        );

    if (logoUrl.trim().isEmpty) return fallback();

    return ClipOval(
      child: Image.network(
        logoUrl,
        width: 60,
        height: 60,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => fallback(),
      ),
    );
  }
}

class _HiringRequirementsPreview extends StatelessWidget {
  const _HiringRequirementsPreview({
    required this.requirementsFuture,
    required this.onRefresh,
  });

  final Future<List<EmployerHiringRequirement>> requirementsFuture;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<EmployerHiringRequirement>>(
      future: requirementsFuture,
      builder: (context, snapshot) {
        final requirements =
            snapshot.data ?? const <EmployerHiringRequirement>[];
        return AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (snapshot.connectionState == ConnectionState.waiting)
                const LinearProgressIndicator()
              else if (requirements.isEmpty)
                const Text('No hiring requirements added yet.',
                    style: AppTextStyles.body)
              else
                ...requirements.take(3).map(
                      (item) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text(
                          '${item.displayRole}: ${item.openings} openings • ${item.status}',
                          style: AppTextStyles.body,
                        ),
                      ),
                    ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: SecondaryButton(
                      label: 'View All',
                      onPressed: () => Navigator.of(context)
                          .pushNamed(AppRoutes.employerHiringRequirements)
                          .then((_) => onRefresh()),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: PrimaryButton(
                      label: 'Add New',
                      onPressed: () => Navigator.of(context)
                          .pushNamed(AppRoutes.employerAddHiringRequirement)
                          .then((_) => onRefresh()),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class EditCompanyProfileScreen extends StatefulWidget {
  const EditCompanyProfileScreen({super.key});

  @override
  State<EditCompanyProfileScreen> createState() =>
      _EditCompanyProfileScreenState();
}

class _EditCompanyProfileScreenState extends State<EditCompanyProfileScreen> {
  final companyController = TextEditingController();
  final industryController = TextEditingController();
  final locationController = TextEditingController();
  final contactController = TextEditingController();
  final contactRoleController = TextEditingController();
  final descriptionController = TextEditingController();
  final repository = const EmployerRepository();
  final storage = const KaamStorageRepository();
  EmployerCompanyData? current;
  bool loading = true;
  bool saving = false;
  bool uploading = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    companyController.dispose();
    industryController.dispose();
    locationController.dispose();
    contactController.dispose();
    contactRoleController.dispose();
    descriptionController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      current = await repository.loadMyCompany();
      final company = current;
      if (company != null) {
        companyController.text = company.companyName;
        industryController.text = company.industry;
        locationController.text = company.location;
        contactController.text = company.contactPerson;
        contactRoleController.text = company.contactRole;
        descriptionController.text = company.description;
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

  Future<void> _save() async {
    setState(() => saving = true);
    try {
      current = await repository.upsertCompanyProfile(
        companyName: companyController.text,
        industry: industryController.text,
        companySize: current?.companySize ?? '',
        location: locationController.text,
        branch: current?.officeArea ?? '',
        contactName: contactController.text,
        contactRole: contactRoleController.text,
        description: descriptionController.text,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Company profile saved.')),
      );
      Navigator.of(context).pop();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not save company: $error')),
      );
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Future<void> _uploadLogo() async {
    setState(() => uploading = true);
    try {
      final picked = await FilePicker.platform
          .pickFiles(withData: true, type: FileType.image);
      final file = picked?.files.single;
      final bytes = file?.bytes;
      if (file == null || bytes == null) return;
      final upload = await storage.uploadPublicFile(
          bytes: bytes, fileName: file.name, folder: 'company-logo');
      current =
          await repository.updateCompanyLogo(upload.publicUrl ?? upload.path);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Company logo uploaded: ${file.name}')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not upload logo: $error')),
      );
    } finally {
      if (mounted) setState(() => uploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ScreenScaffold(
      title: 'Edit Company Profile',
      showBack: true,
      children: [
        if (loading) const LinearProgressIndicator(),
        if (loading) const SizedBox(height: 12),
        const SectionHeader(title: 'Company details'),
        const SizedBox(height: 10),
        AppTextField(
            controller: companyController,
            label: 'Company name',
            hint: EmployerDummyData.companyName),
        const SizedBox(height: 12),
        AppTextField(
            controller: industryController,
            label: 'Industry',
            hint: EmployerDummyData.industry),
        const SizedBox(height: 12),
        AppTextField(
            controller: locationController,
            label: 'Location',
            hint: EmployerDummyData.location),
        const SizedBox(height: 18),
        const SectionHeader(title: 'Contact person'),
        const SizedBox(height: 10),
        AppTextField(
            controller: contactController,
            label: 'Name',
            hint: EmployerDummyData.contactPerson),
        const SizedBox(height: 12),
        AppTextField(
            controller: contactRoleController,
            label: 'Role',
            hint: EmployerDummyData.contactRole),
        const SizedBox(height: 18),
        _UploadLine(
            title: 'Company logo',
            subtitle:
                current?.logoUrl.isEmpty ?? true ? 'Not uploaded' : 'Uploaded',
            loading: uploading,
            onTap: _uploadLogo),
        const SizedBox(height: 12),
        AppTextField(
            controller: descriptionController,
            label: 'About company',
            hint: 'Tell candidates about your company.',
            maxLines: 4),
        const SizedBox(height: 22),
        PrimaryButton(
            label: saving ? 'Saving...' : 'Save Changes',
            onPressed: saving ? null : _save),
      ],
    );
  }
}

class VerificationStatusScreen extends StatefulWidget {
  const VerificationStatusScreen({super.key});

  @override
  State<VerificationStatusScreen> createState() =>
      _VerificationStatusScreenState();
}

class _VerificationStatusScreenState extends State<VerificationStatusScreen> {
  final employer = const EmployerRepository();
  final storage = const KaamStorageRepository();
  late Future<
      ({
        EmployerCompanyData? company,
        List<VerificationDocumentData> documents
      })> statusFuture = _load();

  Future<
      ({
        EmployerCompanyData? company,
        List<VerificationDocumentData> documents
      })> _load() async {
    final company = await employer.loadMyCompany();
    final documents = await storage.listMyDocuments();
    return (company: company, documents: documents);
  }

  @override
  Widget build(BuildContext context) {
    return ScreenScaffold(
      title: 'Verification Status',
      showBack: true,
      children: [
        FutureBuilder<
            ({
              EmployerCompanyData? company,
              List<VerificationDocumentData> documents
            })>(
          future: statusFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return EmptyState(
                icon: Icons.error_outline,
                title: 'Could not load verification',
                message: snapshot.error.toString(),
                action: PrimaryButton(
                  label: 'Retry',
                  onPressed: () => setState(() => statusFuture = _load()),
                ),
              );
            }
            final company = snapshot.data?.company;
            final documents =
                snapshot.data?.documents ?? const <VerificationDocumentData>[];
            final approved = company?.isVerified ?? false;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Current status', style: AppTextStyles.muted),
                      const SizedBox(height: 8),
                      StatusBadge(
                        label: approved ? 'Approved' : 'Pending Review',
                        color: approved ? AppColors.success : AppColors.warning,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        approved
                            ? 'Your employer profile has been approved.'
                            : 'Your dashboard and candidate search remain available while KAAM reviews your documents.',
                        style: AppTextStyles.body,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                const SectionHeader(title: 'Uploaded documents'),
                const SizedBox(height: 10),
                if (documents.isEmpty)
                  const AppCard(
                      child: Text('No verification documents uploaded yet.',
                          style: AppTextStyles.body))
                else
                  ...documents.map(
                    (document) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: AppCard(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            const Icon(Icons.description_outlined,
                                color: AppColors.primaryPink),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                      document.documentType
                                          .replaceAll('-', ' '),
                                      style: AppTextStyles.label),
                                  Text(document.displayName,
                                      style: AppTextStyles.muted),
                                ],
                              ),
                            ),
                            StatusBadge(
                                label: document.status,
                                color: AppColors.warning),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
        const SizedBox(height: 18),
        const AppCard(
          child: Text(
              'Verification documents are stored privately in kaam-private.',
              style: AppTextStyles.body),
        ),
        const SizedBox(height: 22),
        PrimaryButton(
            label: 'Re-upload Documents',
            onPressed: () => Navigator.of(context)
                .pushNamed(AppRoutes.employerBusinessVerification)),
      ],
    );
  }
}

class TeamMembersScreen extends StatelessWidget {
  const TeamMembersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ScreenScaffold(
      title: 'Team Members',
      showBack: true,
      children: [
        ...EmployerDummyData.teamMembers.map((member) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: TeamMemberCard(member: member),
            )),
        const SizedBox(height: 14),
        const AppTextField(
            label: 'Invite team member by email', hint: 'name@company.com'),
        const SizedBox(height: 12),
        const Text(
            'Team invitations are disabled until team-member backend policies are enabled.',
            style: AppTextStyles.muted),
      ],
    );
  }
}

class _UploadLine extends StatelessWidget {
  const _UploadLine({
    required this.title,
    required this.subtitle,
    required this.loading,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final bool loading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: loading ? null : onTap,
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          const Icon(Icons.upload_file_rounded, color: AppColors.primaryPink),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTextStyles.label),
                const SizedBox(height: 4),
                Text(subtitle, style: AppTextStyles.muted),
              ],
            ),
          ),
          if (loading)
            const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2))
          else
            const Icon(Icons.add_circle_outline_rounded,
                color: AppColors.secondaryText),
        ],
      ),
    );
  }
}
