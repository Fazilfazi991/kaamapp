import 'package:flutter/material.dart';

import '../../../core/constants/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/bottom_nav.dart';
import '../../../core/widgets/candidate_widgets.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/widgets/screen_scaffold.dart';
import '../../../core/widgets/section_header.dart';
import '../../../core/widgets/skill_chip.dart';
import '../../../core/widgets/status_badge.dart';
import '../../supabase_backend/kaam_backend.dart';
import '../documents/document_status_service.dart';
import 'candidate_display_formatters.dart';
import 'candidate_profile_completion.dart';

class CandidateProfileScreen extends StatefulWidget {
  const CandidateProfileScreen({super.key});

  @override
  State<CandidateProfileScreen> createState() => _CandidateProfileScreenState();
}

class _CandidateProfileScreenState extends State<CandidateProfileScreen> {
  final repository = const CandidateProfileRepository();
  final storage = const KaamStorageRepository();
  late Future<CandidateProfileData> profileFuture = repository.loadCurrentProfile();
  late Future<List<VerificationDocumentData>> documentsFuture = storage.listMyDocuments();
  late Future<CandidateIdentityDocumentData> identityFuture =
      repository.loadIdentityDocuments();

  Future<void> _refresh() async {
    setState(() {
      profileFuture = repository.loadCurrentProfile();
      documentsFuture = storage.listMyDocuments();
      identityFuture = repository.loadIdentityDocuments();
    });
    await Future.wait([profileFuture, documentsFuture, identityFuture]);
  }

  @override
  Widget build(BuildContext context) {
    return ScreenScaffold(
      title: 'Profile',
      bottomNavigationBar: const KaamBottomNav(currentIndex: 4),
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh_rounded),
          onPressed: _refresh,
        ),
        IconButton(
          icon: const Icon(Icons.settings_outlined),
          onPressed: () =>
              Navigator.of(context).pushNamed(AppRoutes.accountSettings),
        ),
      ],
      children: [
        FutureBuilder<CandidateProfileData>(
          future: profileFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return EmptyState(
                icon: Icons.error_outline,
                title: 'Could not load profile',
                message: snapshot.error.toString(),
                action: PrimaryButton(label: 'Retry', onPressed: _refresh),
              );
            }
            final profile = snapshot.data ?? const CandidateProfileData();
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Header(profile: profile),
                const SizedBox(height: 12),
                FutureBuilder<Object>(
                  future: Future.wait([documentsFuture, identityFuture]),
                  builder: (context, documentsSnapshot) {
                    final values = documentsSnapshot.data as List<Object?>?;
                    final completion = CandidateProfileCompletion.calculate(
                      profile,
                      documents: values?[0] as List<VerificationDocumentData>? ?? const [],
                      identity: values?[1] as CandidateIdentityDocumentData? ??
                          const CandidateIdentityDocumentData(),
                    );
                    return ProfileStrengthCard(
                      value: completion.percentage,
                      helperText: completion.helperText,
                    );
                  },
                ),
                const SizedBox(height: 12),
                const PrivacyModeCard(),
                const SizedBox(height: 18),
                const SectionHeader(title: 'Overview'),
                const SizedBox(height: 10),
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Expected salary: ${_salary(profile)}',
                          style: AppTextStyles.body),
                      const SizedBox(height: 8),
                      Text('Availability: ${profile.availability.trim().isEmpty ? 'Not set' : profile.availability}',
                          style: AppTextStyles.body),
                      const SizedBox(height: 8),
                      Text('Experience: ${profile.experienceYears ?? 0} years',
                          style: AppTextStyles.body),
                      const SizedBox(height: 8),
                      Text('Documents: ${profile.resumeUrl.isEmpty ? 'No CV uploaded' : 'CV uploaded'}',
                          style: AppTextStyles.body),
                      if (profile.bio.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text('About: ${profile.bio}', style: AppTextStyles.body),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                const SectionHeader(title: 'Skills'),
                const SizedBox(height: 10),
                _Chips(values: profile.skills),
                const SizedBox(height: 18),
                const SectionHeader(title: 'Languages'),
                const SizedBox(height: 10),
                _Chips(values: profile.languages),
                const SizedBox(height: 18),
                const SectionHeader(title: 'Identity Documents'),
                const SizedBox(height: 10),
                FutureBuilder<CandidateIdentityDocumentData>(
                  future: identityFuture,
                  builder: (context, identitySnapshot) {
                    final identity =
                        identitySnapshot.data ?? const CandidateIdentityDocumentData();
                    return _IdentityDocumentsCard(identity: identity);
                  },
                ),
                const SizedBox(height: 24),
                PrimaryButton(
                  label: 'Edit Profile',
                  onPressed: () =>
                      Navigator.of(context).pushNamed(AppRoutes.editProfile),
                ),
              ],
            );
          },
        ),
      ],
    );
  }

  String _salary(CandidateProfileData profile) {
    return salaryText(
      currency: profile.currency,
      min: profile.expectedSalaryMin,
      max: profile.expectedSalaryMax,
    );
  }
}

