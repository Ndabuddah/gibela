import '../services/pricing_service.dart';

class VehicleTypeModel {
  final String id;
  final String name;
  final String subtitle;
  final double? basePrice; // Now optional since we calculate dynamically
  final String eta;
  final String imagePath;
  final int maxPeople;
  final double discountPercent; // 0 for none
  final bool available;
  final bool isPromo; // true if discountPercent > 0

  const VehicleTypeModel({
    required this.id,
    required this.name,
    required this.subtitle,
    this.basePrice, // Optional for backward compatibility
    required this.eta,
    required this.imagePath,
    required this.maxPeople,
    this.discountPercent = 0,
    this.available = true,
  }) : isPromo = discountPercent > 0;

  /// Calculate dynamic price based on distance
  double calculatePrice(double distanceKm, {DateTime? requestTime}) {
    return PricingService.calculateFare(
      distanceKm: distanceKm,
      vehicleType: id,
      discountPercent: discountPercent,
      requestTime: requestTime,
    );
  }

  /// Get estimated time based on distance
  String getEstimatedTime(double distanceKm) {
    return PricingService.getEstimatedTime(
      distanceKm: distanceKm,
      vehicleType: id,
    );
  }

  /// Get pricing information for display
  Map<String, dynamic> getPricingInfo(double distanceKm, {DateTime? requestTime}) {
    return PricingService.getPricingInfo(
      distanceKm: distanceKm,
      vehicleType: id,
      discountPercent: discountPercent,
      requestTime: requestTime,
    );
  }
}

const List<VehicleTypeModel> kVehicleTypes = [
  VehicleTypeModel(
    id: 'via',
    name: 'Asambe Via',
    subtitle: 'Affordable rides for up to 3',
    eta: '3-5 min',
    imagePath: 'assets/images/via.png',
    maxPeople: 3,
    discountPercent: 0,
    available: true,
  ),
  VehicleTypeModel(
    id: 'girl',
    name: 'AsambeGirl',
    subtitle: 'Women drivers for women',
    eta: '4-7 min',
    imagePath: 'assets/images/girl.png',
    maxPeople: 3,
    discountPercent: 0, // No discount by default, same price as Via
    available: true,
  ),
  VehicleTypeModel(
    id: 'seven',
    name: 'Asambe7',
    subtitle: 'For groups up to 6',
    eta: '6-10 min',
    imagePath: 'assets/images/7.png',
    maxPeople: 6,
    discountPercent: 0,
    available: true,
  ),
  VehicleTypeModel(
    id: 'luxury',
    name: 'AsambeLuxury',
    subtitle: 'Luxury experience',
    eta: '8-15 min',
    imagePath: 'assets/images/lux.png',
    maxPeople: 3,
    discountPercent: 0, // No discount by default, 55% more than Via
    available: true,
  ),
  VehicleTypeModel(
    id: 'student',
    name: 'AsambeStudent',
    subtitle: 'Discounted rides for students',
    eta: '5-10 min',
    imagePath: 'assets/images/student.png',
    maxPeople: 3,
    discountPercent: 0, // No discount by default, 3% lower than Via
    available: true,
  ),
  VehicleTypeModel(
    id: 'parcel',
    name: 'Asambe Parcel',
    subtitle: 'Send a package',
    eta: '5-12 min',
    imagePath: 'assets/images/parcel.png',
    maxPeople: 1,
    discountPercent: 0, // No discount by default, 60% less than Via
    available: true,
  ),
];
