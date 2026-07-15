import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/widgets/screen_scaffold.dart';

class AvailabilityStatusScreen extends StatefulWidget {
  const AvailabilityStatusScreen({super.key});

  @override
  State<AvailabilityStatusScreen> createState() =>
      _AvailabilityStatusScreenState();
}

class _AvailabilityStatusScreenState extends State<AvailabilityStatusScreen> {
  String value = 'Available immediately';
  final options = [
    'Available immediately',
    'Available after 1 week',
    'Available after 1 month',
    'Not currently looking'
  ];

  @override
  Widget build(BuildContext context) {
    return ScreenScaffold(
      title: 'Update Availability',
      showBack: true,
      children: [
        for (final option in options) ...[
          AppCard(
            onTap: () => setState(() => value = option),
            borderColor:
                value == option ? AppColors.primaryPink : AppColors.border,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Icon(
                  value == option
                      ? Icons.radio_button_checked
                      : Icons.radio_button_off,
                  color: value == option
                      ? AppColors.primaryPink
                      : AppColors.secondaryText,
                ),
                const SizedBox(width: 12),
                Expanded(child: Text(option, style: AppTextStyles.label)),
              ],
            ),
          ),
          const SizedBox(height: 10),
        ],
        const SizedBox(height: 24),
        PrimaryButton(
            label: 'Save Status', onPressed: () => Navigator.of(context).pop()),
      ],
    );
  }
}
