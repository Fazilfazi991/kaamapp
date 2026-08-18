import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/chat/chat_conversation_controller.dart';

import '../../core/supabase/supabase_service.dart';
import '../../core/config/app_config.dart';
import '../../core/storage/private_profile_photo_resolver.dart';
import '../candidate/models/candidate_models.dart';
import '../employer/models/employer_models.dart';
import '../employer/models/employer_interest_state_store.dart';
import '../employer/models/employer_saved_state_store.dart';
import '../employer/models/employer_taxonomy_persistence.dart';
import '../notifications/push_notification_service.dart';

enum KaamRole { candidate, employer }

enum KaamAuthDestination {
  roleSelection,
  blocked,
  candidateOnboarding,
  candidateDashboard,
  employerOnboarding,
  employerDashboard,
}

enum KaamProtectedAccess { allowed, blocked, signedOut, wrongRole }

enum KaamGoogleSignInOutcome {
  success,
  cancelled,
  networkFailure,
  googleSdkFailure,
  invalidToken,
  supabaseExchangeFailure,
  accountResolutionFailure,
}

class KaamProfileStatus {
  const KaamProfileStatus._();

  static const draft = 'draft';
  static const active = 'active';
  static const paused = 'paused';
  static const blocked = 'blocked';

  static const liveEnumValues = {draft, active, paused, blocked};
  static const employerOnboarding = active;
  static const candidateOnboarding = active;

  static bool isLiveEnumValue(String value) => liveEnumValues.contains(value);
}

class KaamSafeErrorMessages {
  const KaamSafeErrorMessages._();

  static const logout = 'We could not log you out. Please try again.';
  static const accountNotFound =
      'No account found with this email. Please create an account first.';
  static const googleSignInCancelled = 'Google sign-in was cancelled.';
  static const googleSignInFailure =
      'We could not sign you in with Google. Please try again.';

  static const employerCompanySave =
      'We could not save your company details. Please try again.';

  static String employerCompanySaveMessage(Object error) {
    _debugSafeError(
      stage: 'employer_company_save',
      error: error,
      safeField: error is PostgrestException && error.code == '22P02'
          ? 'status'
          : null,
    );
    return employerCompanySave;
  }

  static void _debugSafeError({
    required String stage,
    required Object error,
    String? safeField,
  }) {
    if (!kDebugMode) return;
    final code = error is PostgrestException ? error.code : error.runtimeType;
    final field = safeField == null ? '' : ' field=$safeField';
    debugPrint('[Backend] stage=$stage code=$code$field');
  }
}

class KaamAccountStatusPolicy {
  const KaamAccountStatusPolicy._();

  static const blockedMessage =
      'Your Kaam account has been blocked. Please contact support if you believe this is a mistake.';

  static bool isBlocked(String? status) =>
      status?.trim() == KaamProfileStatus.blocked;

  static KaamProtectedAccess protectedAccess({
    required KaamRole? actualRole,
    required String? status,
    required KaamRole expectedRole,
  }) {
    if (actualRole == null) return KaamProtectedAccess.signedOut;
    if (isBlocked(status)) return KaamProtectedAccess.blocked;
    if (actualRole != expectedRole) return KaamProtectedAccess.wrongRole;
    return KaamProtectedAccess.allowed;
  }

  static KaamAuthDestination? blockedDestination(String? status) {
    return isBlocked(status) ? KaamAuthDestination.blocked : null;
  }
}

class CandidateSkillLimits {
  const CandidateSkillLimits._();

  static const maxSkills = 3;

  static String get maxMessage =>
      'You can select a maximum of $maxSkills skills.';

  static bool canAdd({required int selectedCount}) => selectedCount < maxSkills;

  static bool allowsToggle({
    required int selectedCount,
    required bool alreadySelected,
    required bool selecting,
  }) =>
      !selecting || alreadySelected || canAdd(selectedCount: selectedCount);

  static bool isValidCount(int count) => count >= 1 && count <= maxSkills;

  static List<String> normalizeNames(Iterable<String> values) {
    final normalized = <String>[];
    final seen = <String>{};
    for (final value in values) {
      final trimmed = value.trim();
      if (trimmed.isEmpty || !seen.add(trimmed.toLowerCase())) continue;
      normalized.add(trimmed);
      if (normalized.length == maxSkills) break;
    }
    return normalized;
  }
}

class CandidateSkillExperience {
  const CandidateSkillExperience._();

  static const fresher = 'fresher';
  static const lessThanOneYear = 'less_than_1_year';
  static const oneToThreeYears = 'one_to_three_years';
  static const threeToFiveYears = 'three_to_five_years';
  static const fivePlusYears = 'five_plus_years';

  static const labelsByValue = {
    fresher: 'Fresher',
    lessThanOneYear: 'Less than 1 year',
    oneToThreeYears: '1–3 years',
    threeToFiveYears: '3–5 years',
    fivePlusYears: '5+ years',
  };

  static List<String> get labels => labelsByValue.values.toList();

  static String normalize(String? value) {
    final token = (value ?? '')
        .trim()
        .toLowerCase()
        .replaceAll('–', '-')
        .replaceAll('—', '-')
        .replaceAll('_', ' ')
        .replaceAll(RegExp(r'\s+'), ' ');
    return switch (token) {
      'fresher' || 'fresh' || 'no experience' || '0 years' => fresher,
      'less than 1 year' ||
      'less than one year' ||
      'under 1 year' ||
      '<1 year' =>
        lessThanOneYear,
      '1-3 years' ||
      '1 - 3 years' ||
      '1 to 3 years' ||
      '1-2 years' ||
      '1 - 2 years' =>
        oneToThreeYears,
      '3-5 years' || '3 - 5 years' || '3 to 5 years' => threeToFiveYears,
      '5+ years' ||
      '5 plus years' ||
      '6-10 years' ||
      '6 - 10 years' ||
      'more than 10 years' =>
        fivePlusYears,
      _ when labelsByValue.containsKey(token.replaceAll(' ', '_')) =>
        token.replaceAll(' ', '_'),
      _ => '',
    };
  }

  static String labelFor(String? value) =>
      labelsByValue[normalize(value)] ?? '';

  static bool isValid(String? value) => normalize(value).isNotEmpty;

  static Map<String, String> normalizeBySkillId(Map<String, String> values) => {
        for (final entry in values.entries)
          if (entry.key.trim().isNotEmpty && normalize(entry.value).isNotEmpty)
            entry.key.trim(): normalize(entry.value),
      };

  static bool mappingsMatch(
    Map<String, String> expected,
    Map<String, String> actual,
  ) {
    final normalizedExpected = normalizeBySkillId(expected);
    final normalizedActual = normalizeBySkillId(actual);
    return normalizedExpected.length == expected.length &&
        normalizedExpected.length == normalizedActual.length &&
        normalizedExpected.entries.every(
          (entry) => normalizedActual[entry.key] == entry.value,
        );
  }

  static bool allSelectedHaveExperience({
    required int selectedSkillCount,
    required Map<String, String> bySkillId,
  }) =>
      selectedSkillCount > 0 &&
      bySkillId.length == selectedSkillCount &&
      bySkillId.values.every(isValid);

  static int aggregateYears(Iterable<String> values) {
    var maximum = 0;
    for (final value in values) {
      final years = switch (normalize(value)) {
        lessThanOneYear => 1,
        oneToThreeYears => 3,
        threeToFiveYears => 5,
        fivePlusYears => 6,
        _ => 0,
      };
      if (years > maximum) maximum = years;
    }
    return maximum;
  }
}

class KaamAuthRouteResult {
  const KaamAuthRouteResult({required this.destination, required this.message});

  final KaamAuthDestination destination;
  final String message;
}

class KaamGoogleSignInResult {
  const KaamGoogleSignInResult._({required this.outcome, this.route});

  const KaamGoogleSignInResult.success(KaamAuthRouteResult route)
      : this._(outcome: KaamGoogleSignInOutcome.success, route: route);

  const KaamGoogleSignInResult.cancelled()
      : this._(outcome: KaamGoogleSignInOutcome.cancelled);

  const KaamGoogleSignInResult.failure(KaamGoogleSignInOutcome outcome)
      : assert(outcome != KaamGoogleSignInOutcome.success),
        assert(outcome != KaamGoogleSignInOutcome.cancelled),
        outcome = outcome,
        route = null;

  final KaamGoogleSignInOutcome outcome;
  final KaamAuthRouteResult? route;

  bool get isSuccess =>
      outcome == KaamGoogleSignInOutcome.success && route != null;
  bool get isCancelled => outcome == KaamGoogleSignInOutcome.cancelled;
  String get safeMessage => isCancelled
      ? KaamSafeErrorMessages.googleSignInCancelled
      : KaamSafeErrorMessages.googleSignInFailure;
}

class KaamRoleMismatchException implements Exception {
  const KaamRoleMismatchException({
    required this.actualRole,
    required this.requestedRole,
  });

  final KaamRole actualRole;
  final KaamRole requestedRole;

  String get safeMessage => KaamAuthSessionPolicy.roleMismatchMessage(
        actualRole: actualRole,
        requestedRole: requestedRole,
      );

  @override
  String toString() => safeMessage;
}

class KaamAccountNotFoundException implements Exception {
  const KaamAccountNotFoundException();

  String get safeMessage => KaamSafeErrorMessages.accountNotFound;

  @override
  String toString() => safeMessage;
}

class KaamPendingOtpContext {
  const KaamPendingOtpContext({
    required this.normalizedEmail,
    required this.role,
    required this.requestedAt,
    this.freshRegistration = false,
  });

  final String normalizedEmail;
  final KaamRole? role;
  final DateTime requestedAt;
  final bool freshRegistration;
}

class KaamAuthSessionPolicy {
  const KaamAuthSessionPolicy._();

  static bool shouldClearUserScopedState({
    required String? previousUserId,
    required String? nextUserId,
  }) {
    return previousUserId != null &&
        nextUserId != null &&
        previousUserId != nextUserId;
  }

  static bool shouldStartOtpForEnteredEmail({
    required bool hasCurrentSession,
    required String enteredEmail,
    required String? currentSessionEmail,
  }) {
    if (!hasCurrentSession) return true;
    return _normalizeEmail(enteredEmail) !=
        _normalizeEmail(currentSessionEmail);
  }

  static String roleMismatchMessage({
    required KaamRole actualRole,
    required KaamRole requestedRole,
  }) {
    final correctJourney =
        actualRole == KaamRole.candidate ? 'Find Work' : 'Hire Talent';
    final attemptedJourney =
        requestedRole == KaamRole.candidate ? 'Find Work' : 'Hire Talent';
    return 'This account is registered for $correctJourney. Continue with $correctJourney or use another account. You selected $attemptedJourney.';
  }

  static String _normalizeEmail(String? email) =>
      (email ?? '').trim().toLowerCase();
}

class KaamAuthSessionCoordinator {
  const KaamAuthSessionCoordinator._();

  static const _explicitLogoutPreferenceKey = 'kaam.explicit_logout_completed';

  static String? _lastAuthenticatedUserId;
  static bool _explicitLogoutInProgress = false;
  static bool _explicitLogoutCompleted = false;
  static int _sessionEpoch = 0;
  static KaamPendingOtpContext? _pendingOtp;

  static KaamPendingOtpContext? get pendingOtp => _pendingOtp;
  static bool get explicitLogoutInProgress => _explicitLogoutInProgress;
  static bool get explicitLogoutCompleted => _explicitLogoutCompleted;
  static bool get blocksSessionRestore =>
      _explicitLogoutInProgress || _explicitLogoutCompleted;
  static int get sessionEpoch => _sessionEpoch;

  static void markAuthenticatedUser(String? userId) {
    if (KaamAuthSessionPolicy.shouldClearUserScopedState(
      previousUserId: _lastAuthenticatedUserId,
      nextUserId: userId,
    )) {
      clearUserScopedState();
    }
    _lastAuthenticatedUserId = userId;
    if (userId != null) {
      _explicitLogoutInProgress = false;
      _explicitLogoutCompleted = false;
      _persistExplicitLogoutCompleted(false);
    }
  }

  static void setPendingOtp({
    required String email,
    required KaamRole? role,
    DateTime? requestedAt,
  }) {
    _pendingOtp = KaamPendingOtpContext(
      normalizedEmail: email.trim().toLowerCase(),
      role: role,
      requestedAt: requestedAt ?? DateTime.now().toUtc(),
    );
  }

  static void clearPendingOtp() {
    _pendingOtp = null;
  }

  static Future<void> beginExplicitLogout() async {
    _sessionEpoch++;
    _explicitLogoutInProgress = true;
    _explicitLogoutCompleted = false;
    clearUserScopedState();
    await _persistExplicitLogoutCompleted(true);
  }

  static Future<void> finishExplicitLogout() async {
    _sessionEpoch++;
    _lastAuthenticatedUserId = null;
    _explicitLogoutInProgress = false;
    _explicitLogoutCompleted = true;
    clearUserScopedState();
    await _persistExplicitLogoutCompleted(true);
  }

  static Future<void> abandonExplicitLogout() async {
    _explicitLogoutInProgress = false;
    await _persistExplicitLogoutCompleted(_explicitLogoutCompleted);
  }

  static Future<void> restorePersistentLogoutState() async {
    final prefs = await SharedPreferences.getInstance();
    _explicitLogoutCompleted =
        prefs.getBool(_explicitLogoutPreferenceKey) ?? false;
    if (_explicitLogoutCompleted) {
      _lastAuthenticatedUserId = null;
      clearUserScopedState();
    }
  }

  static void clearUserScopedState() {
    clearPendingOtp();
    PrivateProfilePhotoResolver.clear();
  }

  @visibleForTesting
  static void resetForTesting() {
    _lastAuthenticatedUserId = null;
    _explicitLogoutInProgress = false;
    _explicitLogoutCompleted = false;
    _sessionEpoch = 0;
    _pendingOtp = null;
  }

  static Future<void> _persistExplicitLogoutCompleted(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_explicitLogoutPreferenceKey, value);
  }
}

class KaamStoredProfile {
  const KaamStoredProfile({required this.role, required this.status});

  final KaamRole role;
  final String status;
}

class KaamProfileBootstrapResult {
  const KaamProfileBootstrapResult({
    required this.role,
    required this.status,
    required this.candidateProfileExists,
    required this.employerCompanyExists,
  });

  final KaamRole role;
  final String status;
  final bool candidateProfileExists;
  final bool employerCompanyExists;

  factory KaamProfileBootstrapResult.fromRow(Map<String, dynamic> row) {
    return KaamProfileBootstrapResult(
      role: _roleFromName(row['role'] as String? ?? ''),
      status: row['status'] as String? ?? KaamProfileStatus.draft,
      candidateProfileExists: row['candidate_profile_exists'] as bool? ?? false,
      employerCompanyExists: row['employer_company_exists'] as bool? ?? false,
    );
  }
}

class KaamMissingProfileRecovery {
  const KaamMissingProfileRecovery._();

  static const message =
      'Your login is verified, but your KAAM profile setup is incomplete. Choose Find Work or Hire Talent to continue setup.';
}

class CandidatePrivacySettings {
  const CandidatePrivacySettings({
    this.profileVisible = true,
    this.hidePhoneBeforeMatch = true,
    this.hideEmailBeforeMatch = true,
    this.requireApprovalBeforeChat = true,
    this.allowDocumentSharingAfterMatch = true,
  });

  final bool profileVisible;
  final bool hidePhoneBeforeMatch;
  final bool hideEmailBeforeMatch;
  final bool requireApprovalBeforeChat;
  final bool allowDocumentSharingAfterMatch;
}

class CandidateMembershipData {
  const CandidateMembershipData({
    this.id,
    this.planCode = '',
    this.status = 'inactive',
    this.startedAt = '',
    this.expiresAt = '',
    this.paymentProvider = '',
    this.amount,
    this.currency = 'AED',
    this.isTest = false,
    this.loadFailed = false,
  });

  final String? id;
  final String planCode;
  final String status;
  final String startedAt;
  final String expiresAt;
  final String paymentProvider;
  final num? amount;
  final String currency;
  final bool isTest;
  final bool loadFailed;

  bool get isActive => CandidateMembershipPresentation.resolve(this).isActive;

  bool get isExpired =>
      CandidateMembershipPresentation.resolve(this).state ==
      CandidateMembershipState.expired;

  factory CandidateMembershipData.fromRow(Map<String, dynamic>? row) {
    return CandidateMembershipData(
      id: row?['id'] as String?,
      planCode: row?['plan_code'] as String? ?? '',
      status: row?['status'] as String? ?? 'inactive',
      startedAt: row?['started_at'] as String? ?? '',
      expiresAt: row?['expires_at'] as String? ?? '',
      paymentProvider: row?['payment_provider'] as String? ?? '',
      amount: row?['amount'] as num?,
      currency: row?['currency'] as String? ?? 'AED',
      isTest: row?['is_test'] as bool? ?? false,
    );
  }
}

enum CandidateMembershipState {
  inactive,
  activePaid,
  activeTest,
  expired,
  pending,
  unknown,
}

class CandidateMembershipPresentation {
  const CandidateMembershipPresentation({
    required this.state,
    required this.primaryLabel,
    required this.secondaryLabel,
    required this.detailLabel,
    required this.visibilityMessage,
    required this.primaryActionLabel,
  });

  final CandidateMembershipState state;
  final String primaryLabel;
  final String secondaryLabel;
  final String detailLabel;
  final String visibilityMessage;
  final String? primaryActionLabel;

  bool get isActive =>
      state == CandidateMembershipState.activePaid ||
      state == CandidateMembershipState.activeTest;

  bool get isTest => state == CandidateMembershipState.activeTest;

  static CandidateMembershipPresentation resolve(
    CandidateMembershipData membership, {
    DateTime? now,
    bool? visibleToEmployers,
    String? eligibilityMessage,
  }) {
    final current = (now ?? DateTime.now()).toUtc();
    final status = membership.status.trim().toLowerCase();
    final startedAt = DateTime.tryParse(membership.startedAt)?.toUtc();
    final expiresAt = DateTime.tryParse(membership.expiresAt)?.toUtc();

    late final CandidateMembershipState state;
    if (membership.loadFailed) {
      state = CandidateMembershipState.unknown;
    } else if (status == 'expired' ||
        (status == 'active' &&
            expiresAt != null &&
            !expiresAt.isAfter(current))) {
      state = CandidateMembershipState.expired;
    } else if (status == 'active' &&
        startedAt != null &&
        startedAt.isAfter(current)) {
      state = CandidateMembershipState.pending;
    } else if (status == 'active' && expiresAt != null) {
      state = membership.isTest
          ? CandidateMembershipState.activeTest
          : CandidateMembershipState.activePaid;
    } else if (status == 'pending') {
      state = CandidateMembershipState.pending;
    } else if (membership.id == null ||
        const {
          '',
          'inactive',
          'cancelled',
          'canceled',
          'payment_failed',
        }.contains(status)) {
      state = CandidateMembershipState.inactive;
    } else {
      state = CandidateMembershipState.unknown;
    }

    final visibility = _membershipVisibilityMessage(
      state: state,
      visibleToEmployers: visibleToEmployers,
      eligibilityMessage: eligibilityMessage,
    );
    return switch (state) {
      CandidateMembershipState.inactive => CandidateMembershipPresentation(
          state: state,
          primaryLabel: 'Membership inactive',
          secondaryLabel: '',
          detailLabel: '',
          visibilityMessage: visibility,
          primaryActionLabel: 'Activate Membership',
        ),
      CandidateMembershipState.activePaid => CandidateMembershipPresentation(
          state: state,
          primaryLabel: 'Active Member',
          secondaryLabel: '',
          detailLabel: _membershipExpiryLabel(expiresAt),
          visibilityMessage: visibility,
          primaryActionLabel: null,
        ),
      CandidateMembershipState.activeTest => CandidateMembershipPresentation(
          state: state,
          primaryLabel: 'Active Member',
          secondaryLabel: 'Test Membership',
          detailLabel: _membershipExpiryLabel(expiresAt),
          visibilityMessage: visibility,
          primaryActionLabel: null,
        ),
      CandidateMembershipState.expired => CandidateMembershipPresentation(
          state: state,
          primaryLabel: 'Membership expired',
          secondaryLabel: '',
          detailLabel: '',
          visibilityMessage: visibility,
          primaryActionLabel: 'Renew Membership',
        ),
      CandidateMembershipState.pending => CandidateMembershipPresentation(
          state: state,
          primaryLabel: 'Membership pending',
          secondaryLabel: '',
          detailLabel: startedAt == null
              ? 'Activation is being processed'
              : 'Starts ${_membershipDate(startedAt)}',
          visibilityMessage: visibility,
          primaryActionLabel: null,
        ),
      CandidateMembershipState.unknown => CandidateMembershipPresentation(
          state: state,
          primaryLabel: 'Membership status unavailable',
          secondaryLabel: '',
          detailLabel: '',
          visibilityMessage: 'Refresh to check your membership status.',
          primaryActionLabel: 'Retry',
        ),
    };
  }
}

