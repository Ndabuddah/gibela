import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../constants/app_constants.dart';
import '../models/driver_model.dart';
import '../models/ride_model.dart';
import '../services/pricing_service.dart';
import '../services/notification_service.dart';
import '../services/ride_notification_service.dart';
import 'database_service.dart';
import 'location_service.dart';
import 'auto_assignment_service.dart';
// Removed: import 'mapbox_service.dart';

class RideService extends ChangeNotifier {
  final DatabaseService _databaseService = DatabaseService();
  final LocationService _locationService = LocationService();
  final NotificationService _notificationService = NotificationService();
  final AutoAssignmentService _autoAssignmentService = AutoAssignmentService();

  RideModel? _currentRide;
  RideModel? get currentRide => _currentRide;

  StreamSubscription<RideModel>? _rideSubscription;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  @override
  void dispose() {
    _rideSubscription?.cancel();
    _timeoutTimer?.cancel();
    super.dispose();
  }

  // Request a ride (passenger)
  Future<RideModel?> requestRide({
    required String passengerId,
    required String pickupAddress,
    required double pickupLat,
    required double pickupLng,
    required String dropoffAddress,
    required double dropoffLat,
    required double dropoffLng,
    required String vehicleType,
    double distance = 0,
    int passengerCount = 1,
    bool isAsambeGirl = false,
    bool isAsambeStudent = false,
    bool isAsambeLuxury = false,
  }) async {
    _setLoading(true);
    try {
      // Check if passenger already has an active request
      final hasActive = await _databaseService.hasActiveRequest(passengerId);
      if (hasActive) {
        _setLoading(false);
        throw Exception('You already have an active ride request. Please cancel it first or wait for a driver to accept it.');
      }

      // Calculate distance if not provided
      if (distance <= 0) {
        distance = _calculateDistance(pickupLat, pickupLng, dropoffLat, dropoffLng);
      }

      // Use the new pricing service
      final estimatedFare = PricingService.calculateFare(
        distanceKm: distance,
        vehicleType: vehicleType,
        requestTime: DateTime.now(),
      );

      // Create ride model
      final RideModel newRide = RideModel(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        passengerId: passengerId,
        pickupAddress: pickupAddress,
        dropoffAddress: dropoffAddress,
        pickupLat: pickupLat,
        pickupLng: pickupLng,
        dropoffLat: dropoffLat,
        dropoffLng: dropoffLng,
        vehicleType: vehicleType,
        distance: distance,
        estimatedFare: estimatedFare,
        requestTime: DateTime.now(),
        status: RideStatus.requested,
        isPeak: PricingService.isPeakHour(),
        riskFactor: 1.0, // Default risk factor
        passengerCount: passengerCount,
        isAsambeGirl: isAsambeGirl,
        isAsambeStudent: isAsambeStudent,
        isAsambeLuxury: isAsambeLuxury,
      );

      // Save to database
      final String rideId = await _databaseService.createRideRequest(newRide);

      // Get the created ride with the assigned ID
      final createdRide = newRide.copyWith(id: rideId);
      _currentRide = createdRide;

      // Start listening to updates
      _startListeningToRideUpdates(rideId);

      // Schedule auto-assignment after 30 seconds if no manual acceptance
      _scheduleAutoAssignment(rideId);

      _setLoading(false);
      return createdRide;
    } catch (e) {
      _setLoading(false);
      rethrow;
    }
  }

  /// Schedule auto-assignment for a ride request
  void _scheduleAutoAssignment(String rideId) {
    // Wait 30 seconds for manual acceptance, then try auto-assignment
    Timer(const Duration(seconds: 30), () async {
      try {
        // Check if ride is still pending
        final ride = await _databaseService.getRideById(rideId);
        if (ride != null && ride.status == RideStatus.requested && ride.driverId == null) {
          // Attempt auto-assignment
          final assigned = await _autoAssignmentService.assignDriverToRequest(rideId);
          if (assigned) {
            print('✅ Auto-assigned driver to ride $rideId');
          } else {
            print('⚠️ Auto-assignment failed for ride $rideId, will retry');
            // Retry after another 30 seconds
            Timer(const Duration(seconds: 30), () async {
              final ride2 = await _databaseService.getRideById(rideId);
              if (ride2 != null && ride2.status == RideStatus.requested && ride2.driverId == null) {
                await _autoAssignmentService.assignDriverToRequest(rideId);
              }
            });
          }
        }
      } catch (e) {
        print('Error in auto-assignment: $e');
      }
    });
  }

