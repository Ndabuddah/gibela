import 'package:flutter/material.dart';

import '../../../constants/app_colors.dart';
import '../../../widgets/common/custom_button.dart';

class VehicleOfferCard extends StatelessWidget {
  final Map<String, dynamic> offer;
  final VoidCallback onAccept;
  final VoidCallback onReject;
  final bool isDark;

  const VehicleOfferCard({
    super.key,
    required this.offer,
    required this.onAccept,
    required this.onReject,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.getCardColor(isDark),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.getBorderColor(isDark), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
            spreadRadius: 0,
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with vehicle info
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    Icons.directions_car_filled,
                    color: AppColors.primary,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${offer['vehicleMake']} ${offer['vehicleModel']}',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: AppColors.getTextPrimaryColor(isDark),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${offer['vehicleYear']} • ${offer['vehicleType']}',
                        style: TextStyle(
                          fontSize: 15,
                          color: AppColors.getTextSecondaryColor(isDark),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Vehicle details in a more compact format
            _buildCompactDetails(),
            const SizedBox(height: 16),

            // Features (limited to prevent overflow)
            if ((offer['features'] as List<dynamic>?)?.isNotEmpty == true) ...[
              _buildSectionTitle('Features'),
              const SizedBox(height: 8),
              _buildFeaturesChips(offer['features'] as List<dynamic>),
              const SizedBox(height: 16),
            ],

            // Service areas (limited to prevent overflow)
            _buildSectionTitle('Service Areas'),
            const SizedBox(height: 8),
            _buildServiceAreasChips(offer['serviceAreas'] as List<dynamic>),
            const SizedBox(height: 16),

            // Description (truncated to prevent overflow)
            if (offer['description']?.isNotEmpty == true) ...[
              _buildSectionTitle('Description'),
              const SizedBox(height: 8),
              Text(
                offer['description'],
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.getTextSecondaryColor(isDark),
                  height: 1.4,
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 16),
            ],

            // Owner info with improved design
            _buildOwnerInfo(),
            const SizedBox(height: 20),

            // Action buttons with better styling
            Row(
              children: [
                Expanded(
                  child: Container(
                    height: 48,
                    decoration: BoxDecoration(
                      border: Border.all(color: AppColors.getBorderColor(isDark), width: 1.5),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: TextButton.icon(
                      onPressed: onReject,
                      icon: const Icon(Icons.close, size: 20),
                      label: const Text(
                        'Reject',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.getTextSecondaryColor(isDark),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Container(
                    height: 48,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [AppColors.primary, AppColors.primary.withOpacity(0.8)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: TextButton.icon(
                      onPressed: onAccept,
                      icon: const Icon(Icons.check, size: 20, color: Colors.white),
                      label: const Text(
                        'Accept',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      style: TextButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompactDetails() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.getBackgroundColor(isDark),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.getBorderColor(isDark), width: 0.5),
      ),
      child: Column(
        children: [
          _buildDetailRow(Icons.confirmation_number, 'License Plate', offer['licensePlate']),
          const SizedBox(height: 12),
          _buildDetailRow(Icons.settings, 'Transmission', offer['transmission']),
          const SizedBox(height: 12),
          _buildDetailRow(Icons.local_gas_station, 'Fuel Type', offer['fuelType']),
          const SizedBox(height: 12),
          _buildDetailRow(Icons.build, 'Condition', offer['vehicleCondition']),
        ],
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String? value) {
    return Row(
      children: [
        Icon(
          icon,
          size: 18,
          color: AppColors.getTextSecondaryColor(isDark),
        ),
        const SizedBox(width: 8),
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
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.bold,
        color: AppColors.getTextPrimaryColor(isDark),
      ),
    );
  }

  Widget _buildFeaturesChips(List<dynamic> features) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: features
          .take(4) // Limit to prevent overflow
          .map((feature) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.primary.withOpacity(0.3)),
                ),
                child: Text(
                  feature.toString(),
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ))
          .toList(),
    );
  }

  Widget _buildServiceAreasChips(List<dynamic> areas) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: areas
          .take(3) // Limit to prevent overflow
          .map((area) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.getBackgroundColor(isDark),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.getBorderColor(isDark)),
                ),
                child: Text(
                  area.toString(),
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.getTextSecondaryColor(isDark),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ))
          .toList(),
    );
  }

  Widget _buildOwnerInfo() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.getBackgroundColor(isDark),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.getBorderColor(isDark), width: 0.5),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.person,
              color: AppColors.primary,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  offer['ownerName'] ?? 'Vehicle Owner',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.getTextPrimaryColor(isDark),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Car Owner',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.getTextSecondaryColor(isDark),
                  ),
                ),
              ],
            ),
          ),
          if (offer['rating'] != null) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.amber.withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.star,
                    color: Colors.amber,
                    size: 16,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    offer['rating'].toString(),
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: AppColors.getTextPrimaryColor(isDark),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
} 