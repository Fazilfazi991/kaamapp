import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../core/constants/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/widgets/screen_scaffold.dart';
import '../../../core/widgets/secondary_button.dart';
import '../../supabase_backend/kaam_backend.dart';

class MembershipPlansScreen extends StatefulWidget {
  const MembershipPlansScreen({super.key});

  @override
  State<MembershipPlansScreen> createState() => _MembershipPlansScreenState();
}

class _MembershipPlansScreenState extends State<MembershipPlansScreen> {
  final repository = const CandidateProfileRepository();
  late Future<CandidateMembershipData> membershipFuture =
      repository.loadMembership();
  bool activating = false;

  void _reload() {
    setState(() => membershipFuture = repository.loadMembership());
  }

  Future<void> _activateTestMembership() async {
    setState(() => activating = true);
    try {
      await repository.activateTestMembership();
      _reload();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Test membership activated for 30 days.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not activate test membership: $error')),
      );
    } finally {
      if (mounted) setState(() => activating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ScreenScaffold(
      title: 'Membership',
      showBack: true,
      children: [
        FutureBuilder<CandidateMembershipData>(
          future: membershipFuture,
          builder: (context, snapshot) {
            final membership = snapshot.data ?? const CandidateMembershipData();
            return AppCard(
              borderColor:
                  membership.isActive ? AppColors.success : AppColors.border,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.workspace_premium_rounded,
                          color: AppColors.primaryPink),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Text('Premium Membership',
                            style: AppTextStyles.title),
                      ),
                      Text(
                        membership.isActive ? 'Active' : 'Coming Soon',
                        style: TextStyle(
                          color: membership.isActive
                              ? AppColors.success
                              : AppColors.secondaryText,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const _PlanBenefit('Visible in employer searches'),
                  const _PlanBenefit('Receive employer interest requests'),
                  const _PlanBenefit('Verified profile badge after approval'),
                  const _PlanBenefit('Membership duration: 30 days'),
                  if (membership.expiresAt.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text('Expires: ${membership.expiresAt}',
                        style: AppTextStyles.muted),
                  ],
                  const SizedBox(height: 18),
                  if (kDebugMode)
                    PrimaryButton(
                      label: activating
                          ? 'Activating...'
                          : 'Activate Test Membership',
                      icon: Icons.science_rounded,
                      onPressed:
                          activating ? null : () => _activateTestMembership(),
                    )
                  else
                    const SecondaryButton(
                      label: 'Payments Coming Soon',
                      onPressed: null,
                      icon: Icons.lock_outline_rounded,
                    ),
                ],
              ),
            );
          },
        ),
        const SizedBox(height: 14),
        SecondaryButton(
          label: 'Back to Dashboard',
          icon: Icons.dashboard_outlined,
          onPressed: () => Navigator.of(context)
              .pushNamedAndRemoveUntil(AppRoutes.dashboard, (_) => false),
        ),
      ],
    );
  }
}

class _PlanBenefit extends StatelessWidget {
  const _PlanBenefit(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.check_circle_rounded,
              color: AppColors.success, size: 18),
          const SizedBox(width: 8),
          Expanded(child: Text(label, style: AppTextStyles.body)),
        ],
      ),
    );
  }
}
