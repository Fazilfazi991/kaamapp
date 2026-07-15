import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

void showShareCvModal(BuildContext context) {
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: AppColors.elevatedCard,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (context) => Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Share your CV?',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          const Text('Your CV will be shared only with this matched employer.'),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                  child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel'))),
              const SizedBox(width: 12),
              Expanded(
                  child: FilledButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Share CV'))),
            ],
          ),
        ],
      ),
    ),
  );
}
