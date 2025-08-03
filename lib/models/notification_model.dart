// lib/models/notification_model.dart
import 'package:cloud_firestore/cloud_firestore.dart';

enum NotificationCategory {
  ride,
  payment,
  profile,
  document,
  system,
  promotion,
  emergency
}

enum NotificationPriority {
  low,
  medium,
  high,
  urgent
}

class NotificationModel {
  final String id;
  final String userId;
  final String title;
  final String body;
  final Timestamp timestamp;
  final bool isRead;
  final NotificationCategory category;
  final NotificationPriority priority;
  final Map<String, dynamic>? actionData;
  final String? imageUrl;
  final bool isPersistent;
  final DateTime? expiryDate;

  NotificationModel({
    required this.id,
    required this.userId,
    required this.title,
    required this.body,
    required this.timestamp,
    this.isRead = false,
    required this.category,
    required this.priority,
    this.actionData,
    this.imageUrl,
    this.isPersistent = false,
    this.expiryDate,
  });

  factory NotificationModel.fromMap(String id, Map<String, dynamic> data) {
    return NotificationModel(
      id: id,
      userId: data['userId'] ?? '',
      title: data['title'] ?? '',
      body: data['body'] ?? '',
      timestamp: data['timestamp'] ?? Timestamp.now(),
      isRead: data['isRead'] ?? false,
      category: NotificationCategory.values[data['category'] ?? 0],
      priority: NotificationPriority.values[data['priority'] ?? 0],
      actionData: data['actionData'],
      imageUrl: data['imageUrl'],
      isPersistent: data['isPersistent'] ?? false,
      expiryDate: data['expiryDate'] != null ? DateTime.parse(data['expiryDate']) : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'title': title,
      'body': body,
      'timestamp': timestamp,
      'isRead': isRead,
    };
  }
} 