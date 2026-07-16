import '../../core/constants/app_routes.dart';
import '../supabase_backend/kaam_backend.dart';

enum KaamNotificationType {
  employerInterestReceived,
  interestAccepted,
  interestRejected,
  matchCreated,
  newMessage,
  documentPending,
  documentApproved,
  documentRejected,
  documentResubmissionRequested,
  membershipExpiring,
  profileIncomplete,
  profileViewed,
  weeklyActivitySummary,
  candidateAcceptedInterest,
  candidateRejectedInterest,
  companyDocumentApproved,
  companyDocumentRejected,
  companyApproved,
  companyRejected,
  shortlistedCandidateUpdated,
  candidateDocumentSubmitted,
  employerDocumentSubmitted,
  companyReviewSubmitted,
  reportReceived,
}

class KaamNotificationTypes {
  const KaamNotificationTypes._();

  static const supported = {
    'employer_interest_received': KaamNotificationType.employerInterestReceived,
    'interest_accepted': KaamNotificationType.interestAccepted,
    'interest_rejected': KaamNotificationType.interestRejected,
    'match_created': KaamNotificationType.matchCreated,
    'new_message': KaamNotificationType.newMessage,
    'document_pending': KaamNotificationType.documentPending,
    'document_approved': KaamNotificationType.documentApproved,
    'document_rejected': KaamNotificationType.documentRejected,
    'document_resubmission_requested':
        KaamNotificationType.documentResubmissionRequested,
    'membership_expiring': KaamNotificationType.membershipExpiring,
    'profile_incomplete': KaamNotificationType.profileIncomplete,
    'profile_viewed': KaamNotificationType.profileViewed,
    'weekly_activity_summary': KaamNotificationType.weeklyActivitySummary,
    'candidate_accepted_interest':
        KaamNotificationType.candidateAcceptedInterest,
    'candidate_rejected_interest':
        KaamNotificationType.candidateRejectedInterest,
    'company_document_approved': KaamNotificationType.companyDocumentApproved,
    'company_document_rejected': KaamNotificationType.companyDocumentRejected,
    'company_approved': KaamNotificationType.companyApproved,
    'company_rejected': KaamNotificationType.companyRejected,
    'shortlisted_candidate_updated':
        KaamNotificationType.shortlistedCandidateUpdated,
    'candidate_document_submitted':
        KaamNotificationType.candidateDocumentSubmitted,
    'employer_document_submitted':
        KaamNotificationType.employerDocumentSubmitted,
    'company_review_submitted': KaamNotificationType.companyReviewSubmitted,
    'report_received': KaamNotificationType.reportReceived,
  };
}

class KaamNotification {
  const KaamNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.createdAt,
    this.status = 'unread',
    this.actionRoute,
    this.data = const {},
    this.readAt,
  });

  final String id;
  final String type;
  final String title;
  final String body;
  final String status;
  final String? actionRoute;
  final Map<String, dynamic> data;
  final String createdAt;
  final String? readAt;

  bool get isUnread => status == 'unread' && readAt == null;

  factory KaamNotification.fromRow(Map<String, dynamic> row) {
    return KaamNotification(
      id: row['id'] as String? ?? '',
      type: row['type'] as String? ?? '',
      title: row['title'] as String? ?? '',
      body: row['body'] as String? ?? '',
      status: row['status'] as String? ?? 'unread',
      actionRoute: row['action_route'] as String?,
      data: Map<String, dynamic>.from(row['data'] as Map? ?? const {}),
      createdAt: row['created_at'] as String? ?? '',
      readAt: row['read_at'] as String?,
    );
  }
}

class KaamNotificationPreferences {
  const KaamNotificationPreferences({
    this.pushEnabled = true,
    this.inAppEnabled = true,
    this.emailEnabled = false,
    this.whatsappEnabled = false,
    this.newMessagesEnabled = true,
    this.interestsAndMatchesEnabled = true,
    this.documentUpdatesEnabled = true,
    this.accountSecurityEnabled = true,
  });

  final bool pushEnabled;
  final bool inAppEnabled;
  final bool emailEnabled;
  final bool whatsappEnabled;
  final bool newMessagesEnabled;
  final bool interestsAndMatchesEnabled;
  final bool documentUpdatesEnabled;
  final bool accountSecurityEnabled;

  Map<String, dynamic> toRow(String userId) => {
        'user_id': userId,
        'push_enabled': pushEnabled,
        'in_app_enabled': inAppEnabled,
        'email_enabled': emailEnabled,
        'whatsapp_enabled': whatsappEnabled,
        'new_messages_enabled': newMessagesEnabled,
        'interests_and_matches_enabled': interestsAndMatchesEnabled,
        'document_updates_enabled': documentUpdatesEnabled,
        'account_security_enabled': accountSecurityEnabled,
      };

  KaamNotificationPreferences copyWith({
    bool? pushEnabled,
    bool? inAppEnabled,
    bool? emailEnabled,
    bool? whatsappEnabled,
    bool? newMessagesEnabled,
    bool? interestsAndMatchesEnabled,
    bool? documentUpdatesEnabled,
    bool? accountSecurityEnabled,
  }) {
    return KaamNotificationPreferences(
      pushEnabled: pushEnabled ?? this.pushEnabled,
      inAppEnabled: inAppEnabled ?? this.inAppEnabled,
      emailEnabled: emailEnabled ?? this.emailEnabled,
      whatsappEnabled: whatsappEnabled ?? this.whatsappEnabled,
      newMessagesEnabled: newMessagesEnabled ?? this.newMessagesEnabled,
      interestsAndMatchesEnabled:
          interestsAndMatchesEnabled ?? this.interestsAndMatchesEnabled,
      documentUpdatesEnabled:
          documentUpdatesEnabled ?? this.documentUpdatesEnabled,
      accountSecurityEnabled:
          accountSecurityEnabled ?? this.accountSecurityEnabled,
    );
  }

