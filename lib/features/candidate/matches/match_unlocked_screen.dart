import 'package:flutter/material.dart';

import '../../../core/constants/app_routes.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/widgets/screen_scaffold.dart';
import '../../../core/widgets/secondary_button.dart';
import '../models/candidate_models.dart';

class MatchUnlockedScreen extends StatelessWidget {
  const MatchUnlockedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final match = ModalRoute.of(context)?.settings.arguments as MatchItem?;
    return ScreenScaffold(
      title: 'Match',
      showBack: true,
      children: [
        const SizedBox(height: 24),
        const Center(child: Icon(Icons.handshake_rounded, size: 76)),
        const SizedBox(height: 18),
        const Center(
            child: Text('Match Details', style: AppTextStyles.headline)),
        const SizedBox(height: 8),
        Text(
          match?.chatEnabled == true
              ? 'Both sides are interested. You can chat securely.'
              : 'Both sides are interested. Chat is available with an active membership.',
          textAlign: TextAlign.center,
          style: AppTextStyles.body,
        ),
        const SizedBox(height: 24),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(match?.company ?? 'Matched employer',
                  style: AppTextStyles.title),
              const SizedBox(height: 8),
              Text(match?.role ?? 'Matched role', style: AppTextStyles.body),
              if ((match?.location ?? '').isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(match!.location, style: AppTextStyles.body),
              ],
              const SizedBox(height: 12),
              Text(match?.preview ?? '', style: AppTextStyles.muted),
            ],
          ),
        ),
        const SizedBox(height: 24),
        PrimaryButton(
          label: match?.chatEnabled == true ? 'Start Chat' : 'Chat Locked',
          onPressed: match?.chatEnabled == true
              ? () => Navigator.of(context)
                  .pushNamed(AppRoutes.privateChat, arguments: match)
              : null,
        ),
        const SizedBox(height: 10),
        SecondaryButton(
          label: 'Back to Matches',
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }
}
