import 'package:flutter/material.dart';

import '../../../core/constants/app_routes.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/widgets/screen_scaffold.dart';
import '../../../core/widgets/secondary_button.dart';

class MatchUnlockedScreen extends StatelessWidget {
  const MatchUnlockedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ScreenScaffold(
      title: 'Match',
      showBack: true,
      children: [
        const SizedBox(height: 24),
        const Center(child: Icon(Icons.handshake_rounded, size: 76)),
        const SizedBox(height: 18),
        const Center(
            child: Text('Match Unlocked', style: AppTextStyles.headline)),
        const SizedBox(height: 8),
        const Text(
          'Both sides are interested. You can now chat securely.',
          textAlign: TextAlign.center,
          style: AppTextStyles.body,
        ),
        const SizedBox(height: 24),
        const AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Bright Star Cleaning Services', style: AppTextStyles.title),
              SizedBox(height: 8),
              Text('Cleaner Supervisor', style: AppTextStyles.body),
              SizedBox(height: 8),
              Text('AED 2,200 - AED 2,800 • Dubai, UAE',
                  style: AppTextStyles.body),
            ],
          ),
        ),
        const SizedBox(height: 24),
        PrimaryButton(
          label: 'Start Chat',
          onPressed: () =>
              Navigator.of(context).pushNamed(AppRoutes.privateChat),
        ),
        const SizedBox(height: 10),
        SecondaryButton(label: 'View Employer Profile', onPressed: () {}),
      ],
    );
  }
}
