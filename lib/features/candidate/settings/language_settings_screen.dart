import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/screen_scaffold.dart';

class LanguageSettingsScreen extends StatefulWidget {
  const LanguageSettingsScreen({super.key});

  @override
  State<LanguageSettingsScreen> createState() => _LanguageSettingsScreenState();
}

class _LanguageSettingsScreenState extends State<LanguageSettingsScreen> {
  String selected = 'English';

  static const languages = ['English', 'Malayalam', 'Hindi', 'Arabic'];

  @override
  Widget build(BuildContext context) {
    return ScreenScaffold(
      title: 'Language',
      showBack: true,
      children: [
        const Text('App language preference', style: AppTextStyles.headline),
        const SizedBox(height: 8),
        const Text(
          'English is active now. Other app translations are coming soon.',
          style: AppTextStyles.body,
        ),
        const SizedBox(height: 18),
        for (final language in languages) ...[
          AppCard(
            onTap: language == 'English'
                ? () => setState(() => selected = language)
                : null,
            borderColor:
                selected == language ? AppColors.primaryPink : AppColors.border,
            child: Row(
              children: [
                Icon(
                  selected == language
                      ? Icons.radio_button_checked
                      : Icons.radio_button_off,
                  color: selected == language
                      ? AppColors.primaryPink
                      : AppColors.secondaryText,
                ),
                const SizedBox(width: 12),
                Expanded(child: Text(language, style: AppTextStyles.label)),
                if (language != 'English')
                  const Text('Coming soon', style: AppTextStyles.muted),
              ],
            ),
          ),
          const SizedBox(height: 10),
        ],
      ],
    );
  }
}
