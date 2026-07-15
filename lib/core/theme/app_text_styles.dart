import 'package:flutter/material.dart';

import 'app_colors.dart';

class AppTextStyles {
  const AppTextStyles._();

  static const display = TextStyle(
    fontSize: 34,
    height: 1.12,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.3,
    color: AppColors.white,
  );

  static const headline = TextStyle(
    fontSize: 26,
    height: 1.25,
    fontWeight: FontWeight.w800,
    color: AppColors.white,
  );

  static const title = TextStyle(
    fontSize: 20,
    height: 1.3,
    fontWeight: FontWeight.w700,
    color: AppColors.white,
  );

  static const body = TextStyle(
    fontSize: 15,
    height: 1.45,
    color: AppColors.secondaryText,
  );

  static const label = TextStyle(
    fontSize: 13,
    height: 1.25,
    fontWeight: FontWeight.w700,
    color: AppColors.white,
  );

  static const muted = TextStyle(
    fontSize: 13,
    height: 1.35,
    color: AppColors.mutedText,
  );
}
