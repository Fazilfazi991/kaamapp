import 'package:flutter/material.dart';

import '../../../core/constants/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/screen_scaffold.dart';
import '../../qa/qa_mode.dart';
import '../../supabase_backend/kaam_backend.dart';
import '../data/employer_dummy_data.dart';

class EmployerNotificationsScreen extends StatelessWidget {
  const EmployerNotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ScreenScaffold(
      title: 'Notifications',
      showBack: true,
      children: [
        ...EmployerDummyData.notifications.map((item) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: AppCard(
                padding: const EdgeInsets.all(16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.notifications_active_outlined,
                        color: AppColors.primaryPink),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(item.title, style: AppTextStyles.label),
                          const SizedBox(height: 4),
                          Text(item.body, style: AppTextStyles.body),
                          const SizedBox(height: 4),
                          Text(item.time, style: AppTextStyles.muted),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            )),
      ],
    );
  }
}

class EmployerSettingsScreen extends StatelessWidget {
  const EmployerSettingsScreen({super.key});

  Future<void> _logout(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Are you sure you want to log out?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Logout')),
        ],
      ),
    );
    if (confirmed != true) return;
    await const KaamAuthRepository().signOut();
    if (!context.mounted) return;
    Navigator.of(context)
        .pushNamedAndRemoveUntil(AppRoutes.roleSelection, (_) => false);
  }

  @override
  Widget build(BuildContext context) {
    final items = [
      (
        Icons.business_outlined,
        'Company profile',
        AppRoutes.employerCompanyProfile
      ),
      (
        Icons.verified_outlined,
        'Verification',
        AppRoutes.employerVerificationStatus
      ),
      (
        Icons.work_history_outlined,
        'Hiring Requirements',
        AppRoutes.employerHiringRequirements
      ),
      (Icons.group_outlined, 'Team members', AppRoutes.employerTeamMembers),
      (
        Icons.notifications_outlined,
        'Notifications',
        AppRoutes.employerNotifications
      ),
      (
        Icons.privacy_tip_outlined,
        'Privacy & hiring rules',
        AppRoutes.employerRules
      ),
      (
        Icons.help_outline_rounded,
        'Help & support',
        AppRoutes.employerDashboard
      ),
      if (QaMode.enabled)
        (Icons.build_circle_outlined, 'QA Tools', AppRoutes.qaTools),
    ];
    return ScreenScaffold(
      title: 'Settings',
      showBack: true,
      children: [
        ...items.map((item) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: AppCard(
                onTap: () => Navigator.of(context).pushNamed(item.$3),
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(item.$1, color: AppColors.primaryPink),
                    const SizedBox(width: 12),
                    Expanded(
                        child: Text(item.$2,
                            style: AppTextStyles.body
                                .copyWith(color: AppColors.white))),
                    const Icon(Icons.chevron_right_rounded,
                        color: AppColors.mutedText),
                  ],
                ),
              ),
            )),
        AppCard(
          onTap: () => _logout(context),
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              const Icon(Icons.logout_rounded, color: AppColors.primaryPink),
              const SizedBox(width: 12),
              Expanded(
                  child: Text('Logout',
                      style:
                          AppTextStyles.body.copyWith(color: AppColors.white))),
              const Icon(Icons.chevron_right_rounded,
                  color: AppColors.mutedText),
            ],
          ),
        ),
      ],
    );
  }
}