  // Helper method to calculate distance between two points
  double _calculateDistance(double lat1, double lng1, double lat2, double lng2) {
    const double R = 6371; // Radius of the earth in km
    final double dLat = (lat2 - lat1) * 3.141592653589793 / 180;
    final double dLon = (lng2 - lng1) * 3.141592653589793 / 180;
    final double a = 0.5 - (cos(dLat) / 2) + cos(lat1 * 3.141592653589793 / 180) * cos(lat2 * 3.141592653589793 / 180) * (1 - cos(dLon)) / 2;
    final double distance = R * 2 * asin(sqrt(a));
    return distance;
  }

  // Start listening to ride updates
  Timer? _timeoutTimer;
  
  void _startListeningToRideUpdates(String rideId) {
    _rideSubscription?.cancel();
    _timeoutTimer?.cancel();
    
    _rideSubscription = _databaseService.listenToRideUpdates(rideId).listen((updatedRide) {
      _currentRide = updatedRide;
      
      // Cancel timeout if ride is accepted
      if (updatedRide.status != RideStatus.requested) {
        _timeoutTimer?.cancel();
        _timeoutTimer = null;
      }
      
      notifyListeners();
    });
    
    // Start timeout monitoring (15 minutes for regular requests)
    _timeoutTimer = Timer(const Duration(minutes: 15), () {
      // Check if ride is still pending
      if (_currentRide != null && _currentRide!.status == RideStatus.requested) {
        // Request has timed out - the cleanup service will handle cancellation
        // This is just for local state management
        print('⚠️ Ride request ${_currentRide!.id} has timed out');
        _databaseService.checkAndHandleRequestTimeouts();
      }
    });
  }

  // Accept a ride request (driver) - Transaction-safe to prevent race conditions
  Future<void> acceptRideRequest(String rideId, String driverId) async {
    // Validate input parameters
    if (rideId.isEmpty) {
      print('❌ Ride acceptance failed: Empty ride ID detected');
      throw Exception('Ride ID cannot be empty');
    }
    if (driverId.isEmpty) {
      print('❌ Ride acceptance failed: Empty driver ID detected');
      throw Exception('Driver ID cannot be empty');
    }
    
    print('✅ Accepting ride request: $rideId by driver: $driverId');
    
    _setLoading(true);
    try {
      // Get the ride first to validate passenger ID (before transaction)
      final RideModel? ride = await _databaseService.getRideById(rideId);
      if (ride == null) {
        _setLoading(false);
        throw Exception('Ride not found');
      }

      // Validate passenger ID
      if (ride.passengerId.isEmpty) {
        print('❌ Ride acceptance failed: Empty passenger ID in ride data');
        _setLoading(false);
        throw Exception('Passenger ID is missing from ride data');
      }

      print('✅ Ride found with passenger: ${ride.passengerId}');

      // Use transaction-safe acceptance to prevent race conditions
      final accepted = await _databaseService.acceptRideRequestTransaction(rideId, driverId);
      
      if (!accepted) {
        _setLoading(false);
        throw Exception('Failed to accept ride request');
      }

      print('✅ Ride accepted successfully via transaction');

      // Create chat between driver and passenger (outside transaction for performance)
      await _databaseService.createOrGetChat(driverId, ride.passengerId);
      print('✅ Chat created successfully');

      // Send notification to passenger
      await RideNotificationService.sendRideAcceptedNotification(
        rideId: rideId,
        passengerId: ride.passengerId,
        driverId: driverId,
        vehicleType: ride.vehicleType,
      );
      print('✅ Notification sent to passenger');

      _setLoading(false);
    } catch (e) {
      print('❌ Error in acceptRideRequest: $e');
      _setLoading(false);
      rethrow;
    }
  }

