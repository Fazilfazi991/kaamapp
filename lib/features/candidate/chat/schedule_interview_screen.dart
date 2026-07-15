import 'package:flutter/material.dart';

import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/widgets/screen_scaffold.dart';

class ScheduleInterviewScreen extends StatelessWidget {
  const ScheduleInterviewScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ScreenScaffold(
      title: 'Schedule Interview',
      showBack: true,
      children: [
        const AppTextField(label: 'Preferred date', hint: 'Thursday, 9 July'),
        const SizedBox(height: 12),
        const AppTextField(label: 'Preferred time', hint: '10:00 AM'),
        const SizedBox(height: 12),
        const AppTextField(
            label: 'Interview mode: Call / WhatsApp / In-person',
            hint: 'WhatsApp'),
        const SizedBox(height: 12),
        const AppTextField(
            label: 'Notes', hint: 'I am available after 10 AM.', maxLines: 4),
        const SizedBox(height: 24),
        PrimaryButton(
            label: 'Send Availability',
            onPressed: () => Navigator.of(context).pop()),
      ],
    );
  }
}
