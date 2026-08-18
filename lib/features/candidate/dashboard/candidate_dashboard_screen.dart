import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../core/constants/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/bottom_nav.dart';
import '../../../core/widgets/candidate_widgets.dart';
import '../../../core/widgets/private_profile_photo_avatar.dart';
import '../../../core/widgets/privacy_badge.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/widgets/screen_scaffold.dart';
import '../../../core/widgets/secondary_button.dart';
import '../../../core/widgets/section_header.dart';
import '../../../core/widgets/status_badge.dart';
import '../../supabase_backend/kaam_backend.dart';
import '../../notifications/notification_repository.dart';
import '../../notifications/notification_models.dart';
import '../documents/document_status_service.dart';
import '../documents/candidate_document_action_button.dart';
import '../documents/identity_document_ocr_service.dart';
import '../onboarding/documents_upload_screen.dart';
import '../profile/candidate_display_formatters.dart';
import '../profile/candidate_profile_completion.dart';

class CandidateDashboardScreen extends StatefulWidget {
  const CandidateDashboardScreen({super.key});

  @override
  State<CandidateDashboardScreen> createState() =>
      _CandidateDashboardScreenState();
}

class _CandidateDashboardScreenState extends State<CandidateDashboardScreen>
    with WidgetsBindingObserver {
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
  late Future<bool> visibleToEmployersFuture =
      repository.currentCandidateVisibleToEmployers();
  late Future<List<KaamNotification>> documentNotificationsFuture =
      notifications.loadNotifications();
  late Future<int> unreadCountFuture = notifications.unreadCount();
  late Future<List<Object?>> dashboardStatusFuture = Future.wait<Object?>([
    profileFuture,
    documentsFuture,
    identityFuture,
    membershipFuture,
    visibleToEmployersFuture,
  ]);
  late Future<List<Object?>> documentAlertFuture = Future.wait<Object?>([
    identityFuture,
    documentNotificationsFuture,
  ]);
  bool activatingTestMembership = false;
  bool checkedImportantDocumentNotice = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _showImportantDocumentNoticeOnce();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _reload();
    }
  }

  Future<void> _showImportantDocumentNoticeOnce() async {
    if (checkedImportantDocumentNotice) return;
    checkedImportantDocumentNotice = true;
    try {
      final unread = await notifications.loadNotifications(unreadOnly: true);
      final importantMatches = unread.where((item) {
        return {
          'candidate_document_approved',
          'candidate_document_rejected',
          'candidate_document_resubmission_requested',
        }.contains(item.type);
      }).toList();
      final important =
          importantMatches.isEmpty ? null : importantMatches.first;
      if (important == null || !mounted) return;
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(important.title),
          content: Text(important.body),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      await notifications.markRead(important.id);
      _reload();
    } catch (_) {
      // Notification prompts are helpful, but must not block dashboard access.
    }
  }

  void _reload() {
    setState(() {
      profileFuture = repository.loadCurrentProfile();
      documentsFuture = storage.listMyDocuments();
      identityFuture = repository.loadIdentityDocuments();
      membershipFuture = repository.loadMembership();
      visibleToEmployersFuture =
          repository.currentCandidateVisibleToEmployers();
      documentNotificationsFuture = notifications.loadNotifications();
      unreadCountFuture = notifications.unreadCount();
      dashboardStatusFuture = Future.wait<Object?>([
        profileFuture,
        documentsFuture,
        identityFuture,
        membershipFuture,
        visibleToEmployersFuture,
      ]);
      documentAlertFuture = Future.wait<Object?>([
        identityFuture,
        documentNotificationsFuture,
      ]);
    });
  }

  void _reloadNotifications() {
    setState(() {
      documentNotificationsFuture = notifications.loadNotifications();
      unreadCountFuture = notifications.unreadCount();
      documentAlertFuture = Future.wait<Object?>([
        identityFuture,
        documentNotificationsFuture,
      ]);
    });
  }

  void _reloadMembership() {
    setState(() {
      membershipFuture = repository.loadMembership();
      visibleToEmployersFuture =
          repository.currentCandidateVisibleToEmployers();
      dashboardStatusFuture = Future.wait<Object?>([
        profileFuture,
        documentsFuture,
        identityFuture,
        membershipFuture,
        visibleToEmployersFuture,
      ]);
    });
  }

  Future<void> _activateTestMembership() async {
    setState(() => activatingTestMembership = true);
    try {
      await repository.activateTestMembership();
      _reloadMembership();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Test membership activated.')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not activate membership. Please try again.'),
        ),
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
            future: unreadCountFuture,
            builder: (context, snapshot) => Badge(
              isLabelVisible: (snapshot.data ?? 0) > 0,
              label: Text('${snapshot.data ?? 0}'),
              child: const Icon(Icons.notifications_none_rounded),
            ),
          ),
          onPressed: () => Navigator.of(
            context,
          )
              .pushNamed(AppRoutes.notifications)
              .then((_) => _reloadNotifications()),
        ),
        IconButton(icon: const Icon(Icons.refresh_rounded), onPressed: _reload),
      ],
      children: [
        FutureBuilder<CandidateProfileData>(
          future: profileFuture,
          builder: (context, snapshot) {
            final profile = snapshot.data;
            final name = profile?.fullName ?? '';
            return Row(
              children: [
                PrivateProfilePhotoAvatar(
                  path: profile?.profilePhotoUrl ?? '',
                  initials: profileInitials(name),
                  size: 54,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    name.isEmpty ? 'Hi' : 'Hi, ${titleCase(name)}',
                    style: AppTextStyles.headline,
                  ),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 8),
        const PrivacyBadge(
          label: 'Your contact details are private until an accepted match.',
        ),
        const SizedBox(height: 20),
        FutureBuilder<Object>(
          future: dashboardStatusFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return const AppCard(
                child: Text(
                  'We could not refresh your profile status. Please try again.',
                  style: AppTextStyles.body,
                ),
              );
            }
            final values = snapshot.data as List<Object?>?;
            final profile = values?[0] as CandidateProfileData? ??
                const CandidateProfileData();
            final documents =
                values?[1] as List<VerificationDocumentData>? ?? const [];
            final identity = values?[2] as CandidateIdentityDocumentData? ??
                const CandidateIdentityDocumentData();
            final membership = values?[3] as CandidateMembershipData? ??
                const CandidateMembershipData();
            final visibleToEmployers = values?[4] as bool? ?? false;
            final completion = CandidateProfileCompletion.calculate(
              profile,
              documents: documents,
              identity: identity,
            );
            final eligibility =
                CandidateDashboardEligibilityStatus.fromLiveData(
              profile: profile,
              identity: identity,
              membership: membership,
              visibleToEmployersOverride: visibleToEmployers,
            );
            _debugCandidateDashboardStatus(
              identity: identity,
              completion: completion,
              eligibility: eligibility,
            );
            return Column(
              children: [
                _DashboardDocumentActionAlert(identity: identity),
                if (_needsDocumentAction(identity)) const SizedBox(height: 16),
                _EmployerVisibilityCard(
                  eligibility: eligibility,
                  membership: membership,
                  activatingTestMembership: activatingTestMembership,
                  onActivateTestMembership: _activateTestMembership,
                ),
                const SizedBox(height: 16),
                ProfileStrengthCard(
                  value: completion.percentage,
                  helperText: completion.helperText,
                  onImprove: () => Navigator.of(context).pushNamed(
                    AppRoutes.editProfile,
                  ),
                ),
                const SizedBox(height: 12),
                CandidateMembershipBadge(
                  membership: membership,
                  visibleToEmployers: eligibility.visibleToEmployers,
                  eligibilityMessage: eligibility.visibilityReason,
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 16),
        FutureBuilder<List<Object?>>(
          future: documentAlertFuture,
          builder: (context, snapshot) {
            final values = snapshot.data;
            final identity = values?[0] as CandidateIdentityDocumentData? ??
                const CandidateIdentityDocumentData();
            final reviews = values?[1] as List<KaamNotification>? ?? const [];
            return _DocumentsCard(identity: identity, reviews: reviews);
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
              onTap: () => Navigator.of(
                context,
              ).pushNamed(AppRoutes.editProfile).then((_) => _reload()),
            ),
          ],
        ),
      ],
    );
  }
}

bool _needsDocumentAction(CandidateIdentityDocumentData identity) {
  return [identity.passportStatus, identity.visaStatus].any((status) =>
      status == DocumentStatusService.rejected ||
      status == DocumentStatusService.reuploadRequired);
}

class _DashboardDocumentActionAlert extends StatelessWidget {
  const _DashboardDocumentActionAlert({required this.identity});
  final CandidateIdentityDocumentData identity;
  @override
  Widget build(BuildContext context) {
    final passport =
        identity.passportStatus == DocumentStatusService.rejected ||
            identity.passportStatus == DocumentStatusService.reuploadRequired;
    final visa = identity.visaStatus == DocumentStatusService.rejected ||
        identity.visaStatus == DocumentStatusService.reuploadRequired;
    if (!passport && !visa) return const SizedBox.shrink();
    final label = passport ? 'Passport' : 'Visa';
    return AppCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Action required: $label needs attention',
            style: AppTextStyles.title),
        const SizedBox(height: 6),
        Text(
            'Your $label was not approved. Review the reason and upload a corrected document.',
            style: AppTextStyles.body),
        const SizedBox(height: 8),
        PrimaryButton(
            label: 'Review and upload again',
            onPressed: () => Navigator.of(context).pushNamed(
                  AppRoutes.documentsUpload,
                  arguments: const CandidateDocumentEntryArgs.dashboard(),
                )),
      ]),
    );
  }
}

