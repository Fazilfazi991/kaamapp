import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/config/app_config.dart';
import '../../../core/constants/app_assets.dart';
import '../../../core/constants/app_routes.dart';
import '../../../core/supabase/supabase_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/widgets/screen_scaffold.dart';
import '../../auth/otp_verification_screen.dart';
import '../../qa/qa_mode.dart';
import '../../supabase_backend/kaam_backend.dart';

class EmployerSplashScreen extends StatelessWidget {
  const EmployerSplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            children: [
              const Spacer(),
              Image.asset(AppAssets.logo, width: 292, fit: BoxFit.contain),
              const SizedBox(height: 20),
              Text(
                'Perfect Match',
                style: AppTextStyles.title.copyWith(
                  color: AppColors.primaryPink,
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                'Find trusted candidates through mutual interest.',
                textAlign: TextAlign.center,
                style: AppTextStyles.body,
              ),
              const Spacer(),
              PrimaryButton(
                label: 'Get Started',
                onPressed: () =>
                    Navigator.of(context).pushNamed(AppRoutes.employerLogin),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class EmployerLoginScreen extends StatefulWidget {
  const EmployerLoginScreen({super.key, this.googleSignIn});

  final Future<KaamGoogleSignInResult> Function()? googleSignIn;

  @override
  State<EmployerLoginScreen> createState() => _EmployerLoginScreenState();
}

class _EmployerLoginScreenState extends State<EmployerLoginScreen> {
  final contactController = TextEditingController();
  final auth = const KaamAuthRepository();
  bool loading = false;
  bool googleSignInInProgress = false;
  bool navigationCommitted = false;

  @override
  void dispose() {
    contactController.dispose();
    super.dispose();
  }

  Future<void> _continue() async {
    setState(() => loading = true);
    try {
      await SupabaseService.waitForSessionRecovery();
      await auth.signInWithOtp(
        email: contactController.text,
        role: KaamRole.employer,
        freshRegistration: _freshRegistration,
      );
      if (!mounted) return;
      Navigator.of(context).pushReplacementNamed(
        AppRoutes.employerOtp,
        arguments: {
          'email': contactController.text.trim().toLowerCase(),
          'role': KaamRole.employer,
          'freshRegistration': _freshRegistration,
        },
      );
    } catch (error) {
      if (!mounted) return;
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

  void _openAccountLogin() {
    if (loading) return;
    KaamAuthSessionCoordinator.clearUserScopedState();
    Navigator.of(context).pushReplacementNamed(AppRoutes.login);
  }

  Future<void> _continueWithGoogle() async {
    if (loading || googleSignInInProgress || navigationCommitted) return;
    setState(() => googleSignInInProgress = true);
    try {
      final result = await (widget.googleSignIn ?? auth.signInWithGoogle)();
      if (!mounted || result.isCancelled) return;
      if (!result.isSuccess) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result.safeMessage)),
        );
        return;
      }
      if (navigationCommitted) return;
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
      Navigator.of(context).pushReplacementNamed(route);
    } on Object {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text(KaamSafeErrorMessages.googleSignInFailure)),
      );
    } finally {
      if (mounted && !navigationCommitted) {
        setState(() => googleSignInInProgress = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final registering = _freshRegistration;
    final authBusy = loading || googleSignInInProgress;
    return PopScope(
      canPop: !googleSignInInProgress && !navigationCommitted,
      child: ScreenScaffold(
        title: registering ? 'Create employer account' : 'Employer Login',
        showBack: true,
        children: [
          Text(
            registering ? 'Create employer account' : 'Start hiring with KAAM',
            style: AppTextStyles.headline,
          ),
          const SizedBox(height: 10),
          Text(
            registering
                ? 'Use your company email to create your employer account.'
                : 'Use your email to sign in or create your employer account.',
            style: AppTextStyles.body,
          ),
          const SizedBox(height: 18),
          const AppCard(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _LoginOption(
                  icon: Icons.check_circle_outline_rounded,
                  label: 'Email OTP login is active',
                ),
                SizedBox(height: 8),
                _LoginOption(
                  icon: Icons.phone_iphone_rounded,
                  label: 'Phone OTP coming soon',
                ),
                SizedBox(height: 8),
              ],
            ),
          ),
          const SizedBox(height: 18),
          AppTextField(
            controller: contactController,
            label: 'Company email',
            hint: 'hr@company.com',
            keyboardType: TextInputType.emailAddress,
          ),
          const SizedBox(height: 22),
          PrimaryButton(
            label: loading ? 'Sending...' : 'Continue with email',
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
          if (registering) ...[
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
            const SizedBox(height: 12),
            const Center(
              child: Text(
                'New or existing employer? Continue with email.',
                textAlign: TextAlign.center,
                style: AppTextStyles.muted,
              ),
            ),
          ],
          const SizedBox(height: 18),
          IgnorePointer(
            ignoring: authBusy,
            child: QaLoginShortcuts(
              showCandidate: false,
              onPickEmail: (email) =>
                  setState(() => contactController.text = email),
            ),
          ),
        ],
      ),
    );
  }

  bool get _freshRegistration {
    final arguments = ModalRoute.of(context)?.settings.arguments;
    if (arguments is Map) return arguments['freshRegistration'] == true;
    return false;
  }
}

class EmployerOtpScreen extends StatefulWidget {
  const EmployerOtpScreen({super.key});

  @override
  State<EmployerOtpScreen> createState() => _EmployerOtpScreenState();
}

class _EmployerOtpScreenState extends State<EmployerOtpScreen> {
  static final otpLength = AppConfig.emailOtpLength;

  final controllers = List.generate(otpLength, (_) => TextEditingController());
  final focusNodes = List.generate(otpLength, (_) => FocusNode());
  final auth = const KaamAuthRepository();
  bool loading = false;
  bool autoSubmitted = false;
  final resendSeconds = ValueNotifier<int>(45);
  final otpComplete = ValueNotifier<bool>(false);
  Timer? resendTimer;

  bool get canVerify =>
      controllers.map((controller) => controller.text).join().length ==
      otpLength;

  @override
  void dispose() {
    resendTimer?.cancel();
    resendSeconds.dispose();
    otpComplete.dispose();
    for (final controller in controllers) {
      controller.dispose();
    }
    for (final node in focusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _startResendCountdown();
  }

  Future<void> _verify() async {
    final otpContext = _otpContext();
    final email = otpContext.normalizedEmail;
    final token = controllers.map((controller) => controller.text).join();

    setState(() => loading = true);
    try {
      final result = await auth.verifyOtp(
        email: email,
        token: token,
        role: KaamRole.employer,
      );
      if (!mounted) return;
      if (result.message.startsWith('This email is already registered')) {
        await showDialog<void>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Account found'),
            content: Text(result.message),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('Continue to Login'),
              ),
            ],
          ),
        );
        if (!mounted) return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(result.message)));
      if (_otpContext().freshRegistration) {
        await _showRegistrationSuccess();
        if (!mounted) return;
      }
      Navigator.of(
        context,
      ).pushNamedAndRemoveUntil(_routeFor(result.destination), (_) => false);
    } on KaamRoleMismatchException catch (error) {
      if (!mounted) return;
      autoSubmitted = false;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.safeMessage)));
    } catch (_) {
      if (!mounted) return;
      autoSubmitted = false;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'We could not verify that code. Check it and try again.',
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _resend() async {
    final otpContext = _otpContext();
    final email = otpContext.normalizedEmail;
    setState(() {
      loading = true;
      autoSubmitted = false;
    });
    try {
      await auth.signInWithOtp(
        email: email,
        role: KaamRole.employer,
        freshRegistration: otpContext.freshRegistration,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('OTP resent.')));
      _startResendCountdown();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not resend OTP: $error')));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  KaamPendingOtpContext _otpContext() {
    final args = ModalRoute.of(context)?.settings.arguments;
    final data = args is Map ? args : const {};
    final email = (data['email'] as String? ??
            KaamAuthSessionCoordinator.pendingOtp?.normalizedEmail ??
            '')
        .trim()
        .toLowerCase();
    return KaamPendingOtpContext(
      normalizedEmail: email,
      role: KaamRole.employer,
      requestedAt: KaamAuthSessionCoordinator.pendingOtp?.requestedAt ??
          DateTime.now().toUtc(),
      freshRegistration: data['freshRegistration'] == true,
    );
  }

  Future<void> _showRegistrationSuccess() async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Registration successful'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.check_circle_outline,
              color: AppColors.success,
              size: 48,
            ),
            SizedBox(height: 12),
            Text('Your KAAM account has been created successfully.'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Continue'),
          ),
        ],
      ),
    );
  }

  void _startResendCountdown() {
    resendTimer?.cancel();
    resendSeconds.value = 45;
    resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (resendSeconds.value <= 1) {
        timer.cancel();
        resendSeconds.value = 0;
      } else {
        resendSeconds.value -= 1;
      }
    });
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
    final email = _otpContext().normalizedEmail;
    return ScreenScaffold(
      title: 'Verification',
      showBack: true,
      children: [
        const Text('Verify your account', style: AppTextStyles.headline),
        const SizedBox(height: 10),
        Text(
          'Enter the ${AppConfig.emailOtpLength}-digit code sent to $email.',
          style: AppTextStyles.body,
        ),
        const SizedBox(height: 28),
        OtpCodeFields(
          controllers: controllers,
          focusNodes: focusNodes,
          onChanged: () => otpComplete.value = canVerify,
          onCompleted: () {
            if (!loading && canVerify && !autoSubmitted) {
              autoSubmitted = true;
              _verify();
            }
          },
        ),
        const SizedBox(height: 28),
        ValueListenableBuilder<bool>(
          valueListenable: otpComplete,
          builder: (context, complete, _) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              PrimaryButton(
                label: loading ? 'Verifying...' : 'Verify',
                onPressed: loading || !complete ? null : _verify,
              ),
              const SizedBox(height: 12),
              ValueListenableBuilder<int>(
                valueListenable: resendSeconds,
                builder: (context, seconds, _) => TextButton(
                  onPressed: loading || seconds > 0 ? null : _resend,
                  child: Text(
                    seconds > 0 ? 'Resend in ${seconds}s' : 'Resend code',
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _LoginOption extends StatelessWidget {
  const _LoginOption({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: AppColors.primaryPink),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: AppTextStyles.body.copyWith(color: AppColors.white),
          ),
        ),
      ],
    );
  }
}