String _membershipVisibilityMessage({
  required CandidateMembershipState state,
  required bool? visibleToEmployers,
  required String? eligibilityMessage,
}) {
  if (visibleToEmployers == true) {
    return state == CandidateMembershipState.activePaid ||
            state == CandidateMembershipState.activeTest
        ? 'Your profile is visible to employers.'
        : 'Your profile is visible to employers. Membership unlocks chat and contact features.';
  }
  final eligibility = eligibilityMessage?.trim() ?? '';
  if (eligibility.isNotEmpty) return eligibility;
  if (state == CandidateMembershipState.activePaid ||
      state == CandidateMembershipState.activeTest) {
    return 'Your membership is active. Complete profile and document requirements to become visible.';
  }
  if (state == CandidateMembershipState.expired) {
    return 'Renew membership to unlock member chat and contact features again.';
  }
  return 'Profile and document eligibility determine employer visibility. Activate membership to unlock chat and contact features.';
}

String _membershipExpiryLabel(DateTime? expiry) =>
    expiry == null ? '' : 'Valid until ${_membershipDate(expiry)}';

String _membershipDate(DateTime date) {
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return '${date.day} ${months[date.month - 1]} ${date.year}';
}

class CandidateEmployerVisibility {
  const CandidateEmployerVisibility({
    required this.profileCompleted,
    required this.documentsVerified,
    required this.membershipActive,
    required this.profileVisible,
    this.accountActive = true,
  });

  final bool profileCompleted;
  final bool documentsVerified;
  final bool membershipActive;
  final bool profileVisible;
  final bool accountActive;

  bool get visibleToEmployers =>
      profileCompleted && documentsVerified && profileVisible && accountActive;
}

class TestMembershipActivationAccess {
  const TestMembershipActivationAccess._();

  static bool isAvailable({required bool debugBuild}) => debugBuild;
}

class CandidateVisaStatus {
  const CandidateVisaStatus._();

  static const employmentVisa = 'employment_visa';
  static const visitVisa = 'visit_visa';
  static const cancelledVisa = 'cancelled_visa';
  static const ownVisa = 'own_visa';
  static const noVisa = 'no_visa';
  static const outsideUae = 'outside_uae';

  static const labelsByValue = <String, String>{
    employmentVisa: 'Employment Visa',
    visitVisa: 'Visit Visa',
    cancelledVisa: 'Cancelled Visa',
    ownVisa: 'Own Visa',
    noVisa: 'No Visa',
    outsideUae: 'Outside UAE',
  };

  static List<String> get labels => labelsByValue.values.toList();

  static String normalize(String? value) {
    final normalized = (value ?? '')
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');
    return switch (normalized) {
      'employment_visa' => employmentVisa,
      'visit_visa' => visitVisa,
      'cancelled_visa' || 'canceled_visa' => cancelledVisa,
      'own_visa' => ownVisa,
      'no_visa' || 'not_applicable' => noVisa,
      'outside_uae' => outsideUae,
      _ => normalized,
    };
  }

  static bool isSupported(String? value) =>
      labelsByValue.containsKey(normalize(value));

  static String labelFor(String? value) {
    final normalized = normalize(value);
    if (normalized.isEmpty) return '';
    return labelsByValue[normalized] ??
        normalized
            .split('_')
            .where((part) => part.isNotEmpty)
            .map(
              (part) => part.length == 1
                  ? part.toUpperCase()
                  : '${part[0].toUpperCase()}${part.substring(1)}',
            )
            .join(' ');
  }
}

class CandidateVisaExpiry {
  const CandidateVisaExpiry._();

  static bool requiresExpiry(String? visaStatus) {
    return switch (CandidateVisaStatus.normalize(visaStatus)) {
      CandidateVisaStatus.employmentVisa ||
      CandidateVisaStatus.visitVisa ||
      CandidateVisaStatus.ownVisa =>
        true,
      _ => false,
    };
  }

  static DateTime? parse(String? value) {
    final trimmed = (value ?? '').trim();
    final match = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(trimmed);
    if (match == null) return null;
    final year = int.tryParse(match.group(1)!);
    final month = int.tryParse(match.group(2)!);
    final day = int.tryParse(match.group(3)!);
    if (year == null || month == null || day == null) return null;
    final parsed = DateTime.utc(year, month, day);
    if (parsed.year != year || parsed.month != month || parsed.day != day) {
      return null;
    }
    return parsed;
  }

  static DateTime dateOnly(DateTime value) =>
      DateTime.utc(value.year, value.month, value.day);

  static DateTime latestAllowed(DateTime today) =>
      DateTime.utc(today.year + 20, 12, 31);

  static String normalizeDate(DateTime value) {
    String twoDigits(int part) => part.toString().padLeft(2, '0');
    return '${value.year.toString().padLeft(4, '0')}-'
        '${twoDigits(value.month)}-${twoDigits(value.day)}';
  }

  static String displayDate(String? value) {
    final parsed = parse(value);
    if (parsed == null) return '';
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${parsed.day} ${months[parsed.month - 1]} ${parsed.year}';
  }

  static String? validationError(
    String? visaStatus,
    String? expiryValue, {
    DateTime? today,
  }) {
    if (!requiresExpiry(visaStatus)) return null;
    final trimmed = (expiryValue ?? '').trim();
    if (trimmed.isEmpty) return 'Select your visa expiry date.';
    final parsed = parse(trimmed);
    if (parsed == null) return 'Select a valid visa expiry date.';
    final currentDate = dateOnly(today ?? DateTime.now());
    if (!parsed.isAfter(currentDate)) {
      return 'This visa has expired. Please update your visa status or expiry date.';
    }
    if (parsed.isAfter(latestAllowed(currentDate))) {
      return 'Select a visa expiry date within the next 20 years.';
    }
    return null;
  }

  static bool isValidForStatus(
    String? visaStatus,
    String? expiryValue, {
    DateTime? today,
  }) =>
      validationError(visaStatus, expiryValue, today: today) == null;
}

class CandidateProfileData {
  const CandidateProfileData({
    this.fullName = '',
    this.phone = '',
    this.email = '',
    this.headline = '',
    this.nationality = '',
    this.currentCountry = '',
    this.currentCity = '',
    this.preferredCountry = '',
    this.preferredCity = '',
    this.jobCategories = const [],
    this.jobCategoryIds = const [],
    this.primarySkillId = '',
    this.skillIds = const [],
    this.skills = const [],
    this.skillExperiences = const {},
    this.languages = const [],
    this.experienceYears,
    this.expectedSalaryMin,
    this.expectedSalaryMax,
    this.currency = 'AED',
    this.availability = '',
    this.visaStatus = '',
    this.visaExpiryDate = '',
    this.profilePhotoUrl = '',
    this.profilePhotoFileName = '',
    this.resumeUrl = '',
    this.resumeFileName = '',
    this.resumeFileSize,
    this.drivingLicenses = const [],
    this.currentEmploymentStatus = '',
    this.currentEmploymentStatusOther = '',
    this.bio = '',
    this.isVisible = true,
    this.hidePhoneBeforeMatch = true,
    this.hideEmailBeforeMatch = true,
    this.requireApprovalBeforeChat = true,
    this.allowDocumentSharingAfterMatch = true,
  });

  final String fullName;
  final String phone;
  final String email;
  final String headline;
  final String nationality;
  final String currentCountry;
  final String currentCity;
  final String preferredCountry;
  final String preferredCity;
  final List<String> jobCategories;
  final List<String> jobCategoryIds;
  final String primarySkillId;
  final List<String> skillIds;
  final List<String> skills;
  final Map<String, String> skillExperiences;
  final List<String> languages;
  final num? experienceYears;
  final int? expectedSalaryMin;
  final int? expectedSalaryMax;
  final String currency;
  final String availability;
  final String visaStatus;
  final String visaExpiryDate;
  final String profilePhotoUrl;
  final String profilePhotoFileName;
  final String resumeUrl;
  final String resumeFileName;
  final int? resumeFileSize;
  final List<String> drivingLicenses;
  final String currentEmploymentStatus;
  final String currentEmploymentStatusOther;
  final String bio;
  final bool isVisible;
  final bool hidePhoneBeforeMatch;
  final bool hideEmailBeforeMatch;
  final bool requireApprovalBeforeChat;
  final bool allowDocumentSharingAfterMatch;

  factory CandidateProfileData.fromRows({
    required Map<String, dynamic>? profile,
    required Map<String, dynamic>? candidate,
    Map<String, String> skillExperiences = const {},
    CandidateJobHierarchy hierarchy = const CandidateJobHierarchy.empty(),
  }) {
    final currentCountry = CandidateLocationOptions.normalizeCountry(
      candidate?['current_country'] as String?,
    );
    final preferredCountry = CandidateLocationOptions.normalizeCountry(
      candidate?['preferred_country'] as String?,
    );
    return CandidateProfileData(
      fullName: profile?['full_name'] as String? ?? '',
      phone: profile?['phone'] as String? ?? '',
      email: profile?['email'] as String? ?? '',
      headline: candidate?['headline'] as String? ?? '',
      nationality: candidate?['nationality'] as String? ?? '',
      currentCountry: currentCountry,
      currentCity: CandidateLocationOptions.normalizeRegionForCountry(
        currentCountry,
        candidate?['current_city'] as String? ?? '',
      ),
      preferredCountry: preferredCountry,
      preferredCity: CandidateLocationOptions.normalizeRegionForCountry(
        preferredCountry,
        candidate?['preferred_city'] as String? ?? '',
      ),
      jobCategories: _stringList(candidate?['job_categories']),
      jobCategoryIds:
          hierarchy.categoryId.isEmpty ? const [] : [hierarchy.categoryId],
      primarySkillId: hierarchy.subcategoryId,
      skillIds: hierarchy.skillIds,
      skills: CandidateSkillLimits.normalizeNames(
        _stringList(candidate?['skills']),
      ),
      skillExperiences:
          CandidateSkillExperience.normalizeBySkillId(skillExperiences),
      languages: _stringList(candidate?['languages']),
      experienceYears: candidate?['experience_years'] as num?,
      expectedSalaryMin: candidate?['expected_salary_min'] as int?,
      expectedSalaryMax: candidate?['expected_salary_max'] as int?,
      currency: candidate?['currency'] as String? ?? 'AED',
      availability: candidate?['availability'] as String? ?? '',
      visaStatus: CandidateVisaStatus.normalize(
        candidate?['visa_status'] as String?,
      ),
      visaExpiryDate: candidate?['visa_expiry_date'] as String? ?? '',
      profilePhotoUrl: candidate?['profile_photo_url'] as String? ?? '',
      profilePhotoFileName:
          candidate?['profile_photo_file_name'] as String? ?? '',
      resumeUrl: candidate?['resume_url'] as String? ?? '',
      resumeFileName: candidate?['resume_file_name'] as String? ?? '',
      resumeFileSize: candidate?['resume_file_size'] as int?,
      drivingLicenses: _drivingLicensesFromRow(candidate),
      currentEmploymentStatus:
          candidate?['current_employment_status'] as String? ?? '',
      currentEmploymentStatusOther:
          candidate?['current_employment_status_other'] as String? ?? '',
      bio: candidate?['bio'] as String? ?? '',
      isVisible: candidate?['is_visible'] as bool? ?? true,
      hidePhoneBeforeMatch:
          candidate?['hide_phone_before_match'] as bool? ?? true,
      hideEmailBeforeMatch:
          candidate?['hide_email_before_match'] as bool? ?? true,
      requireApprovalBeforeChat:
          candidate?['require_approval_before_chat'] as bool? ?? true,
      allowDocumentSharingAfterMatch:
          candidate?['allow_document_sharing_after_match'] as bool? ?? true,
    );
  }
}

List<String> _drivingLicensesFromRow(Map<String, dynamic>? candidate) {
  final values = _stringList(candidate?['driving_licenses']);
  if (values.isNotEmpty) return values;
  final legacy = (candidate?['driving_license'] as String? ?? '').trim();
  if (legacy.isEmpty) return const [];
  return switch (legacy) {
    'UAE' => const ['UAE Driving Licence'],
    'India' => const ['India Driving Licence'],
    'None' => const ['No Driving Licence'],
    _ => [legacy],
  };
}

class SkillCategoryData {
  const SkillCategoryData({
    required this.id,
    required this.name,
    required this.iconName,
  });

  final String id;
  final String name;
  final String iconName;

  factory SkillCategoryData.fromRow(Map<String, dynamic> row) =>
      SkillCategoryData(
        id: row['id'] as String,
        name: row['name'] as String? ?? '',
        iconName: row['icon_name'] as String? ?? '',
      );
}

class SkillData {
  const SkillData({
    required this.id,
    required this.categoryId,
    required this.name,
  });

  final String id;
  final String categoryId;
  final String name;

  factory SkillData.fromRow(Map<String, dynamic> row) => SkillData(
        id: row['id'] as String,
        categoryId: row['category_id'] as String,
        name: row['name'] as String? ?? '',
      );
}

class CandidateSkillData {
  const CandidateSkillData({
    required this.skill,
    required this.category,
    this.isPrimary = false,
    this.experienceRange = '',
    this.skillLevel = '',
    this.uaeExperienceRange = '',
    this.availability = '',
    this.certificateTypes = const [],
    this.otherCertificateName = '',
  });

  final SkillData skill;
  final SkillCategoryData category;
  final bool isPrimary;
  final String experienceRange;
  final String skillLevel;
  final String uaeExperienceRange;
  final String availability;
  final List<String> certificateTypes;
  final String otherCertificateName;
}

class CandidateJobHierarchy {
  const CandidateJobHierarchy({
    required this.categoryId,
    required this.subcategoryId,
    required this.skillIds,
  });

  const CandidateJobHierarchy.empty()
      : categoryId = '',
        subcategoryId = '',
        skillIds = const [];

  final String categoryId;

  /// The primary skill is the product's selected job subcategory/profession.
  final String subcategoryId;
  final List<String> skillIds;

  bool get isComplete =>
      categoryId.isNotEmpty &&
      subcategoryId.isNotEmpty &&
      skillIds.isNotEmpty &&
      skillIds.length <= CandidateSkillLimits.maxSkills &&
      skillIds.contains(subcategoryId) &&
      skillIds.toSet().length == skillIds.length;

  factory CandidateJobHierarchy.fromSelections(
    Iterable<CandidateSkillData> selections,
  ) {
    final values = selections.toList();
    if (values.isEmpty) return const CandidateJobHierarchy.empty();
    final categoryIds = values.map((item) => item.category.id).toSet();
    final primaryIds = values
        .where((item) => item.isPrimary)
        .map((item) => item.skill.id)
        .toList();
    final categoryId = categoryIds.length == 1 ? categoryIds.single : '';
    final skillIds = values
        .where((item) => item.skill.categoryId == categoryId)
        .map((item) => item.skill.id)
        .toSet()
        .toList()
      ..sort();
    return CandidateJobHierarchy(
      categoryId: categoryId,
      subcategoryId: primaryIds.length == 1 ? primaryIds.single : '',
      skillIds: skillIds,
    );
  }

  factory CandidateJobHierarchy.fromSkillRows(
    Iterable<Map<String, dynamic>> rows,
  ) {
    final categoryIds = <String>{};
    final skillIds = <String>{};
    final primaryIds = <String>[];
    for (final row in rows) {
      final skillId = row['skill_id'] as String? ?? '';
      final skill = row['skills'];
      final categoryId = skill is Map
          ? skill['category_id'] as String? ?? ''
          : row['category_id'] as String? ?? '';
      if (skillId.isEmpty || categoryId.isEmpty) continue;
      skillIds.add(skillId);
      categoryIds.add(categoryId);
      if (row['is_primary'] as bool? ?? false) primaryIds.add(skillId);
    }
    final sortedSkillIds = skillIds.toList()..sort();
    return CandidateJobHierarchy(
      categoryId: categoryIds.length == 1 ? categoryIds.single : '',
      subcategoryId: primaryIds.length == 1 ? primaryIds.single : '',
      skillIds: sortedSkillIds,
    );
  }

  bool matches(CandidateJobHierarchy other) =>
      categoryId == other.categoryId &&
      subcategoryId == other.subcategoryId &&
      _sameStringSet(skillIds, other.skillIds);

  static bool profileIsComplete(CandidateProfileData profile) {
    final stable = CandidateJobHierarchy(
      categoryId: profile.jobCategoryIds.length == 1
          ? profile.jobCategoryIds.single
          : '',
      subcategoryId: profile.primarySkillId,
      skillIds: profile.skillIds,
    );
    if (stable.categoryId.isNotEmpty ||
        stable.subcategoryId.isNotEmpty ||
        stable.skillIds.isNotEmpty) {
      return stable.isComplete;
    }
    // Legacy label-only profiles remain readable but incomplete unless all
    // hierarchy labels are present and unambiguous.
    return profile.jobCategories.length == 1 &&
        profile.headline.trim().isNotEmpty &&
        CandidateSkillLimits.isValidCount(profile.skills.length);
  }
}

class CandidateJobHierarchyRestore {
  const CandidateJobHierarchyRestore({
    required this.category,
    required this.subcategoryId,
    required this.skills,
    required this.usedLegacyLabels,
  });

  final SkillCategoryData? category;
  final String? subcategoryId;
  final List<SkillData> skills;
  final bool usedLegacyLabels;

  factory CandidateJobHierarchyRestore.resolve({
    required List<SkillCategoryData> categories,
    required List<SkillData> skills,
    required List<CandidateSkillData> savedSelections,
    List<String> legacyCategoryLabels = const [],
    List<String> legacySkillLabels = const [],
    String legacyPrimaryLabel = '',
  }) {
    final stable = CandidateJobHierarchy.fromSelections(savedSelections);
    SkillCategoryData? category =
        categories.where((item) => item.id == stable.categoryId).firstOrNull;
    var usedLegacy = false;
    if (category == null && legacyCategoryLabels.length == 1) {
      final normalized = _normalizeHierarchyLabel(
        legacyCategoryLabels.single,
      );
      final matches = categories
          .where(
            (item) => _normalizeHierarchyLabel(item.name) == normalized,
          )
          .toList();
      if (matches.length == 1) {
        category = matches.single;
        usedLegacy = true;
      }
    }

    final available = category == null
        ? const <SkillData>[]
        : skills.where((item) => item.categoryId == category!.id).toList();
    final stableIds = stable.skillIds.toSet();
    var selected =
        available.where((item) => stableIds.contains(item.id)).toList();
    if (selected.isEmpty && category != null && legacySkillLabels.isNotEmpty) {
      final normalizedLegacy =
          legacySkillLabels.map(_normalizeHierarchyLabel).toSet();
      selected = available
          .where(
            (item) => normalizedLegacy.contains(
              _normalizeHierarchyLabel(item.name),
            ),
          )
          .take(CandidateSkillLimits.maxSkills)
          .toList();
      usedLegacy = selected.isNotEmpty;
    }

    String? subcategoryId =
        selected.any((item) => item.id == stable.subcategoryId)
            ? stable.subcategoryId
            : null;
    if (subcategoryId == null && legacyPrimaryLabel.trim().isNotEmpty) {
      final normalizedPrimary = _normalizeHierarchyLabel(legacyPrimaryLabel);
      final matches = selected
          .where(
            (item) => _normalizeHierarchyLabel(item.name) == normalizedPrimary,
          )
          .toList();
      if (matches.length == 1) {
        subcategoryId = matches.single.id;
        usedLegacy = true;
      }
    }
    return CandidateJobHierarchyRestore(
      category: category,
      subcategoryId: subcategoryId,
      skills: selected,
      usedLegacyLabels: usedLegacy,
    );
  }
}

