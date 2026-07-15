import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/widgets/screen_scaffold.dart';

class ProfileViewsScreen extends StatelessWidget {
  const ProfileViewsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ScreenScaffold(
      title: 'Profile Views',
      showBack: true,
      children: [
        const AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('17 views this week', style: AppTextStyles.title),
              SizedBox(height: 8),
              Text('11 employers viewed your profile',
                  style: AppTextStyles.body),
              SizedBox(height: 8),
              Text('3 interest requests received', style: AppTextStyles.body),
            ],
          ),
        ),
        const SizedBox(height: 16),
        AppCard(
          child: SizedBox(
            height: 140,
            child: CustomPaint(
              painter: _LineChartPainter(),
              child: const Center(
                  child:
                      Text('Weekly profile views', style: AppTextStyles.muted)),
            ),
          ),
        ),
        const SizedBox(height: 16),
        const Text('Recent viewers', style: AppTextStyles.title),
        const SizedBox(height: 10),
        const AppCard(
            child: Text('Verified employer viewed your profile',
                style: AppTextStyles.body)),
        const SizedBox(height: 10),
        const AppCard(
            child: Text('Bright Star Cleaning Services viewed your profile',
                style: AppTextStyles.body)),
        const SizedBox(height: 10),
        const AppCard(
            child: Text('City Way Facilities viewed your profile',
                style: AppTextStyles.body)),
        const SizedBox(height: 24),
        PrimaryButton(
            label: 'Improve Profile',
            onPressed: () => Navigator.of(context).pop()),
      ],
    );
  }
}

class _LineChartPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.primaryPink
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final path = Path()
      ..moveTo(0, size.height * 0.75)
      ..cubicTo(size.width * 0.2, size.height * 0.4, size.width * 0.35,
          size.height * 0.9, size.width * 0.55, size.height * 0.45)
      ..cubicTo(size.width * 0.7, size.height * 0.1, size.width * 0.82,
          size.height * 0.6, size.width, size.height * 0.25);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
