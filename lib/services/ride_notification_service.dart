import 'package:cloud_firestore/cloud_firestore.dart';
import 'notification_service.dart';

class RideNotificationService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final NotificationService _notificationService = NotificationService();

  // Get complete driver details from drivers collection
  static Future<Map<String, dynamic>?> _getDriverDetails(String driverId) async {
    try {
      final driverDoc = await _firestore.collection('drivers').doc(driverId).get();
      if (driverDoc.exists) {
        return driverDoc.data();
      }
      return null;
    } catch (e) {
      print('Error fetching driver details: $e');
      return null;
    }
  }

  // Send notification when driver accepts a ride
  static Future<void> sendRideAcceptedNotification({
    required String rideId,
    required String passengerId,
    required String driverId,
    String? driverName,
    required String vehicleType,
  }) async {
    try {
      // Fetch complete driver details
      final driverDetails = await _getDriverDetails(driverId);
      final driverName = driverDetails?['name'] ?? 'Unknown Driver';
      final vehicleModel = driverDetails?['vehicleModel'] ?? 'Vehicle';
      final vehicleColor = driverDetails?['vehicleColor'] ?? '';
      final licensePlate = driverDetails?['licensePlate'] ?? '';
      final averageRating = driverDetails?['averageRating'] ?? 0.0;
      final totalRides = driverDetails?['totalRides'] ?? 0;
      final profileImage = driverDetails?['profileImage'] ?? '';

      // Create rich notification body with driver details
      String body = '$driverName has accepted your ride request';
      if (vehicleModel.isNotEmpty) {
        body += '\nVehicle: $vehicleModel';
        if (vehicleColor.isNotEmpty) {
          body += ' ($vehicleColor)';
        }
      }
      if (licensePlate != null && licensePlate.isNotEmpty) {
        body += '\nPlate: $licensePlate';
      }
      if (averageRating > 0) {
        body += '\nRating: ${averageRating.toStringAsFixed(1)} ⭐ ($totalRides trips)';
      }

      await _notificationService.sendRideNotification(
        userId: passengerId,
        title: 'Driver Found!',
        body: body,
        rideId: rideId,
        data: {
          'driverId': driverId,
          'driverName': driverName,
          'vehicleModel': vehicleModel,
          'vehicleColor': vehicleColor,
          'licensePlate': licensePlate,
          'averageRating': averageRating,
          'totalRides': totalRides,
          'profileImage': profileImage,
        },
      );
    } catch (e) {
      print('Error sending ride accepted notification: $e');
    }
  }

  // Send notification when driver arrives
  static Future<void> sendDriverArrivedNotification({
    required String rideId,
    required String passengerId,
    required String driverId,
    String? driverName,
  }) async {
    try {
      // Fetch complete driver details
      final driverDetails = await _getDriverDetails(driverId);
      final driverName = driverDetails?['name'] ?? 'Unknown Driver';
      final vehicleModel = driverDetails?['vehicleModel'] ?? 'Vehicle';
      final vehicleColor = driverDetails?['vehicleColor'] ?? '';
      final licensePlate = driverDetails?['licensePlate'] ?? '';
      final profileImage = driverDetails?['profileImage'] ?? '';

      // Create rich notification body
      String body = '$driverName has arrived at your pickup location';
      if (vehicleModel.isNotEmpty) {
        body += '\nVehicle: $vehicleModel';
        if (vehicleColor.isNotEmpty) {
          body += ' ($vehicleColor)';
        }
      }
      if (licensePlate != null && licensePlate.isNotEmpty) {
        body += '\nPlate: $licensePlate';
      }

      await _notificationService.sendDriverArrivedNotification(
        userId: passengerId,
        driverName: driverName,
        rideId: rideId,
        data: {
          'driverId': driverId,
          'vehicleModel': vehicleModel,
          'vehicleColor': vehicleColor,
          'licensePlate': licensePlate,
          'profileImage': profileImage,
        },
      );
    } catch (e) {
      print('Error sending driver arrived notification: $e');
    }
  }

  // Send notification when ride starts
  static Future<void> sendRideStartedNotification({
    required String rideId,
    required String passengerId,
    required String driverId,
    String? driverName,
  }) async {
    try {
      // Fetch complete driver details
      final driverDetails = await _getDriverDetails(driverId);
      final driverName = driverDetails?['name'] ?? 'Unknown Driver';
      final vehicleModel = driverDetails?['vehicleModel'] ?? 'Vehicle';
      final vehicleColor = driverDetails?['vehicleColor'] ?? '';

      String body = 'Your ride with $driverName has started';
      if (vehicleModel.isNotEmpty) {
        body += '\nVehicle: $vehicleModel';
        if (vehicleColor.isNotEmpty) {
          body += ' ($vehicleColor)';
        }
      }

      await _notificationService.sendRideNotification(
        userId: passengerId,
        title: 'Ride Started',
        body: body,
        rideId: rideId,
        data: {
          'driverId': driverId,
          'driverName': driverName,
          'vehicleModel': vehicleModel,
          'vehicleColor': vehicleColor,
        },
      );
    } catch (e) {
      print('Error sending ride started notification: $e');
    }
  }

  // Send notification when ride is completed
  static Future<void> sendRideCompletedNotification({
    required String rideId,
    required String passengerId,
    required String driverId,
    String? driverName,
    required double fare,
  }) async {
    try {
      // Fetch complete driver details
      final driverDetails = await _getDriverDetails(driverId);
      final driverName = driverDetails?['name'] ?? 'Unknown Driver';
      final averageRating = driverDetails?['averageRating'] ?? 0.0;
      final totalRides = driverDetails?['totalRides'] ?? 0;

      String body = 'Your ride with $driverName has been completed';
      body += '\nFare: R${fare.toStringAsFixed(2)}';
      if (averageRating > 0) {
        body += '\nDriver Rating: ${averageRating.toStringAsFixed(1)} ⭐ ($totalRides trips)';
      }

      await _notificationService.sendRideNotification(
        userId: passengerId,
        title: 'Ride Completed',
        body: body,
        rideId: rideId,
        data: {
          'driverId': driverId,
          'driverName': driverName,
          'fare': fare,
          'averageRating': averageRating,
          'totalRides': totalRides,
        },
      );
    } catch (e) {
      print('Error sending ride completed notification: $e');
    }
  }

  // Send notification when ride is cancelled
  static Future<void> sendRideCancelledNotification({
    required String rideId,
    required String passengerId,
    required String driverId,
    String? driverName,
    required String reason,
  }) async {
    try {
      // Fetch complete driver details
      final driverDetails = await _getDriverDetails(driverId);
      final driverName = driverDetails?['name'] ?? 'Unknown Driver';

      await _notificationService.sendRideNotification(
        userId: passengerId,
        title: 'Ride Cancelled',
        body: 'Your ride with $driverName has been cancelled. Reason: $reason',
        rideId: rideId,
        data: {
          'driverId': driverId,
          'driverName': driverName,
          'reason': reason,
        },
      );
    } catch (e) {
      print('Error sending ride cancelled notification: $e');
    }
  }

  // Send notification to driver when new ride request is available
  static Future<void> sendNewRideRequestNotification({
    required String driverId,
    required String passengerName,
    required String pickupAddress,
    required String dropoffAddress,
    required double estimatedFare,
  }) async {
    try {
      await _notificationService.sendRideNotification(
        userId: driverId,
        title: 'New Ride Request',
        body: 'New ride request from $passengerName. Estimated fare: R${estimatedFare.toStringAsFixed(2)}',
        rideId: '', // Will be set when driver accepts
      );
    } catch (e) {
      print('Error sending new ride request notification: $e');
    }
  }

  // Send notification when driver is near pickup location
  static Future<void> sendDriverNearbyNotification({
    required String rideId,
    required String passengerId,
    required String driverName,
  }) async {
    try {
      await _notificationService.sendRideNotification(
        userId: passengerId,
        title: 'Driver Nearby',
        body: '$driverName is approaching your pickup location',
        rideId: rideId,
      );
    } catch (e) {
      print('Error sending driver nearby notification: $e');
    }
  }

  // Send notification for payment reminder
  static Future<void> sendPaymentReminderNotification({
    required String userId,
    required double amount,
  }) async {
    try {
      await _notificationService.sendRideNotification(
        userId: userId,
        title: 'Payment Reminder',
        body: 'Please complete your payment of R${amount.toStringAsFixed(2)}',
        rideId: '',
      );
    } catch (e) {
      print('Error sending payment reminder notification: $e');
    }
  }

  // Send notification for ride rating reminder
  static Future<void> sendRatingReminderNotification({
    required String userId,
    required String driverName,
  }) async {
    try {
      await _notificationService.sendRideNotification(
        userId: userId,
        title: 'Rate Your Ride',
        body: 'How was your ride with $driverName? Please rate your experience',
        rideId: '',
      );
    } catch (e) {
      print('Error sending rating reminder notification: $e');
    }
  }

  // Send notification for referral bonus
  static Future<void> sendReferralBonusNotification({
    required String userId,
    required double bonusAmount,
  }) async {
    try {
      await _notificationService.sendRideNotification(
        userId: userId,
        title: 'Referral Bonus!',
        body: 'You earned R${bonusAmount.toStringAsFixed(2)} for your referral!',
        rideId: '',
      );
    } catch (e) {
      print('Error sending referral bonus notification: $e');
    }
  }

  // Send notification for account verification
  static Future<void> sendVerificationNotification({
    required String userId,
    required String verificationType,
  }) async {
    try {
      await _notificationService.sendRideNotification(
        userId: userId,
        title: 'Account Verification',
        body: 'Your $verificationType verification has been processed',
        rideId: '',
      );
    } catch (e) {
      print('Error sending verification notification: $e');
    }
  }
} 