class _IdentityDocumentsCard extends StatelessWidget {
  const _IdentityDocumentsCard({required this.identity});

  final CandidateIdentityDocumentData identity;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _DocumentLine(
            title: 'Passport',
            uploaded: identity.hasPassport,
            number: identity.passportNumber,
            expiry: identity.passportExpiryDate,
            status: identity.passportStatus,
          ),
          const SizedBox(height: 14),
          _DocumentLine(
            title: 'Visa',
            uploaded: identity.hasVisa,
            number: identity.visaNumber,
            expiry: identity.visaExpiryDate,
            status: identity.visaStatus,
          ),
          const SizedBox(height: 12),
          PrimaryButton(
            label: 'Replace Document',
            onPressed: () => Navigator.of(context).pushNamed(AppRoutes.documentsUpload),
          ),
        ],
      ),
    );
  }
}

class _DocumentLine extends StatelessWidget {
  const _DocumentLine({
    required this.title,
    required this.uploaded,
    required this.number,
    required this.expiry,
    required this.status,
  });

  final String title;
  final bool uploaded;
  final String number;
  final String expiry;
  final String status;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text(title, style: AppTextStyles.body)),
            StatusBadge(
              label: DocumentStatusService.label(status, uploaded: uploaded, expiry: expiry),
              color: DocumentStatusService.color(status, uploaded: uploaded, expiry: expiry),
            ),
          ],
        ),
        if (number.isNotEmpty)
          Text('Number: $number', style: AppTextStyles.muted),
        if (expiry.isNotEmpty)
          Text(
            'Expiry: $expiry (${DocumentStatusService.validityText(expiry)})',
            style: AppTextStyles.muted,
          ),
      ],
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.profile});

  final CandidateProfileData profile;

  @override
  Widget build(BuildContext context) {
    final initials = profile.fullName
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .take(2)
        .map((part) => part[0].toUpperCase())
        .join();
    return AppCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          ClipOval(
            child: Container(
              width: 68,
              height: 68,
              color: AppColors.elevatedCard,
              child: profile.profilePhotoUrl.isEmpty
                  ? _Initials(initials: initials)
                  : Image.network(
                      profile.profilePhotoUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _Initials(initials: initials),
                    ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(profile.fullName.isEmpty ? 'Name not set' : titleCase(profile.fullName),
                    style: AppTextStyles.title),
                const SizedBox(height: 4),
                Text(profile.headline.isEmpty ? 'Job category not set' : titleCase(profile.headline),
                    style: AppTextStyles.body),
                const SizedBox(height: 4),
                Text(profile.currentCity.isEmpty ? 'Location not set' : titleCase(profile.currentCity),
                    style: AppTextStyles.muted),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Initials extends StatelessWidget {
  const _Initials({required this.initials});

  final String initials;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        initials.isEmpty ? 'K' : initials,
        style: AppTextStyles.title.copyWith(color: AppColors.primaryPink),
      ),
    );
  }
}

class _Chips extends StatelessWidget {
  const _Chips({required this.values});

  final List<String> values;

  @override
  Widget build(BuildContext context) {
    if (values.isEmpty) {
      return const AppCard(child: Text('Not set', style: AppTextStyles.muted));
    }
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [for (final value in values) SkillChip(label: value, selected: true)],
    );
  }
}
