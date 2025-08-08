import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../../../constants/app_colors.dart';
import '../../../providers/theme_provider.dart';

import '../../../widgets/common/loading_indicator.dart';

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
        SnackBar(content: Text('Error loading bookings: $e')),
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
          const SnackBar(content: Text('Booking not found')),
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
        SnackBar(content: Text('Error cancelling booking: $e')),
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
        SnackBar(content: Text('Error setting reminder: $e')),
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
        title: const Text('My Bookings'),
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
          tabs: const [
            Tab(text: 'Scheduled'),
            Tab(text: 'Active'),
            Tab(text: 'Past'),
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
        'No Scheduled Trips',
        'You don\'t have any scheduled trips yet.',
        Icons.schedule,
        'Schedule a Trip',
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
        'No Active Rides',
        'You don\'t have any active rides at the moment.',
        Icons.local_taxi,
        'Book a Ride',
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
        'No Past Rides',
        'Your ride history will appear here.',
        Icons.history,
        'Book a Ride',
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
            const SnackBar(content: Text('Edit functionality coming soon!')),
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
                          const Text('Edit'),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'cancel',
                      child: Row(
                        children: [
                          Icon(Icons.cancel, size: 20, color: Colors.red),
                          const SizedBox(width: 8),
                          const Text('Cancel', style: TextStyle(color: Colors.red)),
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
                    'Active',
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
                      onPressed: () {
                        // TODO: Implement call functionality
                        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Call functionality coming soon!')),
          );
                      },
                      icon: Icon(
                        Icons.phone,
                        color: AppColors.primary,
                      ),
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
                      // TODO: Navigate to tracking screen
                      ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Tracking screen coming soon!')),
          );
                    },
                    icon: const Icon(Icons.location_on),
                    label: const Text('Track'),
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
                    onPressed: () {
                      // TODO: Navigate to chat screen
                      ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Chat functionality coming soon!')),
          );
                    },
                    icon: const Icon(Icons.chat),
                    label: const Text('Chat'),
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
                      onPressed: () {
                        // TODO: Implement rebook functionality
                        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Rebook functionality coming soon!')),
          );
                      },
                      icon: const Icon(Icons.replay),
                      label: const Text('Rebook'),
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
                      onPressed: () {
                        // TODO: Implement rating functionality
                        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Rating functionality coming soon!')),
          );
                      },
                      icon: const Icon(Icons.star),
                      label: const Text('Rate'),
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
            const Text('Cancel Booking'),
          ],
        ),
        content: const Text(
          'Are you sure you want to cancel this scheduled trip? This action cannot be undone.',
          style: TextStyle(fontSize: 16),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Keep'),
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
            child: const Text('Cancel Trip', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
} 