class CandidateJobHierarchyChange {
  const CandidateJobHierarchyChange({
    required this.skills,
    required this.subcategoryId,
  });

  final List<SkillData> skills;
  final String? subcategoryId;

  factory CandidateJobHierarchyChange.forCategory({
    required String categoryId,
    required Iterable<SkillData> currentSkills,
    String? currentSubcategoryId,
  }) {
    final compatible = currentSkills
        .where((skill) => skill.categoryId == categoryId)
        .take(CandidateSkillLimits.maxSkills)
        .toList();
    return CandidateJobHierarchyChange(
      skills: compatible,
      subcategoryId: compatible.any((skill) => skill.id == currentSubcategoryId)
          ? currentSubcategoryId
          : null,
    );
  }
}

String _normalizeHierarchyLabel(String value) =>
    value.trim().replaceAll(RegExp(r'\s+'), ' ').toLowerCase();

bool _sameStringSet(Iterable<String> left, Iterable<String> right) {
  final leftSet = left.toSet();
  final rightSet = right.toSet();
  return leftSet.length == rightSet.length && leftSet.containsAll(rightSet);
}

class CandidateLocationOptions {
  const CandidateLocationOptions._();

  static const countries = ['UAE', 'India'];
  static const uaeEmirates = [
    'Abu Dhabi',
    'Dubai',
    'Sharjah',
    'Ajman',
    'Umm Al Quwain',
    'Ras Al Khaimah',
    'Fujairah',
  ];
  static const _uaeAreas = <String, List<String>>{
    'Abu Dhabi': [
      'Abu Dhabi City',
      'Mussafah',
      'Mohammed Bin Zayed City',
      'Khalifa City',
      'Al Ain',
      'Ruwais',
      'ICAD / Industrial City',
      'Yas Island',
      'Saadiyat Island',
    ],
    'Dubai': [
      'Al Barsha',
      'Al Garhoud',
      'Al Jaddaf',
      'Al Karama',
      'Al Nahda',
      'Al Quoz',
      'Al Qusais',
      'Al Rashidiya',
      'Bur Dubai',
      'Business Bay',
      'Deira',
      'DIP / Dubai Investment Park',
      'Dubai Marina',
      'Dubai Silicon Oasis',
      'International City',
      'Jebel Ali',
      'JLT / Jumeirah Lakes Towers',
      'Jumeirah',
      'Muhaisnah',
      'Satwa',
      'Sheikh Zayed Road',
    ],
    'Sharjah': [
      'Al Nahda',
      'Al Majaz',
      'Al Qasimia',
      'Al Taawun',
      'Al Khan',
      'Industrial Area',
      'Muwaileh Commercial',
      'University City',
      'Sharjah Airport Free Zone',
    ],
    'Ajman': [
      'Ajman City Centre',
      'Al Jurf',
      'Al Nuaimiya',
      'Al Rashidiya',
      'Al Rawda',
      'Al Mowaihat',
      'Ajman Industrial Area',
      'Al Zorah',
    ],
    'Umm Al Quwain': [
      'Umm Al Quwain City',
      'Al Salamah',
      'Al Raas',
      'Falaj Al Mualla',
      'UAQ Free Trade Zone',
      'Al Sinniyah Island',
    ],
    'Ras Al Khaimah': [
      'Ras Al Khaimah City',
      'Al Nakheel',
      'Al Dhait',
      'Al Hamra Village',
      'Al Marjan Island',
      'RAK Economic Zone',
      'Al Jazeera Al Hamra',
      'Khuzam',
    ],
    'Fujairah': [
      'Fujairah City',
      'Al Faseel',
      'Al Hail',
      'Dibba Al Fujairah',
      'Fujairah Free Zone',
      'Sakamkam',
      'Murbah',
    ],
  };
  static const indianStates = [
    'Andhra Pradesh',
    'Arunachal Pradesh',
    'Assam',
    'Bihar',
    'Chhattisgarh',
    'Goa',
    'Gujarat',
    'Haryana',
    'Himachal Pradesh',
    'Jharkhand',
    'Karnataka',
    'Kerala',
    'Madhya Pradesh',
    'Maharashtra',
    'Manipur',
    'Meghalaya',
    'Mizoram',
    'Nagaland',
    'Odisha',
    'Punjab',
    'Rajasthan',
    'Sikkim',
    'Tamil Nadu',
    'Telangana',
    'Tripura',
    'Uttar Pradesh',
    'Uttarakhand',
    'West Bengal',
    'Delhi',
    'Jammu and Kashmir',
    'Ladakh',
    'Puducherry',
    'Chandigarh',
    'Dadra and Nagar Haveli and Daman and Diu',
    'Lakshadweep',
    'Andaman and Nicobar Islands',
  ];

  static const _countryAliases = {
    'uae': 'UAE',
    'u.a.e.': 'UAE',
    'united arab emirates': 'UAE',
    'india': 'India',
  };

  static const _regionAliases = {
    'orissa': 'Odisha',
    'pondicherry': 'Puducherry',
    'jammu & kashmir': 'Jammu and Kashmir',
    'jammu and kashmir': 'Jammu and Kashmir',
    'dadra and nagar haveli & daman and diu':
        'Dadra and Nagar Haveli and Daman and Diu',
  };

  static String normalizeCountry(String? country) {
    return _countryAliases[country?.trim().toLowerCase() ?? ''] ?? '';
  }

  static List<String> regionsForCountry(String country) {
    return switch (normalizeCountry(country)) {
      'UAE' => uaeEmirates,
      'India' => indianStates,
      _ => const [],
    };
  }

  static List<String> areasForEmirate(String emirate) {
    final normalized = normalizeRegionForCountry('UAE', emirate);
    return _uaeAreas[normalized] ?? const [];
  }

  static bool isValidAreaForEmirate(String emirate, String area) {
    final normalizedArea = area.trim().toLowerCase();
    return areasForEmirate(
      emirate,
    ).any((option) => option.toLowerCase() == normalizedArea);
  }

  static String normalizeRegionForCountry(String country, String region) {
    final trimmed = region.trim();
    if (trimmed.isEmpty) return '';
    final normalized = trimmed.toLowerCase();
    final alias = _regionAliases[normalized];
    for (final option in regionsForCountry(normalizeCountry(country))) {
      if (alias == option) return option;
      if (option.toLowerCase() == normalized) return option;
    }
    return '';
  }

  static bool isComplete(String? country, String? region) {
    final normalizedCountry = normalizeCountry(country);
    return normalizedCountry.isNotEmpty &&
        normalizeRegionForCountry(normalizedCountry, region ?? '').isNotEmpty;
  }

  static String? validationError(String? country, String? region) {
    final normalizedCountry = normalizeCountry(country);
    if (normalizedCountry.isEmpty) return 'Select your country.';
    if (normalizeRegionForCountry(normalizedCountry, region ?? '').isEmpty) {
      return normalizedCountry == 'India'
          ? 'Select your state.'
          : 'Select your emirate.';
    }
    return null;
  }

  static String format(String? country, String? region) {
    final normalizedCountry = normalizeCountry(country);
    final normalizedRegion = normalizeRegionForCountry(
      normalizedCountry,
      region ?? '',
    );
    if (normalizedCountry.isEmpty || normalizedRegion.isEmpty) return '';
    return '$normalizedRegion, $normalizedCountry';
  }
}

class CandidateBasicProfileLocationMapper {
  const CandidateBasicProfileLocationMapper._();

  static Map<String, dynamic> candidateProfileValues({
    required String nationality,
    required String currentCountry,
    required String currentLocation,
    required String preferredCountry,
    required String preferredLocation,
  }) {
    final currentCountryValue = _countryOrEmpty(currentCountry);
    final preferredCountryValue = _countryOrEmpty(preferredCountry);
    final currentCityValue = CandidateLocationOptions.normalizeRegionForCountry(
      currentCountryValue,
      currentLocation,
    );
    final preferredCityValue =
        CandidateLocationOptions.normalizeRegionForCountry(
      preferredCountryValue,
      preferredLocation,
    );
    return {
      'nationality': _nullable(nationality),
      'current_country': _nullable(currentCountryValue),
      'current_city': _nullable(currentCityValue),
      'preferred_country': _nullable(preferredCountryValue),
      'preferred_city': _nullable(preferredCityValue),
    };
  }

  static String _countryOrEmpty(String country) {
    return CandidateLocationOptions.normalizeCountry(country);
  }
}

class EmployerCompanyData {
  const EmployerCompanyData({
    this.id,
    this.companyName = '',
    this.contactPerson = '',
    this.contactRole = '',
    this.industry = '',
    this.companySize = '',
    this.location = '',
    this.officeArea = '',
    this.hiringNeeds = const [],
    this.description = '',
    this.logoUrl = '',
    this.isVerified = false,
    this.industryId,
    this.companySizeCode,
    this.contactRoleCode,
    this.contactRoleOther,
    this.companyEmirate,
    this.companyArea,
    this.branchName,
  });

  final String? id;
  final String companyName;
  final String contactPerson;
  final String contactRole;
  final String industry;
  final String companySize;
  final String location;
  final String officeArea;
  final List<String> hiringNeeds;
  final String description;
  final String logoUrl;
  final bool isVerified;
  final String? industryId,
      companySizeCode,
      contactRoleCode,
      contactRoleOther,
      companyEmirate,
      companyArea,
      branchName;

  factory EmployerCompanyData.fromRow(Map<String, dynamic>? row) {
    return EmployerCompanyData(
      id: row?['id'] as String?,
      companyName: row?['company_name'] as String? ?? '',
      contactPerson: row?['contact_person'] as String? ?? '',
      contactRole: row?['contact_role'] as String? ?? '',
      industry: row?['industry'] as String? ?? '',
      companySize: row?['company_size'] as String? ?? '',
      location: row?['city'] as String? ?? '',
      officeArea: row?['office_area'] as String? ?? '',
      hiringNeeds: _stringList(row?['hiring_needs']),
      description: row?['description'] as String? ?? '',
      logoUrl: row?['logo_url'] as String? ?? '',
      isVerified: row?['is_verified'] as bool? ?? false,
      industryId: row?['industry_id'] as String?,
      companySizeCode: row?['company_size_code'] as String?,
      contactRoleCode: row?['contact_role_code'] as String?,
      contactRoleOther: row?['contact_role_other'] as String?,
      companyEmirate: row?['company_emirate'] as String?,
      companyArea: row?['company_area'] as String?,
      branchName: row?['branch_name'] as String?,
    );
  }
}

class EmployerCandidateSearchFilters {
  const EmployerCandidateSearchFilters({
    this.query = '',
    this.category = '',
    this.skill = '',
    this.location = '',
    this.experience = '',
    this.visaStatus = '',
    this.availability = '',
    this.nationality = '',
    this.language = '',
    this.categories = const [],
    this.skills = const [],
    this.locations = const [],
    this.experiences = const [],
    this.visaStatuses = const [],
    this.availabilities = const [],
    this.nationalities = const [],
    this.languages = const [],
    this.verifiedOnly = false,
    this.minimumSalary,
    this.maximumSalary,
  });

  final String query;
  final String category;
  final String skill;
  final String location;
  final String experience;
  final String visaStatus;
  final String availability;
  final String nationality;
  final String language;
  final List<String> categories;
  final List<String> skills;
  final List<String> locations;
  final List<String> experiences;
  final List<String> visaStatuses;
  final List<String> availabilities;
  final List<String> nationalities;
  final List<String> languages;
  final bool verifiedOnly;
  final int? minimumSalary;
  final int? maximumSalary;

  List<String> get effectiveCategories =>
      _uniqueFilterValues([...categories, category]);
  List<String> get effectiveSkills => _uniqueFilterValues([...skills, skill]);
  List<String> get effectiveLocations =>
      _uniqueFilterValues([...locations, location]);
  List<String> get effectiveExperiences =>
      _uniqueFilterValues([...experiences, experience]);
  List<String> get effectiveVisaStatuses =>
      _uniqueFilterValues([...visaStatuses, visaStatus]);
  List<String> get effectiveAvailabilities =>
      _uniqueFilterValues([...availabilities, availability]);
  List<String> get effectiveNationalities =>
      _uniqueFilterValues([...nationalities, nationality]);
  List<String> get effectiveLanguages =>
      _uniqueFilterValues([...languages, language]);

  bool get isEmpty =>
      query.trim().isEmpty &&
      effectiveCategories.isEmpty &&
      effectiveSkills.isEmpty &&
      effectiveLocations.isEmpty &&
      effectiveExperiences.isEmpty &&
      effectiveVisaStatuses.isEmpty &&
      effectiveAvailabilities.isEmpty &&
      effectiveNationalities.isEmpty &&
      effectiveLanguages.isEmpty &&
      minimumSalary == null &&
      maximumSalary == null &&
      !verifiedOnly;
}

bool _isAllFilterValue(String value) {
  final normalized = value.trim().toLowerCase();
  return normalized == 'all' || normalized.startsWith('all ');
}

List<String> _uniqueFilterValues(Iterable<String> values) {
  return _uniqueValues(values.where((value) => !_isAllFilterValue(value)));
}

List<String> _uniqueValues(Iterable<String> values) {
  final seen = <String>{};
  final result = <String>[];
  for (final value in values) {
    final trimmed = value.trim();
    final key = trimmed.toLowerCase();
    if (trimmed.isNotEmpty && seen.add(key)) result.add(trimmed);
  }
  return result;
}

class MultiSelectFilterGroup {
  MultiSelectFilterGroup([Iterable<String> initial = const []])
      : selected = _uniqueValues(initial).toSet();

  final Set<String> selected;

  void toggle(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return;
    final existing = selected
        .where((item) => item.trim().toLowerCase() == trimmed.toLowerCase())
        .firstOrNull;
    if (existing == null) {
      selected.add(trimmed);
    } else {
      selected.remove(existing);
    }
  }

  void clear() => selected.clear();
}

class KaamUploadResult {
  const KaamUploadResult({
    required this.bucket,
    required this.path,
    required this.displayName,
    this.publicUrl,
  });

  const KaamUploadResult.privateReference({
    required this.path,
    required this.displayName,
  })  : bucket = 'kaam-private',
        publicUrl = null;

  final String bucket;
  final String path;
  final String displayName;
  final String? publicUrl;
}

class VerificationDocumentData {
  const VerificationDocumentData({
    required this.id,
    required this.documentType,
    required this.bucketId,
    required this.filePath,
    required this.status,
  });

  final String id;
  final String documentType;
  final String bucketId;
  final String filePath;
  final String status;

  String get displayName => filePath.split('/').last;

  factory VerificationDocumentData.fromRow(Map<String, dynamic> row) {
    return VerificationDocumentData(
      id: row['id'] as String? ?? '',
      documentType: row['document_type'] as String? ?? '',
      bucketId: row['bucket_id'] as String? ?? '',
      filePath: row['file_path'] as String? ?? '',
      status: row['status'] as String? ?? 'pending',
    );
  }
}

class CandidateIdentityDocumentData {
  const CandidateIdentityDocumentData({
    this.id,
    this.passportFileUrl = '',
    this.passportBackFileUrl = '',
    this.visaFileUrl = '',
    this.passportNumber = '',
    this.passportIssueDate = '',
    this.passportExpiryDate = '',
    this.countryOfIssue = '',
    this.fullName = '',
    this.nationality = '',
    this.gender = '',
    this.dob = '',
    this.placeOfBirth = '',
    this.visaNumber = '',
    this.visaType = '',
    this.occupation = '',
    this.sponsor = '',
    this.uidNumber = '',
    this.emiratesId = '',
    this.visaIssueDate = '',
    this.visaExpiryDate = '',
    this.passportVerified = false,
    this.visaVerified = false,
    this.ocrCompleted = false,
    this.passportStatus = 'pending_verification',
    this.visaStatus = 'not_uploaded',
    this.passportUploadedAt = '',
    this.visaUploadedAt = '',
    this.passportVerifiedAt = '',
    this.visaVerifiedAt = '',
    this.passportVersion = 0,
    this.visaVersion = 0,
    this.passportIsActive = false,
    this.visaIsActive = false,
    this.passportArchived = false,
    this.visaArchived = false,
    this.passportExpiryNotificationSent = false,
    this.visaExpiryNotificationSent = false,
    this.createdAt = '',
    this.updatedAt = '',
  });

  final String? id;
  final String passportFileUrl;
  final String passportBackFileUrl;
  final String visaFileUrl;
  final String passportNumber;
  final String passportIssueDate;
  final String passportExpiryDate;
  final String countryOfIssue;
  final String fullName;
  final String nationality;
  final String gender;
  final String dob;
  final String placeOfBirth;
  final String visaNumber;
  final String visaType;
  final String occupation;
  final String sponsor;
  final String uidNumber;
  final String emiratesId;
  final String visaIssueDate;
  final String visaExpiryDate;
  final bool passportVerified;
  final bool visaVerified;
  final bool ocrCompleted;
  final String passportStatus;
  final String visaStatus;
  final String passportUploadedAt;
  final String visaUploadedAt;
  final String passportVerifiedAt;
  final String visaVerifiedAt;
  final int passportVersion;
  final int visaVersion;
  final bool passportIsActive;
  final bool visaIsActive;
  final bool passportArchived;
  final bool visaArchived;
  final bool passportExpiryNotificationSent;
  final bool visaExpiryNotificationSent;
  final String createdAt;
  final String updatedAt;

  bool get hasPassportFront => passportFileUrl.trim().isNotEmpty;
  bool get hasPassportBack => passportBackFileUrl.trim().isNotEmpty;
  bool get hasPassport => hasPassportFront && hasPassportBack;
  bool get hasVisa => visaFileUrl.trim().isNotEmpty;

  factory CandidateIdentityDocumentData.fromRow(Map<String, dynamic>? row) {
    return CandidateIdentityDocumentData(
      id: row?['id'] as String?,
      passportFileUrl: row?['passport_file_url'] as String? ?? '',
      passportBackFileUrl: row?['passport_back_file_url'] as String? ?? '',
      visaFileUrl: row?['visa_file_url'] as String? ?? '',
      passportNumber: row?['passport_number'] as String? ?? '',
      passportIssueDate: row?['passport_issue_date'] as String? ?? '',
      passportExpiryDate: row?['passport_expiry_date'] as String? ?? '',
      countryOfIssue: row?['country_of_issue'] as String? ?? '',
      fullName: row?['full_name'] as String? ?? '',
      nationality: row?['nationality'] as String? ?? '',
      gender: row?['gender'] as String? ?? '',
      dob: row?['dob'] as String? ?? '',
      placeOfBirth: row?['place_of_birth'] as String? ?? '',
      visaNumber: row?['visa_number'] as String? ?? '',
      visaType: row?['visa_type'] as String? ?? '',
      occupation: row?['occupation'] as String? ?? '',
      sponsor: row?['sponsor'] as String? ?? '',
      uidNumber: row?['uid_number'] as String? ?? '',
      emiratesId: row?['emirates_id'] as String? ?? '',
      visaIssueDate: row?['visa_issue_date'] as String? ?? '',
      visaExpiryDate: row?['visa_expiry_date'] as String? ?? '',
      passportVerified: row?['passport_verified'] as bool? ?? false,
      visaVerified: row?['visa_verified'] as bool? ?? false,
      ocrCompleted: row?['ocr_completed'] as bool? ?? false,
      passportStatus:
          row?['passport_status'] as String? ?? 'pending_verification',
      visaStatus: row?['visa_status'] as String? ?? 'not_uploaded',
      passportUploadedAt: row?['passport_uploaded_at'] as String? ?? '',
      visaUploadedAt: row?['visa_uploaded_at'] as String? ?? '',
      passportVerifiedAt: row?['passport_verified_at'] as String? ?? '',
      visaVerifiedAt: row?['visa_verified_at'] as String? ?? '',
      passportVersion: row?['passport_version'] as int? ?? 0,
      visaVersion: row?['visa_version'] as int? ?? 0,
      passportIsActive: row?['passport_is_active'] as bool? ?? false,
      visaIsActive: row?['visa_is_active'] as bool? ?? false,
      passportArchived: row?['passport_archived'] as bool? ?? false,
      visaArchived: row?['visa_archived'] as bool? ?? false,
      passportExpiryNotificationSent:
          row?['passport_expiry_notification_sent'] as bool? ?? false,
      visaExpiryNotificationSent:
          row?['visa_expiry_notification_sent'] as bool? ?? false,
      createdAt: row?['created_at'] as String? ?? '',
      updatedAt: row?['updated_at'] as String? ?? '',
    );
  }
}

