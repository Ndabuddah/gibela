import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/user_model.dart';
import 'notification_service.dart';

class PanicService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final NotificationService _notificationService = NotificationService();

  // Check if user has trusted contacts
  static Future<bool> hasTrustedContacts(String userId) async {
    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        final contacts = data['trustedContacts'] as List<dynamic>? ?? [];
        return contacts.isNotEmpty;
      }
      return false;
    } catch (e) {
      print('Error checking trusted contacts: $e');
      return false;
    }
  }

  // Get trusted contacts
  static Future<List<Map<String, dynamic>>> getTrustedContacts(String userId) async {
    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        final contacts = data['trustedContacts'] as List<dynamic>? ?? [];
        return contacts.cast<Map<String, dynamic>>();
      }
      return [];
    } catch (e) {
      print('Error getting trusted contacts: $e');
      return [];
    }
  }

  // Add trusted contact
  static Future<void> addTrustedContact(String userId, String email, String name) async {
    try {
      final contact = {
        'email': email,
        'name': name,
        'addedAt': FieldValue.serverTimestamp(),
      };

      await _firestore.collection('users').doc(userId).update({
        'trustedContacts': FieldValue.arrayUnion([contact]),
      });
    } catch (e) {
      print('Error adding trusted contact: $e');
      rethrow;
    }
  }

  // Remove trusted contact
  static Future<void> removeTrustedContact(String userId, Map<String, dynamic> contact) async {
    try {
      await _firestore.collection('users').doc(userId).update({
        'trustedContacts': FieldValue.arrayRemove([contact]),
      });
    } catch (e) {
      print('Error removing trusted contact: $e');
      rethrow;
    }
  }

  // Send emergency alert
  static Future<void> sendEmergencyAlert({
    required String userId,
    required String userName,
    required String userEmail,
    required Map<String, dynamic> location,
    Map<String, dynamic>? rideDetails,
    String message = 'EMERGENCY ALERT: User activated panic button',
  }) async {
    try {
      // Create alert data
      final alertData = {
        'userId': userId,
        'userName': userName,
        'userEmail': userEmail,
        'timestamp': FieldValue.serverTimestamp(),
        'location': location,
        'rideDetails': rideDetails,
        'message': message,
        'status': 'active',
      };

      // Save to alerts collection
      await _firestore.collection('alerts').add(alertData);

      // Send to trusted contacts
      await _sendToTrustedContacts(userId, alertData);
    } catch (e) {
      print('Error sending emergency alert: $e');
      rethrow;
    }
  }

  // Send alert to trusted contacts
  static Future<void> _sendToTrustedContacts(String userId, Map<String, dynamic> alertData) async {
    try {
      final contacts = await getTrustedContacts(userId);
      
      for (final contact in contacts) {
        final contactEmail = contact['email']?.toString();
        if (contactEmail != null) {
          // Create notification for trusted contact
          await _firestore.collection('notifications').add({
            'userId': contactEmail, // Using email as identifier
            'title': 'EMERGENCY ALERT',
            'body': '${alertData['userName']} has activated emergency panic alert!',
            'type': 'emergency',
            'alertData': alertData,
            'timestamp': FieldValue.serverTimestamp(),
            'isRead': false,
          });
        }
      }
    } catch (e) {
      print('Error sending to trusted contacts: $e');
    }
  }

  // Get current ride details
  static Future<Map<String, dynamic>?> getCurrentRide(String userId) async {
    try {
      final ridesQuery = await _firestore
          .collection('rides')
          .where('userId', isEqualTo: userId)
          .where('status', whereIn: [1, 2]) // Active or in progress
          .orderBy('timestamp', descending: true)
          .limit(1)
          .get();

      if (ridesQuery.docs.isNotEmpty) {
        return ridesQuery.docs.first.data();
      }
      return null;
    } catch (e) {
      print('Error getting current ride: $e');
      return null;
    }
  }

  // Mark alert as resolved
  static Future<void> resolveAlert(String alertId) async {
    try {
      await _firestore.collection('alerts').doc(alertId).update({
        'status': 'resolved',
        'resolvedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error resolving alert: $e');
      rethrow;
    }
  }

  // Get active alerts for a user
  static Stream<QuerySnapshot> getActiveAlerts(String userId) {
    return _firestore
        .collection('alerts')
        .where('userId', isEqualTo: userId)
        .where('status', isEqualTo: 'active')
        .orderBy('timestamp', descending: true)
        .snapshots();
  }

  // Get all alerts for a user
  static Stream<QuerySnapshot> getAllAlerts(String userId) {
    return _firestore
        .collection('alerts')
        .where('userId', isEqualTo: userId)
        .orderBy('timestamp', descending: true)
        .snapshots();
  }
} 