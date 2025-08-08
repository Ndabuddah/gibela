import 'package:flutter/material.dart';
import '../../../constants/app_colors.dart';
import '../../../providers/theme_provider.dart';
import 'package:provider/provider.dart';

class ScheduledTripHeader extends StatelessWidget {
  const ScheduledTripHeader({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isDark = Provider.of<ThemeProvider>(context).isDarkMode;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.getCardColor(isDark),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.getBorderColor(isDark)),
      ),
      child: Column(
        children: [
          Icon(
            Icons.schedule,
            size: 48,
            color: AppColors.primary,
          ),
          const SizedBox(height: 12),
          Text(
            'Schedule Your Trip',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: AppColors.getTextPrimaryColor(isDark),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Book a ride for a future date and time',
            style: TextStyle(
              fontSize: 16,
              color: AppColors.getTextSecondaryColor(isDark),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
} 