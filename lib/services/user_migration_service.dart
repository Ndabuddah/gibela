import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/user_model.dart';
import 'database_service.dart';
import 'driver_access_service.dart';

class UserMigrationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final DatabaseService _databaseService = DatabaseService();
  final DriverAccessService _driverAccessService = DriverAccessService();

  // Check and fix user state
  Future<Map<String, dynamic>> checkAndFixUserState(String userId) async {
    try {
      print('🔍 Checking user state for: $userId');
      
      final userDoc = await _firestore.collection('users').doc(userId).get();
      if (!userDoc.exists) {
        return {
          'needsAction': true,
          'action': 'relogin',
          'reason': 'User data not found'
        };
      }

      final userData = userDoc.data() as Map<String, dynamic>;
      final isDriver = userData['isDriver'] ?? false;

      if (!isDriver) {
        return {
          'needsAction': false,
          'action': 'none',
          'reason': 'Not a driver'
        };
      }

      print('🚗 Checking driver state...');
      print('- Is Driver: $isDriver');
      print('- Is Approved: ${userData['isApproved']}');
      print('- Requires Signup: ${userData['requiresDriverSignup']}');

      // Check email verification
      final auth = FirebaseAuth.instance;
      final user = auth.currentUser;
      if (user != null) {
        await user.reload();
        if (!user.emailVerified) {
          return {
            'needsAction': true,
            'action': 'verify_email',
            'reason': 'Email not verified'
          };
        }
      }

      // Ensure driver flags are set correctly
      bool needsUpdate = false;
      Map<String, dynamic> updates = {};

      // Force isApproved to false for drivers if not set
      if (userData['isApproved'] == null || (isDriver && userData['isApproved'] == true)) {
        updates['isApproved'] = false;
        needsUpdate = true;
      }

      // Check if requiresDriverSignup should be true
      if (userData['requiresDriverSignup'] == null || userData['requiresDriverSignup'] == false) {
        // Check if driver profile is incomplete
        final driverDoc = await _firestore.collection('drivers').doc(userId).get();
        final hasCompleteProfile = driverDoc.exists && 
            driverDoc.data()?['idNumber'] != null &&
            driverDoc.data()?['documents'] != null &&
            (driverDoc.data()?['documents'] as Map<String, dynamic>).isNotEmpty;

        if (!hasCompleteProfile) {
          updates['requiresDriverSignup'] = true;
          needsUpdate = true;
        }
      }

      // Add approvalStatus if missing
      if (userData['approvalStatus'] == null) {
        updates['approvalStatus'] = 'pending_signup';
        needsUpdate = true;
      }

      if (needsUpdate) {
        print('📝 Updating driver flags:');
        print(updates);
        await _firestore.collection('users').doc(userId).update(updates);
      }

      // Check driver signup status
      final needsSignup = await _databaseService.needsDriverSignup(userId);
      if (needsSignup) {
        return {
          'needsAction': true,
          'action': 'driver_signup',
          'reason': 'Driver signup incomplete'
        };
      }

      // Check payment status
      final accessCheck = await _driverAccessService.checkDriverAccess(userId);
      if (accessCheck['status'] == 'payment_required') {
        return {
          'needsAction': true,
          'action': 'payment',
          'reason': 'Payment required'
        };
      }

      return {
        'needsAction': false,
        'action': 'home',
        'status': accessCheck['status'],
        'isApproved': accessCheck['isApproved']
      };
    } catch (e) {
      print('❌ Error checking user state: $e');
      return {
        'needsAction': true,
        'action': 'relogin',
        'reason': 'Error checking state'
      };
    }
  }

  // Fix driver flags if needed
  Future<void> fixDriverFlags(String userId) async {
    try {
      final userDoc = await _firestore.collection('users').doc(userId).get();
      if (!userDoc.exists) return;

      final userData = userDoc.data() as Map<String, dynamic>;
      if (userData['isDriver'] != true) return;

      Map<String, dynamic> updates = {};

      // Force isApproved to false
      if (userData['isApproved'] == true) {
        updates['isApproved'] = false;
      }

      // Set requiresDriverSignup if profile incomplete
      final driverDoc = await _firestore.collection('drivers').doc(userId).get();
      if (!driverDoc.exists || !_isDriverProfileComplete(driverDoc.data() as Map<String, dynamic>)) {
        updates['requiresDriverSignup'] = true;
      }

      if (updates.isNotEmpty) {
        await _firestore.collection('users').doc(userId).update(updates);
      }
    } catch (e) {
      print('❌ Error fixing driver flags: $e');
    }
  }

  bool _isDriverProfileComplete(Map<String, dynamic> driverData) {
    return driverData['idNumber']?.isNotEmpty == true &&
           driverData['documents']?.isNotEmpty == true &&
           driverData['vehicleType'] != null &&
           driverData['vehicleModel'] != null &&
           driverData['licensePlate'] != null &&
           (driverData['towns'] as List?)?.isNotEmpty == true;
  }
}