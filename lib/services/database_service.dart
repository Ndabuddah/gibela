import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../models/chat_model.dart';
import '../models/driver_model.dart';
import '../models/notification_model.dart';
import '../models/ride_model.dart';
import '../models/user_model.dart';
import 'notification_service.dart';

class DatabaseService extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // --- CHAT & MESSAGING ---
  Future<String> getOrCreateChat(String userId) async {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    if (currentUserId == null) throw Exception('Not logged in');
    
    // Validate input parameters
    if (userId.isEmpty) {
      throw Exception('User ID cannot be empty');
    }
    
    final chatQuery = await _firestore.collection('chats').where('participants', arrayContains: currentUserId).get();
    for (final doc in chatQuery.docs) {
      final participants = List<String>.from(doc['participants'] ?? []);
      if (participants.contains(userId) && participants.length == 2) {
        return doc.id;
      }
    }
    final chatDoc = await _firestore.collection('chats').add({
      'participants': [currentUserId, userId],
      'lastMessage': '',
      'lastMessageSenderId': '',
      'lastMessageTime': FieldValue.serverTimestamp(),
      'unread': {currentUserId: 0, userId: 0},
    });
    return chatDoc.id;
  }

  Future<void> sendMessage(String chatId, String senderId, String text) async {
    final now = DateTime.now();
    final chatRef = _firestore.collection('chats').doc(chatId);
    final chatDoc = await chatRef.get();
    if (!chatDoc.exists) throw Exception('Chat does not exist');
    final participants = List<String>.from(chatDoc['participants'] ?? []);
    
    // Validate participants
    if (participants.isEmpty) {
      throw Exception('Chat has no participants');
    }
    
    final unreadMap = Map<String, dynamic>.from(chatDoc['unread'] ?? {});
    
    // Ensure all participants have unread counts initialized
    for (final uid in participants) {
      if (uid.isNotEmpty && !unreadMap.containsKey(uid)) {
        unreadMap[uid] = 0;
      }
    }
    
    // Update unread counts for non-sender participants
    for (final uid in participants) {
      if (uid.isNotEmpty && uid != senderId) {
        unreadMap[uid] = (unreadMap[uid] ?? 0) + 1;
      }
    }
    
    await chatRef.collection('messages').add({
      'senderId': senderId,
      'text': text,
      'timestamp': now,
      'isRead': false,
    });
    await chatRef.update({
      'lastMessage': text,
      'lastMessageSenderId': senderId,
      'lastMessageTime': now,
      'unread': unreadMap,
    });
  }

  // Create or get chat between driver and passenger
  Future<String> createOrGetChat(String driverId, String passengerId) async {
    // Validate input parameters
    if (driverId.isEmpty || passengerId.isEmpty) {
      print('❌ Chat creation failed: Empty user IDs detected');
      print('   Driver ID: "$driverId" (length: ${driverId.length})');
      print('   Passenger ID: "$passengerId" (length: ${passengerId.length})');
      throw Exception('Driver ID and Passenger ID cannot be empty');
    }
    
    print('✅ Creating chat between driver: $driverId and passenger: $passengerId');
    
    // Sort IDs to ensure consistent chat ID
    final participants = [driverId, passengerId]..sort();
    final chatId = participants.join('_');
    
    // Check if chat already exists
    final chatDoc = await _firestore.collection('chats').doc(chatId).get();
    
    if (!chatDoc.exists) {
      print('📝 Creating new chat document with ID: $chatId');
      // Create new chat
      await _firestore.collection('chats').doc(chatId).set({
        'participants': participants,
        'createdAt': FieldValue.serverTimestamp(),
        'lastMessage': '',
        'lastMessageTime': FieldValue.serverTimestamp(),
        'lastMessageSenderId': '',
        'unread': {
          driverId: 0,
          passengerId: 0,
        },
      });
      print('✅ Chat document created successfully');
    } else {
      print('📝 Chat document already exists with ID: $chatId');
    }
    
    return chatId;
  }

  Stream<List<ChatModel>> getChats() {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    if (currentUserId == null) return const Stream.empty();
    return _firestore.collection('chats').where('participants', arrayContains: currentUserId).orderBy('lastMessageTime', descending: true).snapshots().map((snapshot) => snapshot.docs.map((doc) => ChatModel.fromDocument(doc, currentUserId)).toList());
  }

  Future<void> markMessagesAsRead(String chatId, String userId) async {
    final chatRef = _firestore.collection('chats').doc(chatId);
    final unreadUpdate = {'unread.$userId': 0};
    await chatRef.update(unreadUpdate);
    final messages = await chatRef.collection('messages').where('isRead', isEqualTo: false).where('senderId', isNotEqualTo: userId).get();
    for (final doc in messages.docs) {
      await doc.reference.update({'isRead': true});
    }
  }

  /// Stream the unread count for a chat between two users (passenger and driver)
  Stream<int> getUnreadCountForChat({required String passengerId, required String driverId}) {
    // Create a unique chat ID that's the same regardless of the order of participants
    final participants = [passengerId, driverId]..sort();
    final chatId = participants.join('_');
    
    return _firestore
        .collection('chats')
        .doc(chatId)
        .snapshots()
        .map((doc) {
          if (!doc.exists) return 0;
          final unread = doc.data()?['unread']?[passengerId];
          return unread is int ? unread : 0;
        });
  }

  // Collections
  CollectionReference get _usersCollection => _firestore.collection('users');
  CollectionReference get _driversCollection => _firestore.collection('drivers');
  CollectionReference get _ridesCollection => _firestore.collection('rides');
  CollectionReference get _requestsCollection => _firestore.collection('requests');
  CollectionReference get _scheduledRequestsCollection => _firestore.collection('scheduled_bookings');
  CollectionReference get _notificationsCollection => _firestore.collection('notifications');

  final FirebaseAuth _auth = FirebaseAuth.instance;

// Get the current logged-in user
  Future<UserModel?> getCurrentUser() async {
    try {
      final User? firebaseUser = _auth.currentUser;
      if (firebaseUser != null) {
        final DocumentSnapshot doc = await _usersCollection.doc(firebaseUser.uid).get();
        if (doc.exists) {
          return UserModel.fromMap(doc.data() as Map<String, dynamic>);
        }
      }
      return null;
    } catch (e) {
      rethrow;
    }
  }

  Future<DriverModel?> getCurrentDriver() async {
    try {
      final User? firebaseUser = _auth.currentUser;
      if (firebaseUser != null) {
        final DocumentSnapshot doc = await _driversCollection.doc(firebaseUser.uid).get();
        if (doc.exists) {
          return DriverModel.fromMap(doc.data() as Map<String, dynamic>);
        }
      }
      return null;
    } catch (e) {
      rethrow;
    }
  }

  Stream<bool> isApprovedStream(String userId) {
    return _firestore.collection('users').doc(userId).snapshots().map((snapshot) {
      if (snapshot.exists) {
        return snapshot.data()?['isApproved'] ?? false;
      }
      return false;
    });
  }

// Update user profile with only the provided fields (partial update)
  Future<void> updateUserProfile(String uid, Map<String, dynamic> updatedData) async {
    try {
      await _usersCollection.doc(uid).update(updatedData);
    } catch (e) {
      rethrow;
    }
  }

