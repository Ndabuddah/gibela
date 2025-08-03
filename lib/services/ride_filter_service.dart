import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import '../models/ride_model.dart';
import '../models/driver_model.dart';

class RideFilterService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Calculate distance between two points using Haversine formula
  static double calculateDistance(double lat1, double lng1, double lat2, double lng2) {
    const double earthRadius = 6371; // Earth's radius in kilometers
    
    final double dLat = _degreesToRadians(lat2 - lat1);
    final double dLng = _degreesToRadians(lng2 - lng1);
    
    final double a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_degreesToRadians(lat1)) * cos(_degreesToRadians(lat2)) *
        sin(dLng / 2) * sin(dLng / 2);
    
    final double c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return earthRadius * c;
  }

  static double _degreesToRadians(double degrees) {
    return degrees * (pi / 180);
  }

  // Get filtered ride requests based on driver preferences and distance
  Stream<List<RideModel>> getFilteredRideRequests({
    required String driverId,
    required Position driverLocation,
    required DriverModel driver,
  }) {
    return _firestore
        .collection('rides')
        .where('status', isEqualTo: RideStatus.requested.index)
        .orderBy('requestTime', descending: false)
        .snapshots()
        .map((snapshot) {
      final List<RideModel> allRides = snapshot.docs
          .map((doc) => RideModel.fromMap(doc.data(), doc.id))
          .toList();

      // Apply filtering rules
      final List<RideModel> filteredRides = allRides.where((ride) {
        return _shouldShowRideToDriver(ride, driver, driverLocation);
      }).toList();

      // Sort by distance (closest first)
      filteredRides.sort((a, b) {
        final distanceA = calculateDistance(
          driverLocation.latitude,
          driverLocation.longitude,
          a.pickupLat,
          a.pickupLng,
        );
        final distanceB = calculateDistance(
          driverLocation.latitude,
          driverLocation.longitude,
          b.pickupLat,
          b.pickupLng,
        );
        return distanceA.compareTo(distanceB);
      });

      return filteredRides;
    });
  }

  // Check if a ride should be shown to a specific driver
  bool _shouldShowRideToDriver(RideModel ride, DriverModel driver, Position driverLocation) {
    // Calculate distance from driver to pickup location
    final double distance = calculateDistance(
      driverLocation.latitude,
      driverLocation.longitude,
      ride.pickupLat,
      ride.pickupLng,
    );

    // Debug logging for ride filtering
    print('🚗 Ride ${ride.id}: Distance ${distance.toStringAsFixed(2)}km from driver');
    print('   Driver location: ${driverLocation.latitude}, ${driverLocation.longitude}');
    print('   Pickup location: ${ride.pickupLat}, ${ride.pickupLng}');
    print('   Vehicle type: ${ride.vehicleType} vs Driver: ${driver.vehicleType}');

    // Distance-based filtering (progressive distance expansion)
    if (!_isWithinDistanceRange(distance)) {
      print('   ❌ Filtered out: Distance ${distance.toStringAsFixed(2)}km > 10km limit');
      return false;
    }

    // Asambe Girl filtering
    if (ride.isAsambeGirl && (driver.isFemale != true)) {
      print('   ❌ Filtered out: Girl ride but driver is not female');
      return false;
    }

    // Asambe Student filtering
    if (ride.isAsambeStudent && (driver.isForStudents != true)) {
      print('   ❌ Filtered out: Student ride but driver is not for students');
      return false;
    }

    // Asambe Luxury filtering
    if (ride.isAsambeLuxury && (driver.isLuxury != true)) {
      print('   ❌ Filtered out: Luxury ride but driver is not luxury');
      return false;
    }

    // Passenger count filtering for Max2 drivers
    if (driver.isMax2 == true && ride.passengerCount > 2) {
      print('   ❌ Filtered out: Max2 driver but ride has ${ride.passengerCount} passengers');
      return false;
    }

    // Vehicle type compatibility
    if (!_isVehicleTypeCompatible(ride.vehicleType, driver)) {
      print('   ❌ Filtered out: Vehicle type mismatch');
      return false;
    }

    print('   ✅ Ride will be shown to driver');
    return true;
  }

  // Check if distance is within acceptable range (progressive expansion)
  bool _isWithinDistanceRange(double distance) {
    // First priority: within 1km
    if (distance <= 1.0) return true;
    
    // Second priority: within 3km
    if (distance <= 3.0) return true;
    
    // Third priority: within 10km
    if (distance <= 10.0) return true;
    
    return false;
  }

  // Check vehicle type compatibility
  bool _isVehicleTypeCompatible(String rideVehicleType, DriverModel driver) {
    // If driver has no specific vehicle type, they can accept any ride
    if (driver.vehicleType == null || driver.vehicleType!.isEmpty) {
      return true;
    }

    // Check if driver's vehicle type matches ride requirements
    final driverVehicleType = driver.vehicleType!.toLowerCase();
    final rideVehicleTypeLower = rideVehicleType.toLowerCase();

    // Direct match
    if (driverVehicleType == rideVehicleTypeLower) {
      return true;
    }

    // Handle special cases based on actual vehicle types from vehicle_type_model.dart
    switch (rideVehicleTypeLower) {
      case 'asambe via':
      case 'via':
        // Via rides can be accepted by any vehicle type
        return true;
      case 'asambe girl':
      case 'girl':
        // Only female drivers can accept girl rides
        return driverVehicleType == 'girl' && (driver.isFemale == true);
      case 'asambe7':
      case 'seven':
        // Only 7-seater vehicles can accept 7-seater rides
        return driverVehicleType == 'seven';
      case 'asambe luxury':
      case 'luxury':
        // Only luxury vehicles can accept luxury rides
        return driverVehicleType == 'luxury';
      case 'asambe student':
      case 'student':
        // Only student drivers can accept student rides
        return driverVehicleType == 'student' && (driver.isForStudents == true);
      case 'asambe parcel':
      case 'parcel':
        // Only parcel vehicles can accept parcel rides
        return driverVehicleType == 'parcel';
      default:
        return driverVehicleType == rideVehicleTypeLower;
    }
  }

  // Get distance-based priority for ride requests
  int _getDistancePriority(double distance) {
    if (distance <= 1.0) return 1; // Highest priority
    if (distance <= 3.0) return 2; // Medium priority
    if (distance <= 10.0) return 3; // Lower priority
    return 4; // Lowest priority
  }

  // Get filtered and prioritized ride requests
  Stream<List<RideModel>> getPrioritizedRideRequests({
    required String driverId,
    required Position driverLocation,
    required DriverModel driver,
  }) {
    return getFilteredRideRequests(
      driverId: driverId,
      driverLocation: driverLocation,
      driver: driver,
    ).map((rides) {
      // Group rides by distance priority
      final Map<int, List<RideModel>> priorityGroups = {};
      
      for (final ride in rides) {
        final distance = calculateDistance(
          driverLocation.latitude,
          driverLocation.longitude,
          ride.pickupLat,
          ride.pickupLng,
        );
        final priority = _getDistancePriority(distance);
        
        priorityGroups.putIfAbsent(priority, () => []);
        priorityGroups[priority]!.add(ride);
      }

      // Combine rides in priority order
      final List<RideModel> prioritizedRides = [];
      for (int priority = 1; priority <= 3; priority++) {
        if (priorityGroups.containsKey(priority)) {
          prioritizedRides.addAll(priorityGroups[priority]!);
        }
      }

      return prioritizedRides;
    });
  }

  // Update driver's isMax2 field to false for all drivers
  Future<void> updateAllDriversMax2Field() async {
    try {
      final driversSnapshot = await _firestore.collection('users').get();
      
      final batch = _firestore.batch();
      for (final doc in driversSnapshot.docs) {
        final data = doc.data();
        if (data['isDriver'] == true) {
          batch.update(doc.reference, {'isMax2': false});
        }
      }
      
      await batch.commit();
      print('Successfully updated isMax2 field for all drivers');
    } catch (e) {
      print('Error updating isMax2 field: $e');
      rethrow;
    }
  }

  // Get driver's current location
  Future<Position?> getDriverLocation(String driverId) async {
    try {
      // This would typically come from a location service
      // For now, we'll return null and let the calling code handle it
      return null;
    } catch (e) {
      print('Error getting driver location: $e');
      return null;
    }
  }

  // Check if driver is eligible for a specific ride type
  bool isDriverEligibleForRideType(DriverModel driver, RideModel ride) {
    // Asambe Girl rides
    if (ride.isAsambeGirl && driver.isFemale != true) {
      return false;
    }

    // Asambe Student rides
    if (ride.isAsambeStudent && driver.isForStudents != true) {
      return false;
    }

    // Asambe Luxury rides
    if (ride.isAsambeLuxury && driver.isLuxury != true) {
      return false;
    }

    // Max2 passenger limit
    if (driver.isMax2 == true && ride.passengerCount > 2) {
      return false;
    }

    return true;
  }

  // Get ride eligibility explanation
  String getRideEligibilityExplanation(DriverModel driver, RideModel ride) {
    if (ride.isAsambeGirl && driver.isFemale != true) {
      return 'This ride is for female drivers only';
    }
    
    if (ride.isAsambeStudent && driver.isForStudents != true) {
      return 'This ride is for student drivers only';
    }
    
    if (ride.isAsambeLuxury && driver.isLuxury != true) {
      return 'This ride is for luxury vehicle drivers only';
    }
    
    if (driver.isMax2 == true && ride.passengerCount > 2) {
      return 'This ride has more than 2 passengers (Max2 drivers cannot accept)';
    }
    
    return 'You are eligible for this ride';
  }
} 