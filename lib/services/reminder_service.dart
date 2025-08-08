import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../widgets/common/modern_alert_dialog.dart';

class ReminderService {
  static final ReminderService _instance = ReminderService._internal();
  factory ReminderService() => _instance;
  ReminderService._internal();

  Timer? _reminderTimer;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Start the reminder service
  void startReminderService(BuildContext context) {
    // Check for reminders every 5 minutes
    _reminderTimer = Timer.periodic(const Duration(minutes: 5), (timer) {
      _checkReminders(context);
    });
  }

  // Stop the reminder service
  void stopReminderService() {
    _reminderTimer?.cancel();
    _reminderTimer = null;
  }

  // Check for upcoming bookings that need reminders
  Future<void> _checkReminders(BuildContext context) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final now = DateTime.now();
      final thirtyMinutesFromNow = now.add(const Duration(minutes: 30));
      final oneHourFromNow = now.add(const Duration(hours: 1));

      // Get scheduled bookings that are coming up soon
      try {
        final upcomingBookings = await _firestore
            .collection('scheduled_bookings')
            .where('userId', isEqualTo: user.uid)
            .where('status', isEqualTo: 'scheduled')
            .where('reminderEnabled', isEqualTo: true)
            .get();

        for (final doc in upcomingBookings.docs) {
          final booking = doc.data();
          final scheduledDate = DateTime.parse(booking['scheduledDate']);
          final scheduledTime = booking['scheduledTime'] as String;
          
          // Parse the time
          final timeParts = scheduledTime.split(':');
          final scheduledDateTime = DateTime(
            scheduledDate.year,
            scheduledDate.month,
            scheduledDate.day,
            int.parse(timeParts[0]),
            int.parse(timeParts[1]),
          );

          // Check if reminder should be shown (30 minutes before)
          if (scheduledDateTime.isAfter(now) && 
              scheduledDateTime.isBefore(thirtyMinutesFromNow) &&
              !(booking['reminderShown'] ?? false)) {
            
            _showReminderNotification(context, booking, doc.id);
          }

          // Check if it's time to activate the booking (1 hour before)
          if (scheduledDateTime.isAfter(now) && 
              scheduledDateTime.isBefore(oneHourFromNow) &&
              booking['status'] == 'scheduled') {
            
            _activateBooking(doc.id);
          }
        }
      } catch (e) {
        // If index is still building, try a simpler query
        print('⚠️ Firestore index still building for reminders. Using fallback query.');
        try {
          final fallbackQuery = await _firestore
              .collection('scheduled_bookings')
              .where('userId', isEqualTo: user.uid)
              .get();

          for (final doc in fallbackQuery.docs) {
            final booking = doc.data();
            final status = booking['status'] as String?;
            final reminderEnabled = booking['reminderEnabled'] as bool?;
            
            if (status == 'scheduled' && reminderEnabled == true) {
              final scheduledDate = DateTime.parse(booking['scheduledDate']);
              final scheduledTime = booking['scheduledTime'] as String;
              
              // Parse the time
              final timeParts = scheduledTime.split(':');
              final scheduledDateTime = DateTime(
                scheduledDate.year,
                scheduledDate.month,
                scheduledDate.day,
                int.parse(timeParts[0]),
                int.parse(timeParts[1]),
              );

              // Check if reminder should be shown (30 minutes before)
              if (scheduledDateTime.isAfter(now) && 
                  scheduledDateTime.isBefore(thirtyMinutesFromNow) &&
                  !(booking['reminderShown'] ?? false)) {
                
                _showReminderNotification(context, booking, doc.id);
              }

              // Check if it's time to activate the booking (1 hour before)
              if (scheduledDateTime.isAfter(now) && 
                  scheduledDateTime.isBefore(oneHourFromNow) &&
                  status == 'scheduled') {
                
                _activateBooking(doc.id);
              }
            }
          }
        } catch (fallbackError) {
          print('❌ Fallback query also failed: $fallbackError');
        }
      }
    } catch (e) {
      debugPrint('Error checking reminders: $e');
    }
  }

  // Show reminder notification
  void _showReminderNotification(BuildContext context, Map<String, dynamic> booking, String bookingId) {
    final scheduledDate = DateTime.parse(booking['scheduledDate']);
    final scheduledTime = booking['scheduledTime'] as String;
    
    // Mark reminder as shown
    _firestore
        .collection('scheduled_bookings')
        .doc(bookingId)
        .update({'reminderShown': true});

    // Show in-app notification
    if (context.mounted) {
      _showReminderDialog(context, booking, bookingId);
    }
  }

  // Show reminder dialog
  void _showReminderDialog(BuildContext context, Map<String, dynamic> booking, String bookingId) {
    final scheduledDate = DateTime.parse(booking['scheduledDate']);
    final scheduledTime = booking['scheduledTime'] as String;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.notifications_active, color: Colors.orange, size: 28),
            const SizedBox(width: 12),
            const Text('Upcoming Trip'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Your scheduled trip is coming up in 30 minutes!',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 16),
            _buildReminderInfoRow('Date', DateFormat('EEEE, MMMM d, y').format(scheduledDate)),
            const SizedBox(height: 8),
            _buildReminderInfoRow('Time', scheduledTime),
            const SizedBox(height: 8),
            _buildReminderInfoRow('From', booking['pickupAddress']),
            const SizedBox(height: 8),
            _buildReminderInfoRow('To', booking['dropoffAddress']),
            const SizedBox(height: 8),
            _buildReminderInfoRow('Vehicle', booking['vehicleType'] ?? 'Standard'),
            const SizedBox(height: 8),
            _buildReminderInfoRow('Price', 'R${booking['price']}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _cancelReminder(bookingId);
            },
            child: const Text('Dismiss'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              _viewBookingDetails(context, bookingId);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('View Details', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildReminderInfoRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 60,
          child: Text(
            '$label:',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.grey[700],
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[800],
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  // Cancel reminder for a specific booking
  Future<void> _cancelReminder(String bookingId) async {
    try {
      await _firestore
          .collection('scheduled_bookings')
          .doc(bookingId)
          .update({
        'reminderEnabled': false,
        'reminderShown': false,
      });
    } catch (e) {
      debugPrint('Error cancelling reminder: $e');
    }
  }

  // Activate a booking (change status to active)
  Future<void> _activateBooking(String bookingId) async {
    try {
      await _firestore
          .collection('scheduled_bookings')
          .doc(bookingId)
          .update({
        'status': 'active',
        'activatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Error activating booking: $e');
    }
  }

  // Navigate to booking details
  void _viewBookingDetails(BuildContext context, String bookingId) {
    // TODO: Navigate to booking details screen
    ModernSnackBar.show(
      context, 
      message: 'Booking details screen coming soon!',
    );
  }

  // Set reminder for a booking
  Future<void> setReminder(String bookingId, bool enabled) async {
    try {
      await _firestore
          .collection('scheduled_bookings')
          .doc(bookingId)
          .update({
        'reminderEnabled': enabled,
        'reminderShown': false,
        'reminderSetAt': enabled ? FieldValue.serverTimestamp() : null,
      });
    } catch (e) {
      debugPrint('Error setting reminder: $e');
    }
  }

  // Get upcoming bookings for a user
  Future<List<Map<String, dynamic>>> getUpcomingBookings() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return [];

      final now = DateTime.now();
      final tomorrow = now.add(const Duration(days: 1));

      final query = await _firestore
          .collection('scheduled_bookings')
          .where('userId', isEqualTo: user.uid)
          .where('status', isEqualTo: 'scheduled')
          .where('scheduledDate', isGreaterThanOrEqualTo: now.toIso8601String())
          .where('scheduledDate', isLessThan: tomorrow.toIso8601String())
          .orderBy('scheduledDate')
          .get();

      return query.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();
    } catch (e) {
      debugPrint('Error getting upcoming bookings: $e');
      return [];
    }
  }

  // Check if user has any upcoming bookings
  Future<bool> hasUpcomingBookings() async {
    final bookings = await getUpcomingBookings();
    return bookings.isNotEmpty;
  }

  // Show a simple reminder notification
  void showSimpleReminder(BuildContext context, String message) {
    if (context.mounted) {
      ModernSnackBar.show(
        context,
        message: message,
      );
    }
  }

  // Show a persistent reminder notification
  void showPersistentReminder(BuildContext context, String title, String message, VoidCallback onAction) {
    if (context.mounted) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              Icon(Icons.notifications, color: Colors.orange, size: 24),
              const SizedBox(width: 8),
              Text(title),
            ],
          ),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Later'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                onAction();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('View', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );
    }
  }
} 