class CandidateDocumentVersionData {
  const CandidateDocumentVersionData({
    required this.id,
    required this.documentType,
    required this.filePath,
    this.filePaths = const {},
    required this.versionNumber,
    required this.status,
    required this.isActive,
    required this.createdAt,
  });

  final String id;
  final String documentType;
  final String filePath;
  final Map<String, String> filePaths;
  final int versionNumber;
  final String status;
  final bool isActive;
  final String createdAt;

  String get displayName => filePath.split('/').last;

  factory CandidateDocumentVersionData.fromRow(Map<String, dynamic> row) {
    return CandidateDocumentVersionData(
      id: row['id'] as String? ?? '',
      documentType: row['document_type'] as String? ?? '',
      filePath: row['file_path'] as String? ?? '',
      filePaths: _stringMap(row['file_paths']),
      versionNumber: row['version_number'] as int? ?? 1,
      status: row['status'] as String? ?? 'pending_verification',
      isActive: row['is_active'] as bool? ?? false,
      createdAt: row['created_at'] as String? ?? '',
    );
  }
}

Map<String, String> _stringMap(dynamic value) {
  if (value is! Map) return const {};
  return value.map((key, value) => MapEntry(key.toString(), value.toString()));
}

class CandidateDocumentNotificationData {
  const CandidateDocumentNotificationData({
    required this.id,
    required this.title,
    required this.body,
    required this.notificationType,
    required this.createdAt,
    this.scheduledFor = '',
    this.isRead = false,
  });

  final String id;
  final String title;
  final String body;
  final String notificationType;
  final String createdAt;
  final String scheduledFor;
  final bool isRead;

  factory CandidateDocumentNotificationData.fromRow(Map<String, dynamic> row) {
    return CandidateDocumentNotificationData(
      id: row['id'] as String? ?? '',
      title: row['title'] as String? ?? '',
      body: row['body'] as String? ?? '',
      notificationType: row['notification_type'] as String? ?? '',
      createdAt: row['created_at'] as String? ?? '',
      scheduledFor: row['scheduled_for'] as String? ?? '',
      isRead: row['is_read'] as bool? ?? false,
    );
  }
}

class KaamAuthRepository {
  const KaamAuthRepository();

  SupabaseClient get _client => _requireClient();

  User? get currentUser {
    if (KaamAuthSessionCoordinator.blocksSessionRestore) return null;
    return SupabaseService.maybeClient?.auth.currentUser;
  }

  /// Authenticates the Google identity with Supabase. Role is deliberately not
  /// accepted here: the database profile is the source of truth for an
  /// existing account, and a new user must explicitly choose one afterwards.
  Future<KaamGoogleSignInResult> signInWithGoogle() async {
    await SupabaseService.waitForSessionRecovery();
    final clientId = AppConfig.googleWebClientId.trim();
    if (clientId.isEmpty) {
      _debugGoogleSignIn('configuration_missing');
      return const KaamGoogleSignInResult.failure(
        KaamGoogleSignInOutcome.googleSdkFailure,
      );
    }
    _debugGoogleSignIn('started');
    if (_client.auth.currentUser != null) {
      try {
        await signOut();
      } on Object {
        _debugGoogleSignIn('previous_session_clear_failed');
        return const KaamGoogleSignInResult.failure(
          KaamGoogleSignInOutcome.supabaseExchangeFailure,
        );
      }
    }
    final google = GoogleSignIn(
      scopes: const ['email', 'profile'],
      serverClientId: clientId,
      forceCodeForRefreshToken: false,
    );
    GoogleSignInAccount? account;
    try {
      account = await google.signIn();
    } on PlatformException catch (error) {
      final outcome = _googlePlatformFailure(error);
      _debugGoogleSignIn('picker_${outcome.name}');
      return outcome == KaamGoogleSignInOutcome.cancelled
          ? const KaamGoogleSignInResult.cancelled()
          : KaamGoogleSignInResult.failure(outcome);
    } on SocketException {
      _debugGoogleSignIn('picker_network_failure');
      return const KaamGoogleSignInResult.failure(
        KaamGoogleSignInOutcome.networkFailure,
      );
    } on Object {
      _debugGoogleSignIn('picker_sdk_failure');
      return const KaamGoogleSignInResult.failure(
        KaamGoogleSignInOutcome.googleSdkFailure,
      );
    }
    if (account == null) {
      _debugGoogleSignIn('picker_cancelled');
      return const KaamGoogleSignInResult.cancelled();
    }
    _debugGoogleSignIn('picker_success');
    late final GoogleSignInAuthentication authentication;
    try {
      authentication = await account.authentication;
    } on SocketException {
      return const KaamGoogleSignInResult.failure(
        KaamGoogleSignInOutcome.networkFailure,
      );
    } on Object {
      return const KaamGoogleSignInResult.failure(
        KaamGoogleSignInOutcome.googleSdkFailure,
      );
    }
    final idToken = authentication.idToken;
    if (idToken == null || idToken.isEmpty) {
      _debugGoogleSignIn('invalid_token');
      return const KaamGoogleSignInResult.failure(
        KaamGoogleSignInOutcome.invalidToken,
      );
    }
    _debugGoogleSignIn('supabase_exchange_started');
    try {
      await _client.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: idToken,
        accessToken: authentication.accessToken,
      );
    } on SocketException {
      return const KaamGoogleSignInResult.failure(
        KaamGoogleSignInOutcome.networkFailure,
      );
    } on Object {
      _debugGoogleSignIn('supabase_exchange_failed');
      return const KaamGoogleSignInResult.failure(
        KaamGoogleSignInOutcome.supabaseExchangeFailure,
      );
    }
    final user = _client.auth.currentUser;
    if (user == null) {
      return const KaamGoogleSignInResult.failure(
        KaamGoogleSignInOutcome.supabaseExchangeFailure,
      );
    }
    _debugGoogleSignIn('supabase_exchange_completed');
    KaamAuthSessionCoordinator.markAuthenticatedUser(user.id);

    _debugGoogleSignIn('account_resolution_started');
    try {
      final profile = await _storedProfile();
      if (profile == null) {
        return const KaamGoogleSignInResult.success(
          KaamAuthRouteResult(
            destination: KaamAuthDestination.roleSelection,
            message:
                'Your account setup is incomplete. Please continue registration.',
          ),
        );
      }
      if (KaamAccountStatusPolicy.isBlocked(profile.status)) {
        await signOut();
        return const KaamGoogleSignInResult.success(
          KaamAuthRouteResult(
            destination: KaamAuthDestination.blocked,
            message: KaamAccountStatusPolicy.blockedMessage,
          ),
        );
      }
      final route = await resolvePostOtpDestination(fallbackRole: profile.role);
      _debugGoogleSignIn('account_resolution_completed');
      return KaamGoogleSignInResult.success(route);
    } on SocketException {
      return const KaamGoogleSignInResult.failure(
        KaamGoogleSignInOutcome.networkFailure,
      );
    } on Object {
      _debugGoogleSignIn('account_resolution_failed');
      return const KaamGoogleSignInResult.failure(
        KaamGoogleSignInOutcome.accountResolutionFailure,
      );
    }
  }

  KaamGoogleSignInOutcome _googlePlatformFailure(PlatformException error) {
    final code = error.code.toLowerCase();
    if (code.contains('cancel')) return KaamGoogleSignInOutcome.cancelled;
    if (code.contains('network')) return KaamGoogleSignInOutcome.networkFailure;
    return KaamGoogleSignInOutcome.googleSdkFailure;
  }

  void _debugGoogleSignIn(String stage) {
    if (kDebugMode) debugPrint('[GoogleAuth] stage=$stage');
  }

  Future<bool> signInWithOtp({
    required String email,
    KaamRole? role,
    bool freshRegistration = false,
  }) async {
    final trimmedEmail = email.trim().toLowerCase();
    if (trimmedEmail.isEmpty) {
      throw ArgumentError('Email address is required.');
    }
    final rawSignedInUser = _client.auth.currentUser;
    if (freshRegistration ||
        KaamAuthSessionCoordinator.blocksSessionRestore ||
        KaamAuthSessionPolicy.shouldStartOtpForEnteredEmail(
          hasCurrentSession: rawSignedInUser != null,
          enteredEmail: trimmedEmail,
          currentSessionEmail: rawSignedInUser?.email,
        )) {
      await signOut();
    }

    await _client.auth.signInWithOtp(
      email: trimmedEmail,
      shouldCreateUser: freshRegistration || role != null,
      data: role == null ? null : {'role': role.name},
    );
    KaamAuthSessionCoordinator.setPendingOtp(email: trimmedEmail, role: role);
    _debug(
      'Email OTP requested${role == null ? '' : ' for role ${role.name}'}',
    );
    return true;
  }

  Future<void> prepareFreshRegistration() async {
    await SupabaseService.waitForSessionRecovery();
    final client = SupabaseService.maybeClient;
    if (client?.auth.currentSession != null ||
        client?.auth.currentUser != null ||
        KaamAuthSessionCoordinator.blocksSessionRestore) {
      await signOut();
      return;
    }
    KaamAuthSessionCoordinator.clearUserScopedState();
  }

  Future<KaamAuthRouteResult> verifyOtp({
    required String email,
    required String token,
    KaamRole? role,
  }) async {
    final trimmedToken = token.trim();
    if (trimmedToken.length != AppConfig.emailOtpLength) {
      throw ArgumentError(
        'Enter the ${AppConfig.emailOtpLength}-digit OTP code.',
      );
    }

    await _client.auth.verifyOTP(
      email: email.trim().toLowerCase(),
      token: trimmedToken,
      type: OtpType.email,
    );
    if (_client.auth.currentSession == null ||
        _client.auth.currentUser == null) {
      throw StateError('OTP verified but no Supabase session was created.');
    }
    KaamAuthSessionCoordinator.markAuthenticatedUser(
      _client.auth.currentUser!.id,
    );
    final existingProfile = await _storedProfile();
    _debugAuthResolution(
      stage: 'otp_verified',
      authUserPresent: true,
      profileFound: existingProfile != null,
      storedRole: existingProfile?.role,
      selectedJourney: role,
      bootstrapAttempted: false,
    );
    if (existingProfile == null) {
      final recoveredProfile = await _recoverMissingStoredProfile();
      if (recoveredProfile != null) {
        final result = await resolvePostOtpDestination(
          fallbackRole: recoveredProfile.role,
        );
        KaamAuthSessionCoordinator.clearPendingOtp();
        return result;
      }
      if (role == null) {
        await signOut();
        KaamAuthSessionCoordinator.clearPendingOtp();
        throw const KaamAccountNotFoundException();
      }
      await bootstrapProfile(role: role);
      final result = await resolvePostOtpDestination(fallbackRole: role);
      KaamAuthSessionCoordinator.clearPendingOtp();
      return result;
    }
    if (KaamAccountStatusPolicy.isBlocked(existingProfile.status)) {
      await signOut();
      return const KaamAuthRouteResult(
        destination: KaamAuthDestination.blocked,
        message: KaamAccountStatusPolicy.blockedMessage,
      );
    }

    if (role != null) {
      if (existingProfile.role != role) {
        throw KaamRoleMismatchException(
          actualRole: existingProfile.role,
          requestedRole: role,
        );
      }
    }
    final result = await resolvePostOtpDestination(
      fallbackRole: existingProfile.role,
    );
    KaamAuthSessionCoordinator.clearPendingOtp();
    return result;
  }

  Future<KaamStoredProfile?> _storedProfile() async {
    final client = _client;
    final user = _requireUser(client);
    final profile = await client
        .from('profiles')
        .select('role,status')
        .eq('id', user.id)
        .maybeSingle();
    final roleName = profile?['role'] as String?;
    if (roleName == null) return null;
    return KaamStoredProfile(
      role: _roleFromName(roleName),
      status: profile?['status'] as String? ?? 'draft',
    );
  }

  Future<KaamStoredProfile?> _recoverMissingStoredProfile() async {
    final client = _client;
    final user = _requireUser(client);

    KaamRole? recoveredRole;
    final candidate = await client
        .from('candidate_profiles')
        .select('id')
        .eq('id', user.id)
        .maybeSingle();
    if (candidate != null) {
      recoveredRole = KaamRole.candidate;
    } else {
      final employer = await client
          .from('employer_companies')
          .select('id')
          .eq('owner_id', user.id)
          .maybeSingle();
      if (employer != null) recoveredRole = KaamRole.employer;
    }

    recoveredRole ??= _roleFromMetadata(user.userMetadata?['role']);

    if (recoveredRole == null) return null;
    final result = await _bootstrapUserProfile(client, role: recoveredRole);
    _debugAuthResolution(
      stage: 'missing_profile_recovered',
      authUserPresent: true,
      profileFound: true,
      storedRole: result.role,
      selectedJourney: null,
      bootstrapAttempted: true,
      bootstrapResult: result,
    );
    return KaamStoredProfile(role: result.role, status: result.status);
  }

  Future<KaamRole?> currentBackendRole() async =>
      (await _storedProfile())?.role;

  Future<KaamProtectedAccess> checkProtectedAccess(
    KaamRole expectedRole,
  ) async {
    final client = _client;
    await SupabaseService.waitForSessionRecovery();
    if (KaamAuthSessionCoordinator.blocksSessionRestore) {
      return KaamProtectedAccess.signedOut;
    }
    if (client.auth.currentUser == null) return KaamProtectedAccess.signedOut;
    final profile = await _storedProfile();
    final access = KaamAccountStatusPolicy.protectedAccess(
      actualRole: profile?.role,
      status: profile?.status,
      expectedRole: expectedRole,
    );
    if (access == KaamProtectedAccess.blocked) {
      await signOut();
    }
    return access;
  }

  Future<KaamProfileBootstrapResult> bootstrapProfile({
    required KaamRole role,
  }) async {
    final client = _client;
    final user = _requireUser(client);
    final existingProfile = await _storedProfile();
    _debugAuthResolution(
      stage: 'bootstrap_start',
      authUserPresent: true,
      profileFound: existingProfile != null,
      storedRole: existingProfile?.role,
      selectedJourney: role,
      bootstrapAttempted: true,
    );
    try {
      final result = await _bootstrapUserProfile(client, role: role);
      KaamAuthSessionCoordinator.markAuthenticatedUser(user.id);
      _debugAuthResolution(
        stage: 'bootstrap_complete',
        authUserPresent: true,
        profileFound: true,
        storedRole: result.role,
        selectedJourney: role,
        bootstrapAttempted: true,
        bootstrapResult: result,
      );
      return result;
    } on Object catch (error) {
      _debugAuthResolution(
        stage: 'bootstrap_failed',
        authUserPresent: true,
        profileFound: existingProfile != null,
        storedRole: existingProfile?.role,
        selectedJourney: role,
        bootstrapAttempted: true,
        safeErrorCode: _safeErrorCode(error),
      );
      rethrow;
    }
  }

  Future<KaamAuthRouteResult> resolvePostOtpDestination({
    required KaamRole fallbackRole,
  }) async {
    final client = _client;
    final user = _requireUser(client);
    KaamAuthSessionCoordinator.markAuthenticatedUser(user.id);
    await _ensureCurrentProfileNotBlocked(client);
    final profile = await client
        .from('profiles')
        .select('role,status')
        .eq('id', user.id)
        .maybeSingle();
    if (profile == null) {
      final bootstrap = await bootstrapProfile(role: fallbackRole);
      return resolvePostOtpDestination(fallbackRole: bootstrap.role);
    }
    final roleName = profile['role'] as String?;
    final role = roleName == null ? fallbackRole : _roleFromName(roleName);
    final status = profile['status'] as String?;
    _debugAuthResolution(
      stage: 'route_resolve',
      authUserPresent: true,
      profileFound: true,
      storedRole: role,
      selectedJourney: fallbackRole,
      bootstrapAttempted: false,
    );

    if (roleName == null) {
      return const KaamAuthRouteResult(
        destination: KaamAuthDestination.roleSelection,
        message: KaamMissingProfileRecovery.message,
      );
    }
    if (KaamAccountStatusPolicy.isBlocked(status)) {
      await signOut();
      return const KaamAuthRouteResult(
        destination: KaamAuthDestination.blocked,
        message: KaamAccountStatusPolicy.blockedMessage,
      );
    }

    if (role == KaamRole.candidate) {
      final candidate = await client
          .from('candidate_profiles')
          .select(
            'id,headline,nationality,current_country,current_city,preferred_country,preferred_city,job_categories,availability',
          )
          .eq('id', user.id)
          .maybeSingle();
      if (_candidateOnboardingComplete(candidate)) {
        _debugCandidateProfile(
          stage: 'onboarding_resume_step_resolved',
          userId: user.id,
          fields: const ['candidateDashboard'],
        );
        _debugAuthRoute(KaamAuthDestination.candidateDashboard);
        return const KaamAuthRouteResult(
          destination: KaamAuthDestination.candidateDashboard,
          message: 'Welcome back. Continuing to your account.',
        );
      }
      _debugCandidateProfile(
        stage: 'onboarding_resume_step_resolved',
        userId: user.id,
        fields: const ['candidateOnboarding'],
      );
      _debugAuthRoute(KaamAuthDestination.candidateOnboarding);
      return const KaamAuthRouteResult(
        destination: KaamAuthDestination.candidateOnboarding,
        message: 'Account verified. Let\'s create your profile.',
      );
    }

    final company = await client
        .from('employer_companies')
        .select('id,company_name')
        .eq('owner_id', user.id)
        .limit(1)
        .maybeSingle();
    if ((company?['company_name'] as String? ?? '').trim().isNotEmpty) {
      _debugAuthRoute(KaamAuthDestination.employerDashboard);
      return const KaamAuthRouteResult(
        destination: KaamAuthDestination.employerDashboard,
        message: 'Welcome back. Continuing to your account.',
      );
    }
    _debugAuthRoute(KaamAuthDestination.employerOnboarding);
    return const KaamAuthRouteResult(
      destination: KaamAuthDestination.employerOnboarding,
      message: 'Account verified. Let\'s create your company profile.',
    );
  }

  Future<void> signOut() async {
    await KaamAuthSessionCoordinator.beginExplicitLogout();
    try {
      await KaamPushNotificationService.instance.deactivateCurrentDevice();
      await SupabaseService.maybeClient?.auth.signOut(
        scope: SignOutScope.global,
      );
      // Clears the native account selection cache as well as the Supabase
      // session, so the next Google attempt can choose a different account.
      try {
        await GoogleSignIn().signOut();
      } on Object {
        // Supabase logout remains authoritative; native cache cleanup is best effort.
      }
      final client = SupabaseService.maybeClient;
      if (client?.auth.currentSession != null ||
          client?.auth.currentUser != null) {
        throw StateError('Logout did not finish.');
      }
      await KaamAuthSessionCoordinator.finishExplicitLogout();
    } catch (_) {
      await KaamAuthSessionCoordinator.abandonExplicitLogout();
      rethrow;
    }
  }

  Future<void> deleteCurrentAccount() async {
    final client = _client;
    _requireUser(client);
    final response = await client.functions.invoke('delete-account');
    if (response.status >= 400 ||
        response.data is! Map ||
        response.data['ok'] != true) {
      throw StateError('Account deletion request failed.');
    }
    await KaamAuthSessionCoordinator.beginExplicitLogout();
    try {
      await SupabaseService.maybeClient?.auth
          .signOut(scope: SignOutScope.global);
      await KaamAuthSessionCoordinator.finishExplicitLogout();
    } catch (_) {
      await KaamAuthSessionCoordinator.abandonExplicitLogout();
      rethrow;
    }
  }

  void _debugAuthRoute(KaamAuthDestination destination) {
    if (!kDebugMode) return;
    debugPrint('[AuthResolution] route=${destination.name}');
  }

  void _debugAuthResolution({
    required String stage,
    required bool authUserPresent,
    required bool profileFound,
    required KaamRole? storedRole,
    required KaamRole? selectedJourney,
    required bool bootstrapAttempted,
    KaamProfileBootstrapResult? bootstrapResult,
    Object? safeErrorCode,
  }) {
    if (!kDebugMode) return;
    final bootstrapSummary = bootstrapResult == null
        ? ''
        : ' bootstrapRole=${bootstrapResult.role.name}'
            ' candidateChild=${bootstrapResult.candidateProfileExists}'
            ' employerCompany=${bootstrapResult.employerCompanyExists}';
    final error = safeErrorCode == null ? '' : ' error=$safeErrorCode';
    debugPrint(
      '[AuthResolution] stage=$stage authUser=$authUserPresent '
      'profileFound=$profileFound storedRole=${storedRole?.name ?? 'none'} '
      'selectedJourney=${selectedJourney?.name ?? 'none'} '
      'bootstrapAttempted=$bootstrapAttempted$bootstrapSummary$error',
    );
  }

  Object _safeErrorCode(Object error) {
    if (error is PostgrestException) return error.code ?? 'postgrest';
    return error.runtimeType;
  }
}

