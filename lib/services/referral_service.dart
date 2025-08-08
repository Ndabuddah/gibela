import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ReferralService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  // Validate and process a referral code
  static Future<Map<String, dynamic>> validateReferralCode(String referralCode) async {
    try {
      // Check if the referral code exists (it should be a valid user UID)
      final userDoc = await _firestore.collection('users').doc(referralCode).get();
      
      if (!userDoc.exists) {
        return {
          'valid': false,
          'message': 'Invalid referral code',
        };
      }

      final userData = userDoc.data() as Map<String, dynamic>;
      final referrerId = userDoc.id;
      final currentUserId = _auth.currentUser?.uid;

      // Check if user is trying to refer themselves
      if (currentUserId == referrerId) {
        return {
          'valid': false,
          'message': 'You cannot refer yourself',
        };
      }

      // Check if user has already been referred
      final currentUserDoc = await _firestore.collection('users').doc(currentUserId).get();
      if (currentUserDoc.exists) {
        final currentUserData = currentUserDoc.data() as Map<String, dynamic>;
        if (currentUserData['referredBy'] != null) {
          return {
            'valid': false,
            'message': 'You have already been referred',
          };
        }
      }

      return {
        'valid': true,
        'referrerId': referrerId,
        'referrerName': userData['name'] ?? 'Unknown',
        'message': 'Valid referral code',
      };
    } catch (e) {
      return {
        'valid': false,
        'message': 'Error validating referral code: $e',
      };
    }
  }

  // Apply referral code to a new user
  static Future<void> applyReferralCode(String referralCode, String newUserId) async {
    try {
      final validation = await validateReferralCode(referralCode);
      
      if (!validation['valid']) {
        throw Exception(validation['message']);
      }

      final referrerId = validation['referrerId'] as String;
      final referrerName = validation['referrerName'] as String;

      // Update the new user's document with referral information
      await _firestore.collection('users').doc(newUserId).update({
        'referredBy': referrerId,
        'referredByName': referrerName,
        'referralAppliedAt': FieldValue.serverTimestamp(),
      });

      // Update the referrer's referral count and amount
      await _updateReferrerStats(referrerId);

      // Create a referral record
      await _firestore.collection('referrals').add({
        'referrerId': referrerId,
        'referredUserId': newUserId,
        'referrerName': referrerName,
        'status': 'pending', // pending, completed, cancelled
        'rewardAmount': 50.0, // R50 reward for successful referral
        'createdAt': FieldValue.serverTimestamp(),
        'completedAt': null,
      });

    } catch (e) {
      throw Exception('Failed to apply referral code: $e');
    }
  }

  // Update referrer's statistics
  static Future<void> _updateReferrerStats(String referrerId) async {
    try {
      final userRef = _firestore.collection('users').doc(referrerId);
      
      await _firestore.runTransaction((transaction) async {
        final userDoc = await transaction.get(userRef);
        
        if (userDoc.exists) {
          final currentReferrals = userDoc.data()?['referrals'] ?? 0;
          final currentAmount = userDoc.data()?['referralAmount'] ?? 0.0;
          
          transaction.update(userRef, {
            'referrals': currentReferrals + 1,
            'referralAmount': currentAmount + 50.0, // R50 per referral
            'lastReferral': FieldValue.serverTimestamp(),
          });
        }
      });
    } catch (e) {
      print('Error updating referrer stats: $e');
    }
  }

  // Get referral statistics for a user
  static Future<Map<String, dynamic>> getReferralStats(String userId) async {
    try {
      final userDoc = await _firestore.collection('users').doc(userId).get();
      
      if (!userDoc.exists) {
        return {
          'referrals': 0,
          'referralAmount': 0.0,
          'lastReferral': null,
          'referralCode': userId,
        };
      }

      final userData = userDoc.data() as Map<String, dynamic>;
      
      return {
        'referrals': userData['referrals'] ?? 0,
        'referralAmount': (userData['referralAmount'] ?? 0.0).toDouble(),
        'lastReferral': userData['lastReferral'],
        'referralCode': userId,
      };
    } catch (e) {
      print('Error getting referral stats: $e');
      return {
        'referrals': 0,
        'referralAmount': 0.0,
        'lastReferral': null,
        'referralCode': userId,
      };
    }
  }

  // Get list of users referred by a specific user
  static Future<List<Map<String, dynamic>>> getReferredUsers(String referrerId) async {
    try {
      final querySnapshot = await _firestore
          .collection('users')
          .where('referredBy', isEqualTo: referrerId)
          .orderBy('referralAppliedAt', descending: true)
          .get();

      return querySnapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'userId': doc.id,
          'name': data['name'] ?? 'Unknown',
          'email': data['email'] ?? '',
          'referralAppliedAt': data['referralAppliedAt'],
          'isDriver': data['isDriver'] ?? false,
          'isApproved': data['isApproved'] ?? false,
        };
      }).toList();
    } catch (e) {
      print('Error getting referred users: $e');
      return [];
    }
  }

  // Complete a referral (when referred user completes their first ride)
  static Future<void> completeReferral(String referredUserId) async {
    try {
      // Find the referral record
      final referralQuery = await _firestore
          .collection('referrals')
          .where('referredUserId', isEqualTo: referredUserId)
          .where('status', isEqualTo: 'pending')
          .limit(1)
          .get();

      if (referralQuery.docs.isEmpty) {
        return; // No pending referral found
      }

      final referralDoc = referralQuery.docs.first;
      final referralData = referralDoc.data();
      final referrerId = referralData['referrerId'] as String;

      // Update referral status to completed
      await referralDoc.reference.update({
        'status': 'completed',
        'completedAt': FieldValue.serverTimestamp(),
      });

      // Send notification to referrer
      await _sendReferralCompletionNotification(referrerId, referredUserId);

    } catch (e) {
      print('Error completing referral: $e');
    }
  }

  // Send notification when referral is completed
  static Future<void> _sendReferralCompletionNotification(String referrerId, String referredUserId) async {
    try {
      // Get referred user's name
      final referredUserDoc = await _firestore.collection('users').doc(referredUserId).get();
      final referredUserName = referredUserDoc.data()?['name'] ?? 'Someone';

      // Create notification for referrer
      await _firestore.collection('notifications').add({
        'userId': referrerId,
        'title': 'Referral Completed!',
        'body': '$referredUserName completed their first ride! You earned R50.',
        'type': 'referral_completed',
        'data': {
          'referredUserId': referredUserId,
          'rewardAmount': 50.0,
        },
        'isRead': false,
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error sending referral completion notification: $e');
    }
  }

  // Get referral history for a user
  static Future<List<Map<String, dynamic>>> getReferralHistory(String userId) async {
    try {
      final querySnapshot = await _firestore
          .collection('referrals')
          .where('referrerId', isEqualTo: userId)
          .orderBy('createdAt', descending: true)
          .get();

      return querySnapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'referredUserId': data['referredUserId'],
          'referrerName': data['referrerName'],
          'status': data['status'],
          'rewardAmount': data['rewardAmount'],
          'createdAt': data['createdAt'],
          'completedAt': data['completedAt'],
        };
      }).toList();
    } catch (e) {
      print('Error getting referral history: $e');
      return [];
    }
  }

  // Check if a user has completed referral requirements
  static Future<bool> hasCompletedReferralRequirements(String userId) async {
    try {
      // Check if user has completed at least one ride
      final ridesQuery = await _firestore
          .collection('rides')
          .where('passengerId', isEqualTo: userId)
          .where('status', isEqualTo: 'completed')
          .limit(1)
          .get();

      return ridesQuery.docs.isNotEmpty;
    } catch (e) {
      print('Error checking referral requirements: $e');
      return false;
    }
  }
} 