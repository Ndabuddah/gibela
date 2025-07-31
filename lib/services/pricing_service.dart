import 'dart:math';

class PricingService {
  // Base pricing constants
  static const double _baseFare = 30.0;
  static const double _perKmRate = 7.5;
  static const double _minimumFare = 35.0;
  
  // Vehicle type multipliers
  static const double _viaMultiplier = 1.15;
  static const double _girlMultiplier = 1.15;
  static const double _studentMultiplier = 1.0;
  static const double _luxuryMultiplier = 1.65;
  static const double _parcelMultiplier = 0.6;
  static const double _sevenMultiplier = 1.45;
  
  // Time-based multipliers
  static const double _nightMultiplier = 1.15;
  static const double _peakMultiplier = 1.12;
  
  // Weather multipliers
  static const double _rainMultiplier = 1.15; // 15% increase in rain
  static const double _stormMultiplier = 1.25; // 25% increase in storms
  static const double _extremeWeatherMultiplier = 1.35; // 35% increase in extreme weather
  
  // Demand/busyness multipliers
  static const double _lowDemandMultiplier = 0.95; // 5% discount in very low demand
  static const double _mediumDemandMultiplier = 1.0; // Normal pricing
  static const double _highDemandMultiplier = 1.15; // 15% increase in high demand
  static const double _veryHighDemandMultiplier = 1.25; // 25% increase in very high demand
  
  // Special event multipliers
  static const double _eventMultiplier = 1.2; // 20% increase during events
  static const double _holidayMultiplier = 1.15; // 15% increase during holidays
  
  // Area-based multipliers
  static const double _highRiskAreaMultiplier = 1.2; // 20% increase in high-risk areas
  static const double _remoteAreaMultiplier = 1.15; // 15% increase for remote areas
  
  // Peak hours (24-hour format)
  static const int _peakMorningStart = 7;
  static const int _peakMorningEnd = 9;
  static const int _peakEveningStart = 17;
  static const int _peakEveningEnd = 19;
  
  // Night hours (24-hour format)
  static const int _nightStart = 22;
  static const int _nightEnd = 6;

  /// Calculate the fare with all dynamic factors
  static double calculateFare({
    required double distanceKm,
    required String vehicleType,
    double discountPercent = 0.0,
    DateTime? requestTime,
    Map<String, dynamic>? conditions = const {},
  }) {
    // Use current time if not provided
    final time = requestTime ?? DateTime.now();
    
    // Calculate base fare
    double baseFare = _baseFare + (distanceKm * _perKmRate);
    
    // Apply vehicle type multiplier
    double vehicleMultiplier = _getVehicleMultiplier(vehicleType);
    
    // Apply time-based multipliers
    double timeMultiplier = _getTimeMultiplier(time);
    
    // Apply weather multiplier if provided
    double weatherMultiplier = _getWeatherMultiplier(conditions?['weather']);
    
    // Apply demand multiplier if provided
    double demandMultiplier = _getDemandMultiplier(conditions?['demand']);
    
    // Apply event multiplier if provided
    double eventMultiplier = _getEventMultiplier(conditions?['event']);
    
    // Apply area multiplier if provided
    double areaMultiplier = _getAreaMultiplier(conditions?['area']);
    
    // Calculate total fare with all multipliers
    double totalFare = baseFare * vehicleMultiplier * timeMultiplier * 
                      weatherMultiplier * demandMultiplier * eventMultiplier * 
                      areaMultiplier;
    
    // Apply discount
    if (discountPercent > 0) {
      double discountAmount = totalFare * (discountPercent / 100);
      totalFare = totalFare - discountAmount;
    }
    
    // Ensure minimum fare
    totalFare = max(totalFare, _minimumFare);
    
    // Round to 2 decimal places
    return double.parse(totalFare.toStringAsFixed(2));
  }
  
