import 'package:flutter/material.dart';

import '../../../core/constants/app_routes.dart';
import '../../../core/widgets/candidate_widgets.dart';
import '../../../core/widgets/screen_scaffold.dart';
import '../../qa/qa_mode.dart';
import '../../supabase_backend/kaam_backend.dart';

class AccountSettingsScreen extends StatefulWidget {
  const AccountSettingsScreen({super.key});

  @override
  State<AccountSettingsScreen> createState() => _AccountSettingsScreenState();
}

class _AccountSettingsScreenState extends State<AccountSettingsScreen> {
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
      Navigator.of(context)
          .pushNamedAndRemoveUntil(AppRoutes.roleSelection, (_) => false);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(KaamSafeErrorMessages.logout)),
      );
    } finally {
      if (mounted) setState(() => loggingOut = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = [
      (Icons.person_outline, 'Personal details', AppRoutes.basicDetails),
      (Icons.security_outlined, 'Login & security', AppRoutes.loginSecurity),
      (Icons.privacy_tip_outlined, 'Privacy', AppRoutes.privacyVisibility),
      (Icons.notifications_outlined, 'Notifications', AppRoutes.notifications),
      (Icons.language_outlined, 'Language', AppRoutes.languageSettings),
      (Icons.help_outline, 'Help & support', AppRoutes.helpSupport),
    ];
    return ScreenScaffold(
      title: 'Settings',
      showBack: true,
      children: [
        for (final item in items) ...[
          SettingsTile(
            icon: item.$1,
            title: item.$2,
            onTap: () => Navigator.of(context).pushNamed(item.$3),
          ),
          const SizedBox(height: 10),
        ],
        if (QaMode.enabled) ...[
          SettingsTile(
            icon: Icons.build_circle_outlined,
            title: 'QA Tools',
            onTap: () => Navigator.of(context).pushNamed(AppRoutes.qaTools),
          ),
          const SizedBox(height: 10),
        ],
        SettingsTile(
          icon: Icons.logout,
          title: loggingOut ? 'Logging out...' : 'Logout',
          onTap: loggingOut ? null : _logout,
        ),
      ],
    );
  }
}
