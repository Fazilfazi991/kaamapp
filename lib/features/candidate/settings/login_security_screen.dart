import 'package:flutter/material.dart';

import '../../../core/constants/app_routes.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/widgets/screen_scaffold.dart';
import '../../supabase_backend/kaam_backend.dart';

class LoginSecurityScreen extends StatefulWidget {
  const LoginSecurityScreen({super.key});

  @override
  State<LoginSecurityScreen> createState() => _LoginSecurityScreenState();
}

class _LoginSecurityScreenState extends State<LoginSecurityScreen> {
  final auth = const KaamAuthRepository();
  bool loggingOut = false;

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout?'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Logout'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => loggingOut = true);
    try {
      await auth.signOut();
      if (!mounted) return;
      Navigator.of(context).pushNamedAndRemoveUntil(
        AppRoutes.roleSelection,
        (_) => false,
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not logout: $error')),
      );
    } finally {
      if (mounted) setState(() => loggingOut = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final email = auth.currentUser?.email ?? 'Not available';
    return ScreenScaffold(
      title: 'Login & Security',
      showBack: true,
      children: [
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Logged-in email', style: AppTextStyles.label),
              const SizedBox(height: 6),
              Text(email, style: AppTextStyles.body),
            ],
          ),
        ),
        const SizedBox(height: 12),
        const AppCard(
          child: Text('Change email: Coming soon', style: AppTextStyles.body),
        ),
        const SizedBox(height: 12),
        const AppCard(
          child: Text('Delete account: Coming soon', style: AppTextStyles.body),
        ),
        const SizedBox(height: 24),
        PrimaryButton(
          label: loggingOut ? 'Logging out...' : 'Logout',
          onPressed: loggingOut ? null : _logout,
        ),
      ],
    );
  }
}
