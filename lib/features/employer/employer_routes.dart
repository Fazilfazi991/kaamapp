import 'package:flutter/material.dart';

import '../../core/constants/app_routes.dart';
import '../auth/blocked_account_screen.dart';
import '../supabase_backend/kaam_backend.dart';
import 'auth/employer_auth_screens.dart';
import 'chat/employer_chat_screens.dart';
import 'company/employer_company_screens.dart';
import 'dashboard/employer_dashboard_screen.dart';
import 'hiring/employer_hiring_requirement_screens.dart';
import 'interests/employer_interest_screens.dart';
import 'matches/employer_match_screens.dart';
import 'onboarding/employer_onboarding_screens.dart';
import 'search/employer_search_screens.dart';
import 'settings/employer_settings_screens.dart';

class EmployerRoutes {
  const EmployerRoutes._();

  static Map<String, WidgetBuilder> routes = {
    AppRoutes.employerSplash: (_) => const EmployerSplashScreen(),
    AppRoutes.employerLogin: (_) => const EmployerLoginScreen(),
    AppRoutes.employerOtp: (_) => const EmployerOtpScreen(),
    AppRoutes.employerOnboardingOverview: (_) =>
        _employer(const EmployerOnboardingOverviewScreen()),
    AppRoutes.employerCompanyDetails: (_) =>
        _employer(const CompanyDetailsScreen()),
    AppRoutes.employerBusinessVerification: (_) =>
        _employer(const BusinessVerificationScreen()),
    AppRoutes.employerRules: (_) => _employer(const EmployerRulesScreen()),
    AppRoutes.employerProfileComplete: (_) =>
        _employer(const EmployerProfileCompleteScreen()),
    AppRoutes.employerDashboard: (_) =>
        _employer(const EmployerDashboardScreen()),
    AppRoutes.employerCandidateSearch: (_) =>
        _employer(const CandidateSearchScreen()),
    AppRoutes.employerAdvancedFilters: (_) =>
        _employer(const AdvancedFiltersScreen()),
    AppRoutes.employerCandidateProfile: (_) =>
        _employer(const CandidateProfilePreviewScreen()),
    AppRoutes.employerSavedCandidates: (_) =>
        _employer(const SavedCandidatesScreen()),
    AppRoutes.employerHiringRequirements: (_) =>
        _employer(const HiringRequirementsScreen()),
    AppRoutes.employerAddHiringRequirement: (_) =>
        _employer(const AddHiringRequirementScreen()),
    AppRoutes.employerSendInterest: (_) =>
        _employer(const SendInterestScreen()),
    AppRoutes.employerInterestSent: (_) =>
        _employer(const InterestSentConfirmationScreen()),
    AppRoutes.employerSentRequests: (_) =>
        _employer(const SentInterestRequestsScreen()),
    AppRoutes.employerRequestDetails: (_) =>
        _employer(const EmployerInterestRequestDetailsScreen()),
    AppRoutes.employerMatchUnlocked: (_) =>
        _employer(const EmployerMatchUnlockedScreen()),
    AppRoutes.employerMatches: (_) => _employer(const EmployerMatchesScreen()),
    AppRoutes.employerPipeline: (_) => _employer(const HiringPipelineScreen()),
    AppRoutes.employerChatList: (_) =>
        _employer(const EmployerChatListScreen()),
    AppRoutes.employerPrivateChat: (_) =>
        _employer(const EmployerPrivateChatScreen()),
    AppRoutes.employerScheduleInterview: (_) =>
        _employer(const EmployerScheduleInterviewScreen()),
    AppRoutes.employerCompanyProfile: (_) =>
        _employer(const CompanyProfileScreen()),
    AppRoutes.employerEditCompanyProfile: (_) =>
        _employer(const EditCompanyProfileScreen()),
    AppRoutes.employerVerificationStatus: (_) =>
        _employer(const VerificationStatusScreen()),
    AppRoutes.employerTeamMembers: (_) => _employer(const TeamMembersScreen()),
    AppRoutes.employerNotifications: (_) =>
        _employer(const EmployerNotificationsScreen()),
    AppRoutes.employerSettings: (_) =>
        _employer(const EmployerSettingsScreen()),
  };

  static Widget _employer(Widget child) {
    return ProtectedAccountRoute(role: KaamRole.employer, child: child);
  }
}
