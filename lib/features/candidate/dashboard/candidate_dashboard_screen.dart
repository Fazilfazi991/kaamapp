import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../core/constants/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/bottom_nav.dart';
import '../../../core/widgets/candidate_widgets.dart';
import '../../../core/widgets/privacy_badge.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/widgets/screen_scaffold.dart';
import '../../../core/widgets/secondary_button.dart';
import '../../../core/widgets/section_header.dart';
import '../../../core/widgets/status_badge.dart';
import '../../supabase_backend/kaam_backend.dart';
import '../../notifications/notification_repository.dart';
import '../documents/document_status_service.dart';
import '../profile/candidate_display_formatters.dart';
import '../profile/candidate_profile_completion.dart';

class CandidateDashboardScreen extends StatefulWidget {
  const CandidateDashboardScreen({super.key});

  @override
  State<CandidateDashboardScreen> createState() =>
      _CandidateDashboardScreenState();
}

class _CandidateDashboardScreenState extends State<CandidateDashboardScreen> {
  final repository = const CandidateProfileRepository();
  final notifications = const KaamNotificationRepository();
  final storage = const KaamStorageRepository();
  late Future<CandidateProfileData> profileFuture =
      repository.loadCurrentProfile();
  late Future<List<VerificationDocumentData>> documentsFuture =
      storage.listMyDocuments();
  late Future<CandidateIdentityDocumentData> identityFuture =
      repository.loadIdentityDocuments();
  late Future<CandidateMembershipData> membershipFuture =
      repository.loadMembership();
  bool activatingTestMembership = false;

  void _reload() {
    setState(() {
      profileFuture = repository.loadCurrentProfile();
      documentsFuture = storage.listMyDocuments();
      identityFuture = repository.loadIdentityDocuments();
      membershipFuture = repository.loadMembership();
    });
  }

