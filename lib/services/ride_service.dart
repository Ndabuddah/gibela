import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../constants/app_constants.dart';
import '../models/driver_model.dart';
import '../models/ride_model.dart';
import '../services/pricing_service.dart';
import '../services/notification_service.dart';
import '../services/ride_notification_service.dart';
import 'database_service.dart';
import 'location_service.dart';
// Removed: import 'mapbox_service.dart';

class RideService extends ChangeNotifier {
  final DatabaseService _databaseService = DatabaseService();
  final LocationService _locationService = LocationService();
  final NotificationService _notificationService = NotificationService();

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
    super.dispose();
  }

  // Create a new ride request
  Future<RideModel?> createRideRequest({
    required String passengerId,
    required String pickupAddress,
    required double pickupLat,
    required double pickupLng,
    required String dropoffAddress,
    required double dropoffLat,
    required double dropoffLng,
    required String vehicleType,
    double distance = 1.0, // Default 1km for fare calculation
  }) async {
    _setLoading(true);
    try {
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
      );

      // Save to database
      final String rideId = await _databaseService.createRideRequest(newRide);

      // Get the created ride with the assigned ID
      final createdRide = newRide.copyWith(id: rideId);
      _currentRide = createdRide;

      // Start listening to updates
      _startListeningToRideUpdates(rideId);

      _setLoading(false);
      return createdRide;
    } catch (e) {
      _setLoading(false);
      rethrow;
    }
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
  void _startListeningToRideUpdates(String rideId) {
    _rideSubscription?.cancel();
    _rideSubscription = _databaseService.listenToRideUpdates(rideId).listen((updatedRide) {
      _currentRide = updatedRide;
      notifyListeners();
    });
  }

  // Accept a ride request (driver)
  Future<void> acceptRideRequest(String rideId, String driverId) async {
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
        driverId: driverId,
        status: RideStatus.accepted,
      );

      await _databaseService.updateRide(updatedRide);

      // Create chat between driver and passenger
      await _databaseService.createOrGetChat(driverId, ride.passengerId);

      // Update driver status
      await _databaseService.updateDriverStatus(driverId, DriverStatus.onRide);

      // Send notification to passenger
      await RideNotificationService.sendRideAcceptedNotification(
        rideId: rideId,
        passengerId: ride.passengerId,
        driverId: driverId,
        vehicleType: ride.vehicleType,
      );

      _setLoading(false);
    } catch (e) {
      _setLoading(false);
      rethrow;
    }
  }

  // Driver arrived at pickup location
  Future<void> driverArrived(String rideId) async {
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
        status: RideStatus.driverArrived,
      );

      await _databaseService.updateRide(updatedRide);

      // Send notification to passenger
      if (ride.driverId != null) {
        await RideNotificationService.sendDriverArrivedNotification(
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

      // Use the new completion method that tracks earnings
      await _databaseService.completeRide(rideId, ride.driverId!, actualFare);

      // Send completion notification to passenger with rich driver details
      await RideNotificationService.sendRideCompletedNotification(
        rideId: rideId,
        passengerId: ride.passengerId,
        driverId: ride.driverId!,
        fare: actualFare,
      );

      _setLoading(false);
    } catch (e) {
      _setLoading(false);
      rethrow;
    }
  }

  // Cancel ride with earnings tracking
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

      // Use the new cancellation method that tracks earnings
      await _databaseService.cancelRideAndUpdateEarnings(
        rideId, 
        isDriver ? ride.driverId! : ride.passengerId,
        reason: reason,
        isDriverCancellation: isDriver,
      );

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