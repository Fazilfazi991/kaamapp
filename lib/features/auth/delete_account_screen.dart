import 'package:flutter/material.dart';

import '../../core/constants/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/primary_button.dart';
import '../../core/widgets/screen_scaffold.dart';
import '../supabase_backend/kaam_backend.dart';

class DeleteAccountScreen extends StatefulWidget {
  const DeleteAccountScreen({super.key});

  @override
  State<DeleteAccountScreen> createState() => _DeleteAccountScreenState();
}

class _DeleteAccountScreenState extends State<DeleteAccountScreen> {
  final _confirmation = TextEditingController();
  bool _deleting = false;

  @override
  void dispose() {
    _confirmation.dispose();
    super.dispose();
  }

  Future<void> _delete() async {
    if (_confirmation.text.trim() != 'DELETE') return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Permanently delete account?'),
        content: const Text(
          'This permanently removes your KAAM account and associated personal data. '
          'Some shared records, such as matches and chat, are removed with the account. This cannot be undone.',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Delete account')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _deleting = true);
    try {
      await const KaamAuthRepository().deleteCurrentAccount();
      if (!mounted) return;
      Navigator.of(context)
          .pushNamedAndRemoveUntil(AppRoutes.roleSelection, (_) => false);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text(
                'We could not delete your account. Please try again or contact support.')),
      );
    } finally {
      if (mounted) setState(() => _deleting = false);
    }
  }

  @override
  Widget build(BuildContext context) => ScreenScaffold(
        title: 'Delete account',
        showBack: !_deleting,
        children: [
          AppCard(
            child: Text(
              'Deleting your account permanently removes your profile, identity documents, uploads, device tokens, '
              'notifications, and account access. Type DELETE to continue.',
              style: AppTextStyles.body.copyWith(color: AppColors.white),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _confirmation,
            enabled: !_deleting,
            textCapitalization: TextCapitalization.characters,
            decoration:
                const InputDecoration(labelText: 'Type DELETE to confirm'),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 24),
          PrimaryButton(
            label: _deleting
                ? 'Deleting account...'
                : 'Delete account permanently',
            onPressed: _deleting || _confirmation.text.trim() != 'DELETE'
                ? null
                : _delete,
          ),
        ],
      );
}
