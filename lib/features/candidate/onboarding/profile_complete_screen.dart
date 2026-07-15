import 'package:flutter/material.dart';

import '../../../core/constants/app_routes.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/candidate_widgets.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/widgets/screen_scaffold.dart';
import '../../supabase_backend/kaam_backend.dart';
import '../profile/candidate_profile_completion.dart';

class ProfileCompleteScreen extends StatefulWidget {
  const ProfileCompleteScreen({super.key});

  @override
  State<ProfileCompleteScreen> createState() => _ProfileCompleteScreenState();
}

class _ProfileCompleteScreenState extends State<ProfileCompleteScreen> {
  final profiles = const CandidateProfileRepository();
  final storage = const KaamStorageRepository();
  late Future<
      ({
        CandidateProfileData profile,
        List<VerificationDocumentData> documents,
        CandidateIdentityDocumentData identity,
      })>
      dataFuture = _load();

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

  @override
  Widget build(BuildContext context) {
    return ScreenScaffold(
      title: 'Ready',
      children: [
        const SizedBox(height: 36),
        const Center(child: Icon(Icons.celebration_rounded, size: 72)),
        const SizedBox(height: 18),
        const Center(
            child: Text('Your profile is ready!',
                style: AppTextStyles.headline, textAlign: TextAlign.center)),
        const SizedBox(height: 10),
        const Text(
          'Employers can now discover your profile while your contact details stay private.',
          style: AppTextStyles.body,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
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
        const SizedBox(height: 24),
        PrimaryButton(
          label: 'Go to Jobs',
          onPressed: () => Navigator.of(context)
              .pushNamedAndRemoveUntil(AppRoutes.dashboard, (_) => false),
        ),
      ],
    );
  }
}
