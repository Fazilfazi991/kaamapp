import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import 'app_card.dart';

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.action,
  });

  final IconData icon;
  final String title;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        children: [
          CircleAvatar(
            radius: 30,
            backgroundColor: AppColors.primaryPink.withValues(alpha: 0.14),
            child: Icon(icon, color: AppColors.primaryPink, size: 30),
          ),
          const SizedBox(height: 16),
          Text(title, style: AppTextStyles.title, textAlign: TextAlign.center),
          const SizedBox(height: 8),
          Text(message, style: AppTextStyles.body, textAlign: TextAlign.center),
          if (action != null) ...[
            const SizedBox(height: 18),
            action!,
          ],
        ],
      ),
    );
  }
}
