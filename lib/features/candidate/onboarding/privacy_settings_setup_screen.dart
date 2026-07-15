import 'package:flutter/material.dart';

import '../../../core/constants/app_routes.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/widgets/progress_stepper.dart';
import '../../../core/widgets/screen_scaffold.dart';

class PrivacySettingsSetupScreen extends StatefulWidget {
  const PrivacySettingsSetupScreen({super.key});

  @override
  State<PrivacySettingsSetupScreen> createState() =>
      _PrivacySettingsSetupScreenState();
}

class _PrivacySettingsSetupScreenState
    extends State<PrivacySettingsSetupScreen> {
  final values = [true, true, true, true, false];
  final labels = [
    'Show my profile to employers',
    'Hide my phone number before match',
    'Require approval before chat',
    'Allow CV sharing only after match',
    'Hide from current employer',
  ];

  @override
  Widget build(BuildContext context) {
    return ScreenScaffold(
      title: 'Privacy',
      showBack: true,
      children: [
        const ProgressStepper(current: 5, total: 5),
        const SizedBox(height: 22),
        const Text('Control your visibility', style: AppTextStyles.headline),
        const SizedBox(height: 16),
        for (var i = 0; i < labels.length; i++)
          SwitchListTile(
            value: values[i],
            onChanged: (value) => setState(() => values[i] = value),
            title: Text(labels[i]),
          ),
        const SizedBox(height: 24),
        PrimaryButton(
          label: 'Complete Profile',
          onPressed: () =>
              Navigator.of(context).pushNamed(AppRoutes.profileComplete),
        ),
      ],
    );
  }
}