class _EmployerVisibilityCard extends StatelessWidget {
  const _EmployerVisibilityCard({
    required this.eligibility,
    required this.membership,
    required this.activatingTestMembership,
    required this.onActivateTestMembership,
  });

  final CandidateDashboardEligibilityStatus eligibility;
  final CandidateMembershipData membership;
  final bool activatingTestMembership;
  final VoidCallback onActivateTestMembership;

  @override
  Widget build(BuildContext context) {
    final live = eligibility.visibleToEmployers;
    final membershipPresentation =
        CandidateMembershipPresentation.resolve(membership);
    final title = live
        ? 'Your profile is visible to employers'
        : eligibility.actionRequired
            ? 'Action required'
            : eligibility.underReview
                ? 'Your documents are under review'
                : 'Your profile is not visible to employers yet';
    return AppCard(
      borderColor: live
          ? AppColors.success
          : eligibility.actionRequired
              ? AppColors.error
              : AppColors.warning,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                live
                    ? Icons.verified_user_rounded
                    : eligibility.actionRequired
                        ? Icons.warning_amber_rounded
                        : Icons.visibility_off_rounded,
                color: live
                    ? AppColors.success
                    : eligibility.actionRequired
                        ? AppColors.error
                        : AppColors.warning,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: AppTextStyles.title),
                    const SizedBox(height: 6),
                    Text(
                      eligibility.visibilityReason,
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
              label: 'Visible to Employers',
              color: AppColors.success,
            ),
          ],
          const SizedBox(height: 16),
          const _ChecklistRow(label: 'Account registered', complete: true),
          _ChecklistRow(
            label: 'Profile completed',
            complete: eligibility.profileComplete,
          ),
          _ChecklistRow(
            label: 'Documents verified',
            complete: eligibility.documentsVerified,
          ),
          _ChecklistRow(
            label: 'Chat and contact reveal unlocked',
            complete: eligibility.chatUnlocked,
          ),
          const SizedBox(height: 18),
          _PrimaryVisibilityAction(eligibility: eligibility),
          if (kDebugMode &&
              (membershipPresentation.state ==
                      CandidateMembershipState.inactive ||
                  membershipPresentation.state ==
                      CandidateMembershipState.expired)) ...[
            const SizedBox(height: 10),
            SecondaryButton(
              label: activatingTestMembership
                  ? 'Activating...'
                  : membershipPresentation.primaryActionLabel ??
                      'Activate Membership',
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
  const _PrimaryVisibilityAction({required this.eligibility});

  final CandidateDashboardEligibilityStatus eligibility;

  @override
  Widget build(BuildContext context) {
    final route = switch (eligibility.primaryActionSection) {
      CandidateProfileSection.identityDocuments => AppRoutes.documentsUpload,
      CandidateProfileSection.privacy => AppRoutes.privacyVisibility,
      _ => eligibility.visibleToEmployers
          ? AppRoutes.profile
          : AppRoutes.editProfile,
    };
    final icon = switch (eligibility.primaryActionSection) {
      CandidateProfileSection.identityDocuments => Icons.upload_file_rounded,
      CandidateProfileSection.privacy => Icons.privacy_tip_outlined,
      _ => eligibility.visibleToEmployers
          ? Icons.person_search_rounded
          : Icons.edit_document,
    };
    if (eligibility.visibleToEmployers) {
      return SecondaryButton(
        label: eligibility.primaryActionLabel,
        icon: icon,
        onPressed: () => Navigator.of(context).pushNamed(
          route,
          arguments: route == AppRoutes.documentsUpload
              ? const CandidateDocumentEntryArgs.dashboard()
              : null,
        ),
      );
    }
    return PrimaryButton(
      label: eligibility.primaryActionLabel,
      icon: icon,
      onPressed: () => Navigator.of(context).pushNamed(
        route,
        arguments: route == AppRoutes.documentsUpload
            ? const CandidateDocumentEntryArgs.dashboard()
            : null,
      ),
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
  const _DocumentsCard({required this.identity, required this.reviews});

  final CandidateIdentityDocumentData identity;
  final List<KaamNotification> reviews;

  @override
  Widget build(BuildContext context) {
    final passportStatus = DocumentStatusService.normalized(
      identity.passportStatus,
      uploaded: identity.hasPassport,
      expiry: identity.passportExpiryDate,
    );
    final visaStatus = DocumentStatusService.normalized(
      identity.visaStatus,
      uploaded: identity.hasVisa,
      expiry: identity.visaExpiryDate,
    );
    final passportReview = _latestReview(reviews, 'passport');
    final visaReview = _latestReview(reviews, 'visa');
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Documents', style: AppTextStyles.title),
          const SizedBox(height: 12),
          Row(
            children: [
              const Expanded(
                child: Text('Passport', style: AppTextStyles.body),
              ),
              StatusBadge(
                label:
                    DocumentStatusService.label(passportStatus, uploaded: true),
                color:
                    DocumentStatusService.color(passportStatus, uploaded: true),
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
          _DocumentAttention(
            label: 'Passport',
            status: passportStatus,
            reason: _reason(passportReview),
          ),
          if (passportStatus == DocumentStatusService.notUploaded) ...[
            const SizedBox(height: 8),
            CandidateDocumentActionButton(
              label: 'Upload Passport',
              onPressed: () => Navigator.of(context).pushNamed(
                AppRoutes.documentsUpload,
                arguments: const CandidateDocumentEntryArgs.dashboard(
                  documentType: IdentityDocumentType.passport,
                ),
              ),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              const Expanded(child: Text('Visa', style: AppTextStyles.body)),
              StatusBadge(
                label: DocumentStatusService.label(visaStatus, uploaded: true),
                color: DocumentStatusService.color(visaStatus, uploaded: true),
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
          _DocumentAttention(
            label: 'Visa',
            status: visaStatus,
            reason: _reason(visaReview),
          ),
          if (!identity.hasVisa) ...[
            const SizedBox(height: 12),
            CandidateDocumentActionButton(
              label: 'Upload Visa',
              onPressed: () => Navigator.of(context).pushNamed(
                AppRoutes.documentsUpload,
                arguments: const CandidateDocumentEntryArgs.dashboard(
                  documentType: IdentityDocumentType.visa,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  KaamNotification? _latestReview(List<KaamNotification> source, String type) {
    for (final item in source) {
      if ({
            'candidate_document_rejected',
            'candidate_document_resubmission_requested'
          }.contains(item.type) &&
          item.data['documentType']?.toString() == type) {
        return item;
      }
    }
    return null;
  }

  String? _reason(KaamNotification? item) {
    final value = item?.data['publicReason']?.toString().trim() ?? '';
    return value.isEmpty
        ? 'We could not verify this document. Please upload a clear and valid copy.'
        : value;
  }
}

class _DocumentAttention extends StatelessWidget {
  const _DocumentAttention(
      {required this.label, required this.status, required this.reason});
  final String label;
  final String status;
  final String? reason;
  @override
  Widget build(BuildContext context) {
    if (status != DocumentStatusService.rejected &&
        status != DocumentStatusService.reuploadRequired) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Reason: $reason', style: AppTextStyles.muted),
        CandidateDocumentActionButton(
          onPressed: () => Navigator.of(context).pushNamed(
            AppRoutes.documentsUpload,
            arguments: const CandidateDocumentEntryArgs.dashboard(),
          ),
          label: status == DocumentStatusService.rejected
              ? 'Upload Again'
              : 'Replace $label',
        ),
      ]),
    );
  }
}

void _debugCandidateDashboardStatus({
  required CandidateIdentityDocumentData identity,
  required CandidateProfileCompletion completion,
  required CandidateDashboardEligibilityStatus eligibility,
}) {
  if (!kDebugMode) return;
  debugPrint(
    '[CandidateStatus] refresh=resolved '
    'passport=${identity.passportStatus.trim().isEmpty ? 'empty' : identity.passportStatus} '
    'visa=${identity.visaStatus.trim().isEmpty ? 'empty' : identity.visaStatus} '
    'completion=${completion.percentage} '
    'profile_complete=${eligibility.profileComplete} '
    'documents_verified=${eligibility.documentsVerified} '
    'visible=${eligibility.visibleToEmployers} '
    'state=${eligibility.actionRequired ? 'action_required' : eligibility.underReview ? 'under_review' : eligibility.visibleToEmployers ? 'visible' : 'hidden'}',
  );
}
