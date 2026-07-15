import 'package:flutter/material.dart';

import '../../core/constants/app_routes.dart';
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
    AppRoutes.employerOnboardingOverview: (_) => const EmployerOnboardingOverviewScreen(),
    AppRoutes.employerCompanyDetails: (_) => const CompanyDetailsScreen(),
    AppRoutes.employerBusinessVerification: (_) => const BusinessVerificationScreen(),
    AppRoutes.employerRules: (_) => const EmployerRulesScreen(),
    AppRoutes.employerProfileComplete: (_) => const EmployerProfileCompleteScreen(),
    AppRoutes.employerDashboard: (_) => const EmployerDashboardScreen(),
    AppRoutes.employerCandidateSearch: (_) => const CandidateSearchScreen(),
    AppRoutes.employerAdvancedFilters: (_) => const AdvancedFiltersScreen(),
    AppRoutes.employerCandidateProfile: (_) => const CandidateProfilePreviewScreen(),
    AppRoutes.employerSavedCandidates: (_) => const SavedCandidatesScreen(),
    AppRoutes.employerHiringRequirements: (_) => const HiringRequirementsScreen(),
    AppRoutes.employerAddHiringRequirement: (_) => const AddHiringRequirementScreen(),
    AppRoutes.employerSendInterest: (_) => const SendInterestScreen(),
    AppRoutes.employerInterestSent: (_) => const InterestSentConfirmationScreen(),
    AppRoutes.employerSentRequests: (_) => const SentInterestRequestsScreen(),
    AppRoutes.employerRequestDetails: (_) => const EmployerInterestRequestDetailsScreen(),
    AppRoutes.employerMatchUnlocked: (_) => const EmployerMatchUnlockedScreen(),
    AppRoutes.employerMatches: (_) => const EmployerMatchesScreen(),
    AppRoutes.employerPipeline: (_) => const HiringPipelineScreen(),
    AppRoutes.employerChatList: (_) => const EmployerChatListScreen(),
    AppRoutes.employerPrivateChat: (_) => const EmployerPrivateChatScreen(),
    AppRoutes.employerScheduleInterview: (_) => const EmployerScheduleInterviewScreen(),
    AppRoutes.employerCompanyProfile: (_) => const CompanyProfileScreen(),
    AppRoutes.employerEditCompanyProfile: (_) => const EditCompanyProfileScreen(),
    AppRoutes.employerVerificationStatus: (_) => const VerificationStatusScreen(),
    AppRoutes.employerTeamMembers: (_) => const TeamMembersScreen(),
    AppRoutes.employerNotifications: (_) => const EmployerNotificationsScreen(),
    AppRoutes.employerSettings: (_) => const EmployerSettingsScreen(),
  };
}
