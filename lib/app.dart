import 'package:flutter/material.dart';

import 'core/constants/app_routes.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/blocked_account_screen.dart';
import 'features/auth/login_screen.dart';
import 'features/auth/otp_verification_screen.dart';
import 'features/auth/role_selection_screen.dart';
import 'features/auth/welcome_screen.dart';
import 'features/candidate/chat/chat_list_screen.dart';
import 'features/candidate/chat/private_chat_screen.dart';
import 'features/candidate/chat/schedule_interview_screen.dart';
import 'features/candidate/dashboard/candidate_dashboard_screen.dart';
import 'features/candidate/documents/identity_document_review_screen.dart';
import 'features/candidate/documents/identity_document_viewer_screen.dart';
import 'features/candidate/matches/match_unlocked_screen.dart';
import 'features/candidate/matches/matches_screen.dart';
import 'features/candidate/membership/membership_plans_screen.dart';
import 'features/candidate/onboarding/basic_details_screen.dart';
import 'features/candidate/onboarding/documents_upload_screen.dart';
import 'features/candidate/onboarding/privacy_settings_setup_screen.dart';
import 'features/candidate/onboarding/profile_complete_screen.dart';
import 'features/candidate/onboarding/skills_experience_screen.dart';
import 'features/candidate/onboarding/skill_selection_screen.dart';
import 'features/candidate/onboarding/work_preferences_screen.dart';
import 'features/candidate/profile/candidate_profile_screen.dart';
import 'features/candidate/profile/edit_profile_screen.dart';
import 'features/candidate/requests/interest_request_details_screen.dart';
import 'features/candidate/requests/interest_requests_screen.dart';
import 'features/candidate/settings/account_settings_screen.dart';
import 'features/candidate/settings/availability_status_screen.dart';
import 'features/candidate/settings/help_support_screen.dart';
import 'features/candidate/settings/language_settings_screen.dart';
import 'features/candidate/settings/login_security_screen.dart';
import 'features/candidate/settings/notifications_screen.dart';
import 'features/candidate/settings/privacy_visibility_screen.dart';
import 'features/candidate/views/profile_views_screen.dart';
import 'features/employer/employer_routes.dart';
import 'features/home/home_screen.dart';
import 'features/notifications/push_notification_service.dart';
import 'features/qa/qa_tools_screen.dart';
import 'features/supabase_backend/kaam_backend.dart';

class KaamApp extends StatelessWidget {
  const KaamApp({super.key, this.initialRoute = AppRoutes.welcome});

  final String initialRoute;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: KaamPushNotificationService.navigatorKey,
      title: 'Kaam - Perfect Match',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark(),
      initialRoute: initialRoute,
      routes: {
        AppRoutes.home: (_) => const HomeScreen(),
        AppRoutes.welcome: (_) => const WelcomeScreen(),
        AppRoutes.roleSelection: (_) => const RoleSelectionScreen(),
        AppRoutes.login: (_) => const LoginScreen(),
        AppRoutes.otp: (_) => const OtpVerificationScreen(),
        AppRoutes.accountBlocked: (_) => const BlockedAccountScreen(),
        AppRoutes.basicDetails: (_) => _candidate(const BasicDetailsScreen()),
        AppRoutes.workPreferences: (_) =>
            _candidate(const WorkPreferencesScreen()),
        AppRoutes.skillsExperience: (_) =>
            _candidate(const SkillsExperienceScreen()),
        AppRoutes.primaryProfession: (_) =>
            _candidate(const PrimaryProfessionScreen()),
        AppRoutes.skillDetails: (_) => _candidate(const SkillDetailsScreen()),
        AppRoutes.documentsUpload: (_) =>
            _candidate(const DocumentsUploadScreen()),
        AppRoutes.identityDocumentReview: (_) =>
            _candidate(const IdentityDocumentReviewScreen()),
        AppRoutes.identityDocumentViewer: (_) =>
            _candidate(const IdentityDocumentViewerScreen()),
        AppRoutes.privacySetup: (_) =>
            _candidate(const PrivacySettingsSetupScreen()),
        AppRoutes.profileComplete: (_) =>
            _candidate(const ProfileCompleteScreen()),
        AppRoutes.dashboard: (_) =>
            _candidate(const CandidateDashboardScreen()),
        AppRoutes.membershipPlans: (_) =>
            _candidate(const MembershipPlansScreen()),
        AppRoutes.profile: (_) => _candidate(const CandidateProfileScreen()),
        AppRoutes.editProfile: (_) => _candidate(const EditProfileScreen()),
        AppRoutes.requests: (_) => _candidate(const InterestRequestsScreen()),
        AppRoutes.requestDetails: (_) =>
            _candidate(const InterestRequestDetailsScreen()),
        AppRoutes.matchUnlocked: (_) => _candidate(const MatchUnlockedScreen()),
        AppRoutes.matches: (_) => _candidate(const MatchesScreen()),
        AppRoutes.chatList: (_) => _candidate(const ChatListScreen()),
        AppRoutes.privateChat: (_) => _candidate(const PrivateChatScreen()),
        AppRoutes.scheduleInterview: (_) =>
            _candidate(const ScheduleInterviewScreen()),
        AppRoutes.profileViews: (_) => _candidate(const ProfileViewsScreen()),
        AppRoutes.notifications: (_) => _candidate(const NotificationsScreen()),
        AppRoutes.availability: (_) =>
            _candidate(const AvailabilityStatusScreen()),
        AppRoutes.privacyVisibility: (_) =>
            _candidate(const PrivacyVisibilityScreen()),
        AppRoutes.loginSecurity: (_) => _candidate(const LoginSecurityScreen()),
        AppRoutes.languageSettings: (_) =>
            _candidate(const LanguageSettingsScreen()),
        AppRoutes.helpSupport: (_) => _candidate(const HelpSupportScreen()),
        AppRoutes.accountSettings: (_) =>
            _candidate(const AccountSettingsScreen()),
        AppRoutes.qaTools: (_) => const QaToolsScreen(),
        ...EmployerRoutes.routes,
      },
    );
  }

  static Widget _candidate(Widget child) {
    return ProtectedAccountRoute(role: KaamRole.candidate, child: child);
  }
}
