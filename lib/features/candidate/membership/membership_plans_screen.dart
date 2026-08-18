import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../core/constants/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/candidate_widgets.dart';
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
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not activate membership. Please try again.'),
        ),
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
            if (snapshot.connectionState == ConnectionState.waiting &&
                !snapshot.hasData) {
              return const AppCard(
                child: Center(child: CircularProgressIndicator()),
              );
            }
            final membership = snapshot.hasError
                ? const CandidateMembershipData(loadFailed: true)
                : snapshot.data ?? const CandidateMembershipData();
            final presentation =
                CandidateMembershipPresentation.resolve(membership);
            final canActivate =
                presentation.state == CandidateMembershipState.inactive ||
                    presentation.state == CandidateMembershipState.expired;
            return AppCard(
              borderColor:
                  presentation.isActive ? AppColors.success : AppColors.border,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Candidate Membership',
                    style: AppTextStyles.title,
                  ),
                  const SizedBox(height: 12),
                  CandidateMembershipBadge(membership: membership),
                  const SizedBox(height: 16),
                  Text(
                    presentation.visibilityMessage,
                    style: AppTextStyles.body,
                  ),
                  const SizedBox(height: 16),
                  const _PlanBenefit('Secure chat after an accepted match'),
                  const _PlanBenefit('Optional contact reveal after matching'),
                  const _PlanBenefit('Membership duration: 30 days'),
                  const SizedBox(height: 18),
                  if (presentation.state == CandidateMembershipState.unknown)
                    SecondaryButton(
                      label: presentation.primaryActionLabel ?? 'Retry',
                      onPressed: _reload,
                      icon: Icons.refresh_rounded,
                    )
                  else if (kDebugMode && canActivate)
                    PrimaryButton(
                      label: activating
                          ? 'Activating...'
                          : presentation.primaryActionLabel ??
                              'Activate Membership',
                      icon: Icons.science_rounded,
                      onPressed:
                          activating ? null : () => _activateTestMembership(),
                    )
                  else if (canActivate)
                    const SecondaryButton(
                      label: 'Membership Payments Coming Soon',
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
          onPressed: () => Navigator.of(
            context,
          ).pushNamedAndRemoveUntil(AppRoutes.dashboard, (_) => false),
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
          const Icon(
            Icons.check_circle_rounded,
            color: AppColors.success,
            size: 18,
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(label, style: AppTextStyles.body)),
        ],
      ),
    );
  }
}
