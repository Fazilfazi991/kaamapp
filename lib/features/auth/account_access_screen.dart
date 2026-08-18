import 'package:flutter/material.dart';

import '../../core/constants/app_routes.dart';
import '../../core/supabase/supabase_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/primary_button.dart';
import '../../core/widgets/secondary_button.dart';
import '../supabase_backend/kaam_backend.dart';

typedef SessionRouteResolver = Future<KaamAuthDestination?> Function();

class AccountAccessScreen extends StatefulWidget {
  const AccountAccessScreen({super.key});

  @override
  State<AccountAccessScreen> createState() => _AccountAccessScreenState();
}

class SessionRoutingScreen extends StatefulWidget {
  const SessionRoutingScreen({super.key, this.resolveDestination});

  final SessionRouteResolver? resolveDestination;

  @override
  State<SessionRoutingScreen> createState() => _SessionRoutingScreenState();
}

class _SessionRoutingScreenState extends State<SessionRoutingScreen> {
  @override
  void initState() {
    super.initState();
    _route();
  }

  Future<void> _route() async {
    try {
      final destination =
          await (widget.resolveDestination ?? _resolveDestination)();
      if (!mounted) return;
      _replace(
          destination == null ? AppRoutes.welcome : _routeFor(destination));
    } catch (_) {
      if (mounted) _replace(AppRoutes.welcome);
    }
  }

  static Future<KaamAuthDestination?> _resolveDestination() async {
    await SupabaseService.waitForSessionRecovery();
    const auth = KaamAuthRepository();
    if (auth.currentUser == null ||
        KaamAuthSessionCoordinator.blocksSessionRestore) {
      return null;
    }
    final role = await auth.currentBackendRole();
    if (role == null) return null;
    return (await auth.resolvePostOtpDestination(fallbackRole: role))
        .destination;
  }

  void _replace(String route) =>
      Navigator.of(context).pushNamedAndRemoveUntil(route, (_) => false);

  String _routeFor(KaamAuthDestination destination) => switch (destination) {
        KaamAuthDestination.roleSelection => AppRoutes.roleSelection,
        KaamAuthDestination.blocked => AppRoutes.accountBlocked,
        KaamAuthDestination.candidateOnboarding => AppRoutes.documentsUpload,
        KaamAuthDestination.candidateDashboard => AppRoutes.dashboard,
        KaamAuthDestination.employerOnboarding =>
          AppRoutes.employerOnboardingOverview,
        KaamAuthDestination.employerDashboard => AppRoutes.employerDashboard,
      };

  @override
  Widget build(BuildContext context) => const Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: AppColors.primaryPink),
        ),
      );
}

class _AccountAccessScreenState extends State<AccountAccessScreen> {
  bool checkingSession = true;
  bool startingRegister = false;

  @override
  void initState() {
    super.initState();
    _restoreExistingSession();
  }

  Future<void> _restoreExistingSession() async {
    try {
      await SupabaseService.waitForSessionRecovery();
      if (!mounted) return;
      const auth = KaamAuthRepository();
      if (auth.currentUser == null ||
          KaamAuthSessionCoordinator.blocksSessionRestore) {
        setState(() => checkingSession = false);
        return;
      }
      final role = await auth.currentBackendRole();
      if (!mounted) return;
      if (role == null) {
        setState(() => checkingSession = false);
        return;
      }
      final result = await auth.resolvePostOtpDestination(fallbackRole: role);
      if (!mounted) return;
      Navigator.of(
        context,
      ).pushNamedAndRemoveUntil(_routeFor(result.destination), (_) => false);
    } catch (_) {
      if (mounted) setState(() => checkingSession = false);
    }
  }

  Future<void> _openRegister() async {
    if (startingRegister) return;
    setState(() => startingRegister = true);
    try {
      await const KaamAuthRepository().prepareFreshRegistration();
      if (!mounted) return;
      Navigator.of(context).pushReplacementNamed(
        AppRoutes.roleSelection,
        arguments: {'freshRegistration': true},
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(KaamSafeErrorMessages.logout)),
      );
    } finally {
      if (mounted) setState(() => startingRegister = false);
    }
  }

  void _openLogin() {
    if (checkingSession || startingRegister) return;
    Navigator.of(context).pushReplacementNamed(AppRoutes.login);
  }

  String _routeFor(KaamAuthDestination destination) {
    return switch (destination) {
      KaamAuthDestination.roleSelection => AppRoutes.roleSelection,
      KaamAuthDestination.blocked => AppRoutes.accountBlocked,
      KaamAuthDestination.candidateOnboarding => AppRoutes.documentsUpload,
      KaamAuthDestination.candidateDashboard => AppRoutes.dashboard,
      KaamAuthDestination.employerOnboarding =>
        AppRoutes.employerOnboardingOverview,
      KaamAuthDestination.employerDashboard => AppRoutes.employerDashboard,
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.fromLTRB(24, 28, 24, 32),
              children: [
                const Text(
                  'Account access',
                  style: AppTextStyles.headline,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),
                const Text(
                  'Log in to continue, or create a new KAAM account.',
                  style: AppTextStyles.body,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 28),
                if (checkingSession) ...[
                  const Center(
                    child: CircularProgressIndicator(
                      color: AppColors.primaryPink,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Checking your account...',
                    style: AppTextStyles.muted,
                    textAlign: TextAlign.center,
                  ),
                ] else ...[
                  PrimaryButton(
                    label: 'Login',
                    icon: Icons.login_rounded,
                    onPressed: _openLogin,
                  ),
                  const SizedBox(height: 12),
                  SecondaryButton(
                    label: startingRegister ? 'Starting...' : 'Register',
                    icon: Icons.person_add_alt_1_rounded,
                    onPressed: startingRegister ? null : _openRegister,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
