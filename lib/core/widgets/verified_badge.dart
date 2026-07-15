import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import 'status_badge.dart';

class VerifiedBadge extends StatelessWidget {
  const VerifiedBadge({super.key, this.pending = false});

  final bool pending;

  @override
  Widget build(BuildContext context) {
    return StatusBadge(
      label: pending ? 'Pending Review' : 'Verified',
      color: pending ? AppColors.warning : AppColors.success,
      icon: pending ? Icons.schedule_rounded : Icons.verified_rounded,
    );
  }
}
