import 'package:flutter/material.dart';

import '../../../constants/app_colors.dart';
import '../../../widgets/common/custom_button.dart';

class DriverApplicationCard extends StatelessWidget {
  final Map<String, dynamic> application;
  final VoidCallback onAccept;
  final VoidCallback onReject;
  final VoidCallback onViewDetails;
  final bool isDark;

  const DriverApplicationCard({
    super.key,
    required this.application,
    required this.onAccept,
    required this.onReject,
    required this.onViewDetails,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.getCardColor(isDark),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.getBorderColor(isDark)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with driver info
            Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: AppColors.primary.withOpacity(0.1),
                  child: Text(
                    (application['name'] as String?)?.substring(0, 1).toUpperCase() ?? 'D',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        application['name'] ?? 'Driver',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.getTextPrimaryColor(isDark),
                        ),
                      ),
                      Text(
                        application['drivingExperience'] ?? 'Experience not specified',
                        style: TextStyle(
                          fontSize: 14,
                          color: AppColors.getTextSecondaryColor(isDark),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    application['status'] ?? 'Pending',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Contact info
            _buildDetailRow('Email', application['email']),
            _buildDetailRow('Phone', application['phoneNumber']),
            _buildDetailRow('ID Number', application['idNumber']),
            const SizedBox(height: 12),

            // Availability
            Text(
              'Availability',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.getTextPrimaryColor(isDark),
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.getBackgroundColor(isDark),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.getBorderColor(isDark)),
              ),
              child: Text(
                application['availability'] ?? 'Not specified',
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.getTextSecondaryColor(isDark),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Preferred areas
            Text(
              'Preferred Areas',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.getTextPrimaryColor(isDark),
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: (application['preferredAreas'] as List<dynamic>?)
                      ?.take(4)
                      .map((area) => Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              area.toString(),
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.primary,
                              ),
                            ),
                          ))
                      .toList() ??
                  [],
            ),
            const SizedBox(height: 12),

            // Preferences
            if ((application['preferences'] as List<dynamic>?)?.isNotEmpty == true)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Preferences',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.getTextPrimaryColor(isDark),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: (application['preferences'] as List<dynamic>)
                        .take(6)
                        .map((pref) => Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppColors.getCardColor(isDark),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: AppColors.getBorderColor(isDark)),
                              ),
                              child: Text(
                                pref.toString(),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.getTextSecondaryColor(isDark),
                                ),
                              ),
                            ))
                        .toList(),
                  ),
                  const SizedBox(height: 16),
                ],
              ),

            // Action buttons
            Row(
              children: [
                Expanded(
                  child: CustomButton(
                    text: 'View Details',
                    onPressed: onViewDetails,
                    isOutlined: true,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: CustomButton(
                    text: 'Reject',
                    onPressed: onReject,
                    isOutlined: true,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: CustomButton(
                    text: 'Accept',
                    onPressed: onAccept,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String? value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Text(
            '$label: ',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.getTextPrimaryColor(isDark),
            ),
          ),
          Expanded(
            child: Text(
              value ?? 'N/A',
              style: TextStyle(
                fontSize: 14,
                color: AppColors.getTextSecondaryColor(isDark),
              ),
            ),
          ),
        ],
      ),
    );
  }
} 