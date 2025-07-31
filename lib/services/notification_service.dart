import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

class NotificationService extends ChangeNotifier {
  bool _isInitialized = false;
  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;

  Future<void> initialize(BuildContext context) async {
    if (_isInitialized) return;
    
    try {
      // Request notification permissions
      NotificationSettings settings = await _firebaseMessaging.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );

      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        print('User granted permission');
      } else if (settings.authorizationStatus == AuthorizationStatus.provisional) {
        print('User granted provisional permission');
      } else {
        print('User declined or has not accepted permission');
      }

      // Get FCM token
      String? token = await _firebaseMessaging.getToken();
      if (token != null) {
        print('FCM Token: $token');
        // Save token to user's document in Firestore
        await _saveFCMToken(token);
      }

      // Listen for token refresh
      _firebaseMessaging.onTokenRefresh.listen((newToken) {
        _saveFCMToken(newToken);
      });

      // Handle foreground messages
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        print('Got a message whilst in the foreground!');
        print('Message data: ${message.data}');

        if (message.notification != null) {
          print('Message also contained a notification: ${message.notification}');
          _showInAppNotification(context, message.notification!.title ?? '', message.notification!.body ?? '');
        }
      });

      // Handle background messages
      FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

      // Handle notification taps
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        print('A new onMessageOpenedApp event was published!');
        // Handle navigation based on message data
        _handleNotificationTap(message);
      });

      _isInitialized = true;
      print('Notification service initialized successfully');
    } catch (e) {
      print('Error initializing notification service: $e');
    }
  }

  Future<void> _saveFCMToken(String token) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .update({'fcmToken': token});
      }
    } catch (e) {
      print('Error saving FCM token: $e');
    }
  }

  void _showInAppNotification(BuildContext context, String title, String body) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            Text(body),
          ],
        ),
        duration: const Duration(seconds: 4),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  void _handleNotificationTap(RemoteMessage message) {
    // Handle navigation based on message type
    final data = message.data;
    final type = data['type'];
    
    switch (type) {
      case 'chat':
        // Navigate to chat screen
        break;
      case 'ride':
        // Navigate to ride details
        break;
      case 'emergency':
        // Navigate to emergency screen
        break;
      default:
        // Default navigation
        break;
    }
  }

  Future<void> sendNotificationToUser({
    required String userId,
    required String title,
    required String body,
    required String type,
    Map<String, dynamic>? data,
  }) async {
    try {
      // Save notification to Firestore
      await _saveNotificationToFirestore(userId, title, body, type, data);
      
      // Send FCM notification (this would typically be done from your backend)
      // For now, we'll just save to Firestore
      print('Notification saved for user $userId: $title - $body');
    } catch (e) {
      print('Error sending notification: $e');
    }
  }

  Future<void> sendChatNotification({
    required String recipientId,
    required String senderName,
    required String message,
    required String chatId,
  }) async {
    try {
      await _saveNotificationToFirestore(
        recipientId,
        'New message from $senderName',
        message,
        'chat',
        {
          'chatId': chatId,
          'senderName': senderName,
        },
      );
      
      // In a real app, you would send FCM notification from your backend
      print('Chat notification saved for $recipientId from $senderName: $message');
    } catch (e) {
      print('Error sending chat notification: $e');
    }
  }

  Future<void> sendRideNotification({
    required String userId,
    required String title,
    required String body,
    required String rideId,
    Map<String, dynamic>? data,
  }) async {
    try {
      await _saveNotificationToFirestore(userId, title, body, 'ride', {
        'rideId': rideId,
        if (data != null) ...data,
      });
      
      print('Ride notification saved for $userId: $title - $body');
    } catch (e) {
      print('Error sending ride notification: $e');
    }
  }

  Future<void> sendDriverArrivedNotification({
    required String userId,
    required String driverName,
    required String rideId,
    Map<String, dynamic>? data,
  }) async {
    try {
      await _saveNotificationToFirestore(
        userId,
        'Driver Arrived!',
        '$driverName has arrived at your pickup location',
        'driver_arrived',
        {
          'rideId': rideId,
          'driverName': driverName,
          if (data != null) ...data,
        },
      );
      
      print('Driver arrived notification saved for $userId');
    } catch (e) {
      print('Error sending driver arrived notification: $e');
    }
  }

  Future<void> sendEmergencyAlertNotification({
    required String userId,
    required String userName,
    required Map<String, dynamic> location,
    Map<String, dynamic>? rideDetails,
  }) async {
    try {
      await _saveNotificationToFirestore(
        userId,
        '🚨 EMERGENCY ALERT',
        'Emergency alert from $userName',
        'emergency',
        {
          'userName': userName,
          'location': location,
          'rideDetails': rideDetails,
        },
      );
      
      print('Emergency notification saved for $userId');
    } catch (e) {
      print('Error sending emergency notification: $e');
    }
  }

  Future<void> _saveNotificationToFirestore(
    String userId,
    String title,
    String body,
    String type,
    Map<String, dynamic>? data,
  ) async {
    try {
      final notificationData = {
        'userId': userId,
        'title': title,
        'body': body,
        'type': type,
        'timestamp': FieldValue.serverTimestamp(),
        'isRead': false,
        'data': data,
      };
      
      await FirebaseFirestore.instance
          .collection('notifications')
          .add(notificationData);
    } catch (e) {
      print('Error saving notification to Firestore: $e');
    }
  }

  // Get notifications for a user
  Stream<List<Map<String, dynamic>>> getUserNotifications(String userId) {
    return FirebaseFirestore.instance
        .collection('notifications')
        .where('userId', isEqualTo: userId)
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => {
                  'id': doc.id,
                  ...doc.data(),
                })
            .toList());
  }

  // Mark notification as read
  Future<void> markNotificationAsRead(String notificationId) async {
    try {
      await FirebaseFirestore.instance
          .collection('notifications')
          .doc(notificationId)
          .update({'isRead': true});
    } catch (e) {
      print('Error marking notification as read: $e');
    }
  }

  // Clear all notifications for a user
  Future<void> clearAllNotifications(String userId) async {
    try {
      final notifications = await FirebaseFirestore.instance
          .collection('notifications')
          .where('userId', isEqualTo: userId)
          .get();
      
      for (final doc in notifications.docs) {
        await doc.reference.delete();
      }
    } catch (e) {
      print('Error clearing notifications: $e');
    }
  }
}

// Background message handler
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  print("Handling a background message: ${message.messageId}");
} 