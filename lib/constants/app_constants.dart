class AppConstants {
  // Bolt-like fare structure
  static const double smallBaseFare = 27.0;
  static const double smallPerKm = 7.0;
  static const double smallVehicleMultiplier = 1.0;

  static const double sedanBaseFare = 32.0; // average of 28-35
  static const double sedanPerKm = 8.5;
  static const double sedanVehicleMultiplier = 1.2;

  static const double largeBaseFare = 50.0; // average of 39-85
  static const double largePerKm = 13.0; // average of 11-15
  static const double largeVehicleMultiplier = 2.0;

  static const double parcelBaseFare = smallBaseFare / 2;
  static const double parcelPerKm = smallPerKm / 2;
  static const double parcelVehicleMultiplier = 0.5;

  // Time multipliers
  static const double offPeakMultiplier = 1.0;
  static const double peakMultiplier = 1.3;

  // Risk factor multipliers (areas can be classified as low, medium, high risk)
  static const double lowRiskMultiplier = 1.0;
  static const double mediumRiskMultiplier = 1.2;
  static const double highRiskMultiplier = 1.5;

  // Peak hours (24-hour format)
  static const int peakMorningStart = 6; // 6 AM
  static const int peakMorningEnd = 9; // 9 AM
  static const int peakEveningStart = 16; // 4 PM
  static const int peakEveningEnd = 19; // 7 PM

  // Cloudinary details
  static const String cloudinaryUrl = "cloudinary://253268628468244:3XvYMqbp_tnDLHUGj5pfxjjcfGo@dunfw4ifc";
  static const String cloudinaryUploadUrl = "https://api.cloudinary.com/v1_1/dunfw4ifc/image/upload";
  static const String cloudinaryUploadPreset = "beauti";

  // App configurations
  static const int splashDuration = 3; // seconds
  static const int locationRefreshInterval = 10; // seconds
  static const int driverSearchRadius = 5; // kilometers

  // Driver document types
  static const List<String> requiredDriverDocuments = [
    'ID Document',
    'Professional Driving Permit',
    'Roadworthy Certificate',
    'Vehicle Image',
    'Driver Profile Image',
    'Driver Image Next to Vehicle',
  ];

  static const String googleApiKey = "AIzaSyBSmv_lOddM99LDGDzLzmO6J6liniHi5Lg";

  static bool isCurrentTimePeak() {
    final now = DateTime.now();
    final hour = now.hour;
    final isMorningPeak = hour >= peakMorningStart && hour < peakMorningEnd;
    final isEveningPeak = hour >= peakEveningStart && hour < peakEveningEnd;
    return isMorningPeak || isEveningPeak;
  }

  static double calculateEstimatedFare({
    required double distance,
    required String vehicleType,
    bool isPeak = false,
    double riskFactor = 1.0,
  }) {
    double baseFare;
    double perKm;
    double vehicleMultiplier;
    switch (vehicleType) {
      case 'small':
        baseFare = smallBaseFare;
        perKm = smallPerKm;
        vehicleMultiplier = smallVehicleMultiplier;
        break;
      case 'sedan':
        baseFare = sedanBaseFare;
        perKm = sedanPerKm;
        vehicleMultiplier = sedanVehicleMultiplier;
        break;
      case 'large':
        baseFare = largeBaseFare;
        perKm = largePerKm;
        vehicleMultiplier = largeVehicleMultiplier;
        break;
      case 'parcel':
        baseFare = parcelBaseFare;
        perKm = parcelPerKm;
        vehicleMultiplier = parcelVehicleMultiplier;
        break;
      default:
        baseFare = smallBaseFare;
        perKm = smallPerKm;
        vehicleMultiplier = smallVehicleMultiplier;
    }
    double timeMultiplier = isPeak ? peakMultiplier : offPeakMultiplier;
    double finalFare = (baseFare + (distance * perKm)) * vehicleMultiplier * timeMultiplier * riskFactor;
    return double.parse(finalFare.toStringAsFixed(2));
  }
}
