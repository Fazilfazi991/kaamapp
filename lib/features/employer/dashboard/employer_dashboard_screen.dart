import 'package:flutter/material.dart';

import '../../../core/constants/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/screen_scaffold.dart';
import '../../../core/widgets/section_header.dart';
import '../../../core/widgets/status_badge.dart';
import '../../supabase_backend/kaam_backend.dart';
import '../widgets/employer_widgets.dart';

class EmployerDashboardScreen extends StatefulWidget {
  const EmployerDashboardScreen({super.key});

  @override
  State<EmployerDashboardScreen> createState() => _EmployerDashboardScreenState();
}

class _EmployerDashboardScreenState extends State<EmployerDashboardScreen> {
  final repository = const EmployerRepository();
  late Future<EmployerCompanyData?> companyFuture = repository.loadMyCompany();

  @override
  Widget build(BuildContext context) {
    return ScreenScaffold(
      title: 'Kaam',
      bottomNavigationBar: const EmployerBottomNav(currentIndex: 0),
      actions: [
        IconButton(
          tooltip: 'Search candidates',
          onPressed: () => Navigator.of(context).pushNamed(AppRoutes.employerCandidateSearch),
          icon: const Icon(Icons.search_rounded),
        ),
        IconButton(
          tooltip: 'Notifications',
          onPressed: () => Navigator.of(context).pushNamed(AppRoutes.employerNotifications),
          icon: const Icon(Icons.notifications_outlined),
        ),
      ],
      children: [
        FutureBuilder<EmployerCompanyData?>(
          future: companyFuture,
          builder: (context, snapshot) {
            final name = snapshot.data?.companyName;
            final verified = snapshot.data?.isVerified ?? false;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name == null || name.isEmpty ? 'Welcome' : 'Welcome, $name',
                  style: AppTextStyles.headline,
                ),
                const SizedBox(height: 10),
                StatusBadge(
                  label: verified ? 'Approved' : 'Pending Review',
                  color: verified ? AppColors.success : AppColors.warning,
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 8),
        AppCard(
          onTap: () => Navigator.of(context).pushNamed(AppRoutes.employerCandidateSearch),
          padding: const EdgeInsets.all(14),
          child: const Row(
            children: [
              Icon(Icons.search_rounded, color: AppColors.primaryPink),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Search candidates by skill, role or location',
                  style: AppTextStyles.body,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 22),
        const SectionHeader(title: 'Home Menu'),
        const SizedBox(height: 10),
        EmployerQuickActionCard(
          title: 'Hiring Requirements',
          subtitle: 'Add or manage your hiring needs.',
          icon: Icons.work_history_outlined,
          onTap: () => Navigator.of(context).pushNamed(AppRoutes.employerHiringRequirements),
        ),
        const SizedBox(height: 10),
        EmployerQuickActionCard(
          title: 'Sent Interests',
          subtitle: 'Track pending, accepted, rejected, and withdrawn requests.',
          icon: Icons.outbox_rounded,
          onTap: () => Navigator.of(context).pushNamed(AppRoutes.employerSentRequests),
        ),
        const SizedBox(height: 10),
        EmployerQuickActionCard(
          title: 'View Matches',
          subtitle: 'Open accepted candidates, unread messages, and active chats.',
          icon: Icons.handshake_rounded,
          onTap: () => Navigator.of(context).pushNamed(AppRoutes.employerMatches),
        ),
        const SizedBox(height: 10),
        EmployerQuickActionCard(
          title: 'Company Profile',
          subtitle: 'Save company details and verification documents.',
          icon: Icons.business_outlined,
          onTap: () => Navigator.of(context).pushNamed(AppRoutes.employerCompanyProfile),
        ),
        const SizedBox(height: 18),
        const AppCard(
          color: AppColors.elevatedCard,
          child: Text(
            'Candidate phone, email, and private documents stay hidden before an accepted match.',
            style: AppTextStyles.body,
          ),
        ),
      ],
    );
  }
}
