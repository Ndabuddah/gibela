import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../constants/app_colors.dart';
import '../../services/notification_service.dart';
import '../../services/ride_notification_service.dart';

class NotificationTestScreen extends StatelessWidget {
  const NotificationTestScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      backgroundColor: AppColors.getBackgroundColor(isDark),
      appBar: AppBar(
        title: const Text('Notification Test'),
        backgroundColor: AppColors.primary,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Test Notifications',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            
            // Chat Notification Test
            _NotificationTestCard(
              title: 'Chat Message',
              subtitle: 'Test chat notification',
              icon: Icons.chat,
              color: Colors.blue,
              onTap: () => _testChatNotification(context),
            ),
            
            const SizedBox(height: 16),
            
            // Ride Notification Test
            _NotificationTestCard(
              title: 'Ride Update',
              subtitle: 'Test ride notification',
              icon: Icons.directions_car,
              color: Colors.green,
              onTap: () => _testRideNotification(context),
            ),
            
            const SizedBox(height: 16),
            
            // Driver Arrived Test
            _NotificationTestCard(
              title: 'Driver Arrived',
              subtitle: 'Test driver arrival notification',
              icon: Icons.location_on,
              color: Colors.orange,
              onTap: () => _testDriverArrivedNotification(context),
            ),
            
            const SizedBox(height: 16),
            
            // Emergency Alert Test
            _NotificationTestCard(
              title: 'Emergency Alert',
              subtitle: 'Test emergency notification',
              icon: Icons.emergency,
              color: Colors.red,
              onTap: () => _testEmergencyNotification(context),
            ),
            
            const SizedBox(height: 16),
            
            // Payment Reminder Test
            _NotificationTestCard(
              title: 'Payment Reminder',
              subtitle: 'Test payment notification',
              icon: Icons.payment,
              color: Colors.purple,
              onTap: () => _testPaymentNotification(context),
            ),
            
            const SizedBox(height: 16),
            
            // Rating Reminder Test
            _NotificationTestCard(
              title: 'Rating Reminder',
              subtitle: 'Test rating notification',
              icon: Icons.star,
              color: Colors.amber,
              onTap: () => _testRatingNotification(context),
            ),
          ],
        ),
      ),
    );
  }

  void _testChatNotification(BuildContext context) async {
    try {
      final notificationService = Provider.of<NotificationService>(context, listen: false);
      await notificationService.sendChatNotification(
        recipientId: 'test_user',
        senderName: 'Test Driver',
        message: 'This is a test chat message',
        chatId: 'test_chat_123',
      );
      _showSuccessSnackBar(context, 'Chat notification sent!');
    } catch (e) {
      _showErrorSnackBar(context, 'Error: $e');
    }
  }

  void _testRideNotification(BuildContext context) async {
    try {
      await RideNotificationService.sendRideAcceptedNotification(
        rideId: 'test_ride_123',
        passengerId: 'test_user',
        driverId: 'test_driver',
        driverName: 'Test Driver',
        vehicleType: 'Asambe Via',
      );
      _showSuccessSnackBar(context, 'Ride notification sent!');
    } catch (e) {
      _showErrorSnackBar(context, 'Error: $e');
    }
  }

  void _testDriverArrivedNotification(BuildContext context) async {
    try {
      await RideNotificationService.sendDriverArrivedNotification(
        rideId: 'test_ride_123',
        passengerId: 'test_user',
        driverId: 'test_driver',
        driverName: 'Test Driver',
      );
      _showSuccessSnackBar(context, 'Driver arrived notification sent!');
    } catch (e) {
      _showErrorSnackBar(context, 'Error: $e');
    }
  }

  void _testEmergencyNotification(BuildContext context) async {
    try {
      final notificationService = Provider.of<NotificationService>(context, listen: false);
      await notificationService.sendEmergencyAlertNotification(
        userId: 'test_user',
        userName: 'Test User',
        location: {
          'latitude': -26.2041,
          'longitude': 28.0473,
          'address': 'Johannesburg, South Africa',
        },
        rideDetails: {
          'id': 'test_ride_123',
          'pickupAddress': 'Test Pickup',
          'dropoffAddress': 'Test Dropoff',
        },
      );
      _showSuccessSnackBar(context, 'Emergency notification sent!');
    } catch (e) {
      _showErrorSnackBar(context, 'Error: $e');
    }
  }

  void _testPaymentNotification(BuildContext context) async {
    try {
      await RideNotificationService.sendPaymentReminderNotification(
        userId: 'test_user',
        amount: 45.50,
      );
      _showSuccessSnackBar(context, 'Payment notification sent!');
    } catch (e) {
      _showErrorSnackBar(context, 'Error: $e');
    }
  }

  void _testRatingNotification(BuildContext context) async {
    try {
      await RideNotificationService.sendRatingReminderNotification(
        userId: 'test_user',
        driverName: 'Test Driver',
      );
      _showSuccessSnackBar(context, 'Rating notification sent!');
    } catch (e) {
      _showErrorSnackBar(context, 'Error: $e');
    }
  }

  void _showSuccessSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _showErrorSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }
}

class _NotificationTestCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _NotificationTestCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.getTextPrimaryColor(isDark),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.getTextSecondaryColor(isDark),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios,
                color: AppColors.getTextSecondaryColor(isDark),
                size: 16,
              ),
            ],
          ),
        ),
      ),
    );
  }
} 