class QaToolsRepository {
  const QaToolsRepository();

  SupabaseClient get _client => _requireClient();

  User? get currentUser {
    if (KaamAuthSessionCoordinator.blocksSessionRestore) return null;
    return SupabaseService.maybeClient?.auth.currentUser;
  }

  Future<String> currentRole() async {
    final user = _requireUser(_client);
    final row = await _client
        .from('profiles')
        .select('role')
        .eq('id', user.id)
        .maybeSingle();
    return row?['role'] as String? ?? 'unknown';
  }

  Future<void> reset(String action) async {
    await _client.rpc(
      'qa_reset',
      params: {
        'action': action,
        'build_version': 'flutter',
        'platform': defaultTargetPlatform.name,
      },
    );
  }

  Future<void> signOut() async {
    await KaamAuthSessionCoordinator.beginExplicitLogout();
    try {
      await KaamPushNotificationService.instance.deactivateCurrentDevice();
      await SupabaseService.maybeClient?.auth.signOut(
        scope: SignOutScope.global,
      );
      final client = SupabaseService.maybeClient;
      if (client?.auth.currentSession != null ||
          client?.auth.currentUser != null) {
        throw StateError('Logout did not finish.');
      }
      await KaamAuthSessionCoordinator.finishExplicitLogout();
    } catch (_) {
      await KaamAuthSessionCoordinator.abandonExplicitLogout();
      rethrow;
    }
  }
}

class CandidateProfileRepository {
  const CandidateProfileRepository();

  SupabaseClient get _client => _requireClient();

  Future<CandidateProfileData> loadCurrentProfile() async {
    final client = _client;
    final user = _requireUser(client);

    _debugCandidateProfile(stage: 'profile_load_started', userId: user.id);
    final results = await Future.wait<Object?>([
      client.from('profiles').select().eq('id', user.id).maybeSingle(),
      client
          .from('candidate_profiles')
          .select()
          .eq('id', user.id)
          .maybeSingle(),
      client
          .from('candidate_skills')
          .select('skill_id,is_primary,experience_range,skills(category_id)')
          .eq('candidate_id', user.id),
    ]);
    final profile = results[0] as Map<String, dynamic>?;
    final candidate = results[1] as Map<String, dynamic>?;
    final skillRows = results[2] as List<dynamic>;
    final skillExperiences = <String, String>{
      for (final row in skillRows)
        if ((row['skill_id'] as String? ?? '').isNotEmpty)
          row['skill_id'] as String: CandidateSkillExperience.normalize(
            row['experience_range'] as String?,
          ),
    }..removeWhere((_, value) => value.isEmpty);
    _debugCandidateProfile(
      stage: candidate == null ? 'profile_not_found' : 'profile_found',
      userId: user.id,
      fields: candidate?.keys,
    );

    final result = CandidateProfileData.fromRows(
      profile: profile,
      candidate: candidate,
      skillExperiences: skillExperiences,
      hierarchy: CandidateJobHierarchy.fromSkillRows(
        List<Map<String, dynamic>>.from(skillRows),
      ),
    );
    _debugVisaStatus(
      stage: 'profile_load_succeeded',
      normalizedStatus: result.visaStatus,
    );
    return result;
  }

  Future<CandidateProfileData> upsertBasicProfile({
    required String fullName,
    required String phone,
    required String nationality,
    required String currentCountry,
    required String currentLocation,
    required String preferredCountry,
    required String preferredLocation,
  }) async {
    final client = _client;
    final user = _requireUser(client);

    _debugCandidateProfile(
      stage: 'basic_details_save_started',
      userId: user.id,
      fields: const [
        'profiles.email',
        'profiles.phone',
        'profiles.full_name',
        'candidate_profiles.nationality',
        'candidate_profiles.current_country',
        'candidate_profiles.current_city',
        'candidate_profiles.preferred_country',
        'candidate_profiles.preferred_city',
      ],
    );
    await _bootstrapUserProfile(client, role: KaamRole.candidate);
    await _ensureCandidateProfileRow(client, user.id);
    try {
      await client.from('profiles').update({
        'email': user.email,
        'phone': _nullable(phone),
        'full_name': fullName.trim(),
      }).eq('id', user.id);

      await client.from('candidate_profiles').update({
        ...CandidateBasicProfileLocationMapper.candidateProfileValues(
          nationality: nationality,
          currentCountry: currentCountry,
          currentLocation: currentLocation,
          preferredCountry: preferredCountry,
          preferredLocation: preferredLocation,
        ),
      }).eq('id', user.id);
    } catch (error) {
      _debugCandidateProfile(
        stage: 'basic_details_save_failed',
        userId: user.id,
        safeErrorCode: _safePostgrestCode(error),
      );
      rethrow;
    }

    final saved = await loadCurrentProfile();
    if (!_savedBasicProfileMatches(
      saved,
      fullName: fullName,
      phone: phone,
      nationality: nationality,
      currentCountry: currentCountry,
      currentLocation: currentLocation,
      preferredCountry: preferredCountry,
      preferredLocation: preferredLocation,
    )) {
      _debugCandidateProfile(
        stage: 'basic_details_save_failed',
        userId: user.id,
        safeErrorCode: 'readback_mismatch',
        fields: const [
          'profiles.full_name',
          'profiles.phone',
          'candidate_profiles.nationality',
          'candidate_profiles.current_country',
          'candidate_profiles.current_city',
          'candidate_profiles.preferred_country',
          'candidate_profiles.preferred_city',
        ],
      );
      throw StateError('Basic Details were not saved.');
    }

    _debugCandidateProfile(
      stage: 'basic_details_save_succeeded',
      userId: user.id,
    );
    return saved;
  }

  Future<CandidateProfileData> updateWorkProfile(
    Map<String, dynamic> values,
  ) async {
    final client = _client;
    final user = _requireUser(client);
    await _ensureCurrentProfileNotBlocked(client);
    await _bootstrapUserProfile(client, role: KaamRole.candidate);
    await _ensureCandidateProfileRow(client, user.id);

    final safeValues = Map<String, dynamic>.from(values);
    if (safeValues.containsKey('skills')) {
      safeValues['skills'] = CandidateSkillLimits.normalizeNames(
        _stringList(safeValues['skills']),
      );
    }
    await client
        .from('candidate_profiles')
        .update(safeValues)
        .eq('id', user.id);

    _debug('Candidate work profile saved');
    return loadCurrentProfile();
  }

  Future<CandidateProfileData> updateCurrentLocation({
    required String country,
    required String region,
  }) async {
    final normalizedCountry = CandidateLocationOptions.normalizeCountry(
      country,
    );
    final normalizedRegion = CandidateLocationOptions.normalizeRegionForCountry(
      normalizedCountry,
      region,
    );
    final validationError = CandidateLocationOptions.validationError(
      normalizedCountry,
      normalizedRegion,
    );
    if (validationError != null) {
      throw ArgumentError.value(region, 'region', validationError);
    }

    final client = _client;
    final user = _requireUser(client);
    await _ensureCurrentProfileNotBlocked(client);
    await _bootstrapUserProfile(client, role: KaamRole.candidate);
    await _ensureCandidateProfileRow(client, user.id);
    _debugCandidateProfile(
      stage: 'candidate_location_save_started',
      userId: user.id,
      fields: const [
        'candidate_profiles.current_country',
        'candidate_profiles.current_city',
      ],
    );
    await client.from('candidate_profiles').update({
      'current_country': normalizedCountry,
      'current_city': normalizedRegion,
    }).eq('id', user.id);

    final saved = await loadCurrentProfile();
    if (saved.currentCountry != normalizedCountry ||
        saved.currentCity != normalizedRegion) {
      _debugCandidateProfile(
        stage: 'candidate_location_save_failed',
        userId: user.id,
        safeErrorCode: 'readback_mismatch',
      );
      throw StateError('Candidate location was not saved.');
    }
    _debugCandidateProfile(
      stage: 'candidate_location_save_succeeded',
      userId: user.id,
    );
    return saved;
  }

  Future<CandidateProfileData> updateVisaDetails({
    required String selectedStatus,
    String? expiryDate,
  }) async {
    final normalized = CandidateVisaStatus.normalize(selectedStatus);
    if (!CandidateVisaStatus.isSupported(normalized)) {
      throw ArgumentError.value(selectedStatus, 'selectedStatus');
    }
    final expiryError = CandidateVisaExpiry.validationError(
      normalized,
      expiryDate,
    );
    if (expiryError != null) {
      throw ArgumentError.value(expiryDate, 'expiryDate', expiryError);
    }
    final parsedExpiry = CandidateVisaExpiry.parse(expiryDate);
    final normalizedExpiry = CandidateVisaExpiry.requiresExpiry(normalized)
        ? CandidateVisaExpiry.normalizeDate(parsedExpiry!)
        : null;

    final client = _client;
    final user = _requireUser(client);
    await _ensureCurrentProfileNotBlocked(client);
    await _bootstrapUserProfile(client, role: KaamRole.candidate);
    await _ensureCandidateProfileRow(client, user.id);

    _debugVisaStatus(
      stage: 'save_started',
      normalizedStatus: normalized,
      field: 'candidate_profiles.visa_status',
    );
    try {
      await client.from('candidate_profiles').update({
        'visa_status': normalized,
        'visa_expiry_date': normalizedExpiry,
      }).eq('id', user.id);
      final saved = await loadCurrentProfile();
      if (saved.visaStatus != normalized ||
          saved.visaExpiryDate != (normalizedExpiry ?? '')) {
        _debugVisaStatus(
          stage: 'readback_mismatched',
          normalizedStatus: saved.visaStatus,
          field: 'candidate_profiles.visa_status',
        );
        throw StateError('Visa status readback did not match.');
      }
      _debugVisaStatus(
        stage: 'save_succeeded',
        normalizedStatus: saved.visaStatus,
        field: 'candidate_profiles.visa_status',
      );
      return saved;
    } catch (error) {
      _debugVisaStatus(
        stage: 'save_failed',
        normalizedStatus: normalized,
        field: 'candidate_profiles.visa_status',
        safeErrorCode: _safePostgrestCode(error),
      );
      rethrow;
    }
  }

  Future<List<SkillCategoryData>> loadSkillCategories() async {
    final rows = await _client
        .from('skill_categories')
        .select('id,name,icon_name')
        .eq('is_active', true)
        .order('sort_order');
    return rows.map(SkillCategoryData.fromRow).toList();
  }

  Future<List<SkillData>> loadSkills({
    Iterable<String> categoryIds = const [],
  }) async {
    var query = _client
        .from('skills')
        .select('id,category_id,name')
        .eq('is_active', true)
        .eq('is_approved', true);
    final ids = categoryIds.toList();
    if (ids.isNotEmpty) query = query.inFilter('category_id', ids);
    final rows = await query.order('sort_order');
    return rows.map(SkillData.fromRow).toList();
  }

  Future<List<CandidateSkillData>> loadMySkills() async {
    final user = _requireUser(_client);
    final rows = await _client
        .from('candidate_skills')
        .select(
          'is_primary,experience_range,skill_level,uae_experience_range,availability,certificate_types,other_certificate_name,skills!inner(id,name,category_id,skill_categories!inner(id,name,icon_name))',
        )
        .eq('candidate_id', user.id);
    final selections = rows.map((row) {
      final skillRow = Map<String, dynamic>.from(row['skills'] as Map);
      final categoryRow = Map<String, dynamic>.from(
        skillRow['skill_categories'] as Map,
      );
      return CandidateSkillData(
        skill: SkillData.fromRow(skillRow),
        category: SkillCategoryData.fromRow(categoryRow),
        isPrimary: row['is_primary'] as bool? ?? false,
        experienceRange: CandidateSkillExperience.normalize(
          row['experience_range'] as String?,
        ),
        skillLevel: row['skill_level'] as String? ?? '',
        uaeExperienceRange: row['uae_experience_range'] as String? ?? '',
        availability: row['availability'] as String? ?? '',
        certificateTypes: _stringList(row['certificate_types']),
        otherCertificateName: row['other_certificate_name'] as String? ?? '',
      );
    }).toList()
      ..sort((a, b) {
        if (a.isPrimary == b.isPrimary) return 0;
        return a.isPrimary ? -1 : 1;
      });
    return selections.take(CandidateSkillLimits.maxSkills).toList();
  }

  Future<void> saveSkills({
    required List<CandidateSkillData> selections,
  }) async {
    final user = _requireUser(_client);
    await _ensureCurrentProfileNotBlocked(_client);
    if (selections.isEmpty ||
        selections.length > CandidateSkillLimits.maxSkills) {
      throw ArgumentError(
        'Choose between 1 and ${CandidateSkillLimits.maxSkills} skills.',
      );
    }
    if (selections.where((item) => item.isPrimary).length != 1) {
      throw ArgumentError('Choose exactly one main profession.');
    }
    final expectedHierarchy = CandidateJobHierarchy.fromSelections(selections);
    if (!expectedHierarchy.isComplete) {
      throw ArgumentError('Choose one category and a valid job subcategory.');
    }
    final skillIds = selections.map((item) => item.skill.id).toSet();
    if (skillIds.length != selections.length) {
      throw ArgumentError('Duplicate skills are not allowed.');
    }
    final primary = selections.firstWhere((item) => item.isPrimary);
    if (selections.any(
      (item) => !CandidateSkillExperience.isValid(item.experienceRange),
    )) {
      throw ArgumentError('Add experience for every selected skill.');
    }
    if (primary.skillLevel.isEmpty) {
      throw ArgumentError(
        'Add experience and skill level for your main profession.',
      );
    }
    _debugSkillExperience(stage: 'save_started', count: selections.length);

    // Clear the old primary before assigning the replacement: the database
    // intentionally permits only one primary skill per candidate.
    await _client
        .from('candidate_skills')
        .update({'is_primary': false}).eq('candidate_id', user.id);
    await _client.from('candidate_skills').upsert([
      for (final item in selections)
        {
          'candidate_id': user.id,
          'skill_id': item.skill.id,
          'is_primary': false,
          'experience_range': CandidateSkillExperience.normalize(
            item.experienceRange,
          ),
          'skill_level': _nullable(item.skillLevel),
          'uae_experience_range': _nullable(item.uaeExperienceRange),
          'availability': _nullable(item.availability),
          'certificate_types': item.certificateTypes,
          'other_certificate_name': _nullable(item.otherCertificateName),
        },
    ], onConflict: 'candidate_id,skill_id');
    await _client
        .from('candidate_skills')
        .update({'is_primary': true})
        .eq('candidate_id', user.id)
        .eq('skill_id', primary.skill.id);
    await _client
        .from('candidate_skills')
        .delete()
        .eq('candidate_id', user.id)
        .not('skill_id', 'in', '(${skillIds.map((id) => '"$id"').join(',')})');
    await updateWorkProfile({
      'headline': primary.skill.name,
      'job_categories':
          selections.map((item) => item.category.name).toSet().toList(),
      'skills': CandidateSkillLimits.normalizeNames(
        selections.map((item) => item.skill.name),
      ),
      'availability':
          primary.availability.isEmpty ? null : primary.availability,
    });
    final saved = await loadMySkills();
    final savedHierarchy = CandidateJobHierarchy.fromSelections(saved);
    final expectedExperiences = {
      for (final item in selections)
        item.skill.id: CandidateSkillExperience.normalize(item.experienceRange),
    };
    final savedExperiences = {
      for (final item in saved) item.skill.id: item.experienceRange,
    };
    if (!expectedHierarchy.matches(savedHierarchy) ||
        !CandidateSkillExperience.mappingsMatch(
          expectedExperiences,
          savedExperiences,
        )) {
      _debugSkillExperience(stage: 'readback_mismatch', count: saved.length);
      throw StateError('Job hierarchy readback did not match.');
    }
    _debugSkillExperience(stage: 'readback_matched', count: saved.length);
  }

  Future<void> updateSkillExperiences(
    Map<String, String> experienceBySkillId,
  ) async {
    final user = _requireUser(_client);
    await _ensureCurrentProfileNotBlocked(_client);
    final normalized = CandidateSkillExperience.normalizeBySkillId(
      experienceBySkillId,
    );
    if (normalized.length != experienceBySkillId.length ||
        normalized.isEmpty ||
        normalized.length > CandidateSkillLimits.maxSkills) {
      throw ArgumentError('Add valid experience for every selected skill.');
    }
    final existing = await loadMySkills();
    final existingIds = existing.map((item) => item.skill.id).toSet();
    if (existingIds.length != normalized.length ||
        !existingIds.containsAll(normalized.keys)) {
      throw StateError('Selected skills changed before experience was saved.');
    }
    _debugSkillExperience(stage: 'save_started', count: normalized.length);
    await _client.from('candidate_skills').upsert([
      for (final entry in normalized.entries)
        {
          'candidate_id': user.id,
          'skill_id': entry.key,
          'experience_range': entry.value,
        },
    ], onConflict: 'candidate_id,skill_id');
    final readback = await loadMySkills();
    final actual = {
      for (final item in readback) item.skill.id: item.experienceRange,
    };
    if (!CandidateSkillExperience.mappingsMatch(normalized, actual)) {
      _debugSkillExperience(
        stage: 'readback_mismatch',
        count: readback.length,
      );
      throw StateError('Skill experience readback did not match.');
    }
    _debugSkillExperience(stage: 'readback_matched', count: readback.length);
  }

  Future<void> submitCustomSkill({
    required String categoryId,
    required String name,
  }) async {
    final trimmed = name.trim();
    if (trimmed.length < 2 || trimmed.length > 50) {
      throw ArgumentError('Custom skill names must be 2 to 50 characters.');
    }
    final user = _requireUser(_client);
    await _ensureCurrentProfileNotBlocked(_client);
    final existing = await loadSkills(categoryIds: [categoryId]);
    if (existing.any(
      (skill) => skill.name.toLowerCase() == trimmed.toLowerCase(),
    )) {
      throw ArgumentError(
        'That skill is already available. Select it from the list.',
      );
    }
    await _client.from('candidate_custom_skills').upsert({
      'candidate_id': user.id,
      'category_id': categoryId,
      'skill_name': trimmed,
      'approval_status': 'pending',
    }, onConflict: 'candidate_id,category_id,skill_name');
  }

  Future<CandidateProfileData> updateProfilePhoto(
    String path, {
    String fileName = '',
  }) async {
    return updateWorkProfile({
      'profile_photo_url': path,
      'profile_photo_file_name': _nullable(fileName),
    });
  }

  Future<CandidateProfileData> updateResumePath(
    String path, {
    String fileName = '',
    int? fileSize,
  }) async {
    return updateWorkProfile({
      'resume_url': path,
      'resume_file_name': _nullable(fileName),
      'resume_file_size': fileSize,
    });
  }

