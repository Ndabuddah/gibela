import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';

class DriverAccessService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Check if driver has completed signup and payment
  Future<Map<String, dynamic>> checkDriverAccess(String userId) async {
    try {
      final userDoc = await _firestore.collection('users').doc(userId).get();
      final driverDoc = await _firestore.collection('drivers').doc(userId).get();
      
      if (!userDoc.exists) {
        return {
          'canAccess': false,
          'reason': 'User not found',
          'status': 'error',
        };
      }

      final userData = userDoc.data() as Map<String, dynamic>;
      
      // Check if user is registered as a driver
      if (!userData['isDriver']) {
        return {
          'canAccess': false,
          'reason': 'Not registered as a driver',
          'status': 'error',
        };
      }

      // Check if email is verified
      if (userData['emailVerified'] != true) {
        return {
          'canAccess': false,
          'reason': 'Email not verified',
          'status': 'email_verification_required',
        };
      }

      // Check payment status FIRST - even if profile is complete, payment is required
      final paymentsQuery = await _firestore
          .collection('driver_payments')
          .where('driverId', isEqualTo: userId)
          .where('status', isEqualTo: 'success')
          .orderBy('timestamp', descending: true)
          .limit(1)
          .get();

      if (paymentsQuery.docs.isEmpty) {
        return {
          'canAccess': false,
          'reason': 'Payment required',
          'status': 'payment_required',
        };
      }

      // Check if driver signup is required
      if (userData['requiresDriverSignup'] == true || 
          !driverDoc.exists || 
          userData['driverProfileCompleted'] != true) {
        print('🚫 Driver signup check failed:');
        print('- Requires Signup: ${userData['requiresDriverSignup']}');
        print('- Profile Exists: ${driverDoc.exists}');
        print('- Profile Completed: ${userData['driverProfileCompleted']}');
        
        return {
          'canAccess': false,
          'reason': 'Driver signup or profile incomplete',
          'status': 'signup_required',
          'missingItems': _getMissingItems(driverDoc.data() as Map<String, dynamic>?),
        };
      }

      // Check if driver profile is complete
      if (driverDoc.exists && !_isDriverProfileComplete(driverDoc.data() as Map<String, dynamic>)) {
        print('🚫 Driver profile incomplete:');
        final missingItems = _getMissingItems(driverDoc.data() as Map<String, dynamic>);
        print('Missing items: $missingItems');
        
        return {
          'canAccess': false,
          'reason': 'Driver profile incomplete',
          'status': 'signup_required',
          'missingItems': missingItems,
        };
      }

      // Check if the driver is approved
      final isApproved = userData['isApproved'] ?? false;
      
      // Driver can access but show appropriate status
      return {
        'canAccess': true,
        'isApproved': isApproved,
        'status': isApproved ? 'approved' : 'awaiting_approval',
        'reason': isApproved ? 'Fully approved' : 'Awaiting approval',
      };
    } catch (e) {
      print('Error checking driver access: $e');
      return {
        'canAccess': false,
        'reason': 'Error checking access',
        'status': 'error',
      };
    }
  }

  // Stream to monitor driver's approval status
  Stream<String> driverStatusStream(String userId) {
    return _firestore.collection('users').doc(userId).snapshots().map((snapshot) {
      if (!snapshot.exists) return 'error';
      
      final data = snapshot.data() as Map<String, dynamic>;
      
      if (!data['isDriver']) return 'not_driver';
      if (data['requiresDriverSignup'] == true) return 'signup_required';
      if (data['driverProfileCompleted'] != true) return 'profile_incomplete';
      if (data['isApproved'] == true) return 'approved';
      
      return 'awaiting_approval';
    });
  }

  // Check if payment is required
  Future<bool> isPaymentRequired(String userId) async {
    try {
      final paymentsQuery = await _firestore
          .collection('driver_payments')
          .where('driverId', isEqualTo: userId)
          .where('status', isEqualTo: 'success')
          .orderBy('timestamp', descending: true)
          .limit(1)
          .get();

      if (paymentsQuery.docs.isEmpty) {
        return true;
      }

      // Check if the last payment is still valid
      final lastPayment = paymentsQuery.docs.first.data();
      final paymentDate = (lastPayment['timestamp'] as Timestamp).toDate();
      final validUntil = lastPayment['validUntil'] != null 
          ? (lastPayment['validUntil'] as Timestamp).toDate()
          : paymentDate.add(const Duration(days: 7)); // Default 7-day validity

      return DateTime.now().isAfter(validUntil);
    } catch (e) {
      print('Error checking payment status: $e');
      return true;
    }
  }

  // Helper method to check if driver profile is complete
  bool _isDriverProfileComplete(Map<String, dynamic> driverData) {
    return driverData['idNumber']?.isNotEmpty == true &&
           driverData['documents']?.isNotEmpty == true &&
           driverData['vehicleType'] != null &&
           driverData['vehicleModel'] != null &&
           driverData['vehicleColor'] != null &&
           driverData['licensePlate'] != null &&
           driverData['towns']?.isNotEmpty == true;
  }

  // Helper method to get list of missing items
  List<String> _getMissingItems(Map<String, dynamic>? driverData) {
    if (driverData == null) return ['Complete Driver Profile'];
    
    final missingItems = <String>[];
    
    if (driverData['idNumber']?.isEmpty ?? true) {
      missingItems.add('ID Number');
    }
    if (driverData['documents']?.isEmpty ?? true) {
      missingItems.add('Required Documents');
    }
    if (driverData['vehicleType'] == null) {
      missingItems.add('Vehicle Type');
    }
    if (driverData['vehicleModel'] == null) {
      missingItems.add('Vehicle Model');
    }
    if (driverData['vehicleColor'] == null) {
      missingItems.add('Vehicle Color');
    }
    if (driverData['licensePlate'] == null) {
      missingItems.add('License Plate');
    }
    if (driverData['towns']?.isEmpty ?? true) {
      missingItems.add('Service Areas');
    }
    
    return missingItems;
  }
}