  factory KaamNotificationPreferences.fromRow(Map<String, dynamic>? row) {
    if (row == null) return const KaamNotificationPreferences();
    return KaamNotificationPreferences(
      pushEnabled: row['push_enabled'] as bool? ?? true,
      inAppEnabled: row['in_app_enabled'] as bool? ?? true,
      emailEnabled: row['email_enabled'] as bool? ?? false,
      whatsappEnabled: row['whatsapp_enabled'] as bool? ?? false,
      newMessagesEnabled: row['new_messages_enabled'] as bool? ?? true,
      interestsAndMatchesEnabled:
          row['interests_and_matches_enabled'] as bool? ?? true,
      documentUpdatesEnabled: row['document_updates_enabled'] as bool? ?? true,
      accountSecurityEnabled: row['account_security_enabled'] as bool? ?? true,
    );
  }
}

class KaamNotificationDeepLinks {
  const KaamNotificationDeepLinks._();

  static const candidateFallback = AppRoutes.notifications;
  static const employerFallback = AppRoutes.employerNotifications;

  static String fallbackForRole(KaamRole role) =>
      role == KaamRole.candidate ? candidateFallback : employerFallback;

  static String routeFor({
    required KaamRole role,
    required String type,
    String? actionRoute,
  }) {
    final safeAction = _allowlistedRoute(role, actionRoute);
    if (safeAction != null) return safeAction;

    return switch ((role, type)) {
      (KaamRole.candidate, 'employer_interest_received') => AppRoutes.requests,
      (KaamRole.candidate, 'interest_accepted') => AppRoutes.requests,
      (KaamRole.candidate, 'interest_rejected') => AppRoutes.requests,
      (KaamRole.candidate, 'match_created') => AppRoutes.matches,
      (KaamRole.candidate, 'new_message') => AppRoutes.chatList,
      (KaamRole.candidate, 'document_pending') => AppRoutes.documentsUpload,
      (KaamRole.candidate, 'document_approved') => AppRoutes.documentsUpload,
      (KaamRole.candidate, 'document_rejected') => AppRoutes.documentsUpload,
      (KaamRole.candidate, 'document_resubmission_requested') =>
        AppRoutes.documentsUpload,
      (KaamRole.candidate, 'membership_expiring') => AppRoutes.membershipPlans,
      (KaamRole.candidate, 'profile_incomplete') => AppRoutes.editProfile,
      (KaamRole.candidate, 'profile_viewed') => AppRoutes.profileViews,
      (KaamRole.employer, 'candidate_accepted_interest') =>
        AppRoutes.employerSentRequests,
      (KaamRole.employer, 'candidate_rejected_interest') =>
        AppRoutes.employerSentRequests,
      (KaamRole.employer, 'match_created') => AppRoutes.employerMatches,
      (KaamRole.employer, 'new_message') => AppRoutes.employerChatList,
      (KaamRole.employer, 'company_document_approved') =>
        AppRoutes.employerVerificationStatus,
      (KaamRole.employer, 'company_document_rejected') =>
        AppRoutes.employerVerificationStatus,
      (KaamRole.employer, 'company_approved') =>
        AppRoutes.employerCompanyProfile,
      (KaamRole.employer, 'company_rejected') =>
        AppRoutes.employerCompanyProfile,
      (KaamRole.employer, 'shortlisted_candidate_updated') =>
        AppRoutes.employerSavedCandidates,
      _ => fallbackForRole(role),
    };
  }

  static String? _allowlistedRoute(KaamRole role, String? route) {
    if (route == null || route.trim().isEmpty) return null;
    final trimmed = route.trim();
    if (!trimmed.startsWith('/') || trimmed.startsWith('//')) return null;
    if (trimmed.contains('://')) return null;
    if (role == KaamRole.candidate && _candidateRoutes.contains(trimmed)) {
      return trimmed;
    }
    if (role == KaamRole.employer && _employerRoutes.contains(trimmed)) {
      return trimmed;
    }
    return null;
  }

  static const _candidateRoutes = {
    AppRoutes.notifications,
    AppRoutes.requests,
    AppRoutes.requestDetails,
    AppRoutes.matches,
    AppRoutes.chatList,
    AppRoutes.documentsUpload,
    AppRoutes.membershipPlans,
    AppRoutes.editProfile,
    AppRoutes.profileViews,
  };

  static const _employerRoutes = {
    AppRoutes.employerNotifications,
    AppRoutes.employerSentRequests,
    AppRoutes.employerRequestDetails,
    AppRoutes.employerMatches,
    AppRoutes.employerChatList,
    AppRoutes.employerVerificationStatus,
    AppRoutes.employerCompanyProfile,
    AppRoutes.employerSavedCandidates,
  };
}

class KaamPushPayloadSafety {
  const KaamPushPayloadSafety._();

  static const sensitiveKeys = {
    'passport_number',
    'dob',
    'date_of_birth',
    'phone',
    'email',
    'storage_path',
    'signed_url',
    'otp',
    'access_token',
    'message_body',
  };

  static Map<String, String> sanitize(Map<String, dynamic> payload) {
    final safe = <String, String>{};
    for (final entry in payload.entries) {
      if (sensitiveKeys.contains(entry.key) || entry.value == null) continue;
      safe[entry.key] = entry.value.toString();
    }
    return safe;
  }
}
