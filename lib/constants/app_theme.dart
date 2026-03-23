import 'package:flutter/material.dart';
import 'app_colors.dart';

class AppTheme {
  // Colors
  static const Color primaryColor = AppColors.primary;
  static const Color darkBackground = AppColors.darkBackground;
  static const Color darkerBackground = AppColors.darkCard;
  static const Color greyText = AppColors.lightTextHint;

  // Text Styles
  static const TextStyle subTitleStyle = TextStyle(
    color: AppColors.lightTextHint,
    fontSize: 14,
    fontWeight: FontWeight.w500,
  );

  static const TextStyle nameStyle = TextStyle(
    color: AppColors.lightTextPrimary,
    fontSize: 16,
    fontWeight: FontWeight.w600,
  );

  static const TextStyle timeStyle = TextStyle(
    color: AppColors.lightTextHint,
    fontSize: 12,
    fontWeight: FontWeight.w500,
  );

  static const TextStyle recentNameStyle = TextStyle(
    color: AppColors.lightTextPrimary,
    fontSize: 14,
    fontWeight: FontWeight.w500,
  );
}


