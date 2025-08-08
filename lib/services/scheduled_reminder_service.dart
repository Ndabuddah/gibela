import 'dart:async';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/driver_model.dart';
import '../models/user_model.dart';
import '../widgets/common/modern_alert_dialog.dart';
import 'database_service.dart';

class ScheduledReminderService extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  Timer? _reminderTimer;
  Timer? _countdownTimer;
  Map<String, Timer> _individualTimers = {};
  
  // Reminder states
  bool _showReminderDialog = false;
  Map<String, dynamic>? _currentReminder;
  Map<String, DateTime> _dismissedReminders = {};
  
  // Countdown data
  Map<String, Duration> _countdowns = {};
  Map<String, bool> _flashingStates = {};
  
  // Getters
  bool get showReminderDialog => _showReminderDialog;
  Map<String, dynamic>? get currentReminder => _currentReminder;
  Map<String, Duration> get countdowns => _countdowns;
  Map<String, bool> get flashingStates => _flashingStates;

  ScheduledReminderService() {
    _initializeReminders();
  }

  void _initializeReminders() {
    // Start checking for reminders every minute
    _reminderTimer = Timer.periodic(const Duration(minutes: 1), (timer) {
      _checkForReminders();
    });
    
    // Start countdown timer every second
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _updateCountdowns();
    });
  }

  Future<void> _checkForReminders() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      final now = DateTime.now();
      
      // Check if user is driver or passenger
      final isDriver = await _isUserDriver(user.uid);
      
      if (isDriver) {
        await _checkDriverReminders(user.uid, now);
      } else {
        await _checkPassengerReminders(user.uid, now);
      }
    } catch (e) {
      print('Error checking reminders: $e');
    }
  }

  Future<bool> _isUserDriver(String userId) async {
    try {
      final userDoc = await _firestore.collection('users').doc(userId).get();
      if (userDoc.exists) {
        return userDoc.data()?['isDriver'] == true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  Future<void> _checkDriverReminders(String driverId, DateTime now) async {
    try {
      // Get driver's accepted scheduled requests
      final scheduledQuery = await _firestore
          .collection('scheduledRequests')
          .where('driverId', isEqualTo: driverId)
          .where('status', isEqualTo: 'accepted')
          .get();

      for (final doc in scheduledQuery.docs) {
        final data = doc.data();
        final scheduledDateTime = (data['scheduledDateTime'] as Timestamp).toDate();
        final timeUntilPickup = scheduledDateTime.difference(now);
        
        // Check if it's time to show reminder (30 minutes before)
        if (timeUntilPickup.inMinutes <= 30 && timeUntilPickup.inMinutes > 0) {
          final reminderKey = '${doc.id}_$driverId';
          
          // Check if reminder was already dismissed
          if (!_dismissedReminders.containsKey(reminderKey)) {
            await _showDriverReminder(data, doc.id, timeUntilPickup);
          }
        }
      }
    } catch (e) {
      print('Error checking driver reminders: $e');
    }
  }

  Future<void> _checkPassengerReminders(String passengerId, DateTime now) async {
    try {
      // Get passenger's scheduled requests
      final scheduledQuery = await _firestore
          .collection('scheduledRequests')
          .where('userId', isEqualTo: passengerId)
          .where('status', whereIn: ['pending', 'accepted'])
          .get();

      for (final doc in scheduledQuery.docs) {
        final data = doc.data();
        final scheduledDateTime = (data['scheduledDateTime'] as Timestamp).toDate();
        final timeUntilPickup = scheduledDateTime.difference(now);
        
        // Check if it's time to show reminder (30 minutes before)
        if (timeUntilPickup.inMinutes <= 30 && timeUntilPickup.inMinutes > 0) {
          final reminderKey = '${doc.id}_$passengerId';
          
          // Check if reminder was already dismissed
          if (!_dismissedReminders.containsKey(reminderKey)) {
            await _showPassengerReminder(data, doc.id, timeUntilPickup);
          }
        }
      }
    } catch (e) {
      print('Error checking passenger reminders: $e');
    }
  }

  Future<void> _showDriverReminder(Map<String, dynamic> request, String requestId, Duration timeUntilPickup) async {
    _currentReminder = {
      ...request,
      'id': requestId,
      'type': 'driver',
      'timeUntilPickup': timeUntilPickup,
    };
    _showReminderDialog = true;
    notifyListeners();
  }

  Future<void> _showPassengerReminder(Map<String, dynamic> request, String requestId, Duration timeUntilPickup) async {
    _currentReminder = {
      ...request,
      'id': requestId,
      'type': 'passenger',
      'timeUntilPickup': timeUntilPickup,
    };
    _showReminderDialog = true;
    notifyListeners();
  }

  void _updateCountdowns() {
    final now = DateTime.now();
    final newCountdowns = <String, Duration>{};
    final newFlashingStates = <String, bool>{};
    
    _countdowns.forEach((requestId, duration) {
      final scheduledDateTime = now.add(duration);
      final timeUntilPickup = scheduledDateTime.difference(now);
      
      if (timeUntilPickup.isNegative) {
        // Remove expired countdowns
        _individualTimers[requestId]?.cancel();
        _individualTimers.remove(requestId);
      } else {
        newCountdowns[requestId] = timeUntilPickup;
        // Start flashing 30 minutes before
        newFlashingStates[requestId] = timeUntilPickup.inMinutes <= 30;
      }
    });
    
    _countdowns = newCountdowns;
    _flashingStates = newFlashingStates;
    notifyListeners();
  }

  Future<void> dismissReminder() async {
    if (_currentReminder != null) {
      final reminderKey = '${_currentReminder!['id']}_${_auth.currentUser?.uid}';
      _dismissedReminders[reminderKey] = DateTime.now();
      
      // Save to shared preferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('dismissed_reminders', _dismissedReminders.toString());
    }
    
    _showReminderDialog = false;
    _currentReminder = null;
    notifyListeners();
  }

  Future<void> loadScheduledBookings() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      final isDriver = await _isUserDriver(user.uid);
      final now = DateTime.now();
      
      if (isDriver) {
        await _loadDriverScheduledBookings(user.uid, now);
      } else {
        await _loadPassengerScheduledBookings(user.uid, now);
      }
    } catch (e) {
      print('Error loading scheduled bookings: $e');
    }
  }

  Future<void> _loadDriverScheduledBookings(String driverId, DateTime now) async {
    try {
      final scheduledQuery = await _firestore
          .collection('scheduledRequests')
          .where('driverId', isEqualTo: driverId)
          .where('status', isEqualTo: 'accepted')
          .get();

      for (final doc in scheduledQuery.docs) {
        final data = doc.data();
        final scheduledDateTime = (data['scheduledDateTime'] as Timestamp).toDate();
        final timeUntilPickup = scheduledDateTime.difference(now);
        
        if (timeUntilPickup.isNegative) continue; // Skip past bookings
        
        _countdowns[doc.id] = timeUntilPickup;
        _flashingStates[doc.id] = timeUntilPickup.inMinutes <= 30;
        
        // Start individual timer for this booking
        _startIndividualTimer(doc.id, scheduledDateTime);
      }
    } catch (e) {
      print('Error loading driver scheduled bookings: $e');
    }
  }

  Future<void> _loadPassengerScheduledBookings(String passengerId, DateTime now) async {
    try {
      final scheduledQuery = await _firestore
          .collection('scheduledRequests')
          .where('userId', isEqualTo: passengerId)
          .where('status', whereIn: ['pending', 'accepted'])
          .get();

      for (final doc in scheduledQuery.docs) {
        final data = doc.data();
        final scheduledDateTime = (data['scheduledDateTime'] as Timestamp).toDate();
        final timeUntilPickup = scheduledDateTime.difference(now);
        
        if (timeUntilPickup.isNegative) continue; // Skip past bookings
        
        _countdowns[doc.id] = timeUntilPickup;
        _flashingStates[doc.id] = timeUntilPickup.inMinutes <= 30;
        
        // Start individual timer for this booking
        _startIndividualTimer(doc.id, scheduledDateTime);
      }
    } catch (e) {
      print('Error loading passenger scheduled bookings: $e');
    }
  }

  void _startIndividualTimer(String requestId, DateTime scheduledDateTime) {
    // Cancel existing timer if any
    _individualTimers[requestId]?.cancel();
    
    // Calculate time until 30 minutes before pickup
    final reminderTime = scheduledDateTime.subtract(const Duration(minutes: 30));
    final now = DateTime.now();
    
    if (reminderTime.isAfter(now)) {
      final delay = reminderTime.difference(now);
      _individualTimers[requestId] = Timer(delay, () {
        _triggerReminder(requestId);
      });
    }
  }

  void _triggerReminder(String requestId) {
    // This will be handled by the periodic timer
    print('Reminder triggered for request: $requestId');
  }

  String formatCountdown(Duration duration) {
    if (duration.inDays > 0) {
      return '${duration.inDays}d ${duration.inHours % 24}h ${duration.inMinutes % 60}m';
    } else if (duration.inHours > 0) {
      return '${duration.inHours}h ${duration.inMinutes % 60}m';
    } else {
      return '${duration.inMinutes}m';
    }
  }

  @override
  void dispose() {
    _reminderTimer?.cancel();
    _countdownTimer?.cancel();
    _individualTimers.values.forEach((timer) => timer.cancel());
    super.dispose();
  }
} 