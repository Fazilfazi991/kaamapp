import 'package:flutter/material.dart';

import 'core/constants/app_routes.dart';
import 'core/remote_config/app_remote_config.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/account_access_screen.dart';
import 'features/auth/delete_account_screen.dart';
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
import 'features/candidate/onboarding/profile_media_screen.dart';
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
  const KaamApp({
    super.key,
    this.initialRoute = AppRoutes.sessionRouting,
    this.startupConfigurationError,
    required this.remoteConfig,
  });

  final String initialRoute;
  final String? startupConfigurationError;
  final AppRemoteConfigService remoteConfig;

  @override
  Widget build(BuildContext context) {
    final configurationError = startupConfigurationError;
    if (configurationError != null) {
      return MaterialApp(
        title: 'Kaam - Perfect Match',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.dark(),
        home: StartupConfigurationErrorScreen(message: configurationError),
      );
    }

    return AnimatedBuilder(
      animation: remoteConfig,
      builder: (context, _) {
        if (remoteConfig.config.maintenanceMode) {
          return MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: AppTheme.dark(),
            home: MaintenanceScreen(
              config: remoteConfig.config,
              onRetry: remoteConfig.refresh,
            ),
          );
        }
        return MaterialApp(
          navigatorKey: KaamPushNotificationService.navigatorKey,
          title: 'Kaam - Perfect Match',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.dark(),
          initialRoute: initialRoute,
          routes: {
            AppRoutes.home: (_) => const HomeScreen(),
            AppRoutes.sessionRouting: (_) => const SessionRoutingScreen(),
            AppRoutes.welcome: (_) => const WelcomeScreen(),
            AppRoutes.accountAccess: (_) => const AccountAccessScreen(),
            AppRoutes.roleSelection: (_) => const RoleSelectionScreen(),
            AppRoutes.login: (_) => const LoginScreen(),
            AppRoutes.otp: (_) => const OtpVerificationScreen(),
            AppRoutes.accountBlocked: (_) => const BlockedAccountScreen(),
            AppRoutes.basicDetails: (_) =>
                _candidate(const BasicDetailsScreen()),
            AppRoutes.editBasicDetails: (_) =>
                _candidate(const BasicDetailsScreen.forProfileEdit()),
            AppRoutes.workPreferences: (_) =>
                _candidate(const WorkPreferencesScreen()),
            AppRoutes.skillsExperience: (_) =>
                _candidate(const SkillsExperienceScreen()),
            AppRoutes.profileMedia: (_) =>
                _candidate(const ProfileMediaScreen()),
            AppRoutes.primaryProfession: (_) =>
                _candidate(const PrimaryProfessionScreen()),
            AppRoutes.skillDetails: (_) =>
                _candidate(const SkillDetailsScreen()),
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
            AppRoutes.profile: (_) =>
                _candidate(const CandidateProfileScreen()),
            AppRoutes.editProfile: (_) => _candidate(const EditProfileScreen()),
            AppRoutes.requests: (_) =>
                _candidate(const InterestRequestsScreen()),
            AppRoutes.requestDetails: (_) =>
                _candidate(const InterestRequestDetailsScreen()),
            AppRoutes.matchUnlocked: (_) =>
                _candidate(const MatchUnlockedScreen()),
            AppRoutes.matches: (_) => _candidate(const MatchesScreen()),
            AppRoutes.chatList: (_) => _candidate(const ChatListScreen()),
            AppRoutes.privateChat: (_) => _candidate(const PrivateChatScreen()),
            AppRoutes.scheduleInterview: (_) =>
                _candidate(const ScheduleInterviewScreen()),
            AppRoutes.profileViews: (_) =>
                _candidate(const ProfileViewsScreen()),
            AppRoutes.notifications: (_) =>
                _candidate(const NotificationsScreen()),
            AppRoutes.availability: (_) =>
                _candidate(const AvailabilityStatusScreen()),
            AppRoutes.privacyVisibility: (_) =>
                _candidate(const PrivacyVisibilityScreen()),
            AppRoutes.loginSecurity: (_) =>
                _candidate(const LoginSecurityScreen()),
            AppRoutes.languageSettings: (_) =>
                _candidate(const LanguageSettingsScreen()),
            AppRoutes.helpSupport: (_) => _candidate(const HelpSupportScreen()),
            AppRoutes.accountSettings: (_) =>
                _candidate(const AccountSettingsScreen()),
            AppRoutes.deleteAccount: (_) => const DeleteAccountScreen(),
            AppRoutes.qaTools: (_) => const QaToolsScreen(),
            ...EmployerRoutes.routes,
          },
        );
      },
    );
  }

  static Widget _candidate(Widget child) {
    return ProtectedAccountRoute(role: KaamRole.candidate, child: child);
  }
}

class MaintenanceScreen extends StatelessWidget {
  const MaintenanceScreen(
      {super.key, required this.config, required this.onRetry});
  final AppRemoteConfig config;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: const Color(0xFF070A18),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.build_circle_outlined,
                    color: Color(0xFFED5AA6), size: 56),
                const SizedBox(height: 20),
                Text(config.maintenanceTitle,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 26,
                        fontWeight: FontWeight.w800)),
                const SizedBox(height: 12),
                Text(config.maintenanceMessage,
                    textAlign: TextAlign.center,
                    style:
                        const TextStyle(color: Color(0xFFD7D9E8), height: 1.5)),
                const SizedBox(height: 24),
                FilledButton(onPressed: onRetry, child: const Text('Retry')),
              ],
            ),
          ),
        ),
      );
}

class StartupConfigurationErrorScreen extends StatelessWidget {
  const StartupConfigurationErrorScreen({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF070A18),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Build configuration required',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    message,
                    style: const TextStyle(
                      color: Color(0xFFD7D9E8),
                      fontSize: 16,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Rebuild from the primary KAAM APP folder with valid ignored environment files. No secret values are shown here.',
                    style: TextStyle(
                      color: Color(0xFF9EA4BE),
                      fontSize: 14,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
