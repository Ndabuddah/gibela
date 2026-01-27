import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/user_model.dart';

class DriverAccessService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Check if driver has completed signup and payment
  Future<Map<String, dynamic>> checkDriverAccess(String userId) async {
    try {
      print('🔍 Checking driver access for user: $userId');
      
      final userDoc = await _firestore.collection('users').doc(userId).get();
      final driverDoc = await _firestore.collection('drivers').doc(userId).get();
      
      if (!userDoc.exists) {
        print('❌ User document not found: $userId');
        return {
          'canAccess': false,
          'reason': 'User not found',
          'status': 'error',
        };
      }

      final userData = userDoc.data() as Map<String, dynamic>;
      
      // Check if user is registered as a driver
      if (!userData['isDriver']) {
        print('❌ User is not registered as driver: $userId');
        return {
          'canAccess': false,
          'reason': 'Not registered as a driver',
          'status': 'error',
        };
      }

      print('✅ User is registered as driver');

      // Payment is no longer required for any driver
      print('✅ Payment is free for all drivers');

      // Check if driver signup is required
      if (userData['requiresDriverSignup'] == true || !driverDoc.exists) {
        print('🚫 Driver signup check failed:');
        print('- Requires Signup: ${userData['requiresDriverSignup']}');
        print('- Profile Exists: ${driverDoc.exists}');
        
        return {
          'canAccess': false,
          'reason': 'Driver signup required',
          'status': 'signup_required',
          'missingItems': _getMissingItems(driverDoc.data() as Map<String, dynamic>?),
        };
      }

      // Check if driver profile is complete (but don't block access if approved)
      final isApproved = userData['isApproved'] ?? false;
      final isProfileComplete = userData['driverProfileCompleted'] == true;
      
      print('📋 Driver profile status:');
      print('- Is Approved: $isApproved');
      print('- Profile Complete: $isProfileComplete');
      
      if (!isProfileComplete && !isApproved) {
        print('🚫 Driver profile incomplete and not approved');
        
        return {
          'canAccess': false,
          'reason': 'Driver profile incomplete',
          'status': 'signup_required',
          'missingItems': _getMissingItems(driverDoc.data() as Map<String, dynamic>?),
        };
      }

      // Driver can access but show appropriate status
      final result = {
        'canAccess': true,
        'isApproved': isApproved,
        'status': isApproved ? 'approved' : 'awaiting_approval',
        'reason': isApproved ? 'Fully approved' : 'Awaiting approval',
      };
      
      print('✅ Driver access granted: ${result['status']}');
      return result;
      
    } catch (e) {
      print('❌ Error checking driver access: $e');
      return {
        'canAccess': false,
        'reason': 'Error checking access: $e',
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
    // Payment is no longer required for any driver
    return false;
  }

  // Helper method to check if driver profile is complete
  bool _isDriverProfileComplete(Map<String, dynamic> driverData) {
    // Check personal information
    if (driverData['name']?.isEmpty ?? true) return false;
    if (driverData['phoneNumber']?.isEmpty ?? true) return false;
    if (driverData['idNumber']?.isEmpty ?? true) return false;
    
    // Check vehicle information
    if (driverData['vehicleType']?.isEmpty ?? true) return false;
    if (driverData['vehicleModel']?.isEmpty ?? true) return false;
    if (driverData['vehicleColor']?.isEmpty ?? true) return false;
    if (driverData['licensePlate']?.isEmpty ?? true) return false;
    
    // Check location information
    if (driverData['towns']?.isEmpty ?? true) return false;
    
    // Check documents
    if (driverData['documents']?.isEmpty ?? true) return false;
    
    // Check for specific required documents
    final documents = driverData['documents'] as Map<String, dynamic>? ?? {};
    final requiredDocs = [
      'ID Document',
      'Professional Driving Permit',
      'Roadworthy Certificate',
      'Vehicle Image',
      'Driver Profile Image',
      'Driver Image Next to Vehicle',
      'Bank Statement'
    ];
    
    for (final doc in requiredDocs) {
      if (!documents.containsKey(doc) || documents[doc]?.isEmpty == true) {
        return false;
      }
    }
    
    return true;
  }

  // Helper method to get list of missing items
  List<String> _getMissingItems(Map<String, dynamic>? driverData) {
    if (driverData == null) return ['Complete Driver Profile'];
    
    final missingItems = <String>[];
    
    // Check personal information
    if (driverData['name']?.isEmpty ?? true) {
      missingItems.add('Full Name');
    }
    if (driverData['phoneNumber']?.isEmpty ?? true) {
      missingItems.add('Phone Number');
    }
    if (driverData['idNumber']?.isEmpty ?? true) {
      missingItems.add('ID Number');
    }
    
    // Check vehicle information
    if (driverData['vehicleType']?.isEmpty ?? true) {
      missingItems.add('Vehicle Type');
    }
    if (driverData['vehicleModel']?.isEmpty ?? true) {
      missingItems.add('Vehicle Model');
    }
    if (driverData['vehicleColor']?.isEmpty ?? true) {
      missingItems.add('Vehicle Color');
    }
    if (driverData['licensePlate']?.isEmpty ?? true) {
      missingItems.add('License Plate');
    }
    
    // Check location information
    if (driverData['towns']?.isEmpty ?? true) {
      missingItems.add('Service Areas');
    }
    
    // Check documents
    if (driverData['documents']?.isEmpty ?? true) {
      missingItems.add('Required Documents');
    } else {
      // Check for specific required documents
      final documents = driverData['documents'] as Map<String, dynamic>? ?? {};
      final requiredDocs = [
        'ID Document',
        'Professional Driving Permit',
        'Roadworthy Certificate',
        'Vehicle Image',
        'Driver Profile Image',
        'Driver Image Next to Vehicle',
        'Bank Statement'
      ];
      
      final missingDocs = requiredDocs.where((doc) => 
        !documents.containsKey(doc) || documents[doc]?.isEmpty == true
      ).toList();
      
      if (missingDocs.isNotEmpty) {
        missingItems.add('Required Documents');
      }
    }
    
    return missingItems;
  }
}