  Future<CandidateProfileData> updateVisibility(bool isVisible) async {
    return updateWorkProfile({'is_visible': isVisible});
  }

  Future<CandidatePrivacySettings> loadPrivacySettings() async {
    final profile = await loadCurrentProfile();
    return CandidatePrivacySettings(
      profileVisible: profile.isVisible,
      hidePhoneBeforeMatch: profile.hidePhoneBeforeMatch,
      hideEmailBeforeMatch: profile.hideEmailBeforeMatch,
      requireApprovalBeforeChat: profile.requireApprovalBeforeChat,
      allowDocumentSharingAfterMatch: profile.allowDocumentSharingAfterMatch,
    );
  }

  Future<CandidatePrivacySettings> updatePrivacySettings(
    CandidatePrivacySettings settings,
  ) async {
    final profile = await updateWorkProfile({
      'is_visible': settings.profileVisible,
      'hide_phone_before_match': settings.hidePhoneBeforeMatch,
      'hide_email_before_match': settings.hideEmailBeforeMatch,
      'require_approval_before_chat': settings.requireApprovalBeforeChat,
      'allow_document_sharing_after_match':
          settings.allowDocumentSharingAfterMatch,
    });
    return CandidatePrivacySettings(
      profileVisible: profile.isVisible,
      hidePhoneBeforeMatch: profile.hidePhoneBeforeMatch,
      hideEmailBeforeMatch: profile.hideEmailBeforeMatch,
      requireApprovalBeforeChat: profile.requireApprovalBeforeChat,
      allowDocumentSharingAfterMatch: profile.allowDocumentSharingAfterMatch,
    );
  }

  Future<CandidateIdentityDocumentData> loadIdentityDocuments() async {
    final client = _client;
    final user = _requireUser(client);
    final row = await client
        .from('candidate_documents')
        .select()
        .eq('candidate_id', user.id)
        .maybeSingle();
    return CandidateIdentityDocumentData.fromRow(row);
  }

  Future<CandidateMembershipData> loadMembership() async {
    final client = _client;
    final user = _requireUser(client);
    try {
      final row = await client
          .from('candidate_memberships')
          .select(
            'id,plan_code,status,started_at,expires_at,payment_provider,amount,currency,is_test',
          )
          .eq('candidate_id', user.id)
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();
      if (kDebugMode) {
        final host = Uri.tryParse(AppConfig.supabaseUrl)?.host ?? 'invalid';
        debugPrint(
          '[Membership] host=$host table_query=success has_record=${row != null}',
        );
      }
      return CandidateMembershipData.fromRow(row);
    } on PostgrestException catch (error) {
      if (kDebugMode) {
        final host = Uri.tryParse(AppConfig.supabaseUrl)?.host ?? 'invalid';
        debugPrint(
          '[Membership] host=$host table_query=fallback code=${error.code ?? 'unknown'}',
        );
      }
      return const CandidateMembershipData(loadFailed: true);
    } on Object catch (error) {
      if (kDebugMode) {
        final host = Uri.tryParse(AppConfig.supabaseUrl)?.host ?? 'invalid';
        debugPrint(
          '[Membership] host=$host table_query=fallback code=${error.runtimeType}',
        );
      }
      return const CandidateMembershipData(loadFailed: true);
    }
  }

  Future<bool> currentCandidateVisibleToEmployers() async {
    final client = _client;
    final user = _requireUser(client);
    try {
      final result = await client.rpc(
        'candidate_visible_to_employers',
        params: {'target_candidate_id': user.id},
      );
      return result as bool? ?? false;
    } on Object catch (error) {
      if (kDebugMode) {
        debugPrint(
          '[CandidateStatus] employer_visibility=fallback code=${error.runtimeType}',
        );
      }
      return false;
    }
  }

  Future<CandidateMembershipData> activateTestMembership() async {
    if (!TestMembershipActivationAccess.isAvailable(debugBuild: kDebugMode)) {
      throw StateError(
        'Test membership activation is only available in debug builds.',
      );
    }
    await _client.rpc('activate_test_candidate_membership');
    return loadMembership();
  }

  Future<CandidateIdentityDocumentData> saveIdentityDocuments(
    Map<String, dynamic> values, {
    Map<String, dynamic> profileValues = const {},
    Map<String, dynamic> candidateValues = const {},
  }) async {
    final client = _client;
    final user = _requireUser(client);
    await _ensureCurrentProfileNotBlocked(client);
    await _bootstrapUserProfile(client, role: KaamRole.candidate);
    await _ensureCandidateProfileRow(client, user.id);
    final isPassport = values.containsKey('passport_file_url');
    final isVisa = values.containsKey('visa_file_url');
    if (isPassport == isVisa) {
      throw ArgumentError(
          'Submit exactly one validated identity document type.');
    }
    final documentType = isPassport ? 'passport' : 'visa';
    final frontPath =
        (isPassport ? values['passport_file_url'] : values['visa_file_url'])
                ?.toString() ??
            '';
    final backPath =
        isPassport ? values['passport_back_file_url']?.toString() : null;
    final fieldKeys = isPassport
        ? const [
            'full_name',
            'passport_number',
            'passport_issue_date',
            'passport_expiry_date',
            'country_of_issue',
            'nationality',
            'gender',
            'dob',
            'place_of_birth',
            'identity_correction_reason',
          ]
        : const [
            'visa_number',
            'visa_type',
            'occupation',
            'sponsor',
            'uid_number',
            'emirates_id',
            'visa_issue_date',
            'visa_expiry_date',
            'identity_correction_reason',
          ];
    await client.rpc('submit_candidate_identity_documents', params: {
      'p_document_type': documentType,
      'p_front_path': frontPath,
      'p_back_path': backPath,
      'p_fields': {
        for (final key in fieldKeys)
          if (values[key] != null) key: values[key]
      },
      'p_profile_fields': profileValues,
      'p_candidate_fields': candidateValues,
    });
    return loadIdentityDocuments();
  }

  Future<List<CandidateDocumentVersionData>> loadDocumentVersions({
    String? documentType,
  }) async {
    final client = _client;
    final user = _requireUser(client);
    var query = client
        .from('candidate_document_versions')
        .select()
        .eq('candidate_id', user.id);
    if (documentType != null) {
      query = query.eq('document_type', documentType);
    }
    final rows = await query.order('created_at', ascending: false);
    return rows.map(CandidateDocumentVersionData.fromRow).toList();
  }

  Future<List<CandidateDocumentNotificationData>>
      loadDocumentNotifications() async {
    final client = _client;
    final user = _requireUser(client);
    final rows = await client
        .from('candidate_document_notifications')
        .select()
        .eq('candidate_id', user.id)
        .order('created_at', ascending: false)
        .limit(50);
    return rows.map(CandidateDocumentNotificationData.fromRow).toList();
  }

  Future<void> markDocumentNotificationRead(String id) async {
    if (id.trim().isEmpty) return;
    final client = _client;
    final user = _requireUser(client);
    await _ensureCurrentProfileNotBlocked(client);
    await client
        .from('candidate_document_notifications')
        .update({'is_read': true})
        .eq('id', id)
        .eq('candidate_id', user.id);
  }
}

class EmployerRepository {
  const EmployerRepository();

  SupabaseClient get _client => _requireClient();

  Future<EmployerCompanyData?> loadMyCompany() async {
    final client = _client;
    final user = _requireUser(client);

    final row = await client
        .from('employer_companies')
        .select()
        .eq('owner_id', user.id)
        .order('updated_at', ascending: false)
        .limit(1)
        .maybeSingle();
    return row == null ? null : EmployerCompanyData.fromRow(row);
  }

  Future<EmployerCompanyData> upsertCompanyProfile({
    required String companyName,
    required String industry,
    required String companySize,
    required String location,
    required String branch,
    required String contactName,
    required String contactRole,
    String description = '',
    List<String> hiringNeeds = const [],
    String? industryId,
    String? companySizeCode,
    String? contactRoleCode,
    String? contactRoleOther,
    String? companyEmirate,
    String? companyArea,
    String? branchName,
  }) async {
    final client = _client;
    final user = _requireUser(client);
    var profileExists = false;
    var companyExists = false;

    await _bootstrapUserProfile(client, role: KaamRole.employer);
    try {
      await client.from('profiles').update({
        'email': user.email,
        'phone': user.phone,
        'full_name': _nullable(contactName),
      }).eq('id', user.id);
    } on Object catch (error) {
      _debugCompanySaveFailure(
        stage: 'parent_profile_upsert',
        table: 'profiles',
        operation: 'upsert',
        error: error,
        authenticated: true,
        profileExists: profileExists,
        companyExists: companyExists,
      );
      rethrow;
    }

    final profile = await client
        .from('profiles')
        .select('id,role,status')
        .eq('id', user.id)
        .maybeSingle();
    profileExists = profile != null;
    final profileRole = profile?['role'] as String?;
    final profileStatus = profile?['status'] as String?;
    if (!profileExists ||
        profileRole != KaamRole.employer.name ||
        KaamAccountStatusPolicy.isBlocked(profileStatus)) {
      _debugCompanySaveFailure(
        stage: 'parent_profile_verify',
        table: 'profiles',
        operation: 'select',
        error: StateError('invalid_parent_profile'),
        authenticated: true,
        profileExists: profileExists,
        companyExists: companyExists,
      );
      throw StateError('Employer profile could not be verified.');
    }

    late final Map<String, dynamic>? existing;
    try {
      existing = await client
          .from('employer_companies')
          .select('id')
          .eq('owner_id', user.id)
          .limit(1)
          .maybeSingle();
      companyExists = existing != null;
    } on Object catch (error) {
      _debugCompanySaveFailure(
        stage: 'company_existing_select',
        table: 'employer_companies',
        operation: 'select',
        error: error,
        authenticated: true,
        profileExists: profileExists,
        companyExists: companyExists,
      );
      rethrow;
    }

    final values = employerCompanyProfilePayload(
      ownerId: user.id,
      companyName: companyName,
      industry: industry,
      companySize: companySize,
      location: location,
      branch: branch,
      contactName: contactName,
      contactRole: contactRole,
      description: description,
      hiringNeeds: hiringNeeds,
      industryId: industryId,
      companySizeCode: companySizeCode,
      contactRoleCode: contactRoleCode,
      contactRoleOther: contactRoleOther,
      companyEmirate: companyEmirate,
      companyArea: companyArea,
      branchName: branchName,
      status: KaamProfileStatus.employerOnboarding,
    );

    late final Map<String, dynamic> saved;
    if (existing == null) {
      try {
        saved = await client
            .from('employer_companies')
            .insert(values)
            .select()
            .single();
      } on Object catch (error) {
        _debugCompanySaveFailure(
          stage: 'company_insert',
          table: 'employer_companies',
          operation: 'insert',
          error: error,
          authenticated: true,
          profileExists: profileExists,
          companyExists: companyExists,
        );
        rethrow;
      }
    } else {
      try {
        saved = await client
            .from('employer_companies')
            .update(values)
            .eq('id', existing['id'])
            .eq('owner_id', user.id)
            .select()
            .single();
      } on Object catch (error) {
        _debugCompanySaveFailure(
          stage: 'company_update',
          table: 'employer_companies',
          operation: 'update',
          error: error,
          authenticated: true,
          profileExists: profileExists,
          companyExists: companyExists,
        );
        rethrow;
      }
    }

    if (saved['owner_id'] != user.id) {
      _debugCompanySaveFailure(
        stage: 'company_owner_verify',
        table: 'employer_companies',
        operation: existing == null ? 'insert' : 'update',
        error: StateError('saved_company_owner_mismatch'),
        authenticated: true,
        profileExists: profileExists,
        companyExists: companyExists,
      );
      throw StateError('Employer company ownership could not be verified.');
    }

    _debug('Employer company profile saved');
    return EmployerCompanyData.fromRow(saved);
  }

  void _debugCompanySaveFailure({
    required String stage,
    required String table,
    required String operation,
    required Object error,
    required bool authenticated,
    required bool profileExists,
    required bool companyExists,
  }) {
    if (!kDebugMode) return;
    final code = error is PostgrestException ? error.code : error.runtimeType;
    final message = error is PostgrestException
        ? _safePostgrestMessage(error.message)
        : error.runtimeType.toString();
    final column = _safeFailingColumn(error);
    debugPrint(
      '[EmployerCompanySave] stage=$stage table=$table op=$operation '
      'code=$code message=$message column=${column ?? 'unknown'} '
      'authUser=$authenticated parentProfile=$profileExists '
      'employerCompany=$companyExists',
    );
  }

  String _safePostgrestMessage(String message) {
    if (message.contains('row-level security')) return 'row-level security';
    if (message.contains('violates not-null constraint')) {
      return 'not-null constraint';
    }
    if (message.contains('violates foreign key constraint')) {
      return 'foreign key constraint';
    }
    if (message.contains('invalid input value for enum')) {
      return 'invalid enum value';
    }
    if (message.contains('duplicate key value')) return 'duplicate key';
    return 'database rejected request';
  }

  String? _safeFailingColumn(Object error) {
    if (error is! PostgrestException) return null;
    final message = error.message;
    if (message.contains('profile_status') || message.contains('status')) {
      return 'status';
    }
    if (message.contains('owner_id')) return 'owner_id';
    if (message.contains('company_name')) return 'company_name';
    if (message.contains('role')) return 'role';
    return null;
  }

  Future<EmployerCompanyData> updateCompanyLogo(String publicUrl) async {
    final client = _client;
    final user = _requireUser(client);
    await _ensureCurrentProfileNotBlocked(client);
    await client
        .from('employer_companies')
        .update({'logo_url': publicUrl}).eq('owner_id', user.id);
    return await loadMyCompany() ?? const EmployerCompanyData();
  }

  Future<List<EmployerHiringRequirement>> hiringRequirements() async {
    final client = _client;
    final user = _requireUser(client);
    final rows = await client
        .from('employer_hiring_requirements')
        .select()
        .eq('employer_id', user.id)
        .order('updated_at', ascending: false);
    final requirements = rows.map(EmployerHiringRequirement.fromRow).toList();
    final ids = requirements
        .map((requirement) => requirement.id)
        .whereType<String>()
        .toList();
    if (ids.isEmpty) return requirements;
    final skillRows = await client
        .from('employer_hiring_requirement_skills')
        .select('requirement_id, competency_skill_id')
        .inFilter('requirement_id', ids);
    return attachRequirementSkills(
      requirements: requirements,
      skillRows: List<Map<String, dynamic>>.from(skillRows),
    );
  }

  Future<EmployerHiringRequirement> saveHiringRequirement(
    EmployerHiringRequirement requirement,
  ) async {
    final client = _client;
    final user = _requireUser(client);
    await _ensureCurrentProfileNotBlocked(client);
    final company = await loadMyCompany();
    if (company?.id == null) {
      throw StateError(
        'Create your company profile before adding hiring requirements.',
      );
    }
    final values = employerHiringRequirementPayload(
      employerId: user.id,
      companyId: company!.id!,
      requirement: requirement,
    );
    final Map<String, dynamic> row;
    if (requirement.id == null) {
      row = await client
          .from('employer_hiring_requirements')
          .insert(values)
          .select()
          .single();
    } else {
      row = await client
          .from('employer_hiring_requirements')
          .update(values)
          .eq('id', requirement.id!)
          .select()
          .single();
    }
    final saved = EmployerHiringRequirement.fromRow(row);
    await _syncRequirementSkills(saved.id!, requirement.competencySkillIds);
    return saved.copyWith(competencySkillIds: requirement.competencySkillIds);
  }

  Future<void> _syncRequirementSkills(
      String requirementId, List<String> ids) async {
    final client = _client;
    await synchronizeRequirementSkills(
      loadExisting: () async {
        final rows = await client
            .from('employer_hiring_requirement_skills')
            .select('competency_skill_id')
            .eq('requirement_id', requirementId);
        return rows.map((row) => row['competency_skill_id'] as String);
      },
      delete: (skillIds) async {
        await client
            .from('employer_hiring_requirement_skills')
            .delete()
            .eq('requirement_id', requirementId)
            .inFilter('competency_skill_id', skillIds.toList());
      },
      insert: (skillIds) async {
        await client.from('employer_hiring_requirement_skills').insert(
              skillIds
                  .map(
                    (skillId) => {
                      'requirement_id': requirementId,
                      'competency_skill_id': skillId,
                    },
                  )
                  .toList(),
            );
      },
      selected: ids,
    );
  }

  Future<void> updateHiringRequirementStatus(String id, String status) async {
    if (id.isEmpty) throw ArgumentError('Hiring requirement ID is missing.');
    await _ensureCurrentProfileNotBlocked(_client);
    await _client
        .from('employer_hiring_requirements')
        .update({'status': status}).eq('id', id);
  }

  Future<void> deleteHiringRequirement(String id) async {
    if (id.isEmpty) throw ArgumentError('Hiring requirement ID is missing.');
    await _ensureCurrentProfileNotBlocked(_client);
    await _client.from('employer_hiring_requirements').delete().eq('id', id);
  }

  Future<List<EmployerCandidate>> searchCandidates({
    String? query,
    EmployerCandidateSearchFilters filters =
        const EmployerCandidateSearchFilters(),
  }) async {
    final client = _client;
    final user = _requireUser(client);

    List<Map<String, dynamic>> rows;
    if (filters.effectiveCategories.length == 1 &&
        filters.effectiveSkills.length <= 1) {
      final result = await client.rpc(
        'search_candidates_by_skills',
        params: {
          'requested_category': filters.effectiveCategories.first,
          'requested_skill': filters.effectiveSkills.isEmpty
              ? null
              : filters.effectiveSkills.first,
        },
      );
      rows = List<Map<String, dynamic>>.from(result as List);
    } else {
      final result = await client
          .from('public_candidate_search')
          .select()
          .order('updated_at', ascending: false)
          .limit(100);
      rows = List<Map<String, dynamic>>.from(result);
    }
    final effectiveFilters = query == null
        ? filters
        : EmployerCandidateSearchFilters(
            query: query,
            categories: filters.effectiveCategories,
            skills: filters.effectiveSkills,
            locations: filters.effectiveLocations,
            experiences: filters.effectiveExperiences,
            visaStatuses: filters.effectiveVisaStatuses,
            availabilities: filters.effectiveAvailabilities,
            nationalities: filters.effectiveNationalities,
            languages: filters.effectiveLanguages,
            verifiedOnly: filters.verifiedOnly,
            minimumSalary: filters.minimumSalary,
            maximumSalary: filters.maximumSalary,
          );
    final savedIds = await _savedCandidateIds(client, user.id);
    EmployerSavedStateStore.instance.hydrate(savedIds);
    final interests = await _employerInterestStates(client, user.id);
    EmployerInterestStateStore.instance.hydrate(interests);
    return rows
        .where(
          (row) =>
              (effectiveFilters.isEmpty ||
                  EmployerCandidateSearchMatcher.matches(
                      row, effectiveFilters)) &&
              !const {'pending', 'accepted'}.contains(
                interests[row['id'] as String? ?? ''],
              ),
        )
        .map((row) => _candidateFromPublicRow(
              row,
              savedIds: savedIds,
              interestStatus: interests[row['id'] as String? ?? ''],
            ))
        .toList();
  }

  Future<void> saveCandidate(String candidateId) async {
    final client = _client;
    final user = _requireUser(client);
    await _ensureCurrentProfileNotBlocked(client);
    if (candidateId.isEmpty) {
      throw ArgumentError('Candidate ID is missing.');
    }

    await client.from('saved_candidates').upsert({
      'employer_id': user.id,
      'candidate_id': candidateId,
    }, onConflict: 'employer_id,candidate_id');
  }

  Future<void> removeSavedCandidate(String candidateId) async {
    final client = _client;
    final user = _requireUser(client);
    await _ensureCurrentProfileNotBlocked(client);
    if (candidateId.isEmpty) {
      throw ArgumentError('Candidate ID is missing.');
    }
    await client
        .from('saved_candidates')
        .delete()
        .eq('employer_id', user.id)
        .eq('candidate_id', candidateId);
  }

