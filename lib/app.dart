import 'package:flutter/material.dart';

import 'core/constants/app_routes.dart';
import 'core/theme/app_theme.dart';
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
import 'features/qa/qa_tools_screen.dart';

class KaamApp extends StatelessWidget {
  const KaamApp({super.key, this.initialRoute = AppRoutes.welcome});

  final String initialRoute;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
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
        AppRoutes.basicDetails: (_) => const BasicDetailsScreen(),
        AppRoutes.workPreferences: (_) => const WorkPreferencesScreen(),
        AppRoutes.skillsExperience: (_) => const SkillsExperienceScreen(),
        AppRoutes.primaryProfession: (_) => const PrimaryProfessionScreen(),
        AppRoutes.skillDetails: (_) => const SkillDetailsScreen(),
        AppRoutes.documentsUpload: (_) => const DocumentsUploadScreen(),
        AppRoutes.identityDocumentReview: (_) =>
            const IdentityDocumentReviewScreen(),
        AppRoutes.identityDocumentViewer: (_) =>
            const IdentityDocumentViewerScreen(),
        AppRoutes.privacySetup: (_) => const PrivacySettingsSetupScreen(),
        AppRoutes.profileComplete: (_) => const ProfileCompleteScreen(),
        AppRoutes.dashboard: (_) => const CandidateDashboardScreen(),
        AppRoutes.membershipPlans: (_) => const MembershipPlansScreen(),
        AppRoutes.profile: (_) => const CandidateProfileScreen(),
        AppRoutes.editProfile: (_) => const EditProfileScreen(),
        AppRoutes.requests: (_) => const InterestRequestsScreen(),
        AppRoutes.requestDetails: (_) => const InterestRequestDetailsScreen(),
        AppRoutes.matchUnlocked: (_) => const MatchUnlockedScreen(),
        AppRoutes.matches: (_) => const MatchesScreen(),
        AppRoutes.chatList: (_) => const ChatListScreen(),
        AppRoutes.privateChat: (_) => const PrivateChatScreen(),
        AppRoutes.scheduleInterview: (_) => const ScheduleInterviewScreen(),
        AppRoutes.profileViews: (_) => const ProfileViewsScreen(),
        AppRoutes.notifications: (_) => const NotificationsScreen(),
        AppRoutes.availability: (_) => const AvailabilityStatusScreen(),
        AppRoutes.privacyVisibility: (_) => const PrivacyVisibilityScreen(),
        AppRoutes.loginSecurity: (_) => const LoginSecurityScreen(),
        AppRoutes.languageSettings: (_) => const LanguageSettingsScreen(),
        AppRoutes.helpSupport: (_) => const HelpSupportScreen(),
        AppRoutes.accountSettings: (_) => const AccountSettingsScreen(),
        AppRoutes.qaTools: (_) => const QaToolsScreen(),
        ...EmployerRoutes.routes,
      },
    );
  }
}
