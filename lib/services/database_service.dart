import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

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
    final unreadMap = Map<String, dynamic>.from(chatDoc['unread'] ?? {});
    for (final uid in participants) {
      if (uid != senderId) {
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
    // Sort IDs to ensure consistent chat ID
    final participants = [driverId, passengerId]..sort();
    final chatId = participants.join('_');
    
    // Check if chat already exists
    final chatDoc = await _firestore.collection('chats').doc(chatId).get();
    
    if (!chatDoc.exists) {
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

      // Calculate missing fields
      final missingFields = <String>[];
      if (driver.name.isEmpty) missingFields.add('Full Name');
      if (driver.phoneNumber.isEmpty) missingFields.add('Phone Number');
      if (driver.idNumber.isEmpty) missingFields.add('ID Number');
      if (driver.vehicleModel == null || driver.vehicleModel!.isEmpty) missingFields.add('Vehicle Model');
      if (driver.licensePlate == null || driver.licensePlate!.isEmpty) missingFields.add('License Plate');
      if (driver.documents.isEmpty) missingFields.add('Required Documents');

      print('📝 Updating user document with completed driver profile');
      
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
        'driverProfileCompleted': true,
        'driverSignupDate': FieldValue.serverTimestamp(),
        'approvalStatus': 'awaiting_approval', // Update status to awaiting approval
        'savedAddresses': [],
        'recentRides': [],
        'isOnline': false,
        'IsFemale': driver.isFemale ?? false,
        'IsForStudents': driver.isForStudents ?? false,
        'missingProfileFields': missingFields,
        'profileImage': driver.profileImage,
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

  // Create a new ride request
  Future<String> createRideRequest(RideModel ride) async {
    try {
      final DocumentReference docRef = await _ridesCollection.add(ride.toMap());
      return docRef.id;
    } catch (e) {
      rethrow;
    }
  }

  // Get ride by ID
  Future<RideModel?> getRideById(String rideId) async {
    try {
      final DocumentSnapshot doc = await _ridesCollection.doc(rideId).get();
      if (doc.exists) {
        return RideModel.fromMap(doc.data() as Map<String, dynamic>, doc.id);
      }
      return null;
    } catch (e) {
      rethrow;
    }
  }

  // Update ride
  Future<void> updateRide(RideModel ride) async {
    try {
      await _ridesCollection.doc(ride.id).update(ride.toMap());
    } catch (e) {
      rethrow;
    }
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
      final mainRideRef = _ridesCollection.doc(ride.id);
      final mainRideUpdate = {
        'status': RideStatus.requested.index, // Reset to requested so it appears in request list again
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
      return _ridesCollection.where('status', isEqualTo: RideStatus.requested.index).snapshots().map((snapshot) => snapshot.docs
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
      final QuerySnapshot snapshot = await _ridesCollection
          .where('passengerId', isEqualTo: userId)
          .where('status', whereIn: [
            RideStatus.accepted.index,
            RideStatus.driverArrived.index,
            RideStatus.inProgress.index,
          ])
          .limit(1)
          .get();

      if (snapshot.docs.isNotEmpty) {
        return RideModel.fromMap(
          snapshot.docs.first.data() as Map<String, dynamic>,
          snapshot.docs.first.id,
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
      final QuerySnapshot snapshot = await _ridesCollection
          .where('driverId', isEqualTo: driverId)
          .where('status', whereIn: [
            RideStatus.accepted.index,
            RideStatus.driverArrived.index,
            RideStatus.inProgress.index,
          ])
          .limit(1)
          .get();

      if (snapshot.docs.isNotEmpty) {
        return RideModel.fromMap(
          snapshot.docs.first.data() as Map<String, dynamic>,
          snapshot.docs.first.id,
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

  // Listen to ride updates
  Stream<RideModel> listenToRideUpdates(String rideId) {
    return _ridesCollection.doc(rideId).snapshots().map(
          (snapshot) => RideModel.fromMap(
            snapshot.data() as Map<String, dynamic>,
            snapshot.id,
          ),
        );
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
      return userData['isDriver'] == true && 
             (userData['requiresDriverSignup'] == true || 
              userData['driverProfileCompleted'] != true);
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

    final QuerySnapshot snapshot =
        await _ridesCollection.where('driverId', isEqualTo: driverId).where('status', isEqualTo: RideStatus.completed.index).where('dropoffTime', isGreaterThanOrEqualTo: startOfDay.millisecondsSinceEpoch).where('dropoffTime', isLessThanOrEqualTo: endOfDay.millisecondsSinceEpoch).get();

    double totalEarnings = 0.0;
    double cardEarnings = 0.0;
    int rideCount = 0;

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

    return {
      'earnings': totalEarnings,
      'cardEarnings': cardEarnings,
      'rides': rideCount,
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

    final QuerySnapshot snapshot =
        await _ridesCollection.where('driverId', isEqualTo: driverId).where('status', isEqualTo: RideStatus.completed.index).where('dropoffTime', isGreaterThanOrEqualTo: start.millisecondsSinceEpoch).where('dropoffTime', isLessThanOrEqualTo: end.millisecondsSinceEpoch).get();

    double totalEarnings = 0.0;
    double cardEarnings = 0.0;
    int rideCount = 0;

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

    return {
      'earnings': totalEarnings,
      'cardEarnings': cardEarnings,
      'rides': rideCount,
    };
  }

  // Helper to fetch profile image from drivers collection if not present in users
  Future<String?> getDriverProfileImage(String userId) async {
    try {
      final doc = await _driversCollection.doc(userId).get();
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        return data['profileImage'] as String?;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  // Get all accepted rides for a driver (for ride history)
  Future<List<Map<String, dynamic>>> getAcceptedRides(String driverId) async {
    final QuerySnapshot snapshot = await _driversCollection.doc(driverId).collection('rideHistory').where('status', whereIn: [RideStatus.completed.index, RideStatus.cancelled.index, RideStatus.accepted.index]).orderBy('requestTime', descending: true).get();

    return snapshot.docs
        .map((doc) {
          final data = doc.data() as Map<String, dynamic>?;
          if (data == null) {
            return null;
          }
          return {
            'fare': (data['actualFare'] ?? data['estimatedFare'] ?? 0).toDouble(),
            'date': data['requestTime'], // Use requestTime for consistent sorting
            'status': data['status'],
            'id': doc.id,
          };
        })
        .whereType<Map<String, dynamic>>()
        .toList(); // Filter out any null maps
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

      // Get the ride
      final rideDoc = await _ridesCollection.doc(rideId).get();
      if (!rideDoc.exists) throw Exception('Ride not found');

      final rideData = rideDoc.data() as Map<String, dynamic>;
      final ride = RideModel.fromMap(rideData, rideId);

      // Update the ride status
      batch.update(_ridesCollection.doc(rideId), {
        'status': RideStatus.completed.index,
        'actualFare': actualFare,
        'dropoffTime': now.millisecondsSinceEpoch,
      });

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

      // Get the ride
      final rideDoc = await _ridesCollection.doc(rideId).get();
      if (!rideDoc.exists) throw Exception('Ride not found');

      final rideData = rideDoc.data() as Map<String, dynamic>;
      final ride = RideModel.fromMap(rideData, rideId);

      // Update the ride status
      batch.update(_ridesCollection.doc(rideId), {
        'status': RideStatus.cancelled.index,
        'cancellationReason': reason,
        'cancelledAt': now.millisecondsSinceEpoch,
      });

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

        // Update referral status to completed
        await referralDoc.reference.update({
          'status': 'completed',
          'completedAt': FieldValue.serverTimestamp(),
        });

        // Send notification to referrer
        await sendNotification(
          userId: referrerId,
          title: 'Referral Completed!',
          message: 'Your referral has been approved! You earned R50.',
          type: 'referral_completed',
          data: {
            'driverId': driverId,
            'amount': 50.0,
          },
        );

        print('Referral completed for driver: $driverId, referrer: $referrerId');
      }
    } catch (e) {
      print('Error completing referral: $e');
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
}