  // Driver arrived at pickup location (transaction-safe)
  Future<void> driverArrived(String rideId) async {
    _setLoading(true);
    try {
      // Get the ride
      final RideModel? ride = await _databaseService.getRideById(rideId);
      if (ride == null) {
        _setLoading(false);
        throw Exception('Ride not found');
      }

      // Verify ride is in accepted state (can only arrive if accepted)
      if (ride.status != RideStatus.accepted) {
        _setLoading(false);
        throw Exception('Ride must be accepted before marking arrival. Current status: ${ride.status}');
      }

      // Update the ride status (transaction-safe)
      final updatedRide = ride.copyWith(
        status: RideStatus.driverArrived,
      );

      await _databaseService.updateRide(updatedRide);

      // Send notification to passenger (with retry logic)
      if (ride.driverId != null) {
        try {
          await RideNotificationService.sendDriverArrivedNotification(
            rideId: rideId,
            passengerId: ride.passengerId,
            driverId: ride.driverId!,
          );
          print('✅ Driver arrived notification sent successfully');
        } catch (notificationError) {
          print('⚠️ Failed to send notification, but ride status updated: $notificationError');
          // Don't fail the entire operation if notification fails
        }
      }

      _setLoading(false);
    } catch (e) {
      _setLoading(false);
      rethrow;
    }
  }

  // Start ride
  Future<void> startRide(String rideId) async {
    _setLoading(true);
    try {
      // Get the ride
      final RideModel? ride = await _databaseService.getRideById(rideId);
      if (ride == null) {
        _setLoading(false);
        throw Exception('Ride not found');
      }

      // Update the ride
      final updatedRide = ride.copyWith(
        status: RideStatus.inProgress,
        pickupTime: DateTime.now(),
      );

      await _databaseService.updateRide(updatedRide);

      // Send notification to passenger
      if (ride.driverId != null) {
        await RideNotificationService.sendRideStartedNotification(
          rideId: rideId,
          passengerId: ride.passengerId,
          driverId: ride.driverId!,
        );
      }

      _setLoading(false);
    } catch (e) {
      _setLoading(false);
      rethrow;
    }
  }

  // Complete ride
  Future<void> completeRide(String rideId, double actualFare) async {
    _setLoading(true);
    try {
      // Get the ride
      final RideModel? ride = await _databaseService.getRideById(rideId);
      if (ride == null) {
        _setLoading(false);
        throw Exception('Ride not found');
      }

      if (ride.driverId == null) {
        _setLoading(false);
        throw Exception('No driver assigned to this ride');
      }
      
      // Check if ride is in progress
      if (ride.status != RideStatus.inProgress) {
        _setLoading(false);
        throw Exception('Ride is not in progress. Current status: ${ride.status}');
      }

      // Use the new completion method that tracks earnings
      await _databaseService.completeRide(rideId, ride.driverId!, actualFare);
      
      // Update driver status to available
      await _databaseService.updateDriverStatus(ride.driverId!, DriverStatus.online);

      // Send completion notification to passenger with rich driver details
      await RideNotificationService.sendRideCompletedNotification(
        rideId: rideId,
        passengerId: ride.passengerId,
        driverId: ride.driverId!,
        fare: actualFare,
      );
      
      print('✅ Ride completed successfully: $rideId, Fare: R${actualFare.toStringAsFixed(2)}');

      _setLoading(false);
    } catch (e) {
      print('❌ Error completing ride: $e');
      _setLoading(false);
      rethrow;
    }
  }