  Future<List<EmployerCandidate>> savedCandidates() async {
    final client = _client;
    final user = _requireUser(client);
    await _ensureCurrentProfileNotBlocked(client);
    final savedRows = await client
        .from('saved_candidates')
        .select('candidate_id,created_at')
        .eq('employer_id', user.id)
        .order('created_at', ascending: false);
    EmployerSavedStateStore.instance.hydrate(
      savedRows
          .map((row) => row['candidate_id'] as String? ?? '')
          .where((id) => id.isNotEmpty),
    );
    // Saved cards are mounted independently of search and recently viewed
    // cards, so they must fetch the current interest state themselves.
    // Otherwise a pending/accepted candidate can incorrectly offer a new
    // interest request until another screen happens to hydrate the store.
    final interestStates = await _employerInterestStates(client, user.id);
    EmployerInterestStateStore.instance.hydrate(interestStates);
    return _candidateListFromTrackedRows(
      savedRows,
      saved: true,
      interestStates: interestStates,
    );
  }

  Future<void> recordCandidateView(String candidateId) async {
    final client = _client;
    final user = _requireUser(client);
    if (candidateId.isEmpty) return;
    await _ensureCurrentProfileNotBlocked(client);
    await client.from('employer_candidate_views').upsert({
      'employer_id': user.id,
      'candidate_id': candidateId,
      'viewed_at': DateTime.now().toUtc().toIso8601String(),
    }, onConflict: 'employer_id,candidate_id');
  }

  Future<List<EmployerCandidate>> recentlyViewedCandidates({
    int limit = 10,
  }) async {
    final client = _client;
    final user = _requireUser(client);
    await _ensureCurrentProfileNotBlocked(client);
    final rows = await client
        .from('employer_candidate_views')
        .select('candidate_id,viewed_at')
        .eq('employer_id', user.id)
        .order('viewed_at', ascending: false)
        .limit(limit);
    final savedIds = await _savedCandidateIds(client, user.id);
    EmployerSavedStateStore.instance.hydrate(savedIds);
    return _candidateListFromTrackedRows(
      rows,
      savedIds: savedIds,
      interestStates: await _employerInterestStates(client, user.id),
    );
  }

  Future<Map<String, String>> _employerInterestStates(
    SupabaseClient client,
    String employerId,
  ) async {
    final rows = await client
        .from('interest_requests')
        .select('candidate_id,status,created_at')
        .eq('employer_id', employerId)
        .order('created_at', ascending: false);
    final states = <String, String>{};
    for (final row in rows) {
      final id = row['candidate_id'] as String? ?? '';
      if (id.isNotEmpty && !states.containsKey(id)) {
        states[id] = row['status'] as String? ?? '';
      }
    }
    return states;
  }

  Future<Set<String>> _savedCandidateIds(
    SupabaseClient client,
    String employerId,
  ) async {
    final rows = await client
        .from('saved_candidates')
        .select('candidate_id')
        .eq('employer_id', employerId);
    return rows
        .map((row) => row['candidate_id'] as String? ?? '')
        .where((id) => id.isNotEmpty)
        .toSet();
  }

  Future<List<EmployerCandidate>> _candidateListFromTrackedRows(
    List<dynamic> trackedRows, {
    bool saved = false,
    Set<String> savedIds = const {},
    Map<String, String> interestStates = const {},
  }) async {
    final ids = trackedRows
        .map(
          (row) =>
              (row as Map<String, dynamic>)['candidate_id'] as String? ?? '',
        )
        .where((id) => id.isNotEmpty)
        .toList();
    if (ids.isEmpty) return const [];
    final rows = await _client
        .from('public_candidate_search')
        .select()
        .inFilter('id', ids);
    final byId = {
      for (final row in rows)
        row['id'] as String: Map<String, dynamic>.from(row),
    };
    return ids
        .where(byId.containsKey)
        .map(
          (id) => _candidateFromPublicRow(
            byId[id]!,
            savedIds: saved ? {id} : savedIds,
            interestStatus: interestStates[id],
          ),
        )
        .toList();
  }

  EmployerCandidate _candidateFromPublicRow(
    Map<String, dynamic> row, {
    Set<String> savedIds = const {},
    String? interestStatus,
  }) {
    final skills = _stringList(row['skills']);
    final categories = _stringList(row['job_categories']);
    final languages = _stringList(row['languages']);
    final candidateId = row['id'] as String?;
    return EmployerCandidate(
      id: _displayCandidateName(row['full_name'] as String?),
      role: row['headline'] as String? ??
          (categories.isNotEmpty ? categories.join(', ') : 'Candidate'),
      location: CandidateLocationOptions.format(
        row['current_country'] as String?,
        row['current_city'] as String?,
      ),
      expectedSalary: _salaryRange(row),
      availability: row['availability'] as String? ?? 'Availability not set',
      experience: '${row['experience_years'] ?? 0} years experience',
      previousRole: categories.join(', '),
      skills: skills.isEmpty ? categories : skills,
      languages: languages,
      savedDate: 'Saved from Supabase',
      allowedName: row['full_name'] as String?,
      profilePhotoUrl: row['profile_photo_url'] as String?,
      about: row['bio'] as String? ?? '',
      candidateProfileId: candidateId,
      mainCategory: categories.isEmpty ? '' : categories.first,
      currentLocation: CandidateLocationOptions.format(
        row['current_country'] as String?,
        row['current_city'] as String?,
      ),
      preferredLocation: CandidateLocationOptions.format(
        row['preferred_country'] as String?,
        row['preferred_city'] as String?,
      ),
      visaStatus: row['visa_status'] as String? ?? '',
      verificationStatus:
          (row['verification_status'] as String? ?? '').trim().toLowerCase(),
      isSaved: candidateId != null && savedIds.contains(candidateId),
      interestStatus: interestStatus,
    );
  }

  String _salaryRange(Map<String, dynamic> row) {
    return formatCandidateSalary(
      currency: row['currency'] as String? ?? 'AED',
      minimum: row['expected_salary_min'] as num?,
      maximum: row['expected_salary_max'] as num?,
    );
  }
}

String formatCandidateSalary({
  String currency = 'AED',
  num? minimum,
  num? maximum,
}) {
  String amount(num value) {
    final digits = value.round().toString();
    return digits.replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
      (_) => ',',
    );
  }

  final unit = currency.trim().isEmpty ? 'AED' : currency.trim().toUpperCase();
  if (minimum == null && maximum == null) return 'Not specified';
  if (minimum == null) return '$unit ${amount(maximum!)}';
  if (maximum == null || minimum == maximum) {
    return '$unit ${amount(minimum)}';
  }
  return '$unit ${amount(minimum)}–${amount(maximum)}';
}

class EmployerCandidateSearchMatcher {
  const EmployerCandidateSearchMatcher._();

  static bool matches(
    Map<String, dynamic> row,
    EmployerCandidateSearchFilters filters,
  ) {
    final searchable = [
      row['full_name'] as String? ?? '',
      row['headline'] as String? ?? '',
      row['current_city'] as String? ?? '',
      row['preferred_city'] as String? ?? '',
      row['current_country'] as String? ?? '',
      row['preferred_country'] as String? ?? '',
      row['availability'] as String? ?? '',
      row['bio'] as String? ?? '',
      ..._stringList(row['job_categories']),
      ..._stringList(row['skills']),
      ..._stringList(row['languages']),
    ].join(' ').toLowerCase();
    final query = filters.query.trim().toLowerCase();
    if (query.isNotEmpty && !searchable.contains(query)) return false;

    if (!_overlaps(
      _stringList(row['job_categories']),
      filters.effectiveCategories,
    )) {
      return false;
    }
    if (!_overlaps(_stringList(row['skills']), filters.effectiveSkills)) {
      return false;
    }
    if (filters.effectiveLocations.isNotEmpty &&
        !filters.effectiveLocations.any(
          (location) => _matchesLocation(row, location),
        )) {
      return false;
    }
    if (!_valueIn(
      row['visa_status'] as String? ?? '',
      filters.effectiveVisaStatuses,
    )) {
      return false;
    }
    if (!_valueIn(
      row['availability'] as String? ?? '',
      filters.effectiveAvailabilities,
    )) {
      return false;
    }
    if (!_valueIn(
      row['nationality'] as String? ?? '',
      filters.effectiveNationalities,
    )) {
      return false;
    }
    if (!_overlaps(_stringList(row['languages']), filters.effectiveLanguages)) {
      return false;
    }
    if (filters.verifiedOnly &&
        (row['is_verified'] as bool? ?? false) == false) {
      return false;
    }
    if (filters.effectiveExperiences.isNotEmpty) {
      final years = (row['experience_years'] as num?) ?? 0;
      final matchesExperience = filters.effectiveExperiences.any((experience) {
        if (experience == '3+ years') return years >= 3;
        if (experience == '5+ years') return years >= 5;
        if (experience == 'Fresher') return years <= 0;
        return false;
      });
      if (!matchesExperience) return false;
    }
    if (filters.minimumSalary != null || filters.maximumSalary != null) {
      final candidateMinimum = row['expected_salary_min'] as num?;
      final candidateMaximum = row['expected_salary_max'] as num?;
      if (candidateMinimum != null || candidateMaximum != null) {
        final candidateLow = candidateMinimum ?? candidateMaximum!;
        final candidateHigh = candidateMaximum ?? candidateMinimum!;
        final filterLow = filters.minimumSalary ?? 0;
        final filterHigh = filters.maximumSalary ?? 1 << 30;
        if (candidateHigh < filterLow || candidateLow > filterHigh) {
          return false;
        }
      }
    }
    return true;
  }

  static bool _matchesLocation(Map<String, dynamic> row, String location) {
    final selected = location.trim().toLowerCase();
    if (selected.isEmpty) return true;
    final preferred = [
      row['preferred_country'] as String? ?? '',
      row['preferred_city'] as String? ?? '',
    ].join(' ').toLowerCase();
    final current = [
      row['current_country'] as String? ?? '',
      row['current_city'] as String? ?? '',
    ].join(' ').toLowerCase();
    if (selected == 'uae') {
      return preferred.contains('uae') ||
          preferred.contains('both') ||
          current.contains('uae');
    }
    if (selected == 'india') {
      return preferred.contains('india') ||
          preferred.contains('both') ||
          current.contains('india');
    }
    if (selected == 'both') {
      return preferred.contains('uae') ||
          preferred.contains('india') ||
          preferred.contains('both') ||
          current.contains('uae') ||
          current.contains('india');
    }
    return preferred.contains(selected) || current.contains(selected);
  }

  static bool _overlaps(List<String> rowValues, List<String> selectedValues) {
    if (selectedValues.isEmpty) return true;
    final normalizedRows = rowValues.map(_normalize).toSet();
    return selectedValues.map(_normalize).any(normalizedRows.contains);
  }

  static bool _valueIn(String rowValue, List<String> selectedValues) {
    if (selectedValues.isEmpty) return true;
    final normalized = _normalize(rowValue);
    return selectedValues.map(_normalize).contains(normalized);
  }

  static String _normalize(String value) => value.trim().toLowerCase();
}

class InterestAlreadySentException implements Exception {
  const InterestAlreadySentException();
}

class InterestRepository {
  const InterestRepository();

  SupabaseClient get _client => _requireClient();

  Future<List<InterestRequest>> candidateRequests() async {
    final client = _client;
    final user = _requireUser(client);
    final rows = await client
        .from('interest_requests')
        .select(
          'id,status,message,job_title,salary_range,work_location,working_hours,accommodation_provided,transport_provided,visa_support,created_at,employer_companies(company_name,industry,city,logo_url,is_verified)',
        )
        .eq('candidate_id', user.id)
        .order('created_at', ascending: false);
    return rows.map(_candidateRequestFromRow).toList();
  }

  Future<List<EmployerInterestRequest>> employerRequests() async {
    final client = _client;
    final user = _requireUser(client);
    _debugEmployerInterests(stage: 'load_started', employerId: user.id);
    List<Map<String, dynamic>> rows;
    try {
      final result = await client
          .from('interest_requests')
          .select(_employerInterestSelect(structured: true))
          .eq('employer_id', user.id)
          .order('created_at', ascending: false);
      rows = result.map((row) => Map<String, dynamic>.from(row)).toList();
    } on PostgrestException catch (error) {
      _debugEmployerInterests(
        stage: 'structured_request_load_failed',
        employerId: user.id,
        safeErrorCode: error.code ?? 'postgrest',
      );
      final result = await client
          .from('interest_requests')
          .select(_employerInterestSelect(structured: false))
          .eq('employer_id', user.id)
          .order('created_at', ascending: false);
      rows = result.map((row) => Map<String, dynamic>.from(row)).toList();
    }
    _debugEmployerInterests(
      stage: 'request_rows_loaded',
      employerId: user.id,
      count: rows.length,
    );

    final candidateIds = rows
        .map((row) => row['candidate_id'] as String? ?? '')
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList();
    final candidateRows = <String, Map<String, dynamic>>{};
    if (candidateIds.isNotEmpty) {
      final result = await client
          .from('public_candidate_search')
          .select()
          .inFilter('id', candidateIds);
      for (final row in result) {
        final candidate = Map<String, dynamic>.from(row);
        final id = candidate['id'] as String? ?? '';
        if (id.isNotEmpty) candidateRows[id] = candidate;
      }
    }
    _debugEmployerInterests(
      stage: 'candidate_mapping_loaded',
      employerId: user.id,
      count: candidateRows.length,
    );
    return rows
        .map(
          (row) =>
              _employerRequestFromRow(row, candidateRows[row['candidate_id']]),
        )
        .toList();
  }

  Future<void> sendInterest({
    required String candidateId,
    required String jobTitle,
    required String salaryRange,
    required String location,
    required String workingHours,
    required String message,
    required bool accommodationProvided,
    required bool transportProvided,
    required bool visaSupport,
  }) async {
    final client = _client;
    final user = _requireUser(client);
    if (candidateId.isEmpty) {
      throw ArgumentError('Candidate ID is missing.');
    }

    final company = await client
        .from('employer_companies')
        .select('id')
        .eq('owner_id', user.id)
        .limit(1)
        .maybeSingle();
    if (company == null) {
      throw StateError(
        'Create and save your company profile before sending interest.',
      );
    }

    final existing = await client
        .from('interest_requests')
        .select('id')
        .eq('company_id', company['id'])
        .eq('candidate_id', candidateId)
        .limit(1)
        .maybeSingle();
    if (existing != null) throw const InterestAlreadySentException();

    try {
      await client.from('interest_requests').insert({
        'employer_id': user.id,
        'company_id': company['id'],
        'candidate_id': candidateId,
        'job_title': _nullable(jobTitle),
        'salary_range': _nullable(salaryRange),
        'work_location': _nullable(location),
        'working_hours': _nullable(workingHours),
        'accommodation_provided': accommodationProvided,
        'transport_provided': transportProvided,
        'visa_support': visaSupport,
        'message': _nullable(message),
      });
    } on PostgrestException catch (error) {
      if (error.code == '23505') throw const InterestAlreadySentException();
      rethrow;
    }
  }

  Future<void> respondToInterest({
    required String requestId,
    required bool accepted,
  }) async {
    if (requestId.isEmpty) {
      throw ArgumentError('Request ID is missing.');
    }
    await _ensureCurrentProfileNotBlocked(_client);
    await _client.from('interest_requests').update(
        {'status': accepted ? 'accepted' : 'rejected'}).eq('id', requestId);
  }

  InterestRequest _candidateRequestFromRow(Map<String, dynamic> row) {
    final company = row['employer_companies'] as Map<String, dynamic>? ?? {};
    final message = row['message'] as String? ?? '';
    final accommodation = _supportLabel(
      row['accommodation_provided'],
      message,
      legacyLabel: 'Accommodation',
    );
    final transport = _supportLabel(
      row['transport_provided'],
      message,
      legacyLabel: 'Transport',
    );
    final visa = _supportLabel(
      row['visa_support'],
      message,
      legacyLabel: 'Visa support',
    );
    return InterestRequest(
      id: row['id'] as String?,
      status: row['status'] as String? ?? 'pending',
      company: _displayEmployerName(company['company_name'] as String?),
      role: _requestValue(
        row['job_title'],
        message,
        'Role',
        fallback: 'Not specified',
      )!,
      salary: _requestValue(
        row['salary_range'],
        message,
        'Salary',
        fallback: 'Not specified',
      )!,
      location: _requestValue(row['work_location'], message, 'Location') ??
          _clean(company['city'] as String?) ??
          'Not specified',
      message: _requestMessage(message),
      date: row['created_at'] as String? ?? '',
      industry: company['industry'] as String? ?? 'Company',
      hours: _requestValue(
        row['working_hours'],
        message,
        'Hours',
        fallback: 'Not specified',
      )!,
      support: [
        if (accommodation.isNotEmpty) 'Accommodation: $accommodation',
        if (transport.isNotEmpty) 'Transport: $transport',
        if (visa.isNotEmpty) 'Visa Support: $visa',
      ].join(', '),
      accommodation: accommodation,
      transport: transport,
      visaSupport: visa,
      companyLogoUrl: company['logo_url'] as String? ?? '',
      companyVerified: company['is_verified'] as bool? ?? false,
    );
  }

  EmployerInterestRequest _employerRequestFromRow(
    Map<String, dynamic> row,
    Map<String, dynamic>? candidate,
  ) {
    final message = row['message'] as String? ?? '';
    final candidateId = row['candidate_id'] as String? ?? '';
    final candidateRow = candidate ?? const <String, dynamic>{};
    final location = CandidateLocationOptions.format(
      candidateRow['current_country'] as String?,
      candidateRow['current_city'] as String?,
    );
    return EmployerInterestRequest(
      id: row['id'] as String?,
      candidateId: candidateId,
      role: candidateRow['headline'] as String? ?? 'Candidate',
      jobTitle: _requestValue(
        row['job_title'],
        message,
        'Role',
        fallback: 'Not specified',
      )!,
      salary: _requestValue(
        row['salary_range'],
        message,
        'Salary',
        fallback: 'Not specified',
      )!,
      location: _requestValue(row['work_location'], message, 'Location') ??
          (location.isEmpty ? 'Not specified' : location),
      workingHours: _requestValue(
        row['working_hours'],
        message,
        'Hours',
        fallback: 'Not specified',
      )!,
      message: _requestMessage(message),
      status: row['status'] as String? ?? 'pending',
      sentDate: row['created_at'] as String? ?? '',
      candidateName: _displayCandidateName(
        candidateRow['full_name'] as String?,
      ),
      candidatePhotoUrl: candidateRow['profile_photo_url'] as String? ?? '',
      experience:
          '${(candidateRow['experience_years'] as num?)?.toInt() ?? 0} years experience',
      availability: candidateRow['availability'] as String? ?? '',
      accommodation: _supportLabel(
        row['accommodation_provided'],
        message,
        legacyLabel: 'Accommodation',
      ),
      transport: _supportLabel(
        row['transport_provided'],
        message,
        legacyLabel: 'Transport',
      ),
      visaSupport: _supportLabel(
        row['visa_support'],
        message,
        legacyLabel: 'Visa support',
      ),
    );
  }
}

String _employerInterestSelect({required bool structured}) {
  const base = 'id,status,message,created_at,candidate_id';
  if (!structured) return base;
  return [
    base,
    'job_title',
    'salary_range',
    'work_location',
    'working_hours',
    'accommodation_provided',
    'transport_provided',
    'visa_support',
  ].join(',');
}

void _debugEmployerInterests({
  required String stage,
  required String employerId,
  int? count,
  String? safeErrorCode,
}) {
  if (!kDebugMode) return;
  final idHint =
      employerId.length <= 8 ? employerId : employerId.substring(0, 8);
  final countText = count == null ? '' : ' count=$count';
  final errorText = safeErrorCode == null ? '' : ' code=$safeErrorCode';
  debugPrint(
    '[EmployerInterests] stage=$stage employer=$idHint$countText$errorText',
  );
}

class MatchRepository {
  const MatchRepository();

  SupabaseClient get _client => _requireClient();

