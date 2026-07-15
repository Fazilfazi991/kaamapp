import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

class PrivacyBadge extends StatelessWidget {
  const PrivacyBadge({super.key, this.label = 'Privacy Mode ON'});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(color: AppColors.softPink.withValues(alpha: .14), borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.softPink.withValues(alpha: .35))),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Icon(Icons.lock_outline, color: AppColors.softPink, size: 18),
        const SizedBox(width: 8),
        Expanded(child: Text(label, softWrap: true, style: const TextStyle(color: AppColors.softPink, fontSize: 13, fontWeight: FontWeight.w700, height: 1.25))),
      ]),
    );
  }
}
