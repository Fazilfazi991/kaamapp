import 'package:flutter/material.dart';

import '../../../core/theme/app_text_styles.dart';
import '../../../core/constants/app_routes.dart';
import '../../../core/widgets/candidate_widgets.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/widgets/screen_scaffold.dart';
import '../../supabase_backend/kaam_backend.dart';
import 'candidate_profile_completion.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final profiles = const CandidateProfileRepository();
  final storage = const KaamStorageRepository();
  late Future<
      ({
        CandidateProfileData profile,
        List<VerificationDocumentData> documents,
        CandidateIdentityDocumentData identity,
      })>
      dataFuture = _load();
  bool refreshing = false;

  Future<
      ({
        CandidateProfileData profile,
        List<VerificationDocumentData> documents,
        CandidateIdentityDocumentData identity,
      })>
      _load() async {
    final profile = await profiles.loadCurrentProfile();
    final documents = await storage.listMyDocuments();
    final identity = await profiles.loadIdentityDocuments();
    return (profile: profile, documents: documents, identity: identity);
  }

  Future<void> _refresh() async {
    setState(() {
      refreshing = true;
      dataFuture = _load();
    });
    try {
      await dataFuture;
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile data refreshed.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not refresh profile: $error')),
      );
    } finally {
      if (mounted) setState(() => refreshing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const sections = [
      (Icons.person_outline, 'Basic Details'),
      (Icons.work_outline, 'Work Preferences'),
      (Icons.psychology_outlined, 'Skills'),
      (Icons.history_edu_outlined, 'Experience'),
      (Icons.folder_copy_outlined, 'Documents'),
      (Icons.badge_outlined, 'Identity Documents'),
      (Icons.privacy_tip_outlined, 'Privacy'),
    ];
    return ScreenScaffold(
      title: 'Edit Profile',
      showBack: true,
      children: [
        FutureBuilder<
            ({
              CandidateProfileData profile,
              List<VerificationDocumentData> documents,
              CandidateIdentityDocumentData identity,
            })>(
          future: dataFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return EmptyState(
                icon: Icons.error_outline,
                title: 'Could not load profile strength',
                message: snapshot.error.toString(),
              );
            }
            final data = snapshot.data;
            final completion = CandidateProfileCompletion.calculate(
              data?.profile ?? const CandidateProfileData(),
              documents: data?.documents ?? const [],
              identity: data?.identity ?? const CandidateIdentityDocumentData(),
            );
            return ProfileStrengthCard(
              value: completion.percentage,
              helperText: completion.helperText,
            );
          },
        ),
        const SizedBox(height: 16),
        const Text('Editable sections', style: AppTextStyles.title),
        const SizedBox(height: 12),
        for (final section in sections) ...[
          SettingsTile(
            icon: section.$1,
            title: section.$2,
            onTap: () {
              final route = switch (section.$2) {
                'Basic Details' => AppRoutes.basicDetails,
                'Work Preferences' => AppRoutes.workPreferences,
                'Skills' || 'Experience' => AppRoutes.skillsExperience,
                'Documents' => AppRoutes.documentsUpload,
                'Identity Documents' => AppRoutes.documentsUpload,
                'Privacy' => AppRoutes.privacyVisibility,
                _ => AppRoutes.profile,
              };
              Navigator.of(context).pushNamed(route);
            },
          ),
          const SizedBox(height: 10),
        ],
        const SizedBox(height: 18),
        PrimaryButton(
          label: refreshing ? 'Refreshing...' : 'Reload Saved Data',
          onPressed: refreshing ? null : _refresh,
        ),
      ],
    );
  }
}
