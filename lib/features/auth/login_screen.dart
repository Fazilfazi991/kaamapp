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
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final contactController = TextEditingController();
  final auth = const KaamAuthRepository();
  bool loading = false;

  @override
  void dispose() {
    contactController.dispose();
    super.dispose();
  }

  Future<void> _continue() async {
    final requestedRole = _requestedRole;
    setState(() => loading = true);
    try {
      await SupabaseService.waitForSessionRecovery();
      await auth.signInWithOtp(
        email: contactController.text,
        role: requestedRole,
      );
      if (!mounted) return;
      Navigator.of(context).pushReplacementNamed(
        AppRoutes.otp,
        arguments: {
          'email': contactController.text.trim().toLowerCase(),
          'role': requestedRole,
        },
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text(
                'We could not send a verification code. Check your email and connection, then try again.')),
      );
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  KaamRole? get _requestedRole {
    final arguments = ModalRoute.of(context)?.settings.arguments;
    if (arguments is Map) return arguments['role'] as KaamRole?;
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final requestedRole = _requestedRole;
    final creatingCandidate = requestedRole == KaamRole.candidate;
    return ScreenScaffold(
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
          onPressed: loading ? null : _continue,
        ),
        const SizedBox(height: 10),
        const Text('Phone OTP will be available soon.',
            style: AppTextStyles.muted),
        const SizedBox(height: 10),
        const Text('Google login will be enabled after OAuth setup.',
            style: AppTextStyles.muted),
        const SizedBox(height: 18),
        QaLoginShortcuts(
          showEmployer: false,
          onPickEmail: (email) =>
              setState(() => contactController.text = email),
        ),
      ],
    );
  }
}
