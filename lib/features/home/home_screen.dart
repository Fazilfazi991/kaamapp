import 'package:flutter/material.dart';

import '../../core/constants/app_assets.dart';
import '../../core/constants/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/primary_button.dart';
import '../../core/widgets/screen_scaffold.dart';
import '../../core/widgets/secondary_button.dart';
import '../../core/widgets/section_header.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ScreenScaffold(
      title: 'Kaam',
      children: [
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppColors.primaryPink.withValues(alpha: 0.1),
            border: Border.all(
                color: AppColors.primaryPink.withValues(alpha: 0.35)),
            borderRadius: BorderRadius.circular(28),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Image.asset(
                AppAssets.logo,
                width: 240,
                fit: BoxFit.contain,
              ),
              const SizedBox(height: 12),
              const Text('Privacy-first hiring for UAE and GCC teams.',
                  style: AppTextStyles.body),
              const SizedBox(height: 20),
              PrimaryButton(
                  label: 'Find Work',
                  onPressed: () =>
                      Navigator.of(context).pushNamed(AppRoutes.roleSelection)),
              const SizedBox(height: 10),
              SecondaryButton(
                  label: 'Hire Talent',
                  onPressed: () =>
                      Navigator.of(context).pushNamed(AppRoutes.roleSelection)),
            ],
          ),
        ),
        const SizedBox(height: 24),
        const SectionHeader(title: 'Privacy-first'),
        const SizedBox(height: 10),
        const AppCard(
            child: Text(
                'Candidates stay in control. Employers can send interest, but chat and private contact access unlock only after acceptance.',
                style: AppTextStyles.body)),
        const SizedBox(height: 20),
        const SectionHeader(title: 'How it works'),
        const SizedBox(height: 10),
        const AppCard(
            child: Text(
                '1. Build profile\n2. Receive verified employer interest\n3. Accept only the right matches\n4. Chat securely',
                style: AppTextStyles.body)),
        const SizedBox(height: 20),
        const SectionHeader(title: 'Candidate benefits'),
        const SizedBox(height: 10),
        const AppCard(
            child: Text(
                'Private contact details, focused job matches, and simple profile tools for blue-collar and semi-skilled workers.',
                style: AppTextStyles.body)),
        const SizedBox(height: 20),
        const SectionHeader(title: 'Employer benefits'),
        const SizedBox(height: 10),
        const AppCard(
            child: Text(
                'Discover ready candidates, send respectful interest requests, and chat only with accepted matches.',
                style: AppTextStyles.body)),
        const SizedBox(height: 20),
        const SectionHeader(title: 'Employer access'),
        const SizedBox(height: 10),
        const AppCard(
            child: Text(
                'Employers can create a company profile, add hiring requirements, search visible candidates, and send interest requests.',
                style: AppTextStyles.body)),
        const SizedBox(height: 20),
        const SectionHeader(title: 'FAQ'),
        const SizedBox(height: 10),
        const AppCard(
            child: Text(
                'Are phone numbers public? No. Candidate contact details stay hidden before accepted matches.',
                style: AppTextStyles.body)),
      ],
    );
  }
}
