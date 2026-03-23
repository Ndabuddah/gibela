import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import '../models/driver_model.dart';
import '../models/ride_model.dart';
import 'database_service.dart';
import 'ride_filter_service.dart';
import 'ride_notification_service.dart';

/// Service for automatically assigning drivers to ride requests
class AutoAssignmentService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final DatabaseService _databaseService = DatabaseService();
  final RideFilterService _filterService = RideFilterService();
  
  Timer? _assignmentTimer;
  
  /// Start monitoring for ride requests that need auto-assignment
  void startAutoAssignmentMonitoring() {
    // Check every 5 seconds for requests that need assignment
    _assignmentTimer = Timer.periodic(const Duration(seconds: 5), (timer) async {
      await _checkAndAssignPendingRequests();
    });
  }
  
  /// Stop monitoring
  void stopAutoAssignmentMonitoring() {
    _assignmentTimer?.cancel();
    _assignmentTimer = null;
  }
  
  /// Check for pending requests and assign drivers automatically
  Future<void> _checkAndAssignPendingRequests() async {
    try {
      // Get all pending requests older than 30 seconds
      final now = DateTime.now();
      final cutoffTime = now.subtract(const Duration(seconds: 30));
      
      final pendingRequests = await _firestore
          .collection('requests')
          .where('status', isEqualTo: 'pending')
          .where('createdAt', isLessThan: Timestamp.fromDate(cutoffTime))
          .limit(10) // Process max 10 at a time
          .get();
      
      for (var doc in pendingRequests.docs) {
        final requestId = doc.id;
        final data = doc.data();
        
        // Skip if already has a driver assigned
        if (data['driverId'] != null && data['driverId'].toString().isNotEmpty) {
          continue;
        }
        
        // Skip if request was just created (give manual acceptance a chance)
        final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
        if (createdAt == null || now.difference(createdAt).inSeconds < 30) {
          continue;
        }
        
        // Try to auto-assign a driver
        await _attemptAutoAssignment(requestId, data);
      }
    } catch (e) {
      print('Error in auto-assignment check: $e');
    }
  }
  
  /// Attempt to automatically assign a driver to a ride request
  Future<bool> _attemptAutoAssignment(String requestId, Map<String, dynamic> requestData) async {
    try {
      // Convert to RideModel for filtering
      final ride = RideModel.fromMap(requestData, requestId);
      
      // Get pickup coordinates
      final pickupCoords = requestData['pickupCoordinates'] as List<dynamic>?;
      if (pickupCoords == null || pickupCoords.length < 2) {
        print('⚠️ Request $requestId missing pickup coordinates');
        return false;
      }
      
      final pickupLat = (pickupCoords[0] as num).toDouble();
      final pickupLng = (pickupCoords[1] as num).toDouble();
      
      // Find eligible drivers
      final eligibleDrivers = await _findEligibleDrivers(
        ride: ride,
        pickupLat: pickupLat,
        pickupLng: pickupLng,
      );
      
      if (eligibleDrivers.isEmpty) {
        print('⚠️ No eligible drivers found for request $requestId');
        return false;
      }
      
      // Sort by priority: distance → rating → availability
      eligibleDrivers.sort((a, b) {
        // First by distance
        final distanceCompare = a['distance'].compareTo(b['distance']);
        if (distanceCompare != 0) return distanceCompare;
        
        // Then by rating
        final ratingA = a['rating'] as double;
        final ratingB = b['rating'] as double;
        final ratingCompare = ratingB.compareTo(ratingA); // Higher is better
        if (ratingCompare != 0) return ratingCompare;
        
        // Finally by total rides (more experience)
        final ridesA = a['totalRides'] as int;
        final ridesB = b['totalRides'] as int;
        return ridesB.compareTo(ridesA); // More rides is better
      });
      
      // Try to assign the best driver
      for (var driverData in eligibleDrivers) {
        final driverId = driverData['driverId'] as String;
        
        try {
          // Use transaction to ensure atomic assignment
          final success = await _databaseService.acceptRideRequestTransaction(requestId, driverId);
          
          if (success) {
            print('✅ Auto-assigned driver $driverId to request $requestId');
            
            // Send notification to passenger
            final passengerId = requestData['userId'] as String? ?? ride.passengerId;
            await RideNotificationService.sendRideAcceptedNotification(
              rideId: requestId,
              passengerId: passengerId,
              driverId: driverId,
              vehicleType: ride.vehicleType,
            );
            
            return true;
          }
        } catch (e) {
          // Driver might have accepted another ride or gone offline
          // Try next driver
          print('⚠️ Failed to assign driver $driverId: $e');
          continue;
        }
      }
      
      return false;
    } catch (e) {
      print('Error in auto-assignment attempt: $e');
      return false;
    }
  }
  
  /// Find eligible drivers for a ride request
  Future<List<Map<String, dynamic>>> _findEligibleDrivers({
    required RideModel ride,
    required double pickupLat,
    required double pickupLng,
    double maxDistance = 10.0, // Start with 10km radius
  }) async {
    try {
      // Get all online drivers
      final driversSnapshot = await _firestore
          .collection('drivers')
          .where('status', isEqualTo: DriverStatus.online.index)
          .where('isApproved', isEqualTo: true)
          .get();
      
      final List<Map<String, dynamic>> eligibleDrivers = [];
      
      for (var doc in driversSnapshot.docs) {
        try {
          final driverData = doc.data();
          final driver = DriverModel.fromMap(driverData);
          
          // Check if driver has active ride
          final activeRide = await _databaseService.getActiveRideForDriver(driver.userId);
          if (activeRide != null) {
            continue; // Skip drivers with active rides
          }
          
          // Get driver location
          final driverLocation = driverData['currentLocation'] as Map<String, dynamic>?;
          if (driverLocation == null) {
            continue; // Skip drivers without location
          }
          
          final driverLat = (driverLocation['latitude'] as num).toDouble();
          final driverLng = (driverLocation['longitude'] as num).toDouble();
          
          // Calculate distance
          final distance = RideFilterService.calculateDistance(
            pickupLat,
            pickupLng,
            driverLat,
            driverLng,
          );
          
          if (distance > maxDistance) {
            continue; // Skip drivers too far away
          }
          
          // Check eligibility using filter service
          if (!_filterService.isDriverEligibleForRideType(driver, ride)) {
            continue; // Skip ineligible drivers
          }
          
          // Add to eligible list
          eligibleDrivers.add({
            'driverId': driver.userId,
            'driver': driver,
            'distance': distance,
            'rating': driver.averageRating,
            'totalRides': driver.totalRides,
          });
        } catch (e) {
          print('Error processing driver ${doc.id}: $e');
          continue;
        }
      }
      
      return eligibleDrivers;
    } catch (e) {
      print('Error finding eligible drivers: $e');
      return [];
    }
  }
  
  /// Manually trigger auto-assignment for a specific request
  Future<bool> assignDriverToRequest(String requestId) async {
    try {
      final requestDoc = await _firestore.collection('requests').doc(requestId).get();
      if (!requestDoc.exists) {
        return false;
      }
      
      final data = requestDoc.data()!;
      
      // Check if already assigned
      if (data['driverId'] != null && data['driverId'].toString().isNotEmpty) {
        return false;
      }
      
      return await _attemptAutoAssignment(requestId, data);
    } catch (e) {
      print('Error in manual assignment: $e');
      return false;
    }
  }
}

