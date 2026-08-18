import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/constants/app_routes.dart';
import '../../core/config/app_config.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/primary_button.dart';
import '../../core/widgets/screen_scaffold.dart';
import '../supabase_backend/kaam_backend.dart';

class OtpVerificationScreen extends StatefulWidget {
  const OtpVerificationScreen({super.key});

  @override
  State<OtpVerificationScreen> createState() => _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends State<OtpVerificationScreen> {
  static final otpLength = AppConfig.emailOtpLength;

  final controllers = List.generate(otpLength, (_) => TextEditingController());
  final focusNodes = List.generate(otpLength, (_) => FocusNode());
  final auth = const KaamAuthRepository();
  bool loading = false;
  bool resent = false;
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
    final role = otpContext.role;
    final token = controllers.map((controller) => controller.text).join();

    setState(() => loading = true);
    try {
      final result = await auth.verifyOtp(
        email: email,
        token: token,
        role: role,
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
      if (otpContext.freshRegistration) {
        await _showRegistrationSuccess();
        if (!mounted) return;
      }
      Navigator.of(
        context,
      ).pushNamedAndRemoveUntil(_routeFor(result.destination), (_) => false);
    } on KaamAccountNotFoundException catch (error) {
      if (!mounted) return;
      resent = false;
      Navigator.of(context).pushNamedAndRemoveUntil(
        AppRoutes.login,
        (_) => false,
        arguments: {'accountNotFound': true},
      );
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.safeMessage)));
    } on KaamRoleMismatchException catch (error) {
      if (!mounted) return;
      resent = false;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.safeMessage)));
    } catch (_) {
      if (!mounted) return;
      resent = false;
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
    final role = otpContext.role;
    setState(() {
      loading = true;
      resent = false;
    });
    try {
      await auth.signInWithOtp(
        email: email,
        role: role,
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
    final role = data['role'] as KaamRole? ??
        KaamAuthSessionCoordinator.pendingOtp?.role;
    return KaamPendingOtpContext(
      normalizedEmail: email,
      role: role,
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
      title: 'Verify',
      showBack: true,
      children: [
        const Text('Verify your email', style: AppTextStyles.headline),
        const SizedBox(height: 8),
        Text(
          'Enter the ${AppConfig.emailOtpLength}-digit code sent to $email',
          style: AppTextStyles.body,
        ),
        const SizedBox(height: 28),
        OtpCodeFields(
          controllers: controllers,
          focusNodes: focusNodes,
          onChanged: () => otpComplete.value = canVerify,
          onCompleted: () {
            if (!loading && canVerify && !resent) {
              resent = true;
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

class OtpCodeFields extends StatelessWidget {
  const OtpCodeFields({
    super.key,
    required this.controllers,
    required this.focusNodes,
    required this.onChanged,
    this.onCompleted,
  });

  final List<TextEditingController> controllers;
  final List<FocusNode> focusNodes;
  final VoidCallback onChanged;
  final VoidCallback? onCompleted;

  void _handleChanged(BuildContext context, int index, String value) {
    final digits = value.replaceAll(RegExp(r'\D'), '');
    if (digits.length > 1) {
      _pasteDigits(context, index, digits);
      return;
    }

    if (digits != value) {
      controllers[index].text = digits;
      controllers[index].selection = TextSelection.collapsed(
        offset: digits.length,
      );
    }

    if (digits.isEmpty && value.isEmpty && index > 0) {
      FocusScope.of(context).requestFocus(focusNodes[index - 1]);
      onChanged();
      return;
    }

    if (digits.length == 1 && index < controllers.length - 1) {
      FocusScope.of(context).requestFocus(focusNodes[index + 1]);
    }
    onChanged();
    _notifyComplete();
  }

  void _pasteDigits(BuildContext context, int startIndex, String digits) {
    var target = startIndex;
    for (final digit in digits.characters) {
      if (target >= controllers.length) break;
      controllers[target].text = digit;
      controllers[target].selection = const TextSelection.collapsed(offset: 1);
      target++;
    }
    FocusScope.of(
      context,
    ).requestFocus(focusNodes[(target - 1).clamp(0, focusNodes.length - 1)]);
    onChanged();
    _notifyComplete();
  }

  void _notifyComplete() {
    final complete = controllers.every(
      (controller) => controller.text.length == 1,
    );
    if (complete) onCompleted?.call();
  }

  KeyEventResult _handleKey(BuildContext context, int index, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    if (event.logicalKey != LogicalKeyboardKey.backspace) {
      return KeyEventResult.ignored;
    }
    if (controllers[index].text.isEmpty && index > 0) {
      FocusScope.of(context).requestFocus(focusNodes[index - 1]);
      onChanged();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(
        controllers.length,
        (index) => Expanded(
          child: Padding(
            padding: EdgeInsets.only(
              right: index == controllers.length - 1 ? 0 : 8,
            ),
            child: Focus(
              onKeyEvent: (_, event) => _handleKey(context, index, event),
              child: TextField(
                controller: controllers[index],
                focusNode: focusNodes[index],
                textAlign: TextAlign.center,
                keyboardType: TextInputType.number,
                textInputAction: index == controllers.length - 1
                    ? TextInputAction.done
                    : TextInputAction.next,
                showCursor: false,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                onChanged: (value) => _handleChanged(context, index, value),
                decoration: InputDecoration(
                  counterText: '',
                  filled: true,
                  fillColor: AppColors.elevatedCard,
                  contentPadding: const EdgeInsets.symmetric(vertical: 14),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                      color: AppColors.primaryPink,
                      width: 1.5,
                    ),
                  ),
                ),
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: AppColors.white,
                  height: 1,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
