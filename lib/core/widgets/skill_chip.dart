import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

class SkillChip extends StatelessWidget {
  const SkillChip({super.key, required this.label, this.selected = false});

  final String label;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Chip(
      label: Text(label),
      labelStyle: TextStyle(
        color: selected ? AppColors.primaryPink : AppColors.secondaryText,
        fontWeight: FontWeight.w700,
      ),
      side: BorderSide(
          color: selected ? AppColors.primaryPink : AppColors.border),
      backgroundColor: selected
          ? AppColors.primaryPink.withValues(alpha: 0.12)
          : AppColors.elevatedCard,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
    );
  }
}
