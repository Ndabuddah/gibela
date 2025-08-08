import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../constants/app_colors.dart';
import '../../models/vehicle_type_model.dart';
import '../../providers/theme_provider.dart';
import '../../services/pricing_service.dart';

class VehicleSelection extends StatelessWidget {
  final String selectedType;
  final Function(String) onChanged;
  final double? distanceKm;
  final DateTime? requestTime;
  final Set<String>? disabledTypes;
  final void Function(String type)? onDisabledTap;

  const VehicleSelection({Key? key, required this.selectedType, required this.onChanged, this.distanceKm, this.requestTime, this.disabledTypes, this.onDisabledTap}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isDark = Provider.of<ThemeProvider>(context).isDarkMode;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Select Vehicle Type',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.getTextPrimaryColor(isDark)),
        ),
        const SizedBox(height: 16),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: kVehicleTypes.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final vehicle = kVehicleTypes[index];
            final isSelected = selectedType == vehicle.id;
            final pricingInfo = PricingService.getPricingInfo(distanceKm: distanceKm ?? 0, vehicleType: vehicle.id, requestTime: requestTime);

            final isDisabled = (disabledTypes ?? const {}).contains(vehicle.id);
            return _VehicleTypeCard(
              type: vehicle.id,
              name: vehicle.name,
              image: vehicle.imagePath,
              isSelected: isSelected,
              isDisabled: isDisabled,
              onTap: () {
                if (isDisabled) {
                  onDisabledTap?.call(vehicle.id);
                } else {
                  onChanged(vehicle.id);
                }
              },
              pricingInfo: pricingInfo,
              maxPeople: vehicle.maxPeople,
              subtitle: vehicle.subtitle,
              isDark: isDark,
            );
          },
        ),
      ],
    );
  }
}

class _VehicleTypeCard extends StatelessWidget {
  final String type;
  final String name;
  final String image;
  final bool isSelected;
  final bool isDisabled;
  final VoidCallback onTap;
  final Map<String, dynamic> pricingInfo;
  final int maxPeople;
  final String subtitle;
  final bool isDark;

  const _VehicleTypeCard({Key? key, required this.type, required this.name, required this.image, required this.isSelected, required this.isDisabled, required this.onTap, required this.pricingInfo, required this.maxPeople, required this.subtitle, required this.isDark}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final price = pricingInfo['finalPrice'] as double;
    final eta = pricingInfo['estimatedTime'] as String;
    final isPeak = pricingInfo['isPeak'] as bool;
    final isNight = pricingInfo['isNight'] as bool;

    return Material(
      color: isSelected ? AppColors.primary.withOpacity(0.08) : Colors.transparent,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: isDisabled ? null : onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
          child: Row(
            children: [
              // Vehicle image
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                child: Image.asset(image, width: 24, height: 24),
              ),
              const SizedBox(width: 12),
              // Vehicle info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          name,
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: isDisabled ? Colors.grey : AppColors.getTextPrimaryColor(isDark)),
                        ),
                        if (isPeak || isNight) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(color: isPeak ? Colors.orange : Colors.indigo, borderRadius: BorderRadius.circular(12)),
                            child: Text(
                              isPeak ? 'PEAK' : 'NIGHT',
                              style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(subtitle, style: TextStyle(fontSize: 11, color: isDisabled ? Colors.grey : AppColors.getTextSecondaryColor(isDark))),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.person, size: 14, color: AppColors.primary),
                        const SizedBox(width: 4),
                        Text(maxPeople.toString(), style: TextStyle(fontSize: 11, color: AppColors.getTextSecondaryColor(isDark))),
                        const SizedBox(width: 16),
                      ],
                    ),
                  ],
                ),
              ),
              // Price (constrained to avoid overflow)
              SizedBox(
                width: 96,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerRight,
                      child: Text(
                        'R${price.toStringAsFixed(2)}',
                        maxLines: 1,
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: isDisabled ? Colors.grey : AppColors.primary),
                      ),
                    ),
                    if (isSelected)
                      Container(
                        margin: const EdgeInsets.only(top: 4),
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(12)),
                        child: const Text(
                          'Selected',
                          style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                      ),
                    if (isDisabled)
                      Container(
                        margin: const EdgeInsets.only(top: 4),
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(color: Colors.grey.shade400, borderRadius: BorderRadius.circular(12)),
                        child: const Text(
                          'Verify to use',
                          style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
