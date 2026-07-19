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
                style:
                    AppTextStyles.title.copyWith(color: AppColors.primaryPink),
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
  const EmployerLoginScreen({super.key});

  @override
  State<EmployerLoginScreen> createState() => _EmployerLoginScreenState();
}

class _EmployerLoginScreenState extends State<EmployerLoginScreen> {
  final contactController = TextEditingController();
  final auth = const KaamAuthRepository();
  bool loading = false;

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
      );
      if (!mounted) return;
      Navigator.of(context).pushReplacementNamed(
        AppRoutes.employerOtp,
        arguments: {
          'email': contactController.text.trim().toLowerCase(),
          'role': KaamRole.employer,
        },
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not send OTP: $error')),
      );
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ScreenScaffold(
      title: 'Employer Login',
      showBack: true,
      children: [
        const Text('Start hiring with KAAM', style: AppTextStyles.headline),
        const SizedBox(height: 10),
        const Text(
          'Use your email to sign in or create your employer account.',
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
                  label: 'Email OTP login is active'),
              SizedBox(height: 8),
              _LoginOption(
                  icon: Icons.phone_iphone_rounded,
                  label: 'Phone OTP coming soon'),
              SizedBox(height: 8),
              _LoginOption(
                  icon: Icons.g_mobiledata_rounded,
                  label: 'Google login coming soon'),
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
          onPressed: loading ? null : _continue,
        ),
        const SizedBox(height: 12),
        const Center(
          child: Text(
            'New or existing employer? Continue with email.',
            textAlign: TextAlign.center,
            style: AppTextStyles.muted,
          ),
        ),
        const SizedBox(height: 18),
        QaLoginShortcuts(
          showCandidate: false,
          onPickEmail: (email) =>
              setState(() => contactController.text = email),
        ),
      ],
    );
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
  int resendSeconds = 45;
  Timer? resendTimer;

  bool get canVerify =>
      controllers.map((controller) => controller.text).join().length ==
      otpLength;

  @override
  void dispose() {
    resendTimer?.cancel();
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.message)),
      );
      Navigator.of(context).pushNamedAndRemoveUntil(
        _routeFor(result.destination),
        (_) => false,
      );
    } on KaamRoleMismatchException catch (error) {
      if (!mounted) return;
      autoSubmitted = false;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.safeMessage)),
      );
    } catch (_) {
      if (!mounted) return;
      autoSubmitted = false;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content:
              Text('We could not verify that code. Check it and try again.'),
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
      await auth.signInWithOtp(email: email, role: KaamRole.employer);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('OTP resent.')),
      );
      _startResendCountdown();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not resend OTP: $error')),
      );
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
    );
  }

  void _startResendCountdown() {
    resendTimer?.cancel();
    setState(() => resendSeconds = 45);
    resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (resendSeconds <= 1) {
        timer.cancel();
        setState(() => resendSeconds = 0);
      } else {
        setState(() => resendSeconds--);
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
    return ScreenScaffold(
      title: 'Verification',
      showBack: true,
      children: [
        const Text('Verify your account', style: AppTextStyles.headline),
        const SizedBox(height: 10),
        Text(
            'Enter the ${AppConfig.emailOtpLength}-digit code sent to your email.',
            style: AppTextStyles.body),
        const SizedBox(height: 28),
        OtpCodeFields(
          controllers: controllers,
          focusNodes: focusNodes,
          onChanged: () => setState(() {}),
          onCompleted: () {
            if (!loading && canVerify && !autoSubmitted) {
              autoSubmitted = true;
              _verify();
            }
          },
        ),
        const SizedBox(height: 28),
        PrimaryButton(
          label: loading ? 'Verifying...' : 'Verify',
          onPressed: loading || !canVerify ? null : _verify,
        ),
        const SizedBox(height: 12),
        TextButton(
          onPressed: loading || resendSeconds > 0 ? null : _resend,
          child: Text(resendSeconds > 0
              ? 'Resend in ${resendSeconds}s'
              : 'Resend code'),
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
