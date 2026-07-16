import 'package:flutter/material.dart';

import '../../core/constants/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/primary_button.dart';
import '../../core/widgets/screen_scaffold.dart';
import '../supabase_backend/kaam_backend.dart';

class BlockedAccountScreen extends StatelessWidget {
  const BlockedAccountScreen({super.key});

  static const message =
      'Your Kaam account has been blocked. Please contact support if you believe this is a mistake.';

  @override
  Widget build(BuildContext context) {
    return ScreenScaffold(
      title: 'Account blocked',
      children: [
        const Icon(
          Icons.block_rounded,
          size: 64,
          color: AppColors.error,
        ),
        const SizedBox(height: 18),
        const Text('Account blocked', style: AppTextStyles.headline),
        const SizedBox(height: 10),
        const Text(message, style: AppTextStyles.body),
        const SizedBox(height: 22),
        PrimaryButton(
          label: 'Back to login',
          icon: Icons.login_rounded,
          onPressed: () => Navigator.of(context).pushNamedAndRemoveUntil(
            AppRoutes.roleSelection,
            (_) => false,
          ),
        ),
      ],
    );
  }
}

class ProtectedAccountRoute extends StatefulWidget {
  const ProtectedAccountRoute({
    super.key,
    required this.role,
    required this.child,
  });

  final KaamRole role;
  final Widget child;

  @override
  State<ProtectedAccountRoute> createState() => _ProtectedAccountRouteState();
}

class _ProtectedAccountRouteState extends State<ProtectedAccountRoute> {
  final repository = const KaamAuthRepository();
  late final Future<KaamProtectedAccess> access = _checkAccess();

  Future<KaamProtectedAccess> _checkAccess() async {
    final access = await repository.checkProtectedAccess(widget.role);
    if (access == KaamProtectedAccess.blocked) {
      await repository.signOut();
    }
    return access;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<KaamProtectedAccess>(
      future: access,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.data == KaamProtectedAccess.allowed) return widget.child;
        if (snapshot.data == KaamProtectedAccess.blocked) {
          return const BlockedAccountScreen();
        }
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!context.mounted) return;
          Navigator.of(context).pushNamedAndRemoveUntil(
            AppRoutes.roleSelection,
            (_) => false,
          );
        });
        return const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        );
      },
    );
  }
}
