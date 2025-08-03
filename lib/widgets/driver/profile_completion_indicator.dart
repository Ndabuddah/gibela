import 'package:flutter/material.dart';
import '../../constants/app_colors.dart';
import '../../models/driver_model.dart';

class ProfileCompletionIndicator extends StatelessWidget {
  final DriverModel driver;
  final VoidCallback? onTap;

  const ProfileCompletionIndicator({
    Key? key,
    required this.driver,
    this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final percentage = driver.profileCompletionPercentage;

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    percentage == 100 ? Icons.verified : Icons.pending,
                    color: percentage == 100 ? Colors.green : AppColors.warning,
                    size: 24,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Profile Completion',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.getTextPrimaryColor(isDark),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Stack(
                children: [
                  Container(
                    height: 8,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  FractionallySizedBox(
                    widthFactor: percentage / 100,
                    child: Container(
                      height: 8,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: percentage == 100
                              ? [Colors.green, Colors.green.shade300]
                              : [AppColors.primary, AppColors.primaryLight],
                        ),
                        borderRadius: BorderRadius.circular(4),
                        boxShadow: [
                          BoxShadow(
                            color: (percentage == 100 ? Colors.green : AppColors.primary)
                                .withOpacity(0.3),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${percentage.toStringAsFixed(1)}% Complete',
                    style: TextStyle(
                      color: AppColors.getTextSecondaryColor(isDark),
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (percentage < 100)
                    Text(
                      'Tap to complete',
                      style: TextStyle(
                        color: AppColors.primary,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                ],
              ),
              if (percentage < 100) ...[
                const SizedBox(height: 16),
                _buildMissingItems(),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMissingItems() {
    final missingItems = _getMissingItems();
    if (missingItems.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Missing Items:',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Colors.grey,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: missingItems.map((item) => _buildMissingItemChip(item)).toList(),
        ),
      ],
    );
  }

  Widget _buildMissingItemChip(String item) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.warning.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.warning.withOpacity(0.3),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.warning_amber_rounded,
            size: 16,
            color: AppColors.warning,
          ),
          const SizedBox(width: 4),
          Text(
            item,
            style: TextStyle(
              fontSize: 12,
              color: AppColors.warning,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  List<String> _getMissingItems() {
    final List<String> missing = [];

    if (driver.name.isEmpty) missing.add('Full Name');
    if (driver.phoneNumber.isEmpty) missing.add('Phone Number');
    if (driver.email.isEmpty) missing.add('Email');
    if (driver.idNumber.isEmpty) missing.add('ID Number');
    if (driver.profileImage == null) missing.add('Profile Photo');
    if (driver.vehicleType == null) missing.add('Vehicle Type');
    if (driver.vehicleModel == null) missing.add('Vehicle Model');
    if (driver.licensePlate == null) missing.add('License Plate');
    if (driver.documents.isEmpty) missing.add('Required Documents');
    if (driver.workingHours.isEmpty) missing.add('Working Hours');
    if (driver.serviceAreaPreferences.isEmpty) missing.add('Service Areas');

    return missing;
  }
}