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
    final args = ModalRoute.of(context)?.settings.arguments;
    final data = args is Map ? args : const {};
    final email = data['email'] as String? ?? '';
    final role = data['role'] as KaamRole?;
    final token = controllers.map((controller) => controller.text).join();

    setState(() => loading = true);
    try {
      final result =
          await auth.verifyOtp(email: email, token: token, role: role);
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
    } catch (_) {
      if (!mounted) return;
      resent = false;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content:
                Text('We could not verify that code. Check it and try again.')),
      );
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _resend() async {
    final args = ModalRoute.of(context)?.settings.arguments;
    final data = args is Map ? args : const {};
    final email = data['email'] as String? ?? '';
    final role = data['role'] as KaamRole?;
    setState(() {
      loading = true;
      resent = false;
    });
    try {
      await auth.signInWithOtp(email: email, role: role);
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
      title: 'Verify',
      showBack: true,
      children: [
        const Text('Verify your email', style: AppTextStyles.headline),
        const SizedBox(height: 8),
        Text(
            'Enter the ${AppConfig.emailOtpLength}-digit code sent to your email',
            style: AppTextStyles.body),
        const SizedBox(height: 28),
        OtpCodeFields(
          controllers: controllers,
          focusNodes: focusNodes,
          onChanged: () => setState(() {}),
          onCompleted: () {
            if (!loading && canVerify && !resent) {
              resent = true;
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
      controllers[index].selection =
          TextSelection.collapsed(offset: digits.length);
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
    FocusScope.of(context).requestFocus(
      focusNodes[(target - 1).clamp(0, focusNodes.length - 1)],
    );
    onChanged();
    _notifyComplete();
  }

  void _notifyComplete() {
    final complete =
        controllers.every((controller) => controller.text.length == 1);
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
            padding:
                EdgeInsets.only(right: index == controllers.length - 1 ? 0 : 8),
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
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                ],
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
