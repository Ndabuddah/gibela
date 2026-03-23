import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Service for tracking user analytics and app metrics
class AnalyticsService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  /// Track a custom event
  Future<void> trackEvent({
    required String eventName,
    Map<String, dynamic>? parameters,
  }) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      final userId = user?.uid ?? 'anonymous';
      
      await _firestore.collection('analytics').add({
        'userId': userId,
        'eventName': eventName,
        'parameters': parameters ?? {},
        'timestamp': FieldValue.serverTimestamp(),
        'platform': 'mobile', // Could be enhanced to detect iOS/Android
      });
    } catch (e) {
      print('Error tracking event: $e');
      // Don't throw - analytics failures shouldn't break the app
    }
  }
  
  /// Track ride completion
  Future<void> trackRideCompletion({
    required String rideId,
    required String userId,
    required double fare,
    required double distance,
    required int duration,
    required String vehicleType,
  }) async {
    await trackEvent(
      eventName: 'ride_completed',
      parameters: {
        'rideId': rideId,
        'fare': fare,
        'distance': distance,
        'duration': duration,
        'vehicleType': vehicleType,
      },
    );
  }
  
  /// Track ride cancellation
  Future<void> trackRideCancellation({
    required String rideId,
    required String userId,
    required String reason,
    required String cancelledBy, // 'passenger' or 'driver'
  }) async {
    await trackEvent(
      eventName: 'ride_cancelled',
      parameters: {
        'rideId': rideId,
        'reason': reason,
        'cancelledBy': cancelledBy,
      },
    );
  }
  
  /// Track driver acceptance
  Future<void> trackDriverAcceptance({
    required String rideId,
    required String driverId,
    required double timeToAccept, // seconds
    required bool isAutoAssigned,
  }) async {
    await trackEvent(
      eventName: 'driver_accepted',
      parameters: {
        'rideId': rideId,
        'driverId': driverId,
        'timeToAccept': timeToAccept,
        'isAutoAssigned': isAutoAssigned,
      },
    );
  }
  
  /// Track payment success/failure
  Future<void> trackPayment({
    required String userId,
    required double amount,
    required bool success,
    required String paymentMethod,
    String? error,
  }) async {
    await trackEvent(
      eventName: success ? 'payment_success' : 'payment_failed',
      parameters: {
        'amount': amount,
        'paymentMethod': paymentMethod,
        if (error != null) 'error': error,
      },
    );
  }
  
  /// Track feature usage
  Future<void> trackFeatureUsage({
    required String featureName,
    Map<String, dynamic>? metadata,
  }) async {
    await trackEvent(
      eventName: 'feature_used',
      parameters: {
        'featureName': featureName,
        ...?metadata,
      },
    );
  }
  
  /// Track error occurrence
  Future<void> trackError({
    required String errorType,
    required String errorMessage,
    String? screen,
    Map<String, dynamic>? context,
  }) async {
    await trackEvent(
      eventName: 'error_occurred',
      parameters: {
        'errorType': errorType,
        'errorMessage': errorMessage,
        if (screen != null) 'screen': screen,
        ...?context,
      },
    );
  }
  
  /// Track screen view
  Future<void> trackScreenView({
    required String screenName,
  }) async {
    await trackEvent(
      eventName: 'screen_view',
      parameters: {
        'screenName': screenName,
      },
    );
  }
  
  /// Track user action
  Future<void> trackUserAction({
    required String action,
    String? screen,
    Map<String, dynamic>? metadata,
  }) async {
    await trackEvent(
      eventName: 'user_action',
      parameters: {
        'action': action,
        if (screen != null) 'screen': screen,
        ...?metadata,
      },
    );
  }
}