  /// Get vehicle type multiplier based on the specified rules
  static double _getVehicleMultiplier(String vehicleType) {
    switch (vehicleType.toLowerCase()) {
      case 'via':
      case 'asambevia':
        return _viaMultiplier;
      case 'girl':
      case 'asambegirl':
        return _girlMultiplier; // Same as Via
      case 'student':
      case 'asambestudent':
        return _studentMultiplier; // 3% lower than Via
      case 'luxury':
      case 'asambeluxury':
        return _luxuryMultiplier; // 55% more than Via
      case 'parcel':
      case 'asambeparcel':
        return _parcelMultiplier; // 60% less than Via
      case 'seven':
      case 'asambe7':
        return _sevenMultiplier; // 40% more than Via
      default:
        return _viaMultiplier; // Default to Via multiplier
    }
  }
  
  /// Get time-based multiplier (night and peak hours)
  static double _getTimeMultiplier(DateTime time) {
    double multiplier = 1.0;
    
    // Check for night hours (10 PM - 6 AM)
    final hour = time.hour;
    final isNight = (hour >= _nightStart) || (hour < _nightEnd);
    if (isNight) {
      multiplier *= _nightMultiplier;
    }
    
    // Check for peak hours
    final isPeak = _isPeakHour(hour);
    if (isPeak) {
      multiplier *= _peakMultiplier;
    }
    
    return multiplier;
  }
  
  /// Check if current hour is peak hour
  static bool _isPeakHour(int hour) {
    return (hour >= _peakMorningStart && hour < _peakMorningEnd) ||
           (hour >= _peakEveningStart && hour < _peakEveningEnd);
  }
  
  /// Get weather-based multiplier
  static double _getWeatherMultiplier(String? weather) {
    if (weather == null) return 1.0;
    
    switch (weather.toLowerCase()) {
      case 'rain':
        return _rainMultiplier;
      case 'storm':
        return _stormMultiplier;
      case 'extreme':
        return _extremeWeatherMultiplier;
      default:
        return 1.0;
    }
  }

  /// Get demand-based multiplier
  static double _getDemandMultiplier(String? demand) {
    if (demand == null) return _mediumDemandMultiplier;
    
    switch (demand.toLowerCase()) {
      case 'low':
        return _lowDemandMultiplier;
      case 'high':
        return _highDemandMultiplier;
      case 'very_high':
        return _veryHighDemandMultiplier;
      default:
        return _mediumDemandMultiplier;
    }
  }

  /// Get event-based multiplier
  static double _getEventMultiplier(String? event) {
    if (event == null) return 1.0;
    
    switch (event.toLowerCase()) {
      case 'special_event':
        return _eventMultiplier;
      case 'holiday':
        return _holidayMultiplier;
      default:
        return 1.0;
    }
  }

  /// Get area-based multiplier
  static double _getAreaMultiplier(String? area) {
    if (area == null) return 1.0;
    
    switch (area.toLowerCase()) {
      case 'high_risk':
        return _highRiskAreaMultiplier;
      case 'remote':
        return _remoteAreaMultiplier;
      default:
        return 1.0;
    }
  }
  
  /// Get display price with discount applied
  static double getDisplayPrice({
    required double basePrice,
    double discountPercent = 0.0,
  }) {
    if (discountPercent <= 0) {
      return basePrice;
    }
    
    double discountAmount = basePrice * (discountPercent / 100);
    double finalPrice = basePrice - discountAmount;
    
    // Ensure price doesn't go below minimum
    finalPrice = max(finalPrice, _minimumFare);
    
    return double.parse(finalPrice.toStringAsFixed(2));
  }
  
  /// Calculate fare for all vehicle types for comparison
  static Map<String, double> calculateAllFares({
    required double distanceKm,
    DateTime? requestTime,
  }) {
    final vehicleTypes = [
      'via',
      'girl', 
      'student',
      'seven',
      'luxury',
      'parcel'
    ];
    
    final discounts = {
      'via': 0.0,
      'girl': 0.0, // No discount by default
      'student': 0.0, // No discount by default (3% lower is built into multiplier)
      'seven': 0.0,
      'luxury': 0.0,
      'parcel': 0.0,
    };
    
    Map<String, double> fares = {};
    
    for (String vehicleType in vehicleTypes) {
      fares[vehicleType] = calculateFare(
        distanceKm: distanceKm,
        vehicleType: vehicleType,
        discountPercent: discounts[vehicleType]!,
        requestTime: requestTime,
      );
    }
    
    return fares;
  }
  
  /// Get estimated time of arrival based on distance and vehicle type
  static String getEstimatedTime({
    required double distanceKm,
    required String vehicleType,
  }) {
    // Base time: 2 minutes for pickup + 3 minutes per km
    double baseMinutes = 2 + (distanceKm * 3);
    
    // Adjust based on vehicle type
    switch (vehicleType.toLowerCase()) {
      case 'luxury':
      case 'asambeluxury':
        baseMinutes += 2; // Luxury takes longer
        break;
      case 'seven':
      case 'asambe7':
        baseMinutes += 1; // 7-seater slightly longer
        break;
      case 'parcel':
      case 'asambeparcel':
        baseMinutes += 3; // Parcel delivery takes longer
        break;
      default:
        // No adjustment for other vehicle types
        break;
    }
    
    // Round to nearest minute
    int minutes = baseMinutes.round();
    
    // Format as range
    int minTime = max(3, minutes - 2);
    int maxTime = minutes + 2;
    
    return '$minTime-$maxTime min';
  }
  
  /// Check if current time is peak hour
  static bool isPeakHour() {
    final now = DateTime.now();
    return _isPeakHour(now.hour);
  }
  
  /// Check if current time is night hour
  static bool isNightHour() {
    final now = DateTime.now();
    final hour = now.hour;
    return (hour >= _nightStart) || (hour < _nightEnd);
  }
  
  /// Get pricing information with all factors for display
  static Map<String, dynamic> getPricingInfo({
    required double distanceKm,
    required String vehicleType,
    double discountPercent = 0.0,
    DateTime? requestTime,
    Map<String, dynamic>? conditions,
  }) {
    final basePrice = calculateFare(
      distanceKm: distanceKm,
      vehicleType: vehicleType,
      discountPercent: 0.0,
      requestTime: requestTime,
      conditions: conditions,
    );
    
    final finalPrice = getDisplayPrice(
      basePrice: basePrice,
      discountPercent: discountPercent,
    );
    
    final estimatedTime = getEstimatedTime(
      distanceKm: distanceKm,
      vehicleType: vehicleType,
    );
    
    final time = requestTime ?? DateTime.now();
    final isPeak = _isPeakHour(time.hour);
    final isNight = (time.hour >= _nightStart) || (time.hour < _nightEnd);
    
    // Calculate applied multipliers for transparency
    final appliedMultipliers = {
      'vehicle': _getVehicleMultiplier(vehicleType),
      'time': _getTimeMultiplier(time),
      'weather': _getWeatherMultiplier(conditions?['weather']),
      'demand': _getDemandMultiplier(conditions?['demand']),
      'event': _getEventMultiplier(conditions?['event']),
      'area': _getAreaMultiplier(conditions?['area']),
    };
    
    return {
      'basePrice': basePrice,
      'finalPrice': finalPrice,
      'discountAmount': basePrice - finalPrice,
      'discountPercent': discountPercent,
      'estimatedTime': estimatedTime,
      'isPeak': isPeak,
      'isNight': isNight,
      'distanceKm': distanceKm,
      'vehicleType': vehicleType,
      'conditions': conditions,
      'appliedMultipliers': appliedMultipliers,
      'weatherCondition': conditions?['weather'],
      'demandLevel': conditions?['demand'],
      'specialEvent': conditions?['event'],
      'areaType': conditions?['area'],
    };
  }
} 

