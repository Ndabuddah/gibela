import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../constants/app_colors.dart';
import '../../../providers/theme_provider.dart';
import '../../../widgets/common/loading_indicator.dart';
import '../../../widgets/common/rating_dialog.dart';
import '../../../services/database_service.dart';
import '../../../widgets/common/modern_alert_dialog.dart';
import '../../../l10n/app_localizations.dart';
import 'request_ride_screen.dart';
import 'ride_progress_screen.dart';
import '../../chat/chat_screen.dart';

class MyBookingsScreen extends StatefulWidget {
  const MyBookingsScreen({Key? key}) : super(key: key);

  @override
  State<MyBookingsScreen> createState() => _MyBookingsScreenState();
}

class _MyBookingsScreenState extends State<MyBookingsScreen> with TickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true;
  List<Map<String, dynamic>> _scheduledBookings = [];
  List<Map<String, dynamic>> _activeRides = [];
  List<Map<String, dynamic>> _pastRides = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadBookings();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadBookings() async {
    try {
      setState(() => _isLoading = true);
      
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // Load scheduled bookings
      final scheduledQuery = await FirebaseFirestore.instance
          .collection('scheduled_bookings')
          .where('userId', isEqualTo: user.uid)
          .where('status', isEqualTo: 'scheduled')
          .orderBy('scheduledDateTime')
          .get();

      _scheduledBookings = scheduledQuery.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();

      // Load active rides
      final activeQuery = await FirebaseFirestore.instance
          .collection('scheduled_bookings')
          .where('userId', isEqualTo: user.uid)
          .where('status', whereIn: ['active', 'driver_assigned'])
          .orderBy('scheduledDateTime')
          .get();

      _activeRides = activeQuery.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();

      // Load past rides with error handling for index building
      try {
        final pastQuery = await FirebaseFirestore.instance
            .collection('scheduled_bookings')
            .where('userId', isEqualTo: user.uid)
            .where('status', whereIn: ['completed', 'cancelled'])
            .orderBy('scheduledDateTime', descending: true)
            .limit(20)
            .get();

        _pastRides = pastQuery.docs.map((doc) {
          final data = doc.data();
          data['id'] = doc.id;
          return data;
        }).toList();
      } catch (e) {
        // If index is still building, try a simpler query
        print('⚠️ Firestore index still building for past rides. Using fallback query.');
        try {
          final fallbackQuery = await FirebaseFirestore.instance
              .collection('scheduled_bookings')
              .where('userId', isEqualTo: user.uid)
              .get();

          _pastRides = fallbackQuery.docs
              .where((doc) {
                final status = doc.data()['status'] as String?;
                return status == 'completed' || status == 'cancelled';
              })
              .take(20)
              .map((doc) {
                final data = doc.data();
                data['id'] = doc.id;
                return data;
              })
              .toList();
        } catch (fallbackError) {
          print('❌ Fallback query also failed: $fallbackError');
          _pastRides = [];
        }
      }

      setState(() => _isLoading = false);
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${AppLocalizations.of(context)?.translate('error_loading_bookings') ?? 'Error loading bookings'}: $e')),
      );
    }
  }

  Future<void> _cancelBooking(String bookingId) async {
    try {
      // Get the booking details first
      final bookingDoc = await FirebaseFirestore.instance
          .collection('scheduled_bookings')
          .doc(bookingId)
          .get();
      
      if (!bookingDoc.exists) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)?.translate('booking_not_found') ?? 'Booking not found')),
        );
        return;
      }

      final bookingData = bookingDoc.data()!;
      final scheduledDateTime = (bookingData['scheduledDateTime'] as Timestamp).toDate();
      final bookingTime = (bookingData['bookingTime'] as Timestamp).toDate();
      final now = DateTime.now();
      
      // Calculate time differences
      final timeUntilScheduled = scheduledDateTime.difference(now).inMinutes;
      final timeSinceBooking = now.difference(bookingTime).inMinutes;
      
      String message;
      bool canCancel = false;
      
      // Check cancellation policy
      if (timeSinceBooking <= 10) {
        // Free cancellation within 10 minutes of booking
        message = 'Booking cancelled successfully (free cancellation)';
        canCancel = true;
      } else if (timeUntilScheduled >= 30) {
        // Full refund if cancelled 30+ minutes before trip
        message = 'Booking cancelled successfully (full refund)';
        canCancel = true;
      } else if (timeUntilScheduled > 0) {
        // Within 30 minutes - cancellation fee applies
        final cancellationFee = bookingData['cancellationFee'] ?? 0.0;
        message = 'Booking cancelled. Cancellation fee of R${cancellationFee.toStringAsFixed(2)} will be charged.';
        canCancel = true;
      } else {
        // Trip has already started or completed
        message = 'Cannot cancel a trip that has already started';
        canCancel = false;
      }
      
      if (canCancel) {
        await FirebaseFirestore.instance
            .collection('scheduled_bookings')
            .doc(bookingId)
            .update({
          'status': 'cancelled',
          'cancelledAt': FieldValue.serverTimestamp(),
          'cancellationReason': 'User cancelled',
          'refundAmount': timeSinceBooking <= 10 || timeUntilScheduled >= 30 
              ? bookingData['estimatedFare'] 
              : (bookingData['estimatedFare'] - (bookingData['cancellationFee'] ?? 0.0)),
        });

        await _loadBookings();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${AppLocalizations.of(context)?.translate('error_cancelling_booking') ?? 'Error cancelling booking'}: $e')),
      );
    }
  }

  Future<void> _setReminder(String bookingId, bool enabled) async {
    try {
      await FirebaseFirestore.instance
          .collection('scheduled_bookings')
          .doc(bookingId)
          .update({
        'reminderEnabled': enabled,
        'reminderSetAt': enabled ? FieldValue.serverTimestamp() : null,
      });

      await _loadBookings();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(enabled ? 'Reminder set successfully' : 'Reminder disabled'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${AppLocalizations.of(context)?.translate('error_setting_reminder') ?? 'Error setting reminder'}: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;

    return Scaffold(
      backgroundColor: AppColors.getBackgroundColor(isDark),
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)?.translate('my_bookings') ?? 'My Bookings'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: AppColors.getIconColor(isDark)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadBookings,
            tooltip: 'Refresh',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.primary,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.getTextSecondaryColor(isDark),
          tabs: [
            Tab(text: AppLocalizations.of(context)?.translate('scheduled') ?? 'Scheduled'),
            Tab(text: AppLocalizations.of(context)?.translate('active_ride') ?? 'Active'),
            Tab(text: AppLocalizations.of(context)?.translate('past') ?? 'Past'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: LoadingIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildScheduledTab(isDark),
                _buildActiveTab(isDark),
                _buildPastTab(isDark),
              ],
            ),
    );
  }

  Widget _buildScheduledTab(bool isDark) {
    if (_scheduledBookings.isEmpty) {
      return _buildEmptyState(
        isDark,
        AppLocalizations.of(context)?.translate('no_scheduled_trips') ?? 'No Scheduled Trips',
        AppLocalizations.of(context)?.translate('no_scheduled_trips_desc') ?? 'You don\'t have any scheduled trips yet.',
        Icons.schedule,
        AppLocalizations.of(context)?.translate('schedule_ride') ?? 'Schedule a Trip',
        () {
          Navigator.of(context).pop();
        },
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _scheduledBookings.length,
      itemBuilder: (context, index) {
        final booking = _scheduledBookings[index];
        return _buildScheduledBookingCard(booking, isDark);
      },
    );
  }

  Widget _buildActiveTab(bool isDark) {
    if (_activeRides.isEmpty) {
      return _buildEmptyState(
        isDark,
        AppLocalizations.of(context)?.translate('no_active_rides') ?? 'No Active Rides',
        AppLocalizations.of(context)?.translate('no_active_rides_desc') ?? 'You don\'t have any active rides at the moment.',
        Icons.local_taxi,
        AppLocalizations.of(context)?.translate('book_ride') ?? 'Book a Ride',
        () {
          Navigator.of(context).pop();
        },
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _activeRides.length,
      itemBuilder: (context, index) {
        final booking = _activeRides[index];
        return _buildActiveRideCard(booking, isDark);
      },
    );
  }

  Widget _buildPastTab(bool isDark) {
    if (_pastRides.isEmpty) {
      return _buildEmptyState(
        isDark,
        AppLocalizations.of(context)?.translate('no_past_rides') ?? 'No Past Rides',
        AppLocalizations.of(context)?.translate('no_rides_desc') ?? 'Your ride history will appear here.',
        Icons.history,
        AppLocalizations.of(context)?.translate('book_ride') ?? 'Book a Ride',
        () {
          Navigator.of(context).pop();
        },
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _pastRides.length,
      itemBuilder: (context, index) {
        final booking = _pastRides[index];
        return _buildPastRideCard(booking, isDark);
      },
    );
  }

  Widget _buildScheduledBookingCard(Map<String, dynamic> booking, bool isDark) {
    final scheduledDateTime = (booking['scheduledDateTime'] as Timestamp).toDate();
    final scheduledTime = TimeOfDay.fromDateTime(scheduledDateTime).format(context);
    final isUpcoming = scheduledDateTime.isAfter(DateTime.now());
    final reminderEnabled = booking['reminderEnabled'] ?? false;
    final cancellationFee = booking['cancellationFee'] ?? 0.0;
    final totalPrice = booking['estimatedFare'] ?? 0.0;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppColors.getCardColor(isDark),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.getBorderColor(isDark)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with status and actions
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: isUpcoming ? Colors.orange.withOpacity(0.1) : Colors.grey.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    isUpcoming ? 'Upcoming' : 'Today',
                    style: TextStyle(
                      color: isUpcoming ? Colors.orange : Colors.grey,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ),
                const Spacer(),
                PopupMenuButton<String>(
                  icon: Icon(
                    Icons.more_vert,
                    color: AppColors.getIconColor(isDark),
                  ),
                  onSelected: (value) {
                    switch (value) {
                      case 'cancel':
                        _showCancelDialog(booking['id']);
                        break;
                      case 'reminder':
                        _setReminder(booking['id'], !reminderEnabled);
                        break;
                      case 'edit':
                        // TODO: Implement edit functionality
                        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(AppLocalizations.of(context)?.translate('edit_coming_soon') ?? 'Edit functionality coming soon!')),
          );
                        break;
                    }
                  },
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: 'reminder',
                      child: Row(
                        children: [
                          Icon(
                            reminderEnabled ? Icons.notifications_off : Icons.notifications,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(reminderEnabled ? 'Disable Reminder' : 'Set Reminder'),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'edit',
                      child: Row(
                        children: [
                          Icon(Icons.edit, size: 20),
                          const SizedBox(width: 8),
                          Text(AppLocalizations.of(context)?.translate('edit') ?? 'Edit'),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'cancel',
                      child: Row(
                        children: [
                          Icon(Icons.cancel, size: 20, color: Colors.red),
                          const SizedBox(width: 8),
                          Text(AppLocalizations.of(context)?.translate('cancel') ?? 'Cancel', style: const TextStyle(color: Colors.red)),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
            
            const SizedBox(height: 16),

            // Date and Time
            Row(
              children: [
                Icon(
                  Icons.schedule,
                  color: AppColors.primary,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  '${DateFormat('EEEE, MMMM d, y').format(scheduledDateTime)} at $scheduledTime',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.getTextPrimaryColor(isDark),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Locations
            _buildLocationRow(
              Icons.my_location,
              'From',
              booking['pickupAddress'],
              isDark,
            ),
            const SizedBox(height: 8),
            _buildLocationRow(
              Icons.location_on,
              'To',
              booking['dropoffAddress'],
              isDark,
            ),

            const SizedBox(height: 16),

            // Vehicle and Price
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.directions_car,
                    color: AppColors.primary,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        booking['vehicleType'] ?? 'Standard',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.getTextPrimaryColor(isDark),
                        ),
                      ),
                      Text(
                        'Payment: ${booking['paymentType']}',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.getTextSecondaryColor(isDark),
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'R${totalPrice.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                    Text(
                      'Fee: R${cancellationFee.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.getTextSecondaryColor(isDark),
                      ),
                    ),
                  ],
                ),
              ],
            ),

            // Cancellation Policy Info
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.05),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.withOpacity(0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.blue, size: 14),
                      const SizedBox(width: 6),
                      Text(
                        'Cancellation Policy',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.getTextPrimaryColor(isDark),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '• Free cancellation within 10 min of booking\n'
                    '• Full refund if cancelled 30+ min before trip\n'
                    '• R${cancellationFee.toStringAsFixed(2)} fee if cancelled within 30 min',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.getTextSecondaryColor(isDark),
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),

            // Reminder indicator
            if (reminderEnabled) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.notifications_active,
                      color: Colors.green,
                      size: 16,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Reminder set',
                      style: TextStyle(
                        color: Colors.green,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildActiveRideCard(Map<String, dynamic> booking, bool isDark) {
    final scheduledDateTime = (booking['scheduledDateTime'] as Timestamp).toDate();
    final scheduledTime = TimeOfDay.fromDateTime(scheduledDateTime).format(context);
    final driverName = booking['driverName'] ?? 'Driver';
    final driverPhone = booking['driverPhone'] ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppColors.getCardColor(isDark),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withOpacity(0.3)),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    AppLocalizations.of(context)?.translate('active_ride') ?? 'Active',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ),
                const Spacer(),
                Icon(
                  Icons.local_taxi,
                  color: AppColors.primary,
                  size: 24,
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Date and Time
            Row(
              children: [
                Icon(
                  Icons.schedule,
                  color: AppColors.primary,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  '${DateFormat('EEEE, MMMM d, y').format(scheduledDateTime)} at $scheduledTime',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.getTextPrimaryColor(isDark),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Locations
            _buildLocationRow(
              Icons.my_location,
              'From',
              booking['pickupAddress'],
              isDark,
            ),
            const SizedBox(height: 8),
            _buildLocationRow(
              Icons.location_on,
              'To',
              booking['dropoffAddress'],
              isDark,
            ),

            const SizedBox(height: 16),

            // Driver Info
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.getBackgroundColor(isDark),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.getBorderColor(isDark)),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: AppColors.primary.withOpacity(0.1),
                    child: Icon(
                      Icons.person,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          driverName,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppColors.getTextPrimaryColor(isDark),
                          ),
                        ),
                        Text(
                          'Your driver',
                          style: TextStyle(
                            fontSize: 14,
                            color: AppColors.getTextSecondaryColor(isDark),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (driverPhone.isNotEmpty)
                    IconButton(
                      onPressed: () => _makePhoneCall(driverPhone),
                      icon: Icon(
                        Icons.phone,
                        color: AppColors.primary,
                      ),
                      tooltip: 'Call driver',
                    ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Action buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => RideProgressScreen(
                            rideId: booking['id'],
                            pickupAddress: booking['pickupAddress'] ?? '',
                            dropoffAddress: booking['dropoffAddress'] ?? '',
                          ),
                        ),
                      );
                    },
                    icon: const Icon(Icons.location_on),
                    label: Text(AppLocalizations.of(context)?.translate('track') ?? 'Track'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _openChat(booking),
                    icon: const Icon(Icons.chat),
                    label: Text(AppLocalizations.of(context)?.translate('chat') ?? 'Chat'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPastRideCard(Map<String, dynamic> booking, bool isDark) {
    final scheduledDateTime = (booking['scheduledDateTime'] as Timestamp).toDate();
    final scheduledTime = TimeOfDay.fromDateTime(scheduledDateTime).format(context);
    final status = booking['status'] as String;
    final isCompleted = status == 'completed';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppColors.getCardColor(isDark),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.getBorderColor(isDark)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: isCompleted 
                        ? Colors.green.withOpacity(0.1)
                        : Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    isCompleted ? 'Completed' : 'Cancelled',
                    style: TextStyle(
                      color: isCompleted ? Colors.green : Colors.red,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ),
                const Spacer(),
                Text(
                  DateFormat('MMM d, y').format(scheduledDateTime),
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.getTextSecondaryColor(isDark),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Date and Time
            Row(
              children: [
                Icon(
                  Icons.schedule,
                  color: AppColors.getTextSecondaryColor(isDark),
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  '${DateFormat('EEEE, MMMM d, y').format(scheduledDateTime)} at $scheduledTime',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.getTextPrimaryColor(isDark),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Locations
            _buildLocationRow(
              Icons.my_location,
              'From',
              booking['pickupAddress'],
              isDark,
            ),
            const SizedBox(height: 8),
            _buildLocationRow(
              Icons.location_on,
              'To',
              booking['dropoffAddress'],
              isDark,
            ),

            const SizedBox(height: 16),

            // Vehicle and Price
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.getTextSecondaryColor(isDark).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.directions_car,
                    color: AppColors.getTextSecondaryColor(isDark),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        booking['vehicleType'] ?? 'Standard',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.getTextPrimaryColor(isDark),
                        ),
                      ),
                      Text(
                        'Payment: ${booking['paymentType']}',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.getTextSecondaryColor(isDark),
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  'R${booking['price']}',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.getTextSecondaryColor(isDark),
                  ),
                ),
              ],
            ),

            if (isCompleted) ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _rebookRide(booking),
                      icon: const Icon(Icons.replay),
                      label: Text(AppLocalizations.of(context)?.translate('rebook') ?? 'Rebook'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _showRatingDialog(booking),
                      icon: const Icon(Icons.star),
                      label: Text(AppLocalizations.of(context)?.translate('rate_driver') ?? 'Rate'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildLocationRow(IconData icon, String label, String address, bool isDark) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          color: AppColors.getTextSecondaryColor(isDark),
          size: 16,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.getTextSecondaryColor(isDark),
                ),
              ),
              Text(
                address,
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.getTextPrimaryColor(isDark),
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState(bool isDark, String title, String message, IconData icon, String actionText, VoidCallback onAction) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.getCardColor(isDark),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.getBorderColor(isDark)),
              ),
              child: Icon(
                icon,
                size: 80,
                color: AppColors.getTextSecondaryColor(isDark),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              title,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: AppColors.getTextPrimaryColor(isDark),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              message,
              style: TextStyle(
                fontSize: 16,
                color: AppColors.getTextSecondaryColor(isDark),
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: onAction,
              icon: Icon(icon),
              label: Text(actionText),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showCancelDialog(String bookingId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.cancel, color: Colors.red, size: 28),
            const SizedBox(width: 12),
            Text(AppLocalizations.of(context)?.translate('cancel_booking') ?? 'Cancel Booking'),
          ],
        ),
        content: Text(
          AppLocalizations.of(context)?.translate('are_you_sure_cancel_trip') ?? 'Are you sure you want to cancel this scheduled trip? This action cannot be undone.',
          style: const TextStyle(fontSize: 16),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(AppLocalizations.of(context)?.translate('keep') ?? 'Keep'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              _cancelBooking(bookingId);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text(AppLocalizations.of(context)?.translate('cancel_ride') ?? 'Cancel Trip', style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _showRatingDialog(Map<String, dynamic> booking) async {
    final driverId = booking['driverId'] as String?;
    final bookingId = booking['id'] as String;
    final driverName = booking['driverName'] as String? ?? 'Driver';

    if (driverId == null || driverId.isEmpty) {
      ModernSnackBar.show(
        context,
        message: 'Driver information not available for this ride',
        isError: true,
      );
      return;
    }

    // Check if already rated
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final ratingDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(driverId)
            .collection('ratings')
            .doc(bookingId)
            .get();

        if (ratingDoc.exists) {
          ModernSnackBar.show(
            context,
            message: 'You have already rated this driver',
            isError: true,
          );
          return;
        }
      }
    } catch (e) {
      // Continue to show dialog even if check fails
    }

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) => RatingDialog(
        isDriverRating: false,
        receiverName: driverName,
        onSubmit: (rating, notes, report) async {
          try {
            await DatabaseService().rateDriver(
              rideId: bookingId,
              driverId: driverId,
              rating: rating,
              notes: notes?.isEmpty ?? true ? null : notes,
              report: report?.isEmpty ?? true ? null : report,
            );

            if (mounted) {
              ModernSnackBar.show(
                context,
                message: AppLocalizations.of(context)?.translate('thank_you_rating') ?? 'Thank you for your rating!',
              );
              // Reload bookings to reflect the change
              await _loadBookings();
            }
          } catch (e) {
            if (mounted) {
              ModernSnackBar.show(
                context,
                message: '${AppLocalizations.of(context)?.translate('failed_submit_rating') ?? 'Failed to submit rating'}: $e',
                isError: true,
              );
            }
          }
        },
      ),
    );
  }

  void _rebookRide(Map<String, dynamic> booking) {
    final pickupAddress = booking['pickupAddress'] as String?;
    final dropoffAddress = booking['dropoffAddress'] as String?;
    final pickupCoordinates = booking['pickupCoordinates'] as List<dynamic>?;
    final dropoffCoordinates = booking['dropoffCoordinates'] as List<dynamic>?;
    final vehicleType = booking['vehicleType'] as String?;
    final paymentType = booking['paymentType'] as String?;

    if (pickupAddress == null || dropoffAddress == null) {
      ModernSnackBar.show(
        context,
        message: AppLocalizations.of(context)?.translate('cannot_rebook') ?? 'Cannot rebook: Missing location information',
        isError: true,
      );
      return;
    }

    // Convert coordinates if available
    List<double>? pickupCoords;
    List<double>? dropoffCoords;
    
    if (pickupCoordinates != null) {
      pickupCoords = pickupCoordinates.map((e) => (e as num).toDouble()).toList();
    }
    if (dropoffCoordinates != null) {
      dropoffCoords = dropoffCoordinates.map((e) => (e as num).toDouble()).toList();
    }

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => RequestRideScreen(
          initialPickupAddress: pickupAddress,
          initialDropoffAddress: dropoffAddress,
          initialPickupCoordinates: pickupCoords,
          initialDropoffCoordinates: dropoffCoords,
          initialVehicleType: vehicleType,
          initialPaymentType: paymentType,
        ),
      ),
    );
  }

  Future<void> _makePhoneCall(String phoneNumber) async {
    // Remove any non-digit characters except +
    final cleanedNumber = phoneNumber.replaceAll(RegExp(r'[^\d+]'), '');
    
    // Ensure the number starts with + or add country code if needed
    String phoneUrl;
    if (cleanedNumber.startsWith('+')) {
      phoneUrl = 'tel:$cleanedNumber';
    } else if (cleanedNumber.startsWith('0')) {
      // Replace leading 0 with +27 for South Africa
      phoneUrl = 'tel:+27${cleanedNumber.substring(1)}';
    } else {
      // Assume it's a local number, add +27
      phoneUrl = 'tel:+27$cleanedNumber';
    }

    try {
      final uri = Uri.parse(phoneUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else {
        if (mounted) {
          ModernSnackBar.show(
            context,
            message: 'Cannot make phone call. Please check your device settings.',
            isError: true,
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ModernSnackBar.show(
          context,
          message: 'Error making phone call: $e',
          isError: true,
        );
      }
    }
  }

  Future<void> _openChat(Map<String, dynamic> booking) async {
    final driverId = booking['driverId'] as String?;
    final user = FirebaseAuth.instance.currentUser;
    
    if (driverId == null || driverId.isEmpty) {
      ModernSnackBar.show(
        context,
        message: 'Driver information not available for this ride',
        isError: true,
      );
      return;
    }

    if (user == null) {
      ModernSnackBar.show(
        context,
        message: 'Please log in to use chat',
        isError: true,
      );
      return;
    }

    try {
      // Get driver user model
      final driverUser = await DatabaseService().getUserById(driverId);
      if (driverUser == null) {
        ModernSnackBar.show(
          context,
          message: 'Driver information not found',
          isError: true,
        );
        return;
      }

      // Create or get chat ID (same pattern as other screens)
      final participants = [user.uid, driverId]..sort();
      final chatId = participants.join('_');

      // Ensure chat exists in database
      await DatabaseService().createOrGetChat(driverId, user.uid);

      if (mounted) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => ChatScreen(
              chatId: chatId,
              receiver: driverUser,
              currentUserId: user.uid,
            ),
          ),
        );
        // Mark messages as read
        await DatabaseService().markMessagesAsRead(chatId, user.uid);
      }
    } catch (e) {
      if (mounted) {
        ModernSnackBar.show(
          context,
          message: 'Error opening chat: $e',
          isError: true,
        );
      }
    }
  }
} 