import 'package:flutter/material.dart';

import '../../core/config/app_config.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/app_card.dart';

class QaMode {
  const QaMode._();

  static bool get enabled => AppConfig.qaModeEnabled;
}

class QaLoginShortcuts extends StatelessWidget {
  const QaLoginShortcuts({
    super.key,
    required this.onPickEmail,
    this.showCandidate = true,
    this.showEmployer = true,
    this.showAdmin = true,
  });

  final ValueChanged<String> onPickEmail;
  final bool showCandidate;
  final bool showEmployer;
  final bool showAdmin;

  @override
  Widget build(BuildContext context) {
    if (!QaMode.enabled) return const SizedBox.shrink();
    final items = <({String label, String email})>[
      if (showCandidate)
        (label: 'Candidate QA', email: AppConfig.qaCandidateEmail),
      if (showEmployer)
        (label: 'Employer QA', email: AppConfig.qaEmployerEmail),
      if (showAdmin)
        (label: 'Admin QA', email: AppConfig.qaAdminEmail),
    ].where((item) => item.email.trim().isNotEmpty).toList();
    if (items.isEmpty) return const SizedBox.shrink();
    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('QA Test Login', style: AppTextStyles.label),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final item in items)
                OutlinedButton(
                  onPressed: () => onPickEmail(item.email),
                  child: Text(item.label),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
