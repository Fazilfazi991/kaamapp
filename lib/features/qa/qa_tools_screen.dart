import 'package:flutter/material.dart';

import '../../core/constants/app_routes.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/screen_scaffold.dart';
import '../supabase_backend/kaam_backend.dart';
import 'qa_mode.dart';

class QaToolsScreen extends StatefulWidget {
  const QaToolsScreen({super.key});

  @override
  State<QaToolsScreen> createState() => _QaToolsScreenState();
}

class _QaToolsScreenState extends State<QaToolsScreen> {
  final repository = const QaToolsRepository();
  bool busy = false;

  @override
  Widget build(BuildContext context) {
    if (!QaMode.enabled) {
      return const ScreenScaffold(
        title: 'QA Tools',
        showBack: true,
        children: [
          EmptyState(
            icon: Icons.lock_outline_rounded,
            title: 'QA mode disabled',
            message: 'QA tools are hidden outside debug or internal QA builds.',
          ),
        ],
      );
    }
    final user = repository.currentUser;
    return ScreenScaffold(
      title: 'QA Tools',
      showBack: true,
      children: [
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Current Session', style: AppTextStyles.title),
              const SizedBox(height: 8),
              Text('User ID: ${user?.id ?? 'Not signed in'}',
                  style: AppTextStyles.muted),
              Text('Email: ${user?.email ?? 'Not signed in'}',
                  style: AppTextStyles.muted),
              FutureBuilder<String>(
                future: repository.currentRole(),
                builder: (context, snapshot) => Text(
                  'Role: ${snapshot.data ?? 'loading'}',
                  style: AppTextStyles.muted,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        FutureBuilder<String>(
          future: repository.currentRole(),
          builder: (context, snapshot) {
            final role = snapshot.data ?? '';
            if (role == 'candidate') {
              return Column(
                children: [
                  _QaAction(
                      label: 'Reset Candidate Onboarding',
                      onTap: () => _run('reset_candidate_onboarding')),
                  _QaAction(
                      label: 'Reset Document Status Only',
                      onTap: () => _run('reset_document_status')),
                  _QaAction(
                    label: 'Delete Documents and Reset',
                    danger: true,
                    onTap: () => _confirmAndRun(
                      action: 'delete_documents_and_reset',
                      message:
                          'This deletes QA document files and resets document metadata.',
                    ),
                  ),
                  _QaAction(
                    label: 'Full Candidate QA Reset',
                    danger: true,
                    onTap: () => _confirmAndRun(
                      action: 'full_candidate_qa_reset',
                      message:
                          'This will reset this QA candidate account and sign out. The authentication account remains active.',
                      signOutAfter: true,
                    ),
                  ),
                ],
              );
            }
            if (role == 'employer') {
              return Column(
                children: [
                  _QaAction(
                      label: 'Reset Employer Onboarding',
                      onTap: () => _run('reset_employer_onboarding')),
                  _QaAction(
                    label: 'Full Employer QA Reset',
                    danger: true,
                    onTap: () => _confirmAndRun(
                      action: 'full_employer_qa_reset',
                      message:
                          'This will reset this QA employer account and sign out. The authentication account remains active.',
                      signOutAfter: true,
                    ),
                  ),
                ],
              );
            }
            return const AppCard(
              child: Text(
                'Admin QA account: session inspection and sign out are available. No profile reset action is enabled.',
                style: AppTextStyles.body,
              ),
            );
          },
        ),
        _QaAction(label: 'Clear Local App State', onTap: _clearLocal),
        _QaAction(label: 'Sign Out', onTap: _signOut),
      ],
    );
  }

  Future<void> _run(String action, {bool signOutAfter = false}) async {
    setState(() => busy = true);
    try {
      await repository.reset(action);
      if (signOutAfter) {
        await repository.signOut();
        if (!mounted) return;
        Navigator.of(context)
            .pushNamedAndRemoveUntil(AppRoutes.roleSelection, (_) => false);
        return;
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$action completed.')),
      );
      if (action.contains('candidate')) {
        Navigator.of(context)
            .pushNamedAndRemoveUntil(AppRoutes.documentsUpload, (_) => false);
      }
      if (action.contains('employer')) {
        Navigator.of(context).pushNamedAndRemoveUntil(
            AppRoutes.employerOnboardingOverview, (_) => false);
      }
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('QA reset failed: $error')),
      );
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _confirmAndRun({
    required String action,
    required String message,
    bool signOutAfter = false,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm QA reset'),
        content: Text(message),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Reset')),
        ],
      ),
    );
    if (confirmed == true) await _run(action, signOutAfter: signOutAfter);
  }

  Future<void> _clearLocal() async {
    await repository.signOut();
    if (!mounted) return;
    Navigator.of(context)
        .pushNamedAndRemoveUntil(AppRoutes.roleSelection, (_) => false);
  }

  Future<void> _signOut() async {
    await repository.signOut();
    if (!mounted) return;
    Navigator.of(context)
        .pushNamedAndRemoveUntil(AppRoutes.roleSelection, (_) => false);
  }
}

class _QaAction extends StatelessWidget {
  const _QaAction({
    required this.label,
    required this.onTap,
    this.danger = false,
  });

  final String label;
  final VoidCallback onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: AppCard(
        onTap: onTap,
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(danger
                ? Icons.delete_forever_rounded
                : Icons.build_circle_outlined),
            const SizedBox(width: 12),
            Expanded(child: Text(label, style: AppTextStyles.body)),
            const Icon(Icons.chevron_right_rounded),
          ],
        ),
      ),
    );
  }
}
