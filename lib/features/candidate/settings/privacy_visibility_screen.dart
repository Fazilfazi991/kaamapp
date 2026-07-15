import 'package:flutter/material.dart';

import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/widgets/screen_scaffold.dart';
import '../../supabase_backend/kaam_backend.dart';

class PrivacyVisibilityScreen extends StatefulWidget {
  const PrivacyVisibilityScreen({super.key});

  @override
  State<PrivacyVisibilityScreen> createState() =>
      _PrivacyVisibilityScreenState();
}

class _PrivacyVisibilityScreenState extends State<PrivacyVisibilityScreen> {
  final repository = const CandidateProfileRepository();
  bool loading = true;
  bool saving = false;
  bool profileVisible = true;
  bool hidePhone = true;
  bool hideEmail = true;
  bool requireApproval = true;
  bool allowDocumentsAfterMatch = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final settings = await repository.loadPrivacySettings();
      if (mounted) {
        setState(() {
          profileVisible = settings.profileVisible;
          hidePhone = settings.hidePhoneBeforeMatch;
          hideEmail = settings.hideEmailBeforeMatch;
          requireApproval = settings.requireApprovalBeforeChat;
          allowDocumentsAfterMatch = settings.allowDocumentSharingAfterMatch;
        });
      }
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not load privacy settings: $error')),
      );
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _save() async {
    setState(() => saving = true);
    try {
      final saved = await repository.updatePrivacySettings(
        CandidatePrivacySettings(
          profileVisible: profileVisible,
          hidePhoneBeforeMatch: hidePhone,
          hideEmailBeforeMatch: hideEmail,
          requireApprovalBeforeChat: requireApproval,
          allowDocumentSharingAfterMatch: allowDocumentsAfterMatch,
        ),
      );
      if (!mounted) return;
      setState(() {
        profileVisible = saved.profileVisible;
        hidePhone = saved.hidePhoneBeforeMatch;
        hideEmail = saved.hideEmailBeforeMatch;
        requireApproval = saved.requireApprovalBeforeChat;
        allowDocumentsAfterMatch = saved.allowDocumentSharingAfterMatch;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Privacy settings saved.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not save privacy settings: $error')),
      );
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Widget _switchRow({
    required String label,
    required bool value,
    required ValueChanged<bool>? onChanged,
    String? note,
  }) {
    return InkWell(
      onTap: onChanged == null ? null : () => onChanged(!value),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: value,
            onChanged: onChanged,
            title: Text(label),
          ),
          if (note != null)
            Padding(
              padding: const EdgeInsets.only(left: 16, right: 16, bottom: 8),
              child: Text(note, style: AppTextStyles.muted),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ScreenScaffold(
      title: 'Privacy & Visibility',
      showBack: true,
      children: [
        if (loading) const LinearProgressIndicator(),
        if (loading) const SizedBox(height: 12),
        _switchRow(
          label: 'Profile visible to employers',
          value: profileVisible,
          onChanged: (value) => setState(() => profileVisible = value),
        ),
        _switchRow(
          label: 'Hide phone number before match',
          value: hidePhone,
          onChanged: (value) => setState(() => hidePhone = value),
          note: 'Private contact fields stay protected before accepted matches.',
        ),
        _switchRow(
          label: 'Hide email before match',
          value: hideEmail,
          onChanged: (value) => setState(() => hideEmail = value),
          note: 'Email is not exposed in employer candidate search.',
        ),
        _switchRow(
          label: 'Require approval before chat',
          value: requireApproval,
          onChanged: (value) => setState(() => requireApproval = value),
          note: 'Chat unlocks only after you accept an employer request.',
        ),
        _switchRow(
          label: 'Allow document sharing after match',
          value: allowDocumentsAfterMatch,
          onChanged: (value) => setState(() => allowDocumentsAfterMatch = value),
        ),
        _switchRow(
          label: 'Hide profile from selected companies',
          value: false,
          onChanged: null,
          note: 'Coming soon. This option needs company blocklist support.',
        ),
        const SizedBox(height: 24),
        PrimaryButton(
          label: saving ? 'Saving...' : 'Save Privacy Settings',
          onPressed: saving ? null : _save,
        ),
      ],
    );
  }
}