  Future<void> _activateTestMembership() async {
    setState(() => activatingTestMembership = true);
    try {
      await repository.activateTestMembership();
      _reload();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Test membership activated.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not activate membership: $error')),
      );
    } finally {
      if (mounted) setState(() => activatingTestMembership = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ScreenScaffold(
      title: 'Kaam',
      bottomNavigationBar: const KaamBottomNav(currentIndex: 0),
      actions: [
        IconButton(
          icon: FutureBuilder<int>(
            future: notifications.unreadCount(),
            builder: (context, snapshot) => Badge(
              isLabelVisible: (snapshot.data ?? 0) > 0,
              label: Text('${snapshot.data ?? 0}'),
              child: const Icon(Icons.notifications_none_rounded),
            ),
          ),
          onPressed: () =>
              Navigator.of(context).pushNamed(AppRoutes.notifications),
        ),
      ],
      children: [
        FutureBuilder<CandidateProfileData>(
          future: profileFuture,
          builder: (context, snapshot) {
            final name = snapshot.data?.fullName;
            return Text(
              name == null || name.isEmpty ? 'Hi' : 'Hi, ${titleCase(name)}',
              style: AppTextStyles.headline,
            );
          },
        ),
        const SizedBox(height: 8),
        const PrivacyBadge(
            label: 'Your contact details are private until an accepted match.'),
        const SizedBox(height: 20),
        FutureBuilder<Object>(
          future: Future.wait([
            profileFuture,
            documentsFuture,
            identityFuture,
            membershipFuture
          ]),
          builder: (context, snapshot) {
            final values = snapshot.data as List<Object?>?;
            final profile = values?[0] as CandidateProfileData? ??
                const CandidateProfileData();
            final documents =
                values?[1] as List<VerificationDocumentData>? ?? const [];
            final identity = values?[2] as CandidateIdentityDocumentData? ??
                const CandidateIdentityDocumentData();
            final membership = values?[3] as CandidateMembershipData? ??
                const CandidateMembershipData();
            final completion = CandidateProfileCompletion.calculate(
              profile,
              documents: documents,
              identity: identity,
            );
            return Column(
              children: [
                _EmployerVisibilityCard(
                  profile: profile,
                  completion: completion,
                  identity: identity,
                  membership: membership,
                  activatingTestMembership: activatingTestMembership,
                  onActivateTestMembership: _activateTestMembership,
                ),
                const SizedBox(height: 16),
                ProfileStrengthCard(
                  value: completion.percentage,
                  helperText: completion.helperText,
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 16),
        FutureBuilder<CandidateIdentityDocumentData>(
          future: identityFuture,
          builder: (context, snapshot) {
            final identity =
                snapshot.data ?? const CandidateIdentityDocumentData();
            return _DocumentsCard(identity: identity);
          },
        ),
        const SizedBox(height: 22),
        const SectionHeader(title: 'Live actions'),
        const SizedBox(height: 12),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 1.15,
          children: [
            QuickActionCard(
              icon: Icons.inbox_outlined,
              label: 'View Requests',
              onTap: () => Navigator.of(context).pushNamed(AppRoutes.requests),
            ),
            QuickActionCard(
              icon: Icons.handshake_outlined,
              label: 'View Matches',
              onTap: () => Navigator.of(context).pushNamed(AppRoutes.matches),
            ),
            QuickActionCard(
              icon: Icons.chat_bubble_outline,
              label: 'Open Chat',
              onTap: () => Navigator.of(context).pushNamed(AppRoutes.chatList),
            ),
            QuickActionCard(
              icon: Icons.edit_document,
              label: 'Edit Profile',
              onTap: () => Navigator.of(context)
                  .pushNamed(AppRoutes.editProfile)
                  .then((_) => _reload()),
            ),
          ],
        ),
      ],
    );
  }
}

class _EmployerVisibilityCard extends StatelessWidget {
  const _EmployerVisibilityCard({
    required this.profile,
    required this.completion,
    required this.identity,
    required this.membership,
    required this.activatingTestMembership,
    required this.onActivateTestMembership,
  });

  final CandidateProfileData profile;
  final CandidateProfileCompletion completion;
  final CandidateIdentityDocumentData identity;
  final CandidateMembershipData membership;
  final bool activatingTestMembership;
  final VoidCallback onActivateTestMembership;

  bool get _profileCompleted => completion.missingFields.isEmpty;

  bool get _documentsVerified =>
      DocumentStatusService.normalized(
        identity.passportStatus,
        uploaded: identity.hasPassport,
        expiry: identity.passportExpiryDate,
      ) ==
      DocumentStatusService.verified;

  CandidateEmployerVisibility get _visibility => CandidateEmployerVisibility(
        profileCompleted: _profileCompleted,
        documentsVerified: _documentsVerified,
        membershipActive: membership.isActive,
        profileVisible: profile.isVisible,
      );

  @override
  Widget build(BuildContext context) {
    final live = _visibility.visibleToEmployers;
    return AppCard(
      borderColor: live ? AppColors.success : AppColors.warning,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                live
                    ? Icons.verified_user_rounded
                    : Icons.visibility_off_rounded,
                color: live ? AppColors.success : AppColors.warning,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      live
                          ? 'Your profile is live'
                          : 'Your profile is not visible to employers yet',
                      style: AppTextStyles.title,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      live
                          ? 'Employers can now discover your profile and send interest requests.'
                          : 'Complete your profile and document verification to appear in employer searches.',
                      style: AppTextStyles.muted,
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (live) ...[
            const SizedBox(height: 12),
            const StatusBadge(
                label: 'Visible to Employers', color: AppColors.success),
          ],
          const SizedBox(height: 16),
          const _ChecklistRow(label: 'Account registered', complete: true),
          _ChecklistRow(
              label: 'Profile completed', complete: _profileCompleted),
          _ChecklistRow(
              label: 'Documents verified', complete: _documentsVerified),
          _ChecklistRow(
              label: 'Chat and contact reveal unlocked',
              complete: membership.isActive),
          const SizedBox(height: 18),
          _PrimaryVisibilityAction(
            profileCompleted: _profileCompleted,
            identity: identity,
            membership: membership,
          ),
          if (kDebugMode && !membership.isActive) ...[
            const SizedBox(height: 10),
            SecondaryButton(
              label: activatingTestMembership
                  ? 'Activating...'
                  : 'Activate Test Membership',
              icon: Icons.science_rounded,
              onPressed:
                  activatingTestMembership ? null : onActivateTestMembership,
            ),
          ],
        ],
      ),
    );
  }
}

class _PrimaryVisibilityAction extends StatelessWidget {
  const _PrimaryVisibilityAction({
    required this.profileCompleted,
    required this.identity,
    required this.membership,
  });

  final bool profileCompleted;
  final CandidateIdentityDocumentData identity;
  final CandidateMembershipData membership;

  @override
  Widget build(BuildContext context) {
    if (!profileCompleted) {
      return PrimaryButton(
        label: 'Complete Profile',
        icon: Icons.edit_document,
        onPressed: () => Navigator.of(context).pushNamed(AppRoutes.editProfile),
      );
    }

    final status = DocumentStatusService.normalized(
      identity.passportStatus,
      uploaded: identity.hasPassport,
      expiry: identity.passportExpiryDate,
    );
    if (status == DocumentStatusService.notUploaded) {
      return PrimaryButton(
        label: 'Upload Documents',
        icon: Icons.upload_file_rounded,
        onPressed: () =>
            Navigator.of(context).pushNamed(AppRoutes.documentsUpload),
      );
    }
    if (status == DocumentStatusService.rejected ||
        status == DocumentStatusService.reuploadRequired) {
      return PrimaryButton(
        label: 'Review and Resubmit',
        icon: Icons.warning_amber_rounded,
        onPressed: () =>
            Navigator.of(context).pushNamed(AppRoutes.documentsUpload),
      );
    }
    if (status != DocumentStatusService.verified) {
      return const SecondaryButton(
        label: 'Verification Pending',
        icon: Icons.pending_actions_rounded,
        onPressed: null,
      );
    }
    return SecondaryButton(
      label: 'Preview My Profile',
      icon: Icons.person_search_rounded,
      onPressed: () => Navigator.of(context).pushNamed(AppRoutes.profile),
    );
  }
}

class _ChecklistRow extends StatelessWidget {
  const _ChecklistRow({required this.label, required this.complete});

  final String label;
  final bool complete;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(
            complete
                ? Icons.check_circle_rounded
                : Icons.radio_button_unchecked,
            color: complete ? AppColors.success : AppColors.mutedText,
            size: 19,
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(label, style: AppTextStyles.body)),
        ],
      ),
    );
  }
}