  Future<List<MatchItem>> candidateMatches() async {
    final client = _client;
    _requireUser(client);
    final result = await client.rpc('candidate_matches_with_access');
    final rows = List<Map<String, dynamic>>.from(result as List);
    return rows.map((row) {
      final chatEnabled = row['chat_enabled'] as bool? ?? false;
      final contactRevealed = row['contact_revealed'] as bool? ?? false;
      return MatchItem(
        id: row['match_id'] as String?,
        company: row['company_name'] as String? ?? 'Matched company',
        role: row['role'] as String? ?? 'Matched role',
        location: row['location'] as String? ?? '',
        status: 'Matched',
        preview: chatEnabled
            ? contactRevealed
                ? 'Contact details shared with this employer.'
                : 'Chat is available. Contact reveal is optional.'
            : 'Upgrade Candidate Membership to chat with matched employers and reveal your contact details.',
        chatEnabled: chatEnabled,
        canRevealContact: row['can_reveal_contact'] as bool? ?? false,
        contactRevealed: contactRevealed,
      );
    }).toList();
  }

  /// Loads match metadata and all message summaries in two bounded queries.
  Future<List<CandidateConversation>> candidateConversations() async {
    final client = _client;
    final user = _requireUser(client);
    final matches = await candidateMatches();
    final matchIds = matches
        .map((match) => match.id ?? '')
        .where((id) => id.isNotEmpty)
        .toList();
    if (matchIds.isEmpty) return const [];
    final rows = await client
        .from('chat_messages')
        .select('match_id,sender_id,body,is_read,created_at')
        .inFilter('match_id', matchIds)
        .order('created_at', ascending: false);
    final latestByMatch = <String, Map<String, dynamic>>{};
    final unreadByMatch = <String, int>{};
    for (final row in rows) {
      final message = Map<String, dynamic>.from(row);
      final matchId = message['match_id'] as String? ?? '';
      if (matchId.isEmpty) continue;
      latestByMatch.putIfAbsent(matchId, () => message);
      final isIncoming = message['sender_id'] != user.id;
      final isRead = message['is_read'] as bool? ?? false;
      if (isIncoming && !isRead) {
        unreadByMatch[matchId] = (unreadByMatch[matchId] ?? 0) + 1;
      }
    }
    return matches.map((match) {
      final message = latestByMatch[match.id];
      return CandidateConversation(
        match: match,
        lastMessage: message?['body'] as String? ?? '',
        lastMessageAt:
            DateTime.tryParse(message?['created_at'] as String? ?? ''),
        unreadCount: unreadByMatch[match.id] ?? 0,
      );
    }).toList();
  }

  Future<List<EmployerMatch>> employerMatches() async {
    final client = _client;
    _requireUser(client);
    final result = await client.rpc('employer_matches_with_contact');
    final rows = List<Map<String, dynamic>>.from(result as List);
    final candidateIds = rows
        .map((row) => row['candidate_id'] as String? ?? '')
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList();
    final photoRows = candidateIds.isEmpty
        ? const <Map<String, dynamic>>[]
        : await client
            .from('public_candidate_search')
            .select('id,profile_photo_url')
            .inFilter('id', candidateIds);
    final photoPathByCandidate = {
      for (final row in photoRows)
        row['id'] as String: row['profile_photo_url'] as String? ?? '',
    };
    return rows.map((row) {
      final candidateId = row['candidate_id'] as String? ?? '';
      final chatEnabled = row['chat_enabled'] as bool? ?? false;
      final contactRevealed = row['contact_revealed'] as bool? ?? false;
      return EmployerMatch(
        matchId: row['match_id'] as String?,
        candidateId: candidateId.isEmpty
            ? 'Candidate'
            : 'Candidate #${candidateId.substring(0, 8)}',
        name: row['display_name'] as String? ??
            (candidateId.isEmpty
                ? 'Candidate'
                : 'Candidate #${candidateId.substring(0, 8)}'),
        role: row['role'] as String? ?? 'Candidate',
        location: row['location'] as String? ?? '',
        status: 'Matched',
        lastMessage: chatEnabled
            ? contactRevealed
                ? 'Contact details revealed.'
                : 'Chat available. Contact details still hidden.'
            : 'Contact details unavailable.',
        matchDate: row['matched_at'] as String? ?? '',
        unreadCount: 0,
        chatEnabled: chatEnabled,
        contactRevealed: contactRevealed,
        phone: row['phone'] as String? ?? '',
        email: row['email'] as String? ?? '',
        candidateProfileId: candidateId,
        profilePhotoUrl: photoPathByCandidate[candidateId] ?? '',
      );
    }).toList();
  }

  Future<void> revealCandidateContact(String matchId) async {
    if (matchId.isEmpty) throw ArgumentError('Match ID is missing.');
    await _ensureCurrentProfileNotBlocked(_client);
    await _client.rpc(
      'reveal_candidate_contact',
      params: {'target_match_id': matchId},
    );
  }
}

class ChatRepository implements ChatGateway {
  const ChatRepository();

  SupabaseClient get _client => _requireClient();

  @override
  Future<bool> resolveAccess(String matchId) async {
    if (matchId.isEmpty) return false;
    final client = _client;
    _requireUser(client);
    await _ensureCurrentProfileNotBlocked(client);
    return await client.rpc(
          'match_chat_enabled',
          params: {'target_match_id': matchId},
        ) as bool? ??
        false;
  }

  @override
  Future<List<Map<String, dynamic>>> loadMessages(String matchId) async {
    if (matchId.isEmpty) return const [];
    final rows = await _client
        .from('chat_messages')
        .select('id,match_id,sender_id,body,is_read,created_at')
        .eq('match_id', matchId)
        .order('created_at');
    return List<Map<String, dynamic>>.from(rows);
  }

  @override
  Stream<List<Map<String, dynamic>>> realtimeMessages(String matchId) {
    if (matchId.isEmpty) return const Stream.empty();
    return _client
        .from('chat_messages')
        .stream(primaryKey: ['id'])
        .eq('match_id', matchId)
        .order('created_at')
        .map((rows) => rows.cast<Map<String, dynamic>>());
  }

  @override
  Future<ChatSendResult> sendMessage({
    required String matchId,
    required String body,
    required String messageId,
  }) async {
    final client = _client;
    final user = _requireUser(client);
    if (matchId.isEmpty) {
      throw ArgumentError('Match ID is missing.');
    }
    if (body.trim().isEmpty) {
      throw ArgumentError('Message cannot be empty.');
    }
    await _ensureCurrentProfileNotBlocked(client);
    final access = await resolveAccess(matchId);
    if (!access) {
      throw StateError(
        'Chat is available only when the matched candidate has an active membership.',
      );
    }

    try {
      final row = await client
          .from('chat_messages')
          .insert({
            'id': messageId,
            'match_id': matchId,
            'sender_id': user.id,
            'body': body.trim(),
          })
          .select('id,match_id,sender_id,body,is_read,created_at')
          .single();
      return ChatSendResult.success(Map<String, dynamic>.from(row));
    } on PostgrestException catch (error) {
      if (error.code == '23505') {
        final existing = await findMessageById(
          matchId: matchId,
          messageId: messageId,
        );
        if (existing != null) return ChatSendResult.success(existing);
      }
      const conclusiveClientErrors = {
        '22001', // value too long
        '22P02', // invalid input
        '23503', // invalid match/sender reference
        '23514', // check constraint
        '42501', // row-level security / permission denied
      };
      return conclusiveClientErrors.contains(error.code)
          ? const ChatSendResult.permanentFailure()
          : const ChatSendResult.uncertain();
    } on TimeoutException {
      return const ChatSendResult.uncertain();
    } catch (_) {
      return const ChatSendResult.uncertain();
    }
  }

  @override
  Future<Map<String, dynamic>?> findMessageById({
    required String matchId,
    required String messageId,
  }) async {
    final row = await _client
        .from('chat_messages')
        .select('id,match_id,sender_id,body,is_read,created_at')
        .eq('match_id', matchId)
        .eq('id', messageId)
        .maybeSingle();
    return row == null ? null : Map<String, dynamic>.from(row);
  }
}

class KaamStorageRepository {
  const KaamStorageRepository();

  SupabaseClient get _client => _requireClient();

  Future<KaamUploadResult> uploadPublicFile({
    required List<int> bytes,
    required String fileName,
    required String folder,
  }) async {
    return _upload(
      bucket: 'kaam-public',
      folder: folder,
      bytes: bytes,
      fileName: fileName,
      publicFile: true,
    );
  }

  Future<KaamUploadResult> uploadPrivateFile({
    required List<int> bytes,
    required String fileName,
    required String folder,
  }) async {
    return _upload(
      bucket: 'kaam-private',
      folder: folder,
      bytes: bytes,
      fileName: fileName,
      publicFile: false,
    );
  }

  Future<KaamUploadResult> uploadCandidateIdentityDocument({
    required List<int> bytes,
    required String fileName,
    required String documentType,
  }) async {
    await _ensureCurrentProfileNotBlocked(_client);
    final extension = fileName.contains('.') ? fileName.split('.').last : 'bin';
    final safeType = documentType.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '-');
    final safeName =
        '${safeType}_${DateTime.now().millisecondsSinceEpoch}.${extension.toLowerCase()}';
    return _upload(
      bucket: 'kaam-private',
      folder: 'candidate-documents/$safeType',
      bytes: bytes,
      fileName: safeName,
      publicFile: false,
    );
  }

  Future<String> signedPrivateUrl(String path) async {
    if (path.trim().isEmpty) {
      throw ArgumentError('Document path is missing.');
    }
    return _client.storage.from('kaam-private').createSignedUrl(path, 60 * 10);
  }

  Future<void> recordVerificationDocument({
    required String documentType,
    required KaamUploadResult upload,
    String? companyId,
  }) async {
    final client = _client;
    final user = _requireUser(client);
    await _ensureCurrentProfileNotBlocked(client);
    await client.from('verification_documents').insert({
      'owner_id': user.id,
      'company_id': companyId,
      'document_type': documentType,
      'bucket_id': upload.bucket,
      'file_path': upload.path,
      'status': 'pending',
    });
  }

  Future<List<VerificationDocumentData>> listMyDocuments() async {
    final client = _client;
    final user = _requireUser(client);
    final rows = await client
        .from('verification_documents')
        .select('id,document_type,bucket_id,file_path,status')
        .eq('owner_id', user.id)
        .order('created_at', ascending: false);
    return rows.map(VerificationDocumentData.fromRow).toList();
  }

  Future<KaamUploadResult> _upload({
    required String bucket,
    required String folder,
    required List<int> bytes,
    required String fileName,
    required bool publicFile,
  }) async {
    final client = _client;
    final user = _requireUser(client);
    if (bytes.isEmpty) {
      throw ArgumentError('Selected file is empty.');
    }

    final safeName = fileName.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    final path =
        '${user.id}/$folder/${DateTime.now().millisecondsSinceEpoch}_$safeName';
    await client.storage.from(bucket).uploadBinary(
          path,
          Uint8List.fromList(bytes),
          fileOptions: const FileOptions(upsert: true),
        );
    final publicUrl =
        publicFile ? client.storage.from(bucket).getPublicUrl(path) : null;
    _debug('Uploaded $folder file to $bucket');
    return KaamUploadResult(
      bucket: bucket,
      path: path,
      displayName: fileName,
      publicUrl: publicUrl,
    );
  }
}

SupabaseClient _requireClient() {
  final client = SupabaseService.maybeClient;
  if (client == null) {
    throw StateError(
      'Supabase is not configured. Check SUPABASE_URL and SUPABASE_ANON_KEY.',
    );
  }
  return client;
}

User _requireUser(SupabaseClient client) {
  if (KaamAuthSessionCoordinator.blocksSessionRestore) {
    throw StateError('Please sign in again before continuing.');
  }
  final user = client.auth.currentUser;
  if (user == null) {
    throw StateError('Please sign in again before continuing.');
  }
  return user;
}

Future<KaamProfileBootstrapResult> _bootstrapUserProfile(
  SupabaseClient client, {
  required KaamRole role,
}) async {
  final row = await client.rpc('bootstrap_user_profile',
      params: {'selected_role': role.name}).single();
  return KaamProfileBootstrapResult.fromRow(Map<String, dynamic>.from(row));
}

Future<void> _ensureCurrentProfileNotBlocked(SupabaseClient client) async {
  final user = _requireUser(client);
  final row = await client
      .from('profiles')
      .select('status')
      .eq('id', user.id)
      .maybeSingle();
  if (KaamAccountStatusPolicy.isBlocked(row?['status'] as String?)) {
    await KaamAuthSessionCoordinator.beginExplicitLogout();
    try {
      await KaamPushNotificationService.instance.deactivateCurrentDevice();
      await client.auth.signOut(scope: SignOutScope.global);
      await KaamAuthSessionCoordinator.finishExplicitLogout();
    } catch (_) {
      await KaamAuthSessionCoordinator.abandonExplicitLogout();
      rethrow;
    }
    throw StateError(KaamAccountStatusPolicy.blockedMessage);
  }
}

Future<void> _ensureCandidateProfileRow(
  SupabaseClient client,
  String userId,
) async {
  final existing = await client
      .from('candidate_profiles')
      .select('id')
      .eq('id', userId)
      .maybeSingle();
  if (existing != null) {
    _debugCandidateProfile(
      stage: 'candidate_parent_row_found',
      userId: userId,
      fields: const ['id'],
    );
    return;
  }

  try {
    await client.from('candidate_profiles').insert({'id': userId});
    _debugCandidateProfile(
      stage: 'candidate_parent_row_created',
      userId: userId,
      fields: const ['id'],
    );
  } on PostgrestException catch (error) {
    if (error.code == '23505') {
      _debugCandidateProfile(
        stage: 'candidate_parent_row_reused_after_conflict',
        userId: userId,
        fields: const ['id'],
      );
      return;
    }
    _debugCandidateProfile(
      stage: 'candidate_parent_row_create_failed',
      userId: userId,
      safeErrorCode: error.code ?? 'postgrest',
    );
    rethrow;
  }
}

String _safePostgrestCode(Object error) {
  if (error is PostgrestException) return error.code ?? 'postgrest';
  return error.runtimeType.toString();
}

bool _savedBasicProfileMatches(
  CandidateProfileData profile, {
  required String fullName,
  required String phone,
  required String nationality,
  required String currentCountry,
  required String currentLocation,
  required String preferredCountry,
  required String preferredLocation,
}) {
  bool same(String left, String right) =>
      left.trim().toLowerCase() == right.trim().toLowerCase();

  final normalizedCurrentCountry =
      CandidateLocationOptions.normalizeCountry(currentCountry);
  final normalizedPreferredCountry =
      CandidateLocationOptions.normalizeCountry(preferredCountry);
  final normalizedCurrentLocation =
      CandidateLocationOptions.normalizeRegionForCountry(
    normalizedCurrentCountry,
    currentLocation,
  );
  final normalizedPreferredLocation =
      CandidateLocationOptions.normalizeRegionForCountry(
    normalizedPreferredCountry,
    preferredLocation,
  );
  return same(profile.fullName, fullName) &&
      same(profile.phone, phone) &&
      same(profile.nationality, nationality) &&
      same(profile.currentCountry, normalizedCurrentCountry) &&
      same(profile.currentCity, normalizedCurrentLocation) &&
      same(profile.preferredCountry, normalizedPreferredCountry) &&
      same(profile.preferredCity, normalizedPreferredLocation);
}

KaamRole? _roleFromMetadata(Object? value) {
  final roleName = value?.toString().trim();
  if (roleName == null || roleName.isEmpty) return null;
  for (final role in KaamRole.values) {
    if (role.name == roleName) return role;
  }
  return null;
}

void _debugCandidateProfile({
  required String stage,
  required String userId,
  Iterable<String>? fields,
  String? safeErrorCode,
}) {
  if (!kDebugMode) return;
  final idHint = userId.length <= 8 ? userId : userId.substring(0, 8);
  final fieldText = fields == null ? '' : ' fields=${fields.join(',')}';
  final errorText = safeErrorCode == null ? '' : ' code=$safeErrorCode';
  debugPrint(
    '[CandidateProfile] stage=$stage user=$idHint$fieldText$errorText',
  );
}

void _debugSkillExperience({required String stage, required int count}) {
  if (!kDebugMode) return;
  debugPrint('[CandidateSkills] stage=$stage selected_count=$count');
}

void _debugVisaStatus({
  required String stage,
  required String normalizedStatus,
  String? field,
  String? safeErrorCode,
}) {
  if (!kDebugMode) return;
  final fieldText = field == null ? '' : ' field=$field';
  final statusText =
      normalizedStatus.isEmpty ? 'empty' : ' normalized=$normalizedStatus';
  final errorText = safeErrorCode == null ? '' : ' code=$safeErrorCode';
  debugPrint('[CandidateVisa] stage=$stage$fieldText$statusText$errorText');
}

String? _nullable(String value) {
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}

List<String> _stringList(dynamic value) {
  if (value is List) {
    return value
        .map((item) => item.toString())
        .where((item) => item.trim().isNotEmpty)
        .toList();
  }
  if (value is String && value.trim().isNotEmpty) return [value.trim()];
  return const [];
}

List<String> splitCsv(String value) {
  return value
      .split(',')
      .map((item) => item.trim())
      .where((item) => item.isNotEmpty)
      .toList();
}

int? parseFirstInt(String value) {
  final match = RegExp(r'\d+').firstMatch(value.replaceAll(',', ''));
  return match == null ? null : int.tryParse(match.group(0)!);
}

int? parseLastInt(String value) {
  final matches = RegExp(r'\d+').allMatches(value.replaceAll(',', '')).toList();
  return matches.isEmpty ? null : int.tryParse(matches.last.group(0)!);
}

String? _extractLine(String message, String label) {
  final match = RegExp(
    '^$label:\\s*(.+)\$',
    multiLine: true,
  ).firstMatch(message);
  return match?.group(1)?.trim();
}

String _displayCandidateName(String? value) {
  final cleaned = _clean(value);
  if (cleaned == null) return 'Candidate';
  if (cleaned.toLowerCase().startsWith('candidate #')) return 'Candidate';
  return cleaned;
}

String _displayEmployerName(String? value) =>
    _clean(value) ?? 'Verified Employer';

String? _clean(String? value) {
  final trimmed = value?.trim() ?? '';
  return trimmed.isEmpty ? null : trimmed;
}

String? _requestValue(
  dynamic columnValue,
  String message,
  String legacyLabel, {
  String? fallback,
}) {
  final direct = columnValue is String ? _clean(columnValue) : null;
  return direct ?? _extractLine(message, legacyLabel) ?? fallback;
}

String _requestMessage(String message) {
  final cleaned = message
      .split('\n')
      .where((line) {
        final trimmed = line.trim();
        if (trimmed.isEmpty) return true;
        return !RegExp(
          r'^(Role|Salary|Location|Hours|Accommodation|Transport|Visa support):',
          caseSensitive: false,
        ).hasMatch(trimmed);
      })
      .join('\n')
      .trim();
  return cleaned;
}

String _supportLabel(
  dynamic value,
  String legacyMessage, {
  required String legacyLabel,
}) {
  if (value is bool) return value ? 'Provided' : 'Not provided';
  final legacy = _extractLine(legacyMessage, legacyLabel);
  if (legacy == null) return '';
  final normalized = legacy.trim().toLowerCase();
  if (normalized == 'yes' || normalized == 'provided') return 'Provided';
  if (normalized == 'no' || normalized == 'not provided') return 'Not provided';
  return legacy.trim();
}

KaamRole _roleFromName(String value) {
  for (final role in KaamRole.values) {
    if (role.name == value) return role;
  }
  return KaamRole.candidate;
}

bool _candidateOnboardingComplete(Map<String, dynamic>? row) {
  if (row == null) return false;
  final categories = _stringList(row['job_categories']);
  return (row['nationality'] as String? ?? '').trim().isNotEmpty &&
      CandidateLocationOptions.isComplete(
        row['current_country'] as String?,
        row['current_city'] as String?,
      ) &&
      CandidateLocationOptions.isComplete(
        row['preferred_country'] as String?,
        row['preferred_city'] as String?,
      ) &&
      categories.isNotEmpty &&
      (row['headline'] as String? ?? '').trim().isNotEmpty &&
      (row['availability'] as String? ?? '').trim().isNotEmpty;
}

void _debug(String message) {
  if (kDebugMode) {
    debugPrint('Kaam Supabase: $message');
  }
}
