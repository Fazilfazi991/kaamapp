import 'package:flutter/material.dart';

import '../../core/constants/app_routes.dart';
import '../../core/supabase/supabase_service.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/app_text_field.dart';
import '../../core/widgets/primary_button.dart';
import '../../core/widgets/screen_scaffold.dart';
import '../qa/qa_mode.dart';
import '../supabase_backend/kaam_backend.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, this.googleSignIn});

  final Future<KaamGoogleSignInResult> Function()? googleSignIn;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final contactController = TextEditingController();
  final auth = const KaamAuthRepository();
  bool loading = false;
  bool googleSignInInProgress = false;
  bool navigationCommitted = false;
  bool accountNotFound = false;
  int googleResolutionGeneration = 0;

  @override
  void dispose() {
    contactController.dispose();
    super.dispose();
  }

  Future<void> _continue() async {
    final requestedRole = _requestedRole;
    setState(() {
      loading = true;
      accountNotFound = false;
    });
    try {
      await SupabaseService.waitForSessionRecovery();
      await auth.signInWithOtp(
        email: contactController.text,
        role: requestedRole,
        freshRegistration: _freshRegistration,
      );
      if (!mounted) return;
      Navigator.of(context).pushReplacementNamed(
        AppRoutes.otp,
        arguments: {
          'email': contactController.text.trim().toLowerCase(),
          'role': requestedRole,
          'freshRegistration': _freshRegistration,
        },
      );
    } on KaamAccountNotFoundException {
      if (!mounted) return;
      setState(() => accountNotFound = true);
    } catch (_) {
      if (!mounted) return;
      if (!_freshRegistration && requestedRole == null) {
        setState(() => accountNotFound = true);
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'We could not send a verification code. Check your email and connection, then try again.',
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _openRegister() async {
    if (loading) return;
    setState(() => loading = true);
    try {
      contactController.clear();
      setState(() => accountNotFound = false);
      await auth.prepareFreshRegistration();
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
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _continueWithGoogle() async {
    if (loading || googleSignInInProgress || navigationCommitted) return;
    final generation = ++googleResolutionGeneration;
    setState(() {
      googleSignInInProgress = true;
      accountNotFound = false;
    });
    try {
      final result = await (widget.googleSignIn ?? auth.signInWithGoogle)();
      if (!mounted ||
          generation != googleResolutionGeneration ||
          result.isCancelled) {
        return;
      }
      if (!result.isSuccess) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result.safeMessage)),
        );
        return;
      }
      if (navigationCommitted || generation != googleResolutionGeneration) {
        debugPrint('[GoogleAuth] duplicate_navigation_suppressed');
        return;
      }
      navigationCommitted = true;
      final route = switch (result.route!.destination) {
        KaamAuthDestination.roleSelection => AppRoutes.roleSelection,
        KaamAuthDestination.blocked => AppRoutes.accountBlocked,
        KaamAuthDestination.candidateOnboarding => AppRoutes.documentsUpload,
        KaamAuthDestination.candidateDashboard => AppRoutes.dashboard,
        KaamAuthDestination.employerOnboarding =>
          AppRoutes.employerOnboardingOverview,
        KaamAuthDestination.employerDashboard => AppRoutes.employerDashboard,
      };
      debugPrint('[GoogleAuth] navigation_committed');
      Navigator.of(context).pushReplacementNamed(route);
    } on Object {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text(KaamSafeErrorMessages.googleSignInFailure)),
      );
    } finally {
      if (mounted &&
          generation == googleResolutionGeneration &&
          !navigationCommitted) {
        setState(() => googleSignInInProgress = false);
        debugPrint('[GoogleAuth] sign_in_state_reset');
      }
    }
  }

  void _openAccountLogin() {
    if (loading) return;
    KaamAuthSessionCoordinator.clearUserScopedState();
    Navigator.of(context).pushReplacementNamed(AppRoutes.login);
  }

  KaamRole? get _requestedRole {
    final arguments = ModalRoute.of(context)?.settings.arguments;
    if (arguments is Map) return arguments['role'] as KaamRole?;
    return null;
  }

  bool get _freshRegistration {
    final arguments = ModalRoute.of(context)?.settings.arguments;
    if (arguments is Map) return arguments['freshRegistration'] == true;
    return false;
  }

  bool get _showAccountNotFound {
    final arguments = ModalRoute.of(context)?.settings.arguments;
    final fromRoute = arguments is Map && arguments['accountNotFound'] == true;
    return accountNotFound || fromRoute;
  }

  @override
  Widget build(BuildContext context) {
    final requestedRole = _requestedRole;
    final creatingCandidate = requestedRole == KaamRole.candidate;
    final authBusy = loading || googleSignInInProgress;
    return PopScope(
      canPop: !googleSignInInProgress && !navigationCommitted,
      child: ScreenScaffold(
        title: creatingCandidate ? 'Create profile' : 'Log in',
        showBack: true,
        children: [
          Text(
            creatingCandidate
                ? 'Start your candidate profile'
                : 'Continue to KAAM',
            style: AppTextStyles.headline,
          ),
          const SizedBox(height: 10),
          Text(
            creatingCandidate
                ? 'Use your email to create your profile or continue to an existing account.'
                : 'Use your registered email to sign in. We will take you to the right account.',
            style: AppTextStyles.body,
          ),
          const SizedBox(height: 24),
          AppTextField(
            controller: contactController,
            label: 'Email address',
            hint: 'you@example.com',
            keyboardType: TextInputType.emailAddress,
          ),
          const SizedBox(height: 14),
          PrimaryButton(
            label: loading
                ? 'Sending...'
                : creatingCandidate
                    ? 'Continue with email'
                    : 'Send verification code',
            icon: Icons.email_outlined,
            onPressed: authBusy ? null : _continue,
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: authBusy ? null : _continueWithGoogle,
            icon: const Icon(Icons.g_mobiledata_rounded, size: 28),
            label: Text(
              googleSignInInProgress ? 'Signing in…' : 'Continue with Google',
            ),
          ),
          if (_showAccountNotFound) ...[
            const SizedBox(height: 14),
            _AccountNotFoundPanel(
              onCreateAccount: authBusy ? null : _openRegister,
            ),
          ],
          const SizedBox(height: 10),
          const Text(
            'Phone OTP will be available soon.',
            style: AppTextStyles.muted,
          ),
          const SizedBox(height: 18),
          IgnorePointer(
            ignoring: authBusy,
            child: QaLoginShortcuts(
              showEmployer: !_freshRegistration,
              showAdmin: !_freshRegistration,
              onPickEmail: (email) =>
                  setState(() => contactController.text = email),
            ),
          ),
          if (_freshRegistration) ...[
            const SizedBox(height: 20),
            Center(
              child: Wrap(
                alignment: WrapAlignment.center,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  const Text(
                    'Already have an account? ',
                    style: AppTextStyles.muted,
                  ),
                  TextButton(
                    onPressed: authBusy ? null : _openAccountLogin,
                    child: const Text('Login'),
                  ),
                ],
              ),
            ),
          ] else ...[
            const SizedBox(height: 20),
            Center(
              child: Wrap(
                alignment: WrapAlignment.center,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  const Text('Not registered yet? ',
                      style: AppTextStyles.muted),
                  TextButton(
                    onPressed: authBusy ? null : _openRegister,
                    child: const Text('Create an account'),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _AccountNotFoundPanel extends StatelessWidget {
  const _AccountNotFoundPanel({required this.onCreateAccount});

  final VoidCallback? onCreateAccount;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: .14)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            KaamSafeErrorMessages.accountNotFound,
            style: AppTextStyles.body,
          ),
          const SizedBox(height: 12),
          PrimaryButton(
            label: 'Create an account',
            icon: Icons.person_add_alt_1_outlined,
            onPressed: onCreateAccount,
          ),
        ],
      ),
    );
  }
}