  // Cancel ride with earnings tracking and refund processing
  Future<void> cancelRide(String rideId, {String? reason, bool isDriver = false}) async {
    _setLoading(true);
    try {
      // Get the ride
      final RideModel? ride = await _databaseService.getRideById(rideId);
      if (ride == null) {
        _setLoading(false);
        throw Exception('Ride not found');
      }

      if (isDriver && ride.driverId == null) {
        _setLoading(false);
        throw Exception('No driver assigned to this ride');
      }

      // Payment info will be retrieved in cancelRideAndUpdateEarnings
      // No need to fetch it separately here

      // Use the new cancellation method that tracks earnings and processes refunds
      await _databaseService.cancelRideAndUpdateEarnings(
        rideId, 
        isDriver ? ride.driverId! : ride.passengerId,
        reason: reason,
        isDriverCancellation: isDriver,
      );

      // Send appropriate notifications
      final cancellationReason = reason ?? 'No reason provided';
      
      if (isDriver) {
        // Driver cancelled - notify passenger
        await RideNotificationService.sendRideCancelledNotification(
          rideId: rideId,
          passengerId: ride.passengerId,
          driverId: ride.driverId!,
          reason: cancellationReason,
        );
      } else {
        // Passenger cancelled - notify driver
        if (ride.driverId != null) {
          await RideNotificationService.sendRideCancelledToDriverNotification(
            rideId: rideId,
            passengerId: ride.passengerId,
            driverId: ride.driverId!,
            reason: cancellationReason,
          );
        }
      }
      
      // Notify passenger about refund if applicable
      // Get payment info from ride data
      final rideData = await _databaseService.getRideById(rideId);
      if (rideData != null) {
        // Try to get payment info from the ride document or payment collection
        try {
          final rideDoc = await FirebaseFirestore.instance.collection('rides').doc(rideId).get();
          if (rideDoc.exists) {
            final data = rideDoc.data() as Map<String, dynamic>?;
            final paymentType = data?['paymentType'] as String? ?? 'Cash';
            final paymentStatus = data?['paymentStatus'] as String? ?? 'pending';
            
            if (paymentType.toLowerCase() == 'card' && paymentStatus == 'paid') {
              // Refund request has been created in cancelRideAndUpdateEarnings
              // Send notification about refund
              await _notificationService.sendNotificationToUser(
                userId: ride.passengerId,
                title: 'Refund Processing',
                body: 'Your refund of R${ride.estimatedFare.toStringAsFixed(2)} is being processed. It will be credited to your account within 5-7 business days.',
                type: 'refund',
              );
            }
          }
        } catch (e) {
          print('Error checking payment info: $e');
          // Continue without refund notification if payment info can't be retrieved
        }
      }

      _setLoading(false);
    } catch (e) {
      _setLoading(false);
      rethrow;
    }
  }

  // Rate ride
  Future<void> rateRide(String rideId, String rating, {bool isDriver = false}) async {
    _setLoading(true);
    try {
      // Get the ride
      final RideModel? ride = await _databaseService.getRideById(rideId);
      if (ride == null) {
        _setLoading(false);
        throw Exception('Ride not found');
      }

      // Update the ride
      final updatedRide = isDriver ? ride.copyWith(driverRating: rating) : ride.copyWith(passengerRating: rating);

      await _databaseService.updateRide(updatedRide);

      _setLoading(false);
    } catch (e) {
      _setLoading(false);
      rethrow;
    }
  }

  // Get active ride for user
  Future<RideModel?> getUserActiveRide(String userId) async {
    _setLoading(true);
    try {
      final RideModel? activeRide = await _databaseService.getActiveRideForUser(userId);
      if (activeRide != null) {
        _currentRide = activeRide;
        _startListeningToRideUpdates(activeRide.id);
      }

      _setLoading(false);
      return activeRide;
    } catch (e) {
      _setLoading(false);
      rethrow;
    }
  }

  // Get active ride for driver
  Future<RideModel?> getDriverActiveRide(String driverId) async {
    _setLoading(true);
    try {
      final RideModel? activeRide = await _databaseService.getActiveRideForDriver(driverId);
      if (activeRide != null) {
        _currentRide = activeRide;
        _startListeningToRideUpdates(activeRide.id);
      }

      _setLoading(false);
      return activeRide;
    } catch (e) {
      _setLoading(false);
      rethrow;
    }
  }

  // Stop listening to ride updates
  void stopListeningToRideUpdates() {
    _rideSubscription?.cancel();
    _rideSubscription = null;
    _currentRide = null;
  }
}