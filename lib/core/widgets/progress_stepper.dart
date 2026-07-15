import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

class ProgressStepper extends StatelessWidget {
  const ProgressStepper(
      {super.key, required this.current, required this.total});

  final int current;
  final int total;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Step $current of $total',
          style: const TextStyle(
            color: AppColors.softPink,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            minHeight: 8,
            value: current / total,
            backgroundColor: AppColors.border,
            valueColor: const AlwaysStoppedAnimation(AppColors.primaryPink),
          ),
        ),
      ],
    );
  }
}
