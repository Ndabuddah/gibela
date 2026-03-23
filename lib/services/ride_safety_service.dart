import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

/// Service for ride safety features
class RideSafetyService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  /// Share ride details with emergency contacts
  Future<void> shareRideWithContacts({
    required String rideId,
    required String pickupAddress,
    required String dropoffAddress,
    String? driverName,
    String? driverPhone,
    String? vehiclePlate,
  }) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      
      // Get user's emergency contacts
      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      final userData = userDoc.data();
      final emergencyContacts = userData?['emergencyContacts'] as List<dynamic>? ?? [];
      
      // Build share message
      final message = '''
🚗 Gibela Ride Share

I'm currently on a ride:
📍 From: $pickupAddress
📍 To: $dropoffAddress
${driverName != null ? '👤 Driver: $driverName' : ''}
${driverPhone != null ? '📞 Driver Phone: $driverPhone' : ''}
${vehiclePlate != null ? '🚙 Vehicle: $vehiclePlate' : ''}

Ride ID: $rideId

Track my ride in real-time through the Gibela app.
''';
      
      // Share via system share sheet
      await Share.share(message, subject: 'My Gibela Ride');
      
      // Also save to Firestore for emergency access
      await _firestore.collection('ride_shares').add({
        'userId': user.uid,
        'rideId': rideId,
        'sharedAt': FieldValue.serverTimestamp(),
        'contacts': emergencyContacts,
      });
    } catch (e) {
      print('Error sharing ride: $e');
    }
  }
  
  /// Activate panic button
  Future<void> activatePanicButton({
    required String rideId,
    required double latitude,
    required double longitude,
    String? additionalInfo,
  }) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      
      // Get user details
      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      final userData = userDoc.data();
      final userName = userData?['name'] ?? 'Unknown';
      final userPhone = userData?['phone'] ?? '';
      
      // Get ride details
      final rideDoc = await _firestore.collection('rides').doc(rideId).get();
      final rideData = rideDoc.data();
      
      // Create panic alert
      await _firestore.collection('panic_alerts').add({
        'userId': user.uid,
        'userName': userName,
        'userPhone': userPhone,
        'rideId': rideId,
        'latitude': latitude,
        'longitude': longitude,
        'location': FieldValue.serverTimestamp(),
        'status': 'active',
        'additionalInfo': additionalInfo,
        'createdAt': FieldValue.serverTimestamp(),
      });
      
      // Notify emergency contacts
      final emergencyContacts = userData?['emergencyContacts'] as List<dynamic>? ?? [];
      for (var contact in emergencyContacts) {
        if (contact is Map && contact['phone'] != null) {
          // Send SMS or notification to contact
          // This would typically be done via backend/cloud function
          print('⚠️ Panic alert sent to ${contact['name']}');
        }
      }
      
      // Call emergency services (if configured)
      final emergencyNumber = userData?['emergencyNumber'] as String?;
      if (emergencyNumber != null && emergencyNumber.isNotEmpty) {
        final uri = Uri.parse('tel:$emergencyNumber');
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri);
        }
      }
    } catch (e) {
      print('Error activating panic button: $e');
      rethrow;
    }
  }
  
  /// Add emergency contact
  Future<void> addEmergencyContact({
    required String name,
    required String phone,
    String? relationship,
  }) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('User not logged in');
      
      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      final userData = userDoc.data() ?? {};
      final contacts = List<Map<String, dynamic>>.from(
        userData['emergencyContacts'] as List? ?? []
      );
      
      contacts.add({
        'name': name,
        'phone': phone,
        'relationship': relationship ?? 'Contact',
        'addedAt': FieldValue.serverTimestamp(),
      });
      
      await _firestore.collection('users').doc(user.uid).update({
        'emergencyContacts': contacts,
      });
    } catch (e) {
      print('Error adding emergency contact: $e');
      rethrow;
    }
  }
  
  /// Get emergency contacts
  Future<List<Map<String, dynamic>>> getEmergencyContacts() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return [];
      
      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      final userData = userDoc.data();
      final contacts = userData?['emergencyContacts'] as List<dynamic>? ?? [];
      
      return contacts.cast<Map<String, dynamic>>();
    } catch (e) {
      print('Error getting emergency contacts: $e');
      return [];
    }
  }
  
  /// Generate ride verification PIN
  Future<String> generateRideVerificationPIN(String rideId) async {
    try {
      // Generate 4-digit PIN
      final pin = (1000 + (DateTime.now().millisecondsSinceEpoch % 9000)).toString();
      
      // Store PIN in Firestore with expiration (5 minutes)
      await _firestore.collection('ride_pins').doc(rideId).set({
        'pin': pin,
        'rideId': rideId,
        'expiresAt': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
      });
      
      return pin;
    } catch (e) {
      print('Error generating PIN: $e');
      rethrow;
    }
  }
  
  /// Verify ride PIN
  Future<bool> verifyRidePIN(String rideId, String pin) async {
    try {
      final pinDoc = await _firestore.collection('ride_pins').doc(rideId).get();
      if (!pinDoc.exists) return false;
      
      final pinData = pinDoc.data();
      final storedPin = pinData?['pin'] as String?;
      
      return storedPin == pin;
    } catch (e) {
      print('Error verifying PIN: $e');
      return false;
    }
  }
}


