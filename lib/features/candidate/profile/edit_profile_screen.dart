import 'package:flutter/material.dart';

import '../../../core/theme/app_text_styles.dart';
import '../../../core/constants/app_routes.dart';
import '../../../core/widgets/candidate_widgets.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/widgets/private_profile_photo_avatar.dart';
import '../../../core/widgets/screen_scaffold.dart';
import '../../supabase_backend/kaam_backend.dart';
import 'candidate_profile_completion.dart';
import '../onboarding/documents_upload_screen.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final profiles = const CandidateProfileRepository();
  final storage = const KaamStorageRepository();
  late Future<
      ({
        CandidateProfileData profile,
        List<VerificationDocumentData> documents,
        CandidateIdentityDocumentData identity,
        CandidateMembershipData membership,
      })> dataFuture = _load();
  bool refreshing = false;

  Future<
      ({
        CandidateProfileData profile,
        List<VerificationDocumentData> documents,
        CandidateIdentityDocumentData identity,
        CandidateMembershipData membership,
      })> _load() async {
    final profile = await profiles.loadCurrentProfile();
    final documents = await storage.listMyDocuments();
    final identity = await profiles.loadIdentityDocuments();
    final membership = await profiles.loadMembership();
    return (
      profile: profile,
      documents: documents,
      identity: identity,
      membership: membership,
    );
  }

  Future<void> _refresh() async {
    setState(() {
      refreshing = true;
      dataFuture = _load();
    });
    try {
      await dataFuture;
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Profile data refreshed.')));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not refresh profile. Please try again.'),
        ),
      );
    } finally {
      if (mounted) setState(() => refreshing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const sections = [
      (
        Icons.person_outline,
        'Basic Details',
        CandidateProfileSection.basicDetails,
      ),
      (
        Icons.work_outline,
        'Work Preferences',
        CandidateProfileSection.workPreferences,
      ),
      (Icons.psychology_outlined, 'Skills', CandidateProfileSection.skills),
      (
        Icons.history_edu_outlined,
        'Experience',
        CandidateProfileSection.experience,
      ),
      (
        Icons.folder_copy_outlined,
        'Documents',
        CandidateProfileSection.documents,
      ),
      (
        Icons.badge_outlined,
        'Identity Documents',
        CandidateProfileSection.identityDocuments,
      ),
      (Icons.privacy_tip_outlined, 'Privacy', CandidateProfileSection.privacy),
    ];
    return ScreenScaffold(
      title: 'Edit Profile',
      showBack: true,
      children: [
        FutureBuilder<
            ({
              CandidateProfileData profile,
              List<VerificationDocumentData> documents,
              CandidateIdentityDocumentData identity,
              CandidateMembershipData membership,
            })>(
          future: dataFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return const EmptyState(
                icon: Icons.error_outline,
                title: 'Could not load profile strength',
                message: 'Please try again.',
              );
            }
            final data = snapshot.data;
            final completion = CandidateProfileCompletion.calculate(
              data?.profile ?? const CandidateProfileData(),
              documents: data?.documents ?? const [],
              identity: data?.identity ?? const CandidateIdentityDocumentData(),
            );
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: PrivateProfilePhotoAvatar(
                    path: data?.profile.profilePhotoUrl ?? '',
                    initials: profileInitials(data?.profile.fullName ?? ''),
                    size: 76,
                  ),
                ),
                const SizedBox(height: 16),
                ProfileStrengthCard(
                  value: completion.percentage,
                  helperText: completion.helperText,
                ),
                const SizedBox(height: 12),
                _ProfileCompletionSummary(
                  completion: completion,
                  onUploadPassport: () => Navigator.of(context).pushNamed(
                    AppRoutes.documentsUpload,
                    arguments: const CandidateDocumentEntryArgs(
                      mode: CandidateDocumentEntryMode.profile,
                      entrySource: 'profile',
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                CandidateMembershipBadge(
                  membership:
                      data?.membership ?? const CandidateMembershipData(),
                ),
                const SizedBox(height: 16),
                const Text('Editable sections', style: AppTextStyles.title),
                const SizedBox(height: 12),
                for (final section in sections) ...[
                  Builder(
                    builder: (context) {
                      final status = completion.sections[section.$3];
                      return SettingsTile(
                        icon: section.$1,
                        title: section.$2,
                        subtitle: status?.statusLabel,
                        statusIcon: status?.icon,
                        statusColor: status?.color,
                        onTap: () async {
                          final route = switch (section.$3) {
                            CandidateProfileSection.basicDetails =>
                              AppRoutes.editBasicDetails,
                            CandidateProfileSection.workPreferences =>
                              AppRoutes.workPreferences,
                            CandidateProfileSection.skills =>
                              AppRoutes.workPreferences,
                            CandidateProfileSection.experience =>
                              AppRoutes.skillsExperience,
                            CandidateProfileSection.documents =>
                              AppRoutes.profileMedia,
                            CandidateProfileSection.identityDocuments =>
                              AppRoutes.documentsUpload,
                            CandidateProfileSection.privacy =>
                              AppRoutes.privacyVisibility,
                          };
                          final changed = await Navigator.of(context).pushNamed(
                            route,
                            arguments: route == AppRoutes.documentsUpload
                                ? const CandidateDocumentEntryArgs(
                                    mode: CandidateDocumentEntryMode.profile,
                                    entrySource: 'profile',
                                  )
                                : null,
                          );
                          if (changed == true && mounted) _refresh();
                        },
                      );
                    },
                  ),
                  const SizedBox(height: 10),
                ],
              ],
            );
          },
        ),
        const SizedBox(height: 18),
        PrimaryButton(
          label: refreshing ? 'Refreshing...' : 'Reload Saved Data',
          onPressed: refreshing ? null : _refresh,
        ),
      ],
    );
  }
}

class _ProfileCompletionSummary extends StatelessWidget {
  const _ProfileCompletionSummary({
    required this.completion,
    required this.onUploadPassport,
  });

  final CandidateProfileCompletion completion;
  final VoidCallback onUploadPassport;

  @override
  Widget build(BuildContext context) {
    final actions = completion.priorityActions;
    if (actions.isEmpty) {
      return const SizedBox.shrink();
    }
    CandidateProfileAction? passportAction;
    for (final action in actions) {
      if (action.section == CandidateProfileSection.identityDocuments) {
        passportAction = action;
        break;
      }
    }
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Profile Completion', style: AppTextStyles.title),
          const SizedBox(height: 6),
          const Text(
            'Complete the required actions below to finish your profile.',
            style: AppTextStyles.muted,
          ),
          const SizedBox(height: 12),
          for (final action in actions.take(3)) ...[
            Text(action.title, style: AppTextStyles.label),
            if (action.detail.isNotEmpty)
              Text(action.detail, style: AppTextStyles.muted),
            const SizedBox(height: 10),
          ],
          if (passportAction != null)
            PrimaryButton(
                label: 'Upload Passport', onPressed: onUploadPassport),
        ],
      ),
    );
  }
}