// Sign out the user
  Future<void> signOut() async {
    try {
      await _auth.signOut();
    } catch (e) {
      rethrow;
    }
  }

  // ========== USER METHODS ==========

  // Create a new user
  Future<void> createUser(UserModel user) async {
    try {
      print('💾 DatabaseService: Starting user creation for ${user.email}');
      print('💾 DatabaseService: User UID: ${user.uid}');
      print('💾 DatabaseService: User name: ${user.name}');
      print('💾 DatabaseService: User surname: ${user.surname}');
      
      print('💾 DatabaseService: Preparing user data with driver flags');
      print('🚗 Is Driver: ${user.isDriver}');
      
      // Prepare user data with proper driver flags
      final userData = {
        'uid': user.uid,
        'email': user.email,
        'name': user.name,
        'surname': user.surname,
        'phoneNumber': user.phoneNumber,
        'isDriver': user.isDriver,
        // Force isApproved to false for drivers, true for passengers
        'isApproved': user.isDriver ? false : true,
        // Set driver-specific flags
        'requiresDriverSignup': user.isDriver ? true : false,
        'driverProfileCompleted': false,
        'driverSignupDate': user.isDriver ? null : null, // Will be set when signup is completed
        'approvalStatus': user.isDriver ? 'pending_signup' : 'not_required', // Track driver status
        'savedAddresses': user.savedAddresses,
        'recentRides': user.recentRides,
        'isOnline': user.isOnline,
        'rating': user.rating,
        'missingProfileFields': user.isDriver ? ['Driver Profile'] : user.missingProfileFields,
        'referrals': user.referrals,
        'referralAmount': user.referralAmount,
        'lastReferral': user.lastReferral?.toIso8601String(),
        'isGirl': user.isGirl ?? false,
        'isStudent': user.isStudent ?? false,
        'profileImage': user.profileImage,
        'photoUrl': user.photoUrl,
      };
      
      print('💾 DatabaseService: User data prepared, saving to Firestore...');
      print('🚗 DatabaseService: Driver flags:');
      print('   - isDriver: ${userData['isDriver']}');
      print('   - isApproved: ${userData['isApproved']}');
      print('   - requiresDriverSignup: ${userData['requiresDriverSignup']}');
      print('   - driverProfileCompleted: ${userData['driverProfileCompleted']}');
      await _usersCollection.doc(user.uid).set(userData);
      print('✅ DatabaseService: User created successfully in Firestore');
    } catch (e) {
      print('💥 DatabaseService: Error creating user: $e');
      print('💥 DatabaseService: Error type: ${e.runtimeType}');
      print('💥 DatabaseService: Error stack trace: ${StackTrace.current}');
      rethrow;
    }
  }

  // Get user by ID
  Future<UserModel?> getUserById(String userId) async {
    try {
      final DocumentSnapshot doc = await _usersCollection.doc(userId).get();
      if (doc.exists) {
        return UserModel.fromMap(doc.data() as Map<String, dynamic>);
      }
      return null;
    } catch (e) {
      rethrow;
    }
  }

  // Update user
  Future<void> updateUser(UserModel user) async {
    try {
      await _usersCollection.doc(user.uid).update(user.toMap());
    } catch (e) {
      rethrow;
    }
  }

  // ========== DRIVER METHODS ==========

  // Create a driver profile
  Future<void> createDriverProfile(DriverModel driver) async {
    try {
      print('🚗 Creating driver profile for: ${driver.name}');
      
      // Verify that the user exists and is marked as a driver
      final userDoc = await _usersCollection.doc(driver.userId).get();
      if (!userDoc.exists) {
        throw Exception('User does not exist');
      }

      final userData = userDoc.data() as Map<String, dynamic>;
      if (!userData['isDriver']) {
        throw Exception('User is not registered as a driver');
      }

      // Create or update the driver profile document
      await _driversCollection.doc(driver.userId).set(driver.toMap());

      // Calculate missing fields more accurately
      final missingFields = <String>[];
      
      // Check personal information
      if (driver.name.isEmpty) missingFields.add('Full Name');
      if (driver.phoneNumber.isEmpty) missingFields.add('Phone Number');
      if (driver.idNumber.isEmpty) missingFields.add('ID Number');
      
      // Check vehicle information
      if (driver.vehicleModel == null || driver.vehicleModel!.isEmpty) missingFields.add('Vehicle Model');
      if (driver.licensePlate == null || driver.licensePlate!.isEmpty) missingFields.add('License Plate');
      if (driver.vehicleType == null || driver.vehicleType!.isEmpty) missingFields.add('Vehicle Type');
      if (driver.vehicleColor == null || driver.vehicleColor!.isEmpty) missingFields.add('Vehicle Color');
      
      // Check location information
      if (driver.towns.isEmpty) missingFields.add('Service Areas');
      
      // Check documents
      if (driver.documents.isEmpty) {
        missingFields.add('Required Documents');
      } else {
        // Check for specific required documents
        final requiredDocs = [
          'ID Document',
          'Professional Driving Permit',
          'Roadworthy Certificate',
          'Vehicle Image',
          'Driver Profile Image',
          'Driver Image Next to Vehicle',
          'Bank Statement'
        ];
        
        final missingDocs = requiredDocs.where((doc) => !driver.documents.containsKey(doc)).toList();
        if (missingDocs.isNotEmpty) {
          missingFields.add('Required Documents');
        }
      }

      print('📝 Updating user document with completed driver profile');
      
      // Get profile image URL from documents
      String? profileImageUrl = driver.documents['Driver Profile Image'];
      
      // Update user document with comprehensive driver information
      final userUpdates = {
        'uid': driver.userId,
        'email': driver.email,
        'name': driver.name,
        'surname': '', // Default empty surname
        'phoneNumber': driver.phoneNumber,
        'isDriver': true,
        'isApproved': false, // Always false until manually approved
        'requiresDriverSignup': false, // Mark driver signup as completed
        'driverProfileCompleted': missingFields.isEmpty, // Only true if no missing fields
        'driverSignupDate': FieldValue.serverTimestamp(),
        'approvalStatus': 'awaiting_approval', // Update status to awaiting approval
        'savedAddresses': [],
        'recentRides': [],
        'isOnline': false,
        'IsFemale': driver.isFemale ?? false,
        'IsForStudents': driver.isForStudents ?? false,
        'missingProfileFields': missingFields,
        'profileImage': profileImageUrl, // Save profile image URL
        'lastUpdated': FieldValue.serverTimestamp(),
        // Add payment-related flags
        'payLater': driver.payLater,
        'paymentModel': driver.paymentModel.index,
        'isPaid': driver.isPaid,
        'lastPaymentModelChange': driver.lastPaymentModelChange?.toIso8601String(),
      };
      
      await _usersCollection.doc(driver.userId).set(userUpdates, SetOptions(merge: true));
      
      print('✅ Driver profile created successfully');
      print('- Driver ID: ${driver.userId}');
      print('- Name: ${driver.name}');
      print('- Pay Later: ${driver.payLater}');
      print('- Documents: ${driver.documents.length}');
      print('- Missing Fields: ${missingFields.length}');
      print('- Profile Image: ${profileImageUrl != null ? 'Set' : 'Not set'}');
      
    } catch (e) {
      print('❌ Error creating driver profile: $e');
      rethrow;
    }
  }

  // Get driver by user ID
  Future<DriverModel?> getDriverByUserId(String userId) async {
    try {
      final DocumentSnapshot doc = await _driversCollection.doc(userId).get();
      if (doc.exists) {
        return DriverModel.fromMap(doc.data() as Map<String, dynamic>);
      }
      return null;
    } catch (e) {
      rethrow;
    }
  }

  // Update driver
  Future<void> updateDriver(DriverModel driver) async {
    try {
      await _driversCollection.doc(driver.userId).update(driver.toMap());
    } catch (e) {
      rethrow;
    }
  }

  // Update driver status
  Future<void> updateDriverStatus(String driverId, DriverStatus status) async {
    try {
      await _driversCollection.doc(driverId).update({
        'status': status.index,
      });
    } catch (e) {
      rethrow;
    }
  }

  // Update driver payment model
  Future<void> updateDriverPaymentModel(String driverId, PaymentModel paymentModel) async {
    try {
      await _driversCollection.doc(driverId).update({
        'paymentModel': paymentModel.index,
      });
    } catch (e) {
      rethrow;
    }
  }

  // Reset driver's isPaid flag when new earnings are added
  Future<void> resetDriverPaymentStatus(String driverId) async {
    try {
      await _driversCollection.doc(driverId).update({
        'isPaid': false,
      });
    } catch (e) {
      rethrow;
    }
  }

  // Get available drivers
  Future<List<DriverModel>> getAvailableDrivers() async {
    try {
      final QuerySnapshot snapshot = await _driversCollection.where('status', isEqualTo: DriverStatus.online.index).where('isApproved', isEqualTo: true).get();

      return snapshot.docs.map((doc) => DriverModel.fromMap(doc.data() as Map<String, dynamic>)).toList();
    } catch (e) {
      rethrow;
    }
  }

  // ========== RIDE METHODS ==========

  // Check if passenger has an active request
  Future<bool> hasActiveRequest(String passengerId) async {
    try {
      final QuerySnapshot snapshot = await _requestsCollection
          .where('userId', isEqualTo: passengerId)
          .where('status', isEqualTo: 'pending')
          .get();
      
      return snapshot.docs.isNotEmpty;
    } catch (e) {
      print('Error checking active request: $e');
      return false;
    }
  }

  // Cancel all pending requests for a passenger
  Future<void> cancelAllPendingRequests(String passengerId, {String? reason}) async {
    try {
      final QuerySnapshot snapshot = await _requestsCollection
          .where('userId', isEqualTo: passengerId)
          .where('status', isEqualTo: 'pending')
          .get();
      
      final batch = _firestore.batch();
      for (final doc in snapshot.docs) {
        batch.update(doc.reference, {
          'status': 'cancelled',
          'cancelledAt': FieldValue.serverTimestamp(),
          'cancellationReason': reason ?? 'Passenger cancelled',
        });
      }
      
      await batch.commit();
      print('✅ Cancelled ${snapshot.docs.length} pending requests for passenger: $passengerId');
    } catch (e) {
      print('Error cancelling pending requests: $e');
      rethrow;
    }
  }

  // Clean up abandoned requests (requests older than 30 minutes)
  Future<void> cleanupAbandonedRequests() async {
    try {
      final thirtyMinutesAgo = DateTime.now().subtract(const Duration(minutes: 30));
      
      final QuerySnapshot snapshot = await _requestsCollection
          .where('status', isEqualTo: 'pending')
          .where('createdAt', isLessThan: Timestamp.fromDate(thirtyMinutesAgo))
          .get();
      
      if (snapshot.docs.isNotEmpty) {
        final batch = _firestore.batch();
        for (final doc in snapshot.docs) {
          batch.update(doc.reference, {
            'status': 'cancelled',
            'cancelledAt': FieldValue.serverTimestamp(),
            'cancellationReason': 'Request abandoned (timeout)',
          });
        }
        
        await batch.commit();
        print('✅ Cleaned up ${snapshot.docs.length} abandoned requests');
      }
    } catch (e) {
      print('Error cleaning up abandoned requests: $e');
    }
  }

  // Create a new ride request
  Future<String> createRideRequest(RideModel ride) async {
    try {
      // Convert RideModel to requests collection format
      final Map<String, dynamic> requestData = {
        'userId': ride.passengerId, // Use userId instead of passengerId
        'pickupAddress': ride.pickupAddress,
        'pickupCoordinates': [ride.pickupLat, ride.pickupLng], // Use coordinates array
        'dropoffAddress': ride.dropoffAddress,
        'dropoffCoordinates': [ride.dropoffLat, ride.dropoffLng], // Use coordinates array
        'vehicleType': ride.vehicleType,
        'distance': ride.distance,
        'estimatedFare': ride.estimatedFare,
        'basePrice': ride.estimatedFare, // Add basePrice field
        'isPeak': ride.isPeak,
        'isNight': false, // Add isNight field
        'vehiclePrice': ride.vehiclePrice?.toString(),
        'paymentType': 'Cash', // Default payment type
        'paymentStatus': 'pending', // Default payment status
        'status': 'pending', // Use string status
        'createdAt': FieldValue.serverTimestamp(), // Use createdAt instead of requestTime
        'below2': ride.passengerCount <= 2, // Add below2 field
        'passengerCount': ride.passengerCount,
        'isAsambeGirl': ride.isAsambeGirl,
        'isAsambeStudent': ride.isAsambeStudent,
        'isAsambeLuxury': ride.isAsambeLuxury,
      };
      
      final DocumentReference docRef = await _requestsCollection.add(requestData);
      return docRef.id;
    } catch (e) {
      rethrow;
    }
  }

  // Get ride by ID (checks both requests and rides collections)
  Future<RideModel?> getRideById(String rideId) async {
    try {
      // First check in requests collection
      DocumentSnapshot doc = await _requestsCollection.doc(rideId).get();
      if (doc.exists) {
        return RideModel.fromMap(doc.data() as Map<String, dynamic>, doc.id);
      }
      
      // If not found in requests, check in rides collection
      doc = await _ridesCollection.doc(rideId).get();
      if (doc.exists) {
        return RideModel.fromMap(doc.data() as Map<String, dynamic>, doc.id);
      }
      
      return null;
    } catch (e) {
      rethrow;
    }
  }

  // Update ride (updates in the appropriate collection)
  Future<void> updateRide(RideModel ride) async {
    try {
      // First check if it exists in requests collection
      final requestDoc = await _requestsCollection.doc(ride.id).get();
      if (requestDoc.exists) {
        // Convert to requests collection format for updates
        final Map<String, dynamic> updateData = {
          'userId': ride.passengerId,
          'pickupAddress': ride.pickupAddress,
          'pickupCoordinates': [ride.pickupLat, ride.pickupLng],
          'dropoffAddress': ride.dropoffAddress,
          'dropoffCoordinates': [ride.dropoffLat, ride.dropoffLng],
          'vehicleType': ride.vehicleType,
          'distance': ride.distance,
          'estimatedFare': ride.estimatedFare,
          'driverId': ride.driverId,
          'status': _convertStatusToString(ride.status), // Convert status to string
          'updatedAt': FieldValue.serverTimestamp(),
        };
        await _requestsCollection.doc(ride.id).update(updateData);
      } else {
        // If not in requests, update in rides collection
        await _ridesCollection.doc(ride.id).update(ride.toMap());
      }
    } catch (e) {
      rethrow;
    }
  }

  // Helper method to convert RideStatus enum to string
  String _convertStatusToString(RideStatus status) {
    switch (status) {
      case RideStatus.requested:
        return 'pending';
      case RideStatus.accepted:
        return 'accepted';
      case RideStatus.driverArrived:
        return 'driver_arrived';
      case RideStatus.inProgress:
        return 'in_progress';
      case RideStatus.completed:
        return 'completed';
      case RideStatus.cancelled:
        return 'cancelled';
    }
  }

  // ========== SCHEDULED REQUEST METHODS ==========

  // Create a new scheduled request
  Future<String> createScheduledRequest(Map<String, dynamic> requestData) async {
    try {
      final DocumentReference docRef = await _scheduledRequestsCollection.add(requestData);
      return docRef.id;
    } catch (e) {
      rethrow;
    }
  }

  // Get scheduled requests for drivers based on their preferred towns
  Stream<List<Map<String, dynamic>>> getScheduledRequestsForDriver(
    List<String> driverPreferredTowns,
    Position driverLocation,
  ) {
    return _scheduledRequestsCollection
        .where('status', isEqualTo: 'pending')
        .orderBy('scheduledDateTime', descending: false)
        .snapshots()
        .handleError((error) {
          // Handle index building error gracefully
          print('⚠️ Firestore index still building for scheduledRequests. Using fallback query.');
          // Return empty list while index is building
          return const Stream.empty();
        })
        .map((snapshot) {
      final List<Map<String, dynamic>> filteredRequests = [];
      
      for (final doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final pickupAddress = data['pickupAddress'] as String? ?? '';
        
        // Check if pickup address contains any of driver's preferred towns
        final bool matchesPreferredTown = driverPreferredTowns.any((town) =>
            pickupAddress.toLowerCase().contains(town.toLowerCase()));
        
        if (matchesPreferredTown) {
          // Calculate distance for progressive expansion
          final pickupCoordinates = data['pickupCoordinates'] as List?;
          if (pickupCoordinates != null && pickupCoordinates.length >= 2) {
            final distance = _calculateDistance(
              driverLocation.latitude,
              driverLocation.longitude,
              pickupCoordinates[0].toDouble(),
              pickupCoordinates[1].toDouble(),
            );
            
            final scheduledDateTime = (data['scheduledDateTime'] as Timestamp).toDate();
            final now = DateTime.now();
            final timeUntilScheduled = scheduledDateTime.difference(now).inMinutes;
            
            // Progressive distance expansion based on time
            double maxDistance;
            if (timeUntilScheduled > 10) {
              maxDistance = 1.0; // Start with 1km
            } else if (timeUntilScheduled > 5) {
              maxDistance = 5.0; // Expand to 5km after 10 minutes
            } else {
              maxDistance = 10.0; // Expand to 10km after 5 minutes
            }
            
            if (distance <= maxDistance) {
              data['id'] = doc.id;
              data['distance'] = distance;
              data['timeUntilScheduled'] = timeUntilScheduled;
              filteredRequests.add(data);
            }
          }
        }
      }
      
      // Sort by distance and time until scheduled
      filteredRequests.sort((a, b) {
        final distanceA = a['distance'] as double;
        final distanceB = b['distance'] as double;
        final timeA = a['timeUntilScheduled'] as int;
        final timeB = b['timeUntilScheduled'] as int;
        
        // Prioritize by distance first, then by urgency
        final distanceComparison = distanceA.compareTo(distanceB);
        if (distanceComparison != 0) return distanceComparison;
        return timeA.compareTo(timeB);
      });
      
      return filteredRequests;
    });
  }

  // Accept a scheduled request
  Future<void> acceptScheduledRequest(String requestId, String driverId) async {
    try {
      // Get the scheduled request to get passenger ID
      final requestDoc = await _scheduledRequestsCollection.doc(requestId).get();
      if (!requestDoc.exists) {
        throw Exception('Scheduled request not found');
      }
      
      final requestData = requestDoc.data() as Map<String, dynamic>;
      final passengerId = requestData['userId'] as String?;
      final scheduledDateTime = (requestData['scheduledDateTime'] as Timestamp).toDate();
      final paymentType = requestData['paymentType'] as String? ?? 'Cash';
      final estimatedFare = requestData['estimatedFare'] as double? ?? 0.0;
      final status = requestData['status'] as String? ?? 'pending';
      
      if (passengerId == null) {
        throw Exception('Passenger ID not found in scheduled request');
      }
      
      // Check if request is still available
      if (status != 'pending') {
        throw Exception('Scheduled request is no longer available for acceptance');
      }
      
      // Check if driver is already assigned
      if (requestData['driverId'] != null) {
        throw Exception('Scheduled request has already been accepted by another driver');
      }
      
      // Check daily limit (3 bookings per day)
      final today = DateTime.now();
      final startOfDay = DateTime(today.year, today.month, today.day);
      final endOfDay = startOfDay.add(const Duration(days: 1));
      
      final todayBookings = await _scheduledRequestsCollection
          .where('driverId', isEqualTo: driverId)
          .where('status', isEqualTo: 'accepted')
          .where('scheduledDateTime', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
          .where('scheduledDateTime', isLessThan: Timestamp.fromDate(endOfDay))
          .get();
      
      if (todayBookings.docs.length >= 3) {
        throw Exception('You have already accepted 3 scheduled bookings for today. Please try again tomorrow.');
      }
      
      // Check for time conflicts (30-minute buffer)
      final conflictStart = scheduledDateTime.subtract(const Duration(minutes: 30));
      final conflictEnd = scheduledDateTime.add(const Duration(minutes: 30));
      
      final conflictingBookings = await _scheduledRequestsCollection
          .where('driverId', isEqualTo: driverId)
          .where('status', isEqualTo: 'accepted')
          .where('scheduledDateTime', isGreaterThanOrEqualTo: Timestamp.fromDate(conflictStart))
          .where('scheduledDateTime', isLessThanOrEqualTo: Timestamp.fromDate(conflictEnd))
          .get();
      
      if (conflictingBookings.docs.isNotEmpty) {
        throw Exception('You have a conflicting scheduled booking within 30 minutes of this time. Please choose a different time slot.');
      }
      
      // Check if driver is available (not on another ride)
      final driverActiveRide = await getActiveRideForDriver(driverId);
      if (driverActiveRide != null) {
        throw Exception('You are already on an active ride. Please complete it first.');
      }
      
      // Update the scheduled request
      await _scheduledRequestsCollection.doc(requestId).update({
        'driverId': driverId,
        'status': 'accepted',
        'acceptedAt': FieldValue.serverTimestamp(),
      });
      
      // Create chat between driver and passenger
      await createOrGetChat(driverId, passengerId);
      
      // Send notification to passenger
      final notificationRef = _notificationsCollection.doc();
      final notification = NotificationModel(
        id: notificationRef.id,
        userId: passengerId,
        title: 'Scheduled Ride Accepted',
        body: 'Your scheduled ride has been accepted by a driver!',
        timestamp: Timestamp.fromDate(DateTime.now()),
        isRead: false,
        category: NotificationCategory.ride,
        priority: NotificationPriority.high,
      );
      await notificationRef.set(notification.toMap());
      
      print('✅ Scheduled request accepted successfully: $requestId by driver: $driverId');
      
    } catch (e) {
      print('❌ Error accepting scheduled request: $e');
      rethrow;
    }
  }

  // Get scheduled request by ID
  Future<Map<String, dynamic>?> getScheduledRequestById(String requestId) async {
    try {
      final doc = await _scheduledRequestsCollection.doc(requestId).get();
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
        return data;
      }
      return null;
    } catch (e) {
      rethrow;
    }
  }

  // Get driver's accepted scheduled requests
  Stream<List<Map<String, dynamic>>> getDriverAcceptedScheduledRequests(String driverId) {
    return _scheduledRequestsCollection
        .where('driverId', isEqualTo: driverId)
        .where('status', isEqualTo: 'accepted')
        .orderBy('scheduledDateTime', descending: false)
        .snapshots()
        .map((snapshot) {
      final List<Map<String, dynamic>> acceptedRequests = [];
      
      for (final doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
        
        // Calculate time until scheduled
        final scheduledDateTime = (data['scheduledDateTime'] as Timestamp).toDate();
        final now = DateTime.now();
        final timeUntilScheduled = scheduledDateTime.difference(now).inMinutes;
        data['timeUntilScheduled'] = timeUntilScheduled;
        
        acceptedRequests.add(data);
      }
      
      return acceptedRequests;
    });
  }

  // Complete a scheduled booking and track earnings
  Future<void> completeScheduledBooking(String requestId, double actualFare) async {
    try {
      final requestDoc = await _scheduledRequestsCollection.doc(requestId).get();
      if (!requestDoc.exists) {
        throw Exception('Scheduled request not found');
      }
      
      final requestData = requestDoc.data() as Map<String, dynamic>;
      final driverId = requestData['driverId'] as String?;
      final passengerId = requestData['userId'] as String?;
      final paymentType = requestData['paymentType'] as String? ?? 'Cash';
      final estimatedFare = requestData['estimatedFare'] as double? ?? 0.0;
      final status = requestData['status'] as String? ?? 'pending';
      
      if (driverId == null || passengerId == null) {
        throw Exception('Driver or passenger ID not found');
      }
      
      // Check if booking is in progress
      if (status != 'in_progress') {
        throw Exception('Scheduled booking is not in progress. Current status: $status');
      }
      
      final now = DateTime.now();
      
      // Update scheduled request status
      await _scheduledRequestsCollection.doc(requestId).update({
        'status': 'completed',
        'actualFare': actualFare,
        'completedAt': FieldValue.serverTimestamp(),
        'dropoffTime': FieldValue.serverTimestamp(),
      });
      
      // Track earnings based on payment type
      await _trackScheduledBookingEarnings(
        driverId: driverId,
        requestId: requestId,
        actualFare: actualFare,
        paymentType: paymentType,
        isScheduledBooking: true,
      );
      
      // Update driver status to available
      await updateDriverStatus(driverId, DriverStatus.online);
      
      // Handle payment based on payment type
      if (paymentType.toLowerCase() == 'card') {
        // For card payments, payment was already processed
        print('✅ Card payment already processed for scheduled booking');
      } else {
        // For cash payments, update passenger's owing amount if there's a difference
        if (actualFare > estimatedFare) {
          final difference = actualFare - estimatedFare;
          await updateUserOwing(passengerId, difference);
        }
      }
      
      // Create notification for passenger
      final notificationRef = _notificationsCollection.doc();
      final notification = NotificationModel(
        id: notificationRef.id,
        userId: passengerId,
        title: 'Scheduled Ride Completed',
        body: 'Your scheduled ride has been completed. Fare: R${actualFare.toStringAsFixed(2)}',
        timestamp: Timestamp.fromDate(now),
        isRead: false,
        category: NotificationCategory.ride,
        priority: NotificationPriority.high,
      );
      await notificationRef.set(notification.toMap());
      
      print('✅ Scheduled booking completed successfully: $requestId, Fare: R${actualFare.toStringAsFixed(2)}');
      
    } catch (e) {
      print('❌ Error completing scheduled booking: $e');
      rethrow;
    }
  }

  // Cancel a scheduled booking
  Future<void> cancelScheduledBooking(String requestId, String cancelledBy, {String? reason}) async {
    try {
      final requestDoc = await _scheduledRequestsCollection.doc(requestId).get();
      if (!requestDoc.exists) {
        throw Exception('Scheduled request not found');
      }
      
      final requestData = requestDoc.data() as Map<String, dynamic>;
      final driverId = requestData['driverId'] as String?;
      final passengerId = requestData['userId'] as String?;
      final status = requestData['status'] as String?;
      
      if (status != 'accepted') {
        throw Exception('Can only cancel accepted scheduled bookings');
      }
      
      final now = DateTime.now();
      final cancellationReason = reason ?? 'Cancelled by ${cancelledBy == driverId ? 'driver' : 'passenger'}';
      
      // Update scheduled request status
      await _scheduledRequestsCollection.doc(requestId).update({
        'status': 'cancelled',
        'cancelledBy': cancelledBy,
        'cancellationReason': cancellationReason,
        'cancelledAt': FieldValue.serverTimestamp(),
      });
      
      // Create notification for the other party
      final notificationRef = _notificationsCollection.doc();
      final notification = NotificationModel(
        id: notificationRef.id,
        userId: cancelledBy == driverId ? passengerId! : driverId!,
        title: 'Scheduled Ride Cancelled',
        body: 'Your scheduled ride has been cancelled. Reason: $cancellationReason',
        timestamp: Timestamp.fromDate(now),
        isRead: false,
        category: NotificationCategory.ride,
        priority: NotificationPriority.high,
      );
      await notificationRef.set(notification.toMap());
      
    } catch (e) {
      rethrow;
    }
  }

  // Update scheduled request status
  Future<void> updateScheduledRequestStatus(String requestId, String status) async {
    try {
      await _scheduledRequestsCollection.doc(requestId).update({
        'status': status,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error updating scheduled request status: $e');
      rethrow;
    }
  }

  // Track earnings for scheduled bookings
  Future<void> _trackScheduledBookingEarnings({
    required String driverId,
    required String requestId,
    required double actualFare,
    required String paymentType,
    required bool isScheduledBooking,
  }) async {
    try {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      
      // Get driver's earnings document
      final driverEarningsRef = _driversCollection.doc(driverId).collection('earnings').doc('daily');
      final earningsDoc = await driverEarningsRef.get();
      
      Map<String, dynamic> earningsData = {};
      if (earningsDoc.exists) {
        earningsData = earningsDoc.data() as Map<String, dynamic>;
      }
      
      // Update daily earnings
      final currentEarnings = (earningsData['totalEarnings'] ?? 0.0) as double;
      final currentRides = (earningsData['totalRides'] ?? 0) as int;
      final currentScheduledRides = (earningsData['scheduledRides'] ?? 0) as int;
      
      // Update based on payment type
      double cardEarnings = (earningsData['cardEarnings'] ?? 0.0) as double;
      double cashEarnings = (earningsData['cashEarnings'] ?? 0.0) as double;
      
      if (paymentType.toLowerCase() == 'card') {
        cardEarnings += actualFare;
      } else {
        cashEarnings += actualFare;
      }
      
      // Update earnings data
      final updatedEarningsData = {
        'date': Timestamp.fromDate(today),
        'totalEarnings': currentEarnings + actualFare,
        'totalRides': currentRides + 1,
        'scheduledRides': currentScheduledRides + (isScheduledBooking ? 1 : 0),
        'cardEarnings': cardEarnings,
        'cashEarnings': cashEarnings,
        'lastUpdated': FieldValue.serverTimestamp(),
      };
      
      await driverEarningsRef.set(updatedEarningsData, SetOptions(merge: true));
      
      // Add to ride history
      final rideHistoryRef = _driversCollection.doc(driverId).collection('rideHistory').doc(requestId);
      final rideHistoryData = {
        'requestId': requestId,
        'fare': actualFare,
        'paymentType': paymentType,
        'isScheduledBooking': isScheduledBooking,
        'completedAt': FieldValue.serverTimestamp(),
        'status': 'completed',
      };
      
      await rideHistoryRef.set(rideHistoryData, SetOptions(merge: true));
      
    } catch (e) {
      print('Error tracking scheduled booking earnings: $e');
      rethrow;
    }
  }

  // Fallback method for getting scheduled requests when index is building
  Stream<List<Map<String, dynamic>>> getScheduledRequestsForDriverFallback(
    List<String> driverPreferredTowns,
    Position driverLocation,
  ) {
    return _scheduledRequestsCollection
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .map((snapshot) {
      final List<Map<String, dynamic>> filteredRequests = [];
      
      for (final doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final pickupAddress = data['pickupAddress'] as String? ?? '';
        
        // Check if pickup address contains any of driver's preferred towns
        final bool matchesPreferredTown = driverPreferredTowns.any((town) =>
            pickupAddress.toLowerCase().contains(town.toLowerCase()));
        
        if (matchesPreferredTown) {
          // Calculate distance for progressive expansion
          final pickupCoordinates = data['pickupCoordinates'] as List?;
          if (pickupCoordinates != null && pickupCoordinates.length >= 2) {
            final distance = _calculateDistance(
              driverLocation.latitude,
              driverLocation.longitude,
              pickupCoordinates[0].toDouble(),
              pickupCoordinates[1].toDouble(),
            );
            
            final scheduledDateTime = (data['scheduledDateTime'] as Timestamp).toDate();
            final now = DateTime.now();
            final timeUntilScheduled = scheduledDateTime.difference(now).inMinutes;
            
            // Progressive distance expansion based on time
            double maxDistance;
            if (timeUntilScheduled > 10) {
              maxDistance = 1.0; // Start with 1km
            } else if (timeUntilScheduled > 5) {
              maxDistance = 5.0; // Expand to 5km after 10 minutes
            } else {
              maxDistance = 10.0; // Expand to 10km after 5 minutes
            }
            
            if (distance <= maxDistance) {
              data['id'] = doc.id;
              data['distance'] = distance;
              data['timeUntilScheduled'] = timeUntilScheduled;
              filteredRequests.add(data);
            }
          }
        }
      }
      
      // Sort by distance and time until scheduled (client-side sorting)
      filteredRequests.sort((a, b) {
        final distanceA = a['distance'] as double;
        final distanceB = b['distance'] as double;
        final timeA = a['timeUntilScheduled'] as int;
        final timeB = b['timeUntilScheduled'] as int;
        
        // Prioritize by distance first, then by urgency
        final distanceComparison = distanceA.compareTo(distanceB);
        if (distanceComparison != 0) return distanceComparison;
        return timeA.compareTo(timeB);
      });
      
      return filteredRequests;
    });
  }

  // Cancel a scheduled request
  Future<void> cancelScheduledRequest(String requestId, String userId, {String? reason, bool isDriver = false}) async {
    try {
      final batch = _firestore.batch();
      final now = DateTime.now();
      final cancellationReason = reason ?? 'Scheduled request cancelled';

      // Update the scheduled request status
      batch.update(_scheduledRequestsCollection.doc(requestId), {
        'status': 'cancelled',
        'cancelledAt': FieldValue.serverTimestamp(),
        'cancellationReason': cancellationReason,
        'cancelledBy': userId,
        'isDriverCancellation': isDriver,
      });

      // Get the request data to send notifications
      final requestDoc = await _scheduledRequestsCollection.doc(requestId).get();
      if (requestDoc.exists) {
        final requestData = requestDoc.data() as Map<String, dynamic>;
        final driverId = requestData['driverId'] as String?;
        final passengerId = requestData['userId'] as String?;

        // Send notifications
        if (isDriver && passengerId != null) {
          // Driver cancelled - notify passenger
          final notificationRef = _notificationsCollection.doc();
          final notification = NotificationModel(
            id: notificationRef.id,
            userId: passengerId,
            title: 'Scheduled Ride Cancelled',
            body: 'Your scheduled ride has been cancelled by the driver. Reason: $cancellationReason',
            timestamp: Timestamp.fromDate(now),
            isRead: false,
            category: NotificationCategory.ride,
            priority: NotificationPriority.high,
          );
          batch.set(notificationRef, notification.toMap());
        } else if (!isDriver && driverId != null) {
          // Passenger cancelled - notify driver
          final notificationRef = _notificationsCollection.doc();
          final notification = NotificationModel(
            id: notificationRef.id,
            userId: driverId,
            title: 'Scheduled Ride Cancelled',
            body: 'A scheduled ride has been cancelled by the passenger. Reason: $cancellationReason',
            timestamp: Timestamp.fromDate(now),
            isRead: false,
            category: NotificationCategory.ride,
            priority: NotificationPriority.high,
          );
          batch.set(notificationRef, notification.toMap());
        }
      }

      await batch.commit();
    } catch (e) {
      print('Error cancelling scheduled request: $e');
      rethrow;
    }
  }

  // Helper method to calculate distance
  double _calculateDistance(double lat1, double lng1, double lat2, double lng2) {
    const double earthRadius = 6371; // Earth's radius in kilometers
    
    final double dLat = (lat2 - lat1) * (3.141592653589793 / 180);
    final double dLng = (lng2 - lng1) * (3.141592653589793 / 180);
    
    final double a = sin(dLat / 2) * sin(dLat / 2) +
        cos(lat1 * 3.141592653589793 / 180) * cos(lat2 * 3.141592653589793 / 180) *
        sin(dLng / 2) * sin(dLng / 2);
    
    final double c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return earthRadius * c;
  }

  /// Cancels a ride by the driver.
  /// This updates the driver's personal ride history and resets the ride
  /// in the main collection to be available for other drivers.
  Future<void> cancelRideByDriver(String driverId, RideModel ride, {String? reason}) async {
    try {
      print('Starting cancelRideByDriver for ride: ${ride.id}'); // Debug log
      
      // Validate input parameters
      if (driverId.isEmpty) {
        throw Exception('Driver ID cannot be empty');
      }
      if (ride.id.isEmpty) {
        throw Exception('Ride ID cannot be empty');
      }
      if (ride.passengerId.isEmpty) {
        throw Exception('Passenger ID cannot be empty');
      }
      
      final WriteBatch batch = _firestore.batch();
      final now = DateTime.now();
      final cancellationReason = reason ?? 'Ride cancelled by driver';

      print('Creating batch operations...'); // Debug log

      // 1. Add to driver's personal ride history as 'cancelled'
      final driverRideHistoryRef = _driversCollection.doc(driverId).collection('rideHistory').doc(ride.id);
      final cancelledRide = ride.copyWith(
        status: RideStatus.cancelled,
        cancellationReason: cancellationReason,
        cancelledAt: now,
      );
      
      print('Adding to driver history: ${cancelledRide.toMap()}'); // Debug log
      batch.set(driverRideHistoryRef, cancelledRide.toMap(), SetOptions(merge: true));

      // 2. Reset the main ride request to be available again
      final mainRideRef = _requestsCollection.doc(ride.id);
      final mainRideUpdate = {
        'status': 'pending', // Reset to pending so it appears in request list again
        'driverId': null, // Remove driver association
        'cancelledAt': now.millisecondsSinceEpoch,
        'cancellationReason': cancellationReason,
        'updatedAt': FieldValue.serverTimestamp(),
      };
      
      print('Updating main ride: $mainRideUpdate'); // Debug log
      batch.update(mainRideRef, mainRideUpdate);

      // 3. Update the driver's status back to online
      final driverRef = _driversCollection.doc(driverId);
      final driverUpdate = {
        'status': DriverStatus.online.index,
        'updatedAt': FieldValue.serverTimestamp(),
      };
      
      print('Updating driver status: $driverUpdate'); // Debug log
      batch.update(driverRef, driverUpdate);

      // 4. Create a notification for the passenger
      final notificationRef = _notificationsCollection.doc();
      final notification = NotificationModel(
        id: notificationRef.id,
        userId: ride.passengerId,
        title: 'Ride Cancelled',
        body: 'Your driver has cancelled the ride. Looking for another driver...',
        timestamp: Timestamp.fromDate(now),
        isRead: false,
        category: NotificationCategory.ride,
        priority: NotificationPriority.high,
      );
      
      print('Creating notification: ${notification.toMap()}'); // Debug log
      batch.set(notificationRef, notification.toMap());

      print('Committing batch...'); // Debug log
      await batch.commit();
      print('Batch committed successfully'); // Debug log
      
    } catch (e) {
      print('Error cancelling ride: $e');
      print('Error details: ${e.toString()}');
      rethrow;
    }
  }

  // Get pending ride requests
  Stream<List<RideModel>> getPendingRideRequests({required bool isDriverApproved}) {
    if (!isDriverApproved) {
      // Return an empty stream if driver is not approved
      return Stream.value([]);
    }
    try {
      return _requestsCollection.where('status', isEqualTo: 'pending').snapshots().map((snapshot) => snapshot.docs
          .map((doc) => RideModel.fromMap(
                doc.data() as Map<String, dynamic>,
                doc.id,
              ))
          .toList());
    } catch (e) {
      rethrow;
    }
  }

  // Get active ride for user
  Future<RideModel?> getActiveRideForUser(String userId) async {
    try {
      // First check requests collection for active rides
      final requestsSnapshot = await _requestsCollection
          .where('userId', isEqualTo: userId)
          .where('status', whereIn: ['accepted', 'driver_arrived', 'in_progress'])
          .limit(1)
          .get();

      if (requestsSnapshot.docs.isNotEmpty) {
        return RideModel.fromMap(
          requestsSnapshot.docs.first.data() as Map<String, dynamic>,
          requestsSnapshot.docs.first.id,
        );
      }

      // If not found in requests, check rides collection
      final ridesSnapshot = await _ridesCollection
          .where('passengerId', isEqualTo: userId)
          .where('status', whereIn: [
            RideStatus.accepted.index,
            RideStatus.driverArrived.index,
            RideStatus.inProgress.index,
          ])
          .limit(1)
          .get();

      if (ridesSnapshot.docs.isNotEmpty) {
        return RideModel.fromMap(
          ridesSnapshot.docs.first.data() as Map<String, dynamic>,
          ridesSnapshot.docs.first.id,
        );
      }
      return null;
    } catch (e) {
      rethrow;
    }
  }

  // Get active ride for driver
  Future<RideModel?> getActiveRideForDriver(String driverId) async {
    try {
      // First check requests collection for active rides
      final requestsSnapshot = await _requestsCollection
          .where('driverId', isEqualTo: driverId)
          .where('status', whereIn: ['accepted', 'driver_arrived', 'in_progress'])
          .limit(1)
          .get();

      if (requestsSnapshot.docs.isNotEmpty) {
        return RideModel.fromMap(
          requestsSnapshot.docs.first.data() as Map<String, dynamic>,
          requestsSnapshot.docs.first.id,
        );
      }

      // If not found in requests, check rides collection
      final ridesSnapshot = await _ridesCollection
          .where('driverId', isEqualTo: driverId)
          .where('status', whereIn: [
            RideStatus.accepted.index,
            RideStatus.driverArrived.index,
            RideStatus.inProgress.index,
          ])
          .limit(1)
          .get();

      if (ridesSnapshot.docs.isNotEmpty) {
        return RideModel.fromMap(
          ridesSnapshot.docs.first.data() as Map<String, dynamic>,
          ridesSnapshot.docs.first.id,
        );
      }
      return null;
    } catch (e) {
      rethrow;
    }
  }

  // Get user's ride history
  Future<List<RideModel>> getUserRideHistory(String userId) async {
    try {
      final QuerySnapshot snapshot = await _ridesCollection
          .where('passengerId', isEqualTo: userId)
          .where('status', whereIn: [
            RideStatus.completed.index,
            RideStatus.cancelled.index,
          ])
          .orderBy('requestTime', descending: true)
          .get();

      return snapshot.docs
          .map((doc) => RideModel.fromMap(
                doc.data() as Map<String, dynamic>,
                doc.id,
              ))
          .toList();
    } catch (e) {
      rethrow;
    }
  }

  // Listen to ride updates (checks both requests and rides collections)
  Stream<RideModel> listenToRideUpdates(String rideId) async* {
    // First check if it exists in requests collection
    final requestDoc = await _requestsCollection.doc(rideId).get();
    if (requestDoc.exists) {
      yield* _requestsCollection.doc(rideId).snapshots().map(
        (snapshot) => RideModel.fromMap(
          snapshot.data() as Map<String, dynamic>,
          snapshot.id,
        ),
      );
    } else {
      // If not in requests, listen to rides collection
      yield* _ridesCollection.doc(rideId).snapshots().map(
        (snapshot) => RideModel.fromMap(
          snapshot.data() as Map<String, dynamic>,
          snapshot.id,
        ),
      );
    }
  }

  // Check and create basic driver profile if missing
  Future<DriverModel?> ensureDriverProfile(String userId, UserModel user) async {
    try {
      // Check if driver profile exists
      final existingDriver = await getDriverByUserId(userId);
      if (existingDriver != null) {
        return existingDriver;
      }

      // Create basic driver profile if missing
      final basicDriver = DriverModel(
        userId: userId,
        idNumber: '', // Will need to be filled later
        name: user.name,
        phoneNumber: user.phoneNumber ?? '',
        email: user.email,
        documents: {}, // Empty documents
        isApproved: false,
      );

      await createDriverProfile(basicDriver);
      return basicDriver;
    } catch (e) {
      print('Error ensuring driver profile: $e');
      return null;
    }
  }

  // Set isOnline for user
  Future<void> setUserOnlineStatus(String uid, bool isOnline) async {
    try {
      await _usersCollection.doc(uid).update({'isOnline': isOnline});
    } catch (e) {
      rethrow;
    }
  }

  // ========== NOTIFICATION METHODS ==========

  // Get user's notifications
  Stream<List<NotificationModel>> getUserNotifications(String userId) {
    return _notificationsCollection.where('userId', isEqualTo: userId).orderBy('timestamp', descending: true).snapshots().map((snapshot) => snapshot.docs.map((doc) => NotificationModel.fromMap(doc.id, doc.data() as Map<String, dynamic>)).toList());
  }

  // Mark notification as read
  Future<void> markNotificationAsRead(String notificationId) async {
    try {
      await _notificationsCollection.doc(notificationId).update({'isRead': true});
    } catch (e) {
      rethrow;
    }
  }

  // Check if user needs to complete driver signup
  Future<bool> needsDriverSignup(String userId) async {
    try {
      final userDoc = await _usersCollection.doc(userId).get();
      if (!userDoc.exists) {
        return false;
      }

      final userData = userDoc.data() as Map<String, dynamic>;
      
      // If user is not a driver, they don't need driver signup
      if (userData['isDriver'] != true) {
        return false;
      }
      
      // If requiresDriverSignup is explicitly false, signup is completed
      if (userData['requiresDriverSignup'] == false) {
        return false;
      }
      
      // If requiresDriverSignup is true, they need to complete signup
      if (userData['requiresDriverSignup'] == true) {
        return true;
      }
      
      // If requiresDriverSignup is not set, check if driver profile exists
      final driverDoc = await _driversCollection.doc(userId).get();
      return !driverDoc.exists;
    } catch (e) {
      print('Error checking driver signup status: $e');
      return false;
    }
  }



  // Set isOnline for driver
  Future<void> setDriverOnlineStatus(String driverId, bool isOnline) async {
    try {
      final docRef = _driversCollection.doc(driverId);
      final doc = await docRef.get();
      if (doc.exists) {
        // Use the correct status field instead of isOnline
        final status = isOnline ? DriverStatus.online : DriverStatus.offline;
        await docRef.update({'status': status.index});
      } else {
        // Create a minimal driver document with correct status field
        final status = isOnline ? DriverStatus.online : DriverStatus.offline;
        await docRef.set({'status': status.index});
      }
    } catch (e) {
      rethrow;
    }
  }

  // Get today's earnings and ride count for a driver
  Future<Map<String, dynamic>> getTodaysEarningsAndRides(String driverId) async {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final endOfDay = DateTime(now.year, now.month, now.day, 23, 59, 59, 999);

    double totalEarnings = 0.0;
    double cardEarnings = 0.0;
    int rideCount = 0;
    int scheduledRideCount = 0;

    // Get regular rides
    final QuerySnapshot snapshot =
        await _ridesCollection.where('driverId', isEqualTo: driverId).where('status', isEqualTo: RideStatus.completed.index).where('dropoffTime', isGreaterThanOrEqualTo: startOfDay.millisecondsSinceEpoch).where('dropoffTime', isLessThanOrEqualTo: endOfDay.millisecondsSinceEpoch).get();

    for (var doc in snapshot.docs) {
      final data = doc.data() as Map<String, dynamic>;
      final fare = (data['actualFare'] ?? data['estimatedFare'] ?? 0).toDouble();
      final paymentType = data['paymentType'] as String? ?? 'Cash';
      
      totalEarnings += fare;
      rideCount++;
      
      // Calculate card earnings with 6.5% processing fee deduction
      if (paymentType == 'Card') {
        final cardFare = fare * (1 - 0.065); // Deduct 6.5% processing fee
        cardEarnings += cardFare;
      }
    }

    // Get completed scheduled bookings
    final scheduledSnapshot = await _scheduledRequestsCollection
        .where('driverId', isEqualTo: driverId)
        .where('status', isEqualTo: 'completed')
        .where('completedAt', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
        .where('completedAt', isLessThanOrEqualTo: Timestamp.fromDate(endOfDay))
        .get();

    for (var doc in scheduledSnapshot.docs) {
      final data = doc.data() as Map<String, dynamic>;
      final fare = (data['actualFare'] ?? data['estimatedFare'] ?? 0).toDouble();
      final paymentType = data['paymentType'] as String? ?? 'Cash';
      
      totalEarnings += fare;
      rideCount++;
      scheduledRideCount++;
      
      // Calculate card earnings with 6.5% processing fee deduction
      if (paymentType == 'Card') {
        final cardFare = fare * (1 - 0.065); // Deduct 6.5% processing fee
        cardEarnings += cardFare;
      }
    }

    return {
      'earnings': totalEarnings,
      'cardEarnings': cardEarnings,
      'rides': rideCount,
      'scheduledRides': scheduledRideCount,
    };
  }

  // Get weekly or monthly earnings and ride count for a driver
  Future<Map<String, dynamic>> getEarningsAndRidesForPeriod(String driverId, {required String period}) async {
    DateTime now = DateTime.now();
    DateTime start;
    DateTime end = now;
    if (period == 'week') {
      start = now.subtract(Duration(days: now.weekday - 1)); // Start of week (Monday)
    } else if (period == 'month') {
      start = DateTime(now.year, now.month, 1);
    } else {
      throw Exception('Invalid period: $period');
    }

    double totalEarnings = 0.0;
    double cardEarnings = 0.0;
    int rideCount = 0;
    int scheduledRideCount = 0;

    // Get regular rides
    final QuerySnapshot snapshot =
        await _ridesCollection.where('driverId', isEqualTo: driverId).where('status', isEqualTo: RideStatus.completed.index).where('dropoffTime', isGreaterThanOrEqualTo: start.millisecondsSinceEpoch).where('dropoffTime', isLessThanOrEqualTo: end.millisecondsSinceEpoch).get();

    for (var doc in snapshot.docs) {
      final data = doc.data() as Map<String, dynamic>;
      final fare = (data['actualFare'] ?? data['estimatedFare'] ?? 0).toDouble();
      final paymentType = data['paymentType'] as String? ?? 'Cash';
      
      totalEarnings += fare;
      rideCount++;
      
      // Calculate card earnings with 6.5% processing fee deduction
      if (paymentType == 'Card') {
        final cardFare = fare * (1 - 0.065); // Deduct 6.5% processing fee
        cardEarnings += cardFare;
      }
    }

    // Get completed scheduled bookings
    final scheduledSnapshot = await _scheduledRequestsCollection
        .where('driverId', isEqualTo: driverId)
        .where('status', isEqualTo: 'completed')
        .where('completedAt', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('completedAt', isLessThanOrEqualTo: Timestamp.fromDate(end))
        .get();

    for (var doc in scheduledSnapshot.docs) {
      final data = doc.data() as Map<String, dynamic>;
      final fare = (data['actualFare'] ?? data['estimatedFare'] ?? 0).toDouble();
      final paymentType = data['paymentType'] as String? ?? 'Cash';
      
      totalEarnings += fare;
      rideCount++;
      scheduledRideCount++;
      
      // Calculate card earnings with 6.5% processing fee deduction
      if (paymentType == 'Card') {
        final cardFare = fare * (1 - 0.065); // Deduct 6.5% processing fee
        cardEarnings += cardFare;
      }
    }

    return {
      'earnings': totalEarnings,
      'cardEarnings': cardEarnings,
      'rides': rideCount,
      'scheduledRides': scheduledRideCount,
    };
  }

  // Helper to fetch profile image from users or drivers collection
  Future<String?> getDriverProfileImage(String userId) async {
    try {
      // First check user document for profile image
      final userDoc = await _usersCollection.doc(userId).get();
      if (userDoc.exists) {
        final userData = userDoc.data() as Map<String, dynamic>;
        final userProfileImage = userData['profileImage'] as String?;
        if (userProfileImage != null && userProfileImage.isNotEmpty) {
          return userProfileImage;
        }
      }
      
      // If not found in user document, check driver document
      final driverDoc = await _driversCollection.doc(userId).get();
      if (driverDoc.exists) {
        final driverData = driverDoc.data() as Map<String, dynamic>;
        
        // Check for profile image in documents
        final documents = driverData['documents'] as Map<String, dynamic>? ?? {};
        final profileImageUrl = documents['Driver Profile Image'] as String?;
        if (profileImageUrl != null && profileImageUrl.isNotEmpty) {
          return profileImageUrl;
        }
        
        // Check for profile image field
        final driverProfileImage = driverData['profileImage'] as String?;
        if (driverProfileImage != null && driverProfileImage.isNotEmpty) {
          return driverProfileImage;
        }
      }
      
      return null;
    } catch (e) {
      print('Error fetching driver profile image: $e');
      return null;
    }
  }

  // Get all accepted rides for a driver (for ride history)
  Future<List<Map<String, dynamic>>> getAcceptedRides(String driverId) async {
    try {
      final QuerySnapshot snapshot = await _driversCollection
          .doc(driverId)
          .collection('rideHistory')
          .where('status', whereIn: [RideStatus.completed.index, RideStatus.cancelled.index, RideStatus.accepted.index])
          .orderBy('requestTime', descending: true)
          .get();

      return snapshot.docs
          .map((doc) {
            final data = doc.data() as Map<String, dynamic>?;
            if (data == null) {
              return null;
            }
            
            // Handle different timestamp formats
            dynamic requestTime = data['requestTime'];
            int? timestamp;
            
            if (requestTime is Timestamp) {
              timestamp = requestTime.millisecondsSinceEpoch;
            } else if (requestTime is int) {
              timestamp = requestTime;
            } else if (requestTime is String) {
              timestamp = int.tryParse(requestTime);
            }
            
            return {
              'fare': (data['actualFare'] ?? data['estimatedFare'] ?? 0).toDouble(),
              'date': timestamp,
              'status': data['status'],
              'id': doc.id,
              'pickupAddress': data['pickupAddress'] ?? 'Unknown Pickup',
              'destinationAddress': data['dropoffAddress'] ?? 'Unknown Destination',
              'passengerId': data['passengerId'] ?? '',
              'earnings': data['earnings'] ?? 0.0,
            };
          })
          .whereType<Map<String, dynamic>>()
          .toList();
    } catch (e) {
      print('Error fetching accepted rides: $e');
      return [];
    }
  }

  // Rate a passenger after ride completion
  Future<void> ratePassenger({
    required String rideId,
    required String passengerId,
    required int rating,
    String? notes,
    String? report,
  }) async {
    try {
      final driverId = FirebaseAuth.instance.currentUser?.uid;
      if (driverId == null) throw Exception('Driver not logged in');

      final ratingData = {
        'rideId': rideId,
        'passengerId': passengerId,
        'driverId': driverId,
        'rating': rating,
        'notes': notes,
        'report': report,
        'createdAt': FieldValue.serverTimestamp(),
      };

      // Save rating to passenger's user document
      await _firestore
          .collection('users')
          .doc(passengerId)
          .collection('ratings')
          .doc(rideId)
          .set(ratingData);

      // Update passenger's average rating
      await _updateUserAverageRating(passengerId);

      // If there's a report, log it
      if (report != null && report.isNotEmpty) {
        await _firestore.collection('reported_issues').add({
          'rideId': rideId,
          'reportedUserId': passengerId,
          'reporterId': driverId,
          'type': 'passenger_report',
          'reason': report,
          'status': 'pending',
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      throw Exception('Failed to submit rating: $e');
    }
  }

  // Get all rides for a passenger (for ride history)
  Future<List<Map<String, dynamic>>> getPassengerRideHistory(String passengerId) async {
    try {
      // Get rides from both collections
      final requestsSnapshot = await _requestsCollection
          .where('userId', isEqualTo: passengerId)
          .where('status', whereIn: ['completed', 'cancelled', 'accepted'])
          .orderBy('timestamp', descending: true)
          .get();

      final ridesSnapshot = await _ridesCollection
          .where('passengerId', isEqualTo: passengerId)
          .where('status', whereIn: [RideStatus.completed.index, RideStatus.cancelled.index, RideStatus.accepted.index])
          .orderBy('requestTime', descending: true)
          .get();

      final List<Map<String, dynamic>> allRides = [];

      // Process requests collection
      for (final doc in requestsSnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        allRides.add({
          'fare': (data['actualFare'] ?? data['estimatedFare'] ?? 0).toDouble(),
          'date': data['timestamp']?.millisecondsSinceEpoch ?? DateTime.now().millisecondsSinceEpoch,
          'status': _convertStringToStatus(data['status']),
          'id': doc.id,
          'pickupAddress': data['pickupAddress'] ?? 'Unknown Pickup',
          'destinationAddress': data['dropoffAddress'] ?? 'Unknown Destination',
          'driverId': data['driverId'] ?? '',
        });
      }

      // Process rides collection
      for (final doc in ridesSnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        allRides.add({
          'fare': (data['actualFare'] ?? data['estimatedFare'] ?? 0).toDouble(),
          'date': data['requestTime']?.millisecondsSinceEpoch ?? DateTime.now().millisecondsSinceEpoch,
          'status': data['status'],
          'id': doc.id,
          'pickupAddress': data['pickupAddress'] ?? 'Unknown Pickup',
          'destinationAddress': data['dropoffAddress'] ?? 'Unknown Destination',
          'driverId': data['driverId'] ?? '',
        });
      }

      // Sort by date (most recent first)
      allRides.sort((a, b) => (b['date'] as int).compareTo(a['date'] as int));
      
      return allRides;
    } catch (e) {
      print('Error fetching passenger ride history: $e');
      return [];
    }
  }

  // Helper method to convert string status to RideStatus index
  int _convertStringToStatus(String status) {
    switch (status) {
      case 'pending':
        return RideStatus.requested.index;
      case 'accepted':
        return RideStatus.accepted.index;
      case 'driver_arrived':
        return RideStatus.driverArrived.index;
      case 'in_progress':
        return RideStatus.inProgress.index;
      case 'completed':
        return RideStatus.completed.index;
      case 'cancelled':
        return RideStatus.cancelled.index;
      default:
        return RideStatus.requested.index;
    }
  }

  // Rate a driver after ride completion
  Future<void> rateDriver({
    required String rideId,
    required String driverId,
    required int rating,
    String? notes,
    String? report,
  }) async {
    try {
      final passengerId = FirebaseAuth.instance.currentUser?.uid;
      if (passengerId == null) throw Exception('Passenger not logged in');

      final ratingData = {
        'rideId': rideId,
        'passengerId': passengerId,
        'driverId': driverId,
        'rating': rating,
        'notes': notes,
        'report': report,
        'createdAt': FieldValue.serverTimestamp(),
      };

      // Save rating to driver's user document
      await _firestore
          .collection('users')
          .doc(driverId)
          .collection('ratings')
          .doc(rideId)
          .set(ratingData);

      // Update driver's average rating
      await _updateUserAverageRating(driverId);

      // If there's a report, log it
      if (report != null && report.isNotEmpty) {
        await _firestore.collection('reported_issues').add({
          'rideId': rideId,
          'reportedUserId': driverId,
          'reporterId': passengerId,
          'type': 'driver_report',
          'reason': report,
          'status': 'pending',
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      throw Exception('Failed to submit rating: $e');
    }
  }

  // Update user's average rating
  Future<void> _updateUserAverageRating(String userId) async {
    try {
      final ratingsSnapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('ratings')
          .get();

      if (ratingsSnapshot.docs.isEmpty) return;

      double totalRating = 0;
      int ratingCount = 0;

      for (final doc in ratingsSnapshot.docs) {
        final data = doc.data();
        final rating = data['rating'] as int?;
        if (rating != null && rating > 0) {
          totalRating += rating;
          ratingCount++;
        }
      }

      if (ratingCount > 0) {
        final averageRating = totalRating / ratingCount;
        await _firestore.collection('users').doc(userId).update({
          'averageRating': averageRating,
          'ratingCount': ratingCount,
          'lastRatingUpdate': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      print('Error updating average rating: $e');
    }
  }

  // Get the 3 most recent rides for a driver
  Future<List<Map<String, dynamic>>> getRecentRides(String driverId) async {
    final QuerySnapshot snapshot = await _ridesCollection.where('driverId', isEqualTo: driverId).where('status', whereIn: [RideStatus.completed.index, RideStatus.cancelled.index, RideStatus.accepted.index]).orderBy('dropoffTime', descending: true).limit(3).get();

    return snapshot.docs.map((doc) {
      final data = doc.data() as Map<String, dynamic>;
      return {
        'fare': (data['actualFare'] ?? data['estimatedFare'] ?? 0).toDouble(),
        'date': data['dropoffTime'],
        'status': data['status'],
        'id': doc.id,
      };
    }).toList();
  }

  // Send notification to a user
  Future<void> sendNotification({
    required String userId,
    required String title,
    required String message,
    required String type,
    Map<String, dynamic>? data,
  }) async {
    try {
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('notifications')
          .add({
        'title': title,
        'message': message,
        'type': type,
        'data': data ?? {},
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error sending notification: $e');
    }
  }

  // Update all drivers' isMax2 field to false
  Future<void> updateAllDriversMax2Field() async {
    try {
      final driversSnapshot = await _firestore
          .collection('users')
          .where('isDriver', isEqualTo: true)
          .get();
      
      final batch = _firestore.batch();
      for (final doc in driversSnapshot.docs) {
        batch.update(doc.reference, {'isMax2': false});
      }
      
      await batch.commit();
      print('Successfully updated isMax2 field for all drivers');
    } catch (e) {
      print('Error updating isMax2 field: $e');
      rethrow;
    }
  }

  // Complete a ride and update earnings
  Future<void> completeRide(String rideId, String driverId, double actualFare) async {
    try {
      final batch = _firestore.batch();
      final now = DateTime.now();

      // Get the ride from requests collection first, then rides collection
      DocumentSnapshot rideDoc = await _requestsCollection.doc(rideId).get();
      bool isInRequests = rideDoc.exists;
      
      if (!isInRequests) {
        rideDoc = await _ridesCollection.doc(rideId).get();
        if (!rideDoc.exists) throw Exception('Ride not found');
      }

      final rideData = rideDoc.data() as Map<String, dynamic>;
      final ride = RideModel.fromMap(rideData, rideId);

      // Update the ride status in the appropriate collection
      if (isInRequests) {
        // Move from requests to rides collection when completing
        batch.set(_ridesCollection.doc(rideId), {
          ...rideData,
          'status': RideStatus.completed.index,
          'actualFare': actualFare,
          'dropoffTime': now.millisecondsSinceEpoch,
        });
        // Delete from requests collection
        batch.delete(_requestsCollection.doc(rideId));
      } else {
        // Update in rides collection
        batch.update(_ridesCollection.doc(rideId), {
          'status': RideStatus.completed.index,
          'actualFare': actualFare,
          'dropoffTime': now.millisecondsSinceEpoch,
        });
      }

      // Add to driver's ride history with earnings
      final driverHistoryRef = _driversCollection.doc(driverId).collection('rideHistory').doc(rideId);
      batch.set(driverHistoryRef, {
        'rideId': rideId,
        'passengerId': ride.passengerId,
        'pickupAddress': ride.pickupAddress,
        'dropoffAddress': ride.dropoffAddress,
        'estimatedFare': ride.estimatedFare,
        'actualFare': actualFare,
        'status': RideStatus.completed.index,
        'requestTime': ride.requestTime.millisecondsSinceEpoch,
        'dropoffTime': now.millisecondsSinceEpoch,
        'earnings': actualFare, // Track earnings
        'completedAt': now.millisecondsSinceEpoch,
      });

      // Update driver's total earnings and reset payment status
      final driverRef = _driversCollection.doc(driverId);
      batch.update(driverRef, {
        'totalEarnings': FieldValue.increment(actualFare),
        'totalRides': FieldValue.increment(1),
        'status': DriverStatus.online.index, // Set driver back to online
        'isPaid': false, // Reset payment status when new earnings are added
      });

      // Create notification for passenger
      final notificationRef = _notificationsCollection.doc();
      batch.set(notificationRef, {
        'userId': ride.passengerId,
        'title': 'Ride Completed',
        'body': 'Your ride has been completed. Please rate your driver.',
        'timestamp': now,
        'isRead': false,
        'type': 'ride_completed',
        'data': {'rideId': rideId},
      });

      await batch.commit();
    } catch (e) {
      print('Error completing ride: $e');
      rethrow;
    }
  }

  // Cancel a ride and update earnings (subtract if driver cancelled)
  Future<void> cancelRideAndUpdateEarnings(String rideId, String driverId, {String? reason, bool isDriverCancellation = false}) async {
    try {
      final batch = _firestore.batch();
      final now = DateTime.now();

      // Get the ride from requests collection first, then rides collection
      DocumentSnapshot rideDoc = await _requestsCollection.doc(rideId).get();
      bool isInRequests = rideDoc.exists;
      
      if (!isInRequests) {
        rideDoc = await _ridesCollection.doc(rideId).get();
        if (!rideDoc.exists) throw Exception('Ride not found');
      }

      final rideData = rideDoc.data() as Map<String, dynamic>;
      final ride = RideModel.fromMap(rideData, rideId);

      // Update the ride status in the appropriate collection
      if (isInRequests) {
        // Move from requests to rides collection when cancelling
        batch.set(_ridesCollection.doc(rideId), {
          ...rideData,
          'status': RideStatus.cancelled.index,
          'cancellationReason': reason,
          'cancelledAt': now.millisecondsSinceEpoch,
        });
        // Delete from requests collection
        batch.delete(_requestsCollection.doc(rideId));
      } else {
        // Update in rides collection
        batch.update(_ridesCollection.doc(rideId), {
          'status': RideStatus.cancelled.index,
          'cancellationReason': reason,
          'cancelledAt': now.millisecondsSinceEpoch,
        });
      }

      // Add to driver's ride history
      final driverHistoryRef = _driversCollection.doc(driverId).collection('rideHistory').doc(rideId);
      batch.set(driverHistoryRef, {
        'rideId': rideId,
        'passengerId': ride.passengerId,
        'pickupAddress': ride.pickupAddress,
        'dropoffAddress': ride.dropoffAddress,
        'estimatedFare': ride.estimatedFare,
        'actualFare': 0.0, // No earnings for cancelled rides
        'status': RideStatus.cancelled.index,
        'requestTime': ride.requestTime.millisecondsSinceEpoch,
        'cancelledAt': now.millisecondsSinceEpoch,
        'cancellationReason': reason,
        'earnings': 0.0, // No earnings
        'isDriverCancellation': isDriverCancellation,
      });

      // If driver cancelled, they might lose some earnings (penalty)
      if (isDriverCancellation) {
        // Optional: Apply cancellation penalty
        final cancellationPenalty = 0.0; // Set to 0 for now, can be adjusted
        batch.update(_driversCollection.doc(driverId), {
          'totalEarnings': FieldValue.increment(-cancellationPenalty),
          'status': DriverStatus.online.index, // Set driver back to online
        });
      } else {
        // Passenger cancelled, no penalty for driver
        batch.update(_driversCollection.doc(driverId), {
          'status': DriverStatus.online.index,
        });
      }

      await batch.commit();
    } catch (e) {
      print('Error cancelling ride: $e');
      rethrow;
    }
  }

  // Get real-time earnings updates
  Stream<Map<String, dynamic>> getRealTimeEarnings(String driverId) {
    return _driversCollection.doc(driverId).snapshots().map((snapshot) {
      if (snapshot.exists) {
        final data = snapshot.data() as Map<String, dynamic>;
        return {
          'totalEarnings': (data['totalEarnings'] ?? 0.0) as double,
          'totalRides': (data['totalRides'] ?? 0) as int,
          'isOnline': (data['isOnline'] ?? false) as bool,
        };
      }
      return {
        'totalEarnings': 0.0,
        'totalRides': 0,
        'isOnline': false,
      };
    });
  }

  // Complete referral when driver is approved
  Future<void> completeReferral(String driverId) async {
    try {
      print('🔄 Processing referral completion for driver: $driverId');
      
      // Find the referral record for this driver
      final referralQuery = await _firestore
          .collection('referrals')
          .where('referredDriverId', isEqualTo: driverId)
          .where('status', isEqualTo: 'pending')
          .get();

      if (referralQuery.docs.isNotEmpty) {
        final referralDoc = referralQuery.docs.first;
        final referralData = referralDoc.data();
        
        // Verify this is a driver referral
        if (!(referralData['isDriverReferral'] ?? false)) {
          print('❌ Not a driver referral, skipping completion');
          return;
        }
        
        final referrerId = referralData['referrerId'] as String;
        final now = DateTime.now();

        // Update referral status to completed
        await referralDoc.reference.update({
          'status': 'completed',
          'completedAt': FieldValue.serverTimestamp(),
          'completionDate': now.toIso8601String(), // Add explicit date string
        });

        // Update referrer's stats
        final referrerRef = _usersCollection.doc(referrerId);
        final referrerDoc = await referrerRef.get();
        
        if (referrerDoc.exists) {
          final referrerData = referrerDoc.data() as Map<String, dynamic>;
          final currentReferrals = (referrerData['referrals'] ?? 0) as int;
          final currentReferralAmount = (referrerData['referralAmount'] ?? 0.0) as double;
          
          await referrerRef.update({
            'referrals': currentReferrals + 1,
            'referralAmount': currentReferralAmount + 50.0,
            'lastReferral': now.toIso8601String(),
            'lastReferralDate': FieldValue.serverTimestamp(),
          });
        }

        // Send notification to referrer
        await sendNotification(
          userId: referrerId,
          title: 'Referral Completed!',
          message: 'Your referral has been approved! You earned R50.',
          type: 'referral_completed',
          data: {
            'driverId': driverId,
            'amount': 50.0,
            'completedAt': now.toIso8601String(),
          },
        );

        print('✅ Referral completed for driver: $driverId, referrer: $referrerId');
      } else {
        print('⚠️ No pending referral found for driver: $driverId');
      }
    } catch (e) {
      print('❌ Error completing referral: $e');
      // Don't rethrow - referral completion shouldn't block driver approval
    }
  }

  // Get user's referral statistics
  Future<Map<String, dynamic>> getUserReferralStats(String userId) async {
    try {
      final userDoc = await _usersCollection.doc(userId).get();
      if (userDoc.exists) {
        final data = userDoc.data() as Map<String, dynamic>;
        return {
          'referrals': data['referrals'] ?? 0,
          'referralAmount': (data['referralAmount'] ?? 0.0).toDouble(),
          'lastReferral': data['lastReferral'],
        };
      }
      return {
        'referrals': 0,
        'referralAmount': 0.0,
        'lastReferral': null,
      };
    } catch (e) {
      print('Error getting referral stats: $e');
      return {
        'referrals': 0,
        'referralAmount': 0.0,
        'lastReferral': null,
      };
    }
  }

  // Update user's owing amount
  Future<void> updateUserOwing(String userId, double additionalAmount) async {
    try {
      final userRef = _usersCollection.doc(userId);
      final userDoc = await userRef.get();
      
      if (userDoc.exists) {
        final data = userDoc.data() as Map<String, dynamic>;
        final currentOwing = (data['owing'] ?? 0.0) as double;
        await userRef.update({
          'owing': currentOwing + additionalAmount,
          'lastOwingUpdate': FieldValue.serverTimestamp(),
          'owingHistory': FieldValue.arrayUnion([{
            'amount': additionalAmount,
            'reason': 'Waiting time charge',
            'timestamp': FieldValue.serverTimestamp(),
          }]),
        });
      }
    } catch (e) {
      print('Error updating user owing: $e');
      rethrow;
    }
  }

  // Record successful payment for driver
  Future<void> recordDriverPayment(String driverId, double amount, String paymentReference) async {
    try {
      await _firestore.collection('driver_payments').add({
        'driverId': driverId,
        'amount': amount,
        'paymentReference': paymentReference,
        'status': 'success',
        'timestamp': FieldValue.serverTimestamp(),
        'validUntil': FieldValue.serverTimestamp(), // Will be set to 7 days from now
      });
      
      // Update user document to mark payment as completed
      await _usersCollection.doc(driverId).update({
        'paymentCompleted': true,
        'lastPaymentDate': FieldValue.serverTimestamp(),
      });
      
      print('✅ Payment recorded successfully for driver: $driverId');
    } catch (e) {
      print('Error recording payment: $e');
      rethrow;
    }
  }

  // Verify payment status for driver
  Future<bool> verifyDriverPayment(String driverId) async {
    try {
      // First check if user has paymentCompleted flag
      final userDoc = await _usersCollection.doc(driverId).get();
      if (userDoc.exists) {
        final userData = userDoc.data() as Map<String, dynamic>?;
        if (userData?['paymentCompleted'] == true) {
          print('✅ Payment verified via user document flag');
          return true;
        }
      }
      
      // Fallback: check driver_payments collection
      final paymentsQuery = await _firestore
          .collection('driver_payments')
          .where('driverId', isEqualTo: driverId)
          .where('status', isEqualTo: 'success')
          .orderBy('timestamp', descending: true)
          .limit(1)
          .get();

      final hasPayment = paymentsQuery.docs.isNotEmpty;
      print('Payment verification result: $hasPayment');
      return hasPayment;
    } catch (e) {
      print('Error verifying payment: $e');
      return false;
    }
  }

  // Save driver signup progress
  Future<void> saveDriverSignupProgress(String userId, Map<String, dynamic> progressData) async {
    try {
      await _firestore.collection('driver_signup_progress').doc(userId).set({
        ...progressData,
        'lastUpdated': FieldValue.serverTimestamp(),
      });
      print('✅ Driver signup progress saved for user: $userId');
    } catch (e) {
      print('Error saving driver signup progress: $e');
      rethrow;
    }
  }

  // Get driver signup progress
  Future<Map<String, dynamic>?> getDriverSignupProgress(String userId) async {
    try {
      final doc = await _firestore.collection('driver_signup_progress').doc(userId).get();
      if (doc.exists) {
        return doc.data();
      }
      return null;
    } catch (e) {
      print('Error getting driver signup progress: $e');
      return null;
    }
  }

  // Clear driver signup progress (called after successful submission)
  Future<void> clearDriverSignupProgress(String userId) async {
    try {
      await _firestore.collection('driver_signup_progress').doc(userId).delete();
      print('✅ Driver signup progress cleared for user: $userId');
    } catch (e) {
      print('Error clearing driver signup progress: $e');
    }
  }

  // --- NO CAR APPLICATIONS & VEHICLE OFFERS ---
  Future<void> saveNoCarApplication(Map<String, dynamic> applicationData) async {
    await _firestore.collection('no_car_applications').add(applicationData);
  }

  Future<void> saveVehicleOffer(Map<String, dynamic> vehicleData) async {
    await _firestore.collection('vehicle_offers').add(vehicleData);
  }

  Future<List<Map<String, dynamic>>> getNoCarApplications() async {
    final snapshot = await _firestore.collection('no_car_applications').get();
    return snapshot.docs.map((doc) => doc.data()).toList();
  }

  Future<List<Map<String, dynamic>>> getVehicleOffers() async {
    final snapshot = await _firestore.collection('vehicle_offers').where('isAvailable', isEqualTo: true).get();
    return snapshot.docs.map((doc) => doc.data()).toList();
  }

  Future<List<Map<String, dynamic>>> getVehicleOffersByOwner(String ownerId) async {
    final snapshot = await _firestore.collection('vehicle_offers').where('ownerId', isEqualTo: ownerId).get();
    return snapshot.docs.map((doc) => doc.data()).toList();
  }

  // Mock data for testing
  Future<List<Map<String, dynamic>>> getMockVehicleOffers() async {
    return [
      {
        'ownerId': 'mock_owner_1',
        'ownerName': 'Thabo Mokoena',
        'ownerEmail': 'thabo.mokoena@email.com',
        'ownerPhone': '+27 82 123 4567',
        'vehicleMake': 'Toyota',
        'vehicleModel': 'Corolla',
        'vehicleYear': '2021',
        'licensePlate': 'CA 123-456',
        'vehicleType': 'Sedan',
        'transmission': 'Automatic',
        'fuelType': 'Petrol',
        'vehicleCondition': 'Excellent condition, well maintained',
        'dailyRate': 450.0,
        'description': 'Reliable sedan perfect for daily driving. Clean interior and smooth ride.',
        'features': ['Air Conditioning', 'Bluetooth', 'GPS Navigation', 'Backup Camera'],
        'serviceAreas': ['Johannesburg CBD', 'Sandton', 'Rosebank'],
        'status': 'active',
        'isAvailable': true,
        'rating': 4.8,
        'totalRentals': 12,
      },
      {
        'ownerId': 'mock_owner_2',
        'ownerName': 'Nomsa Dlamini',
        'ownerEmail': 'nomsa.dlamini@email.com',
        'ownerPhone': '+27 83 987 6543',
        'vehicleMake': 'BMW',
        'vehicleModel': 'X3',
        'vehicleYear': '2022',
        'licensePlate': 'GP 789-012',
        'vehicleType': 'SUV',
        'transmission': 'Automatic',
        'fuelType': 'Diesel',
        'vehicleCondition': 'Premium condition, luxury features',
        'dailyRate': 750.0,
        'description': 'Luxury SUV with premium features. Perfect for business or leisure.',
        'features': ['Leather Seats', 'Sunroof', 'Alloy Wheels', 'Tinted Windows', 'WiFi Hotspot'],
        'serviceAreas': ['Sandton', 'Fourways', 'Midrand'],
        'status': 'active',
        'isAvailable': true,
        'rating': 4.9,
        'totalRentals': 8,
      },
      {
        'ownerId': 'mock_owner_3',
        'ownerName': 'Sipho Nkosi',
        'ownerEmail': 'sipho.nkosi@email.com',
        'ownerPhone': '+27 84 555 1234',
        'vehicleMake': 'Honda',
        'vehicleModel': 'Civic',
        'vehicleYear': '2020',
        'licensePlate': 'GP 456-789',
        'vehicleType': 'Sedan',
        'transmission': 'Manual',
        'fuelType': 'Petrol',
        'vehicleCondition': 'Good condition, fuel efficient',
        'dailyRate': 350.0,
        'description': 'Economical sedan with great fuel efficiency. Perfect for city driving.',
        'features': ['Air Conditioning', 'Bluetooth'],
        'serviceAreas': ['Johannesburg CBD', 'Braamfontein', 'Newtown'],
        'status': 'active',
        'isAvailable': true,
        'rating': 4.5,
        'totalRentals': 15,
      },
    ];
  }

  Future<List<Map<String, dynamic>>> getMockDriverApplications() async {
    return [
      {
        'userId': 'mock_driver_1',
        'name': 'Lerato Molefe',
        'email': 'lerato.molefe@email.com',
        'phoneNumber': '+27 81 234 5678',
        'idNumber': '8901234567890',
        'drivingExperience': '3-5 years',
        'preferredAreas': ['Johannesburg CBD', 'Sandton', 'Rosebank'],
        'preferences': ['Flexible hours', 'Luxury vehicles', 'Long distance trips'],
        'availability': 'Weekdays 8 AM - 6 PM, Weekends flexible',
        'status': 'pending',
        'createdAt': DateTime.now().subtract(const Duration(days: 2)).toIso8601String(),
      },
      {
        'userId': 'mock_driver_2',
        'name': 'David van der Merwe',
        'email': 'david.vandermerwe@email.com',
        'phoneNumber': '+27 82 345 6789',
        'idNumber': '9012345678901',
        'drivingExperience': '5+ years',
        'preferredAreas': ['Sandton', 'Fourways', 'Midrand'],
        'preferences': ['Weekends only', 'SUV vehicles', 'Local trips only'],
        'availability': 'Weekends only, flexible hours',
        'status': 'pending',
        'createdAt': DateTime.now().subtract(const Duration(days: 1)).toIso8601String(),
      },
      {
        'userId': 'mock_driver_3',
        'name': 'Zinhle Zulu',
        'email': 'zinhle.zulu@email.com',
        'phoneNumber': '+27 83 456 7890',
        'idNumber': '9123456789012',
        'drivingExperience': '1-3 years',
        'preferredAreas': ['Johannesburg CBD', 'Braamfontein', 'Newtown'],
        'preferences': ['Evening shifts', 'Economy vehicles'],
        'availability': 'Evenings 6 PM - 12 AM, weekdays only',
        'status': 'pending',
        'createdAt': DateTime.now().toIso8601String(),
      },
    ];
  }

  // --- EXISTING METHODS ---
}
