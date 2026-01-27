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
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Select Ride',
              style: TextStyle(
                fontSize: 20, 
                fontWeight: FontWeight.w900, 
                color: AppColors.getTextPrimaryColor(isDark),
                letterSpacing: -0.5,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                children: [
                  Icon(Icons.history, size: 14, color: AppColors.primary),
                  const SizedBox(width: 4),
                  Text(
                    'Best Price',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        ListView.separated(
          shrinkWrap: true,
          padding: EdgeInsets.zero,
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

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      margin: const EdgeInsets.only(bottom: 2),
      decoration: BoxDecoration(
        color: isSelected 
            ? AppColors.primary.withOpacity(isDark ? 0.12 : 0.08) 
            : (isDark ? Colors.white.withOpacity(0.03) : Colors.white),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isSelected 
              ? AppColors.primary.withOpacity(0.5) 
              : (isDark ? Colors.white10 : Colors.black.withOpacity(0.05)),
          width: isSelected ? 2 : 1,
        ),
        boxShadow: isSelected ? [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.1),
            blurRadius: 12,
            offset: const Offset(0, 4),
          )
        ] : [],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isDisabled ? onTap : onTap, // Allow tap even if disabled to show verification dialog
          borderRadius: BorderRadius.circular(18),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Vehicle image with container
                Container(
                  width: 64,
                  height: 64,
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white.withOpacity(0.05) : const Color(0xFFF5F5F5),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Image.asset(
                    image,
                    fit: BoxFit.contain,
                    opacity: isDisabled ? const AlwaysStoppedAnimation(0.5) : null,
                  ),
                ),
                const SizedBox(width: 16),
                
                // Vehicle info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            name,
                            style: TextStyle(
                              fontSize: 16, 
                              fontWeight: FontWeight.bold, 
                              color: isDisabled ? Colors.grey : AppColors.getTextPrimaryColor(isDark)
                            ),
                          ),
                          if (isPeak || isNight) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: isPeak ? Colors.orange : Colors.indigo, 
                                borderRadius: BorderRadius.circular(6)
                              ),
                              child: Text(
                                isPeak ? 'PEAK' : 'NIGHT',
                                style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle, 
                        style: TextStyle(
                          fontSize: 12, 
                          color: isDisabled ? Colors.grey : AppColors.getTextSecondaryColor(isDark),
                          height: 1.2,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(Icons.person_outline, size: 14, color: isSelected ? AppColors.primary : Colors.grey),
                          const SizedBox(width: 4),
                          Text(
                            maxPeople.toString(), 
                            style: TextStyle(
                              fontSize: 12, 
                              color: isSelected ? AppColors.primary : Colors.grey,
                              fontWeight: FontWeight.w600,
                            )
                          ),
                          const SizedBox(width: 12),
                          Icon(Icons.access_time_outlined, size: 14, color: Colors.grey),
                          const SizedBox(width: 4),
                          Text(
                            eta, 
                            style: const TextStyle(fontSize: 12, color: Colors.grey)
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                
                // Price & Selection indicator
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'R${price.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontSize: 18, 
                        fontWeight: FontWeight.w900, 
                        color: isDisabled ? Colors.grey : AppColors.primary,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (isSelected)
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.check, color: Colors.white, size: 12),
                      )
                    else if (isDisabled)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.grey.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey.withOpacity(0.2)),
                        ),
                        child: const Text(
                          'Locked',
                          style: TextStyle(color: Colors.grey, fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
