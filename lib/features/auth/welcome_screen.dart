import 'package:flutter/material.dart';

import '../../core/constants/app_assets.dart';
import '../../core/constants/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/primary_button.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(28, 24, 28, 34),
              child: Column(
                children: [
                  const Spacer(flex: 2),
                  Image.asset(AppAssets.logo, width: 176, fit: BoxFit.contain),
                  const SizedBox(height: 30),
                  const Text('Kaam', style: AppTextStyles.display),
                  const SizedBox(height: 8),
                  Text('Perfect Match', style: AppTextStyles.title.copyWith(color: AppColors.primaryPink)),
                  const SizedBox(height: 14),
                  const Text('Privacy-first hiring starts here', style: AppTextStyles.body, textAlign: TextAlign.center),
                  const Spacer(flex: 3),
                  PrimaryButton(
                    label: 'Get Started',
                    onPressed: () => Navigator.of(context).pushNamed(AppRoutes.roleSelection),
                  ),
                  const SizedBox(height: 16),
                  const Text('Your details stay private until you choose to connect.', style: AppTextStyles.muted, textAlign: TextAlign.center),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
