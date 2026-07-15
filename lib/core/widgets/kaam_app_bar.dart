import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

class KaamAppBar extends StatelessWidget implements PreferredSizeWidget {
  const KaamAppBar({
    super.key,
    this.title = 'Kaam',
    this.showBack = false,
    this.actions,
  });

  final String title;
  final bool showBack;
  final List<Widget>? actions;

  @override
  Size get preferredSize => const Size.fromHeight(64);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      automaticallyImplyLeading: showBack,
      title: Text(title,
          style: AppTextStyles.title.copyWith(color: AppColors.primaryPink)),
      actions: actions,
      flexibleSpace: Container(
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: AppColors.border)),
        ),
      ),
    );
  }
}