class _DocumentsCard extends StatelessWidget {
  const _DocumentsCard({required this.identity});

  final CandidateIdentityDocumentData identity;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Documents', style: AppTextStyles.title),
          const SizedBox(height: 12),
          Row(
            children: [
              const Expanded(
                  child: Text('Passport', style: AppTextStyles.body)),
              StatusBadge(
                label: DocumentStatusService.label(
                  identity.passportStatus,
                  uploaded: identity.hasPassport,
                  expiry: identity.passportExpiryDate,
                ),
                color: DocumentStatusService.color(
                  identity.passportStatus,
                  uploaded: identity.hasPassport,
                  expiry: identity.passportExpiryDate,
                ),
              ),
            ],
          ),
          if (identity.passportExpiryDate.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              'Expiry: ${identity.passportExpiryDate} (${DocumentStatusService.validityText(identity.passportExpiryDate)})',
              style: AppTextStyles.muted,
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              const Expanded(child: Text('Visa', style: AppTextStyles.body)),
              StatusBadge(
                label: DocumentStatusService.label(
                  identity.visaStatus,
                  uploaded: identity.hasVisa,
                  expiry: identity.visaExpiryDate,
                ),
                color: DocumentStatusService.color(
                  identity.visaStatus,
                  uploaded: identity.hasVisa,
                  expiry: identity.visaExpiryDate,
                ),
              ),
            ],
          ),
          if (identity.visaExpiryDate.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              'Expiry: ${identity.visaExpiryDate} (${DocumentStatusService.validityText(identity.visaExpiryDate)})',
              style: AppTextStyles.muted,
            ),
          ],
          if (!identity.hasVisa) ...[
            const SizedBox(height: 12),
            TextButton(
              onPressed: () =>
                  Navigator.of(context).pushNamed(AppRoutes.documentsUpload),
              child: const Text('Upload Now'),
            ),
          ],
        ],
      ),
    );
  }
}
