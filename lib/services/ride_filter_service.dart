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
    print('🔍 Starting ride filtering for driver: ${driver.name}');
    print('📍 Driver location: ${driverLocation.latitude}, ${driverLocation.longitude}');
    print('🚗 Driver vehicle type: ${driver.vehicleType}');
    
    return _firestore
        .collection('requests')
        .where('status', isEqualTo: 'pending')
        .orderBy('createdAt', descending: false)
        .snapshots()
        .handleError((error) {
          print('❌ Error in ride filtering: $error');
          // If it's an index error, provide a helpful message
          if (error.toString().contains('FAILED_PRECONDITION') || 
              error.toString().contains('requires an index')) {
            print('⚠️ Firestore index is still building. This may take a few minutes.');
            // Return empty list while index is building
            return const Stream.empty();
          }
          // For other errors, rethrow
          throw error;
        })
        .map((snapshot) {
      print('📊 Found ${snapshot.docs.length} total ride requests in database');
      
      // Debug: Print the first few documents to see their structure
      if (snapshot.docs.isNotEmpty) {
        print('🔍 First document structure: ${snapshot.docs.first.data()}');
      }
      
      final List<RideModel> allRides = snapshot.docs
          .map((doc) => RideModel.fromMap(doc.data(), doc.id))
          .toList();

      // Apply filtering rules with progressive distance expansion
      final List<RideModel> filteredRides = _applyProgressiveDistanceFilter(
        allRides, 
        driver, 
        driverLocation
      );

      print('✅ After filtering: ${filteredRides.length} rides available for driver');

      return filteredRides;
    });
  }

  // Apply progressive distance filtering
  List<RideModel> _applyProgressiveDistanceFilter(
    List<RideModel> allRides, 
    DriverModel driver, 
    Position driverLocation
  ) {
    final now = DateTime.now();
    final List<RideModel> filteredRides = [];
    
    print('🔍 Progressive distance filtering started');
    print('📊 Total rides to filter: ${allRides.length}');
    
    // First pass: Get all rides that pass basic filtering (excluding distance)
    final basicFilteredRides = allRides.where((ride) {
      return _shouldShowRideToDriverBasic(ride, driver, driverLocation);
    }).toList();
    
    print('📊 Rides after basic filtering: ${basicFilteredRides.length}');
    
    // Calculate distances for all rides
    final ridesWithDistance = basicFilteredRides.map((ride) {
      final distance = calculateDistance(
        driverLocation.latitude,
        driverLocation.longitude,
        ride.pickupLat,
        ride.pickupLng,
      );
      return {'ride': ride, 'distance': distance};
    }).toList();
    
    // Sort by distance
    ridesWithDistance.sort((a, b) => (a['distance'] as double).compareTo(b['distance'] as double));
    
    // Track expansion statistics
    int ridesWithin1km = 0;
    int ridesWithin3km = 0;
    int ridesWithin10km = 0;
    
    // Progressive distance expansion based on request age
    for (final rideData in ridesWithDistance) {
      final ride = rideData['ride'] as RideModel;
      final distance = rideData['distance'] as double;
      final requestAge = now.difference(ride.requestTime).inMinutes;
      
      // Determine max distance based on request age
      double maxDistance;
      if (requestAge < 2) {
        maxDistance = 1.0; // Start with 1km for new requests
      } else if (requestAge < 5) {
        maxDistance = 3.0; // Expand to 3km after 2 minutes
      } else {
        maxDistance = 10.0; // Expand to 10km after 5 minutes
      }
      
      if (distance <= maxDistance) {
        filteredRides.add(ride);
        
        // Track statistics
        if (distance <= 1.0) ridesWithin1km++;
        if (distance <= 3.0) ridesWithin3km++;
        if (distance <= 10.0) ridesWithin10km++;
        
        print('✅ Ride ${ride.id} included: ${distance.toStringAsFixed(2)}km (age: ${requestAge}min, max: ${maxDistance}km)');
      } else {
        print('❌ Ride ${ride.id} filtered out: ${distance.toStringAsFixed(2)}km > ${maxDistance}km (age: ${requestAge}min)');
      }
    }
    
    print('📊 Progressive expansion results:');
    print('   - Rides within 1km: $ridesWithin1km');
    print('   - Rides within 3km: $ridesWithin3km');
    print('   - Rides within 10km: $ridesWithin10km');
    print('   - Total rides shown: ${filteredRides.length}');
    
    return filteredRides;
  }

  // Check if a ride should be shown to a specific driver (basic filtering without distance)
  bool _shouldShowRideToDriverBasic(RideModel ride, DriverModel driver, Position driverLocation) {
    // Debug logging for ride filtering
    print('🚗 Ride ${ride.id}: Basic filtering check');
    print('   Driver location: ${driverLocation.latitude}, ${driverLocation.longitude}');
    print('   Pickup location: ${ride.pickupLat}, ${ride.pickupLng}');
    print('   Vehicle type: ${ride.vehicleType} vs Driver: ${driver.vehicleType}');

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

    print('   ✅ Ride passes basic filtering');
    return true;
  }

  // Check if a ride should be shown to a specific driver (legacy method for backward compatibility)
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

    // Distance-based filtering (progressive distance expansion)
    if (!_isWithinDistanceRange(distance)) {
      print('   ❌ Filtered out: Distance ${distance.toStringAsFixed(2)}km > 10km limit');
      return false;
    }

    // Use basic filtering
    return _shouldShowRideToDriverBasic(ride, driver, driverLocation);
  }

  // Check if distance is within acceptable range (progressive expansion)
  bool _isWithinDistanceRange(double distance, {double maxDistance = 10.0}) {
    return distance <= maxDistance;
  }

  // Get distance-based priority for ride requests (legacy method)
  int _getDistancePriority(double distance) {
    if (distance <= 1.0) return 1; // Highest priority
    if (distance <= 3.0) return 2; // Medium priority
    if (distance <= 10.0) return 3; // Lower priority
    return 4; // Lowest priority
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
      // The rides are already sorted by distance and filtered with progressive expansion
      // Just add some additional prioritization based on request age and distance
      final List<RideModel> prioritizedRides = List.from(rides);
      
      // Sort by a combination of distance and request age
      prioritizedRides.sort((a, b) {
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
        
        // Prioritize by distance first, then by request age (older requests get priority)
        final distanceComparison = distanceA.compareTo(distanceB);
        if (distanceComparison != 0) {
          return distanceComparison;
        }
        
        // If distances are equal, prioritize older requests
        return a.requestTime.compareTo(b.requestTime);
      });

      print('🎯 Prioritized ${prioritizedRides.length} rides for driver');
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