import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import '../models/notification_model.dart';

class EnhancedNotificationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final CollectionReference _notificationsCollection = FirebaseFirestore.instance.collection('notifications');

  // Initialize push notifications
  Future<void> initializePushNotifications() async {
    // Request permission
    NotificationSettings settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      // Get FCM token
      String? token = await _messaging.getToken();
      if (token != null) {
        await updateFCMToken(token);
      }

      // Listen for token refresh
      _messaging.onTokenRefresh.listen((newToken) {
        updateFCMToken(newToken);
      });
    }
  }

  // Update FCM token
  Future<void> updateFCMToken(String token) async {
    // TODO: Update user's FCM token in the database
  }

  // Create notification with category and priority
  Future<void> createNotification({
    required String userId,
    required String title,
    required String body,
    required NotificationCategory category,
    NotificationPriority priority = NotificationPriority.medium,
    Map<String, dynamic>? actionData,
    String? imageUrl,
    bool isPersistent = false,
    DateTime? expiryDate,
  }) async {
    try {
      await _notificationsCollection.add({
        'userId': userId,
        'title': title,
        'body': body,
        'timestamp': FieldValue.serverTimestamp(),
        'isRead': false,
        'category': category.index,
        'priority': priority.index,
        'actionData': actionData,
        'imageUrl': imageUrl,
        'isPersistent': isPersistent,
        'expiryDate': expiryDate?.toIso8601String(),
      });
    } catch (e) {
      rethrow;
    }
  }

  // Get notifications by category
  Stream<List<NotificationModel>> getNotificationsByCategory(String userId, NotificationCategory category) {
    return _notificationsCollection
        .where('userId', isEqualTo: userId)
        .where('category', isEqualTo: category.index)
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => NotificationModel.fromMap(doc.id, doc.data() as Map<String, dynamic>))
            .toList());
  }

  // Get notifications by priority
  Stream<List<NotificationModel>> getNotificationsByPriority(String userId, NotificationPriority priority) {
    return _notificationsCollection
        .where('userId', isEqualTo: userId)
        .where('priority', isEqualTo: priority.index)
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => NotificationModel.fromMap(doc.id, doc.data() as Map<String, dynamic>))
            .toList());
  }

  // Get unread notifications count
  Stream<int> getUnreadNotificationsCount(String userId) {
    return _notificationsCollection
        .where('userId', isEqualTo: userId)
        .where('isRead', isEqualTo: false)
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }

  // Mark notification as read
  Future<void> markNotificationAsRead(String notificationId) async {
    try {
      await _notificationsCollection.doc(notificationId).update({
        'isRead': true,
      });
    } catch (e) {
      rethrow;
    }
  }

  // Mark all notifications as read
  Future<void> markAllNotificationsAsRead(String userId) async {
    try {
      final batch = _firestore.batch();
      final notifications = await _notificationsCollection
          .where('userId', isEqualTo: userId)
          .where('isRead', isEqualTo: false)
          .get();

      for (var doc in notifications.docs) {
        batch.update(doc.reference, {'isRead': true});
      }

      await batch.commit();
    } catch (e) {
      rethrow;
    }
  }

  // Delete notification
  Future<void> deleteNotification(String notificationId) async {
    try {
      await _notificationsCollection.doc(notificationId).delete();
    } catch (e) {
      rethrow;
    }
  }

  // Clear all notifications
  Future<void> clearAllNotifications(String userId) async {
    try {
      final batch = _firestore.batch();
      final notifications = await _notificationsCollection
          .where('userId', isEqualTo: userId)
          .where('isPersistent', isEqualTo: false)
          .get();

      for (var doc in notifications.docs) {
        batch.delete(doc.reference);
      }

      await batch.commit();
    } catch (e) {
      rethrow;
    }
  }

  // Get notification preferences
  Future<Map<String, dynamic>> getNotificationPreferences(String userId) async {
    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      return (doc.data()?['notificationPreferences'] as Map<String, dynamic>?) ?? {};
    } catch (e) {
      rethrow;
    }
  }

  // Update notification preferences
  Future<void> updateNotificationPreferences(String userId, Map<String, dynamic> preferences) async {
    try {
      await _firestore.collection('users').doc(userId).update({
        'notificationPreferences': preferences,
      });
    } catch (e) {
      rethrow;
    }
  }

  // Handle notification action
  Future<void> handleNotificationAction(String notificationId, String action) async {
    try {
      final notification = await _notificationsCollection.doc(notificationId).get();
      final data = notification.data() as Map<String, dynamic>;
      final actionData = data['actionData'] as Map<String, dynamic>?;

      if (actionData != null && actionData.containsKey(action)) {
        // Execute the action based on actionData
        // This could be navigation, API calls, etc.
      }
    } catch (e) {
      rethrow;
    }
  }
}