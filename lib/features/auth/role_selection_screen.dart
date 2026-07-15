import 'package:flutter/material.dart';

import '../../core/constants/app_routes.dart';
import '../../core/supabase/supabase_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/primary_button.dart';
import '../../core/widgets/secondary_button.dart';
import '../supabase_backend/kaam_backend.dart';

class RoleSelectionScreen extends StatefulWidget {
  const RoleSelectionScreen({super.key});

  @override
  State<RoleSelectionScreen> createState() => _RoleSelectionScreenState();
}

class _RoleSelectionScreenState extends State<RoleSelectionScreen> {
  KaamRole? selectedRole;
  bool navigating = false;

  Future<void> _continue() async {
    if (navigating || selectedRole == null) return;
    setState(() => navigating = true);
    try {
      await SupabaseService.waitForSessionRecovery();
      if (!mounted) return;
      const auth = KaamAuthRepository();
      if (auth.currentUser == null) {
        final route = selectedRole == KaamRole.candidate ? AppRoutes.login : AppRoutes.employerLogin;
        await Navigator.of(context).pushNamed(route, arguments: {'role': selectedRole});
        return;
      }
      final result = await auth.resolvePostOtpDestination(fallbackRole: selectedRole!);
      if (!mounted) return;
      final route = switch (result.destination) {
        KaamAuthDestination.roleSelection => AppRoutes.roleSelection,
        KaamAuthDestination.candidateOnboarding => AppRoutes.documentsUpload,
        KaamAuthDestination.candidateDashboard => AppRoutes.dashboard,
        KaamAuthDestination.employerOnboarding => AppRoutes.employerOnboardingOverview,
        KaamAuthDestination.employerDashboard => AppRoutes.employerDashboard,
      };
      Navigator.of(context).pushNamed(route);
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not continue: $error')));
    } finally {
      if (mounted) setState(() => navigating = false);
    }
  }

  void _openLogin() {
    if (navigating) return;
    setState(() => navigating = true);
    Navigator.of(context).pushNamed(AppRoutes.login).whenComplete(() {
      if (mounted) setState(() => navigating = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final isCandidate = selectedRole == KaamRole.candidate;
    final isEmployer = selectedRole == KaamRole.employer;
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
          children: [
        const Center(
          child: Text.rich(
            TextSpan(
              text: "Let's start ",
              style: AppTextStyles.headline,
              children: [
                TextSpan(
                  text: 'your journey',
                  style: TextStyle(color: AppColors.primaryPink),
                ),
              ],
            ),
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: 10),
        const Center(
          child: Text(
            'Choose how you want to use KAAM. Your privacy is protected from the first step.',
            style: AppTextStyles.body,
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: 26),
        SizedBox(
          height: 286,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: _JourneyCard(
                  title: 'Find Work',
                  subtitle: 'Create a private profile',
                  icon: Icons.work_outline_rounded,
                  color: AppColors.primaryPink,
                  selected: isCandidate,
                  onTap: () =>
                      setState(() => selectedRole = KaamRole.candidate),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _JourneyCard(
                  title: 'Hire Talent',
                  subtitle: 'Discover skilled professionals',
                  icon: Icons.business_center_outlined,
                  color: AppColors.accentPurple,
                  selected: isEmployer,
                  onTap: () => setState(() => selectedRole = KaamRole.employer),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        PrimaryButton(
          label: navigating
              ? 'Opening...'
              : isCandidate
                  ? 'Continue to find work'
                  : isEmployer
                      ? 'Continue to hire talent'
                      : 'Select how you want to continue',
          onPressed: navigating || selectedRole == null ? null : _continue,
        ),
        const SizedBox(height: 22),
        const Row(
          children: [
            Expanded(child: Divider(color: AppColors.border)),
            Padding(
                padding: EdgeInsets.symmetric(horizontal: 12),
                child: Text('or', style: AppTextStyles.muted)),
            Expanded(child: Divider(color: AppColors.border)),
          ],
        ),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            children: [
              const Icon(Icons.account_circle_outlined,
                  color: AppColors.softPink, size: 30),
              const SizedBox(height: 10),
              const Text('Already registered?', style: AppTextStyles.title),
              const SizedBox(height: 5),
              const Text('Sign in to continue your journey.',
                  style: AppTextStyles.body, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              SecondaryButton(
                label: 'Log In',
                icon: Icons.login_rounded,
                onPressed: navigating ? null : _openLogin,
              ),
            ],
          ),
        ),
        const SizedBox(height: 22),
        const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.lock_outline, color: AppColors.softPink, size: 18),
            SizedBox(width: 8),
            Flexible(
                child: Text('Your privacy is important. We keep it protected.',
                    style: AppTextStyles.muted)),
          ],
        ),
          ],
        ),
      ),
    );
  }
}

class _JourneyCard extends StatelessWidget {
  const _JourneyCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: title,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            color: selected ? color.withValues(alpha: .11) : AppColors.card,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
                color: selected ? color : AppColors.border,
                width: selected ? 1.6 : 1),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Align(
                alignment: Alignment.topRight,
                child: Icon(
                    selected ? Icons.check_circle : Icons.circle_outlined,
                    color: selected ? color : AppColors.mutedText),
              ),
              Container(
                padding: const EdgeInsets.all(11),
                decoration: BoxDecoration(
                    color: color.withValues(alpha: .18),
                    shape: BoxShape.circle),
                child: Icon(icon, color: color),
              ),
              const SizedBox(height: 22),
              Text(title, style: AppTextStyles.title.copyWith(fontSize: 18)),
              const SizedBox(height: 6),
              Text(subtitle, style: AppTextStyles.muted),
              const SizedBox(height: 14),
              Row(
                children: [
                  Icon(Icons.shield_outlined, color: color, size: 16),
                  const SizedBox(width: 6),
                  Expanded(
                      child: Text('Details stay private until a match',
                          style: AppTextStyles.muted.copyWith(fontSize: 11))),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