/// DYNAMIC PRICING IMPLEMENTATION GUIDE
/// ==================================
///
/// This guide outlines the future implementation steps for the dynamic pricing system.
///
/// 1. WEATHER CONDITIONS INTEGRATION
/// -------------------------------
/// Create WeatherService to integrate with weather APIs:
/// ```dart
/// class WeatherService {
///   Future<String> getCurrentWeather(double lat, double lng) async {
///     // API call to get current weather
///     // Return: 'normal', 'rain', 'storm', 'extreme'
///   }
///   
///   Stream<String> weatherUpdates(double lat, double lng) {
///     // WebSocket or periodic API calls for real-time updates
///   }
/// }
/// ```
///
/// 2. DEMAND CALCULATION
/// -------------------
/// Implement DemandService to track real-time demand:
/// ```dart
/// class DemandService {
///   String calculateDemand({
///     required int activeRides,
///     required int pendingRequests,
///     required int availableDrivers,
///     required String area,
///   }) {
///     double demandRatio = (activeRides + pendingRequests) / availableDrivers;
///     if (demandRatio < 0.5) return 'low';
///     if (demandRatio < 0.8) return 'medium';
///     if (demandRatio < 1.2) return 'high';
///     return 'very_high';
///   }
/// }
/// ```
///
/// 3. SPECIAL EVENTS DETECTION
/// -------------------------
/// Create EventService for event tracking:
/// ```dart
/// class EventService {
///   Future<Map<String, dynamic>> checkEvents({
///     required double lat,
///     required double lng,
///     required DateTime time,
///   }) async {
///     return {
///       'type': 'special_event', // or 'holiday'
///       'name': 'Concert at Stadium',
///       'expectedCrowdSize': 50000,
///     };
///   }
/// }
/// ```
///
/// 4. AREA RISK ASSESSMENT
/// ---------------------
/// Implement AreaService:
/// ```dart
/// class AreaService {
///   Future<String> assessArea(double lat, double lng) async {
///     // Check crime stats, time of day, historical data
///     return 'normal' // or 'high_risk', 'remote'
///   }
/// }
/// ```
///
/// 5. FIREBASE IMPLEMENTATION
/// ------------------------
/// Store conditions in Firestore:
/// ```
/// rides/{rideId}: {
///   conditions: {
///     weather: 'rain',
///     demand: 'high',
///     event: 'special_event',
///     area: 'high_risk'
///   },
///   appliedMultipliers: {
///     weather: 1.15,
///     demand: 1.15,
///     event: 1.2,
///     area: 1.2
///   }
/// }
/// ```
///
/// 6. USAGE IN RIDE REQUEST
/// ----------------------
/// ```dart
/// final price = await calculateDynamicPrice({
///   vehicleType: 'via',
///   distance: 10.5,
///   pickup: LatLng(-26.2041, 28.0473),
///   dropoff: LatLng(-26.1052, 28.0560),
/// });
/// ```
///
/// 7. FUTURE ENHANCEMENTS
/// --------------------
/// 1. Machine Learning Integration:
///    - Demand prediction
///    - Optimal pricing
///    - Pattern recognition
///
/// 2. Dynamic Multiplier Adjustment:
///    - Based on acceptance rates
///    - Competition analysis
///    - Time-based patterns
///
/// 3. Personalized Pricing:
///    - User rating based
///    - Usage frequency rewards
///    - Corporate accounts
///
/// 4. Advanced Weather Integration:
///    - Forecast-based pricing
///    - Severity levels
///    - Road conditions
///
/// 5. Smart Event Detection:
///    - Social media monitoring
///    - News integration
///    - Traffic analysis
///
/// 6. Geographic Optimization:
///    - Zone-based pricing
///    - Dynamic boundaries
///    - Cross-border handling
///
/// IMPLEMENTATION STEPS:
/// 1. Create services (Weather, Demand, Event, Area)
/// 2. Set up Firebase listeners for real-time updates
/// 3. Implement UI components for price breakdown
/// 4. Add analytics tracking
/// 5. Test with historical data
/// 6. Gradually roll out features
/// 7. Monitor and adjust multipliers
///
/// Note: This implementation requires:
/// - Weather API key
/// - Firebase setup
/// - Location services
/// - Real-time database
/// - Analytics integration 