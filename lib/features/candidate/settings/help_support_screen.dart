import 'package:flutter/material.dart';

import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/screen_scaffold.dart';

class HelpSupportScreen extends StatelessWidget {
  const HelpSupportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const ScreenScaffold(
      title: 'Help & Support',
      showBack: true,
      children: [
        Text('How can we help?', style: AppTextStyles.headline),
        SizedBox(height: 14),
        AppCard(
          child: Text(
            'WhatsApp support: Coming soon\nEmail support: support@kaam.app',
            style: AppTextStyles.body,
          ),
        ),
        SizedBox(height: 12),
        AppCard(
          child: Text(
            'FAQ\n\nYour phone and email stay private before an accepted match.\n\nEmployers can send interest requests. Chat opens only after you accept.\n\nDocuments are stored privately and shared only with your permission.',
            style: AppTextStyles.body,
          ),
        ),
      ],
    );
  }
}
