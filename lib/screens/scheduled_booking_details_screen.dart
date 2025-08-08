import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

import '../constants/app_colors.dart';
import '../models/driver_model.dart';
import '../models/user_model.dart';
import '../services/database_service.dart';
import '../services/scheduled_reminder_service.dart';
import '../widgets/common/modern_alert_dialog.dart';

class ScheduledBookingDetailsScreen extends StatefulWidget {
  final String bookingId;
  final bool isDriver;

  const ScheduledBookingDetailsScreen({
    required this.bookingId,
    required this.isDriver,
    Key? key,
  }) : super(key: key);

  @override
  State<ScheduledBookingDetailsScreen> createState() => _ScheduledBookingDetailsScreenState();
}

class _ScheduledBookingDetailsScreenState extends State<ScheduledBookingDetailsScreen>
    with TickerProviderStateMixin {
  Map<String, dynamic>? _bookingData;
  UserModel? _passengerData;
  DriverModel? _driverData;
  bool _isLoading = true;
  bool _showContactInfo = false;
  
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _loadBookingDetails();
  }

  void _initializeAnimations() {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
    
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutBack,
    ));
    
    _animationController.forward();
  }

  Future<void> _loadBookingDetails() async {
    try {
      final databaseService = DatabaseService();
      final booking = await databaseService.getScheduledRequestById(widget.bookingId);
      
      if (booking != null) {
        setState(() {
          _bookingData = booking;
        });
        
        // Load user details
        if (widget.isDriver) {
          // Driver viewing - load passenger details
          final passenger = await databaseService.getUserById(booking['userId']);
          setState(() {
            _passengerData = passenger;
          });
        } else {
          // Passenger viewing - load driver details if accepted
          if (booking['driverId'] != null) {
            final driver = await databaseService.getCurrentDriver();
            setState(() {
              _driverData = driver;
            });
          }
        }
      }
    } catch (e) {
      ModernSnackBar.show(context, message: 'Error loading booking details: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  bool _canShowContactInfo() {
    if (_bookingData == null) return false;
    
    final scheduledDateTime = (_bookingData!['scheduledDateTime'] as Timestamp).toDate();
    final now = DateTime.now();
    final timeUntilPickup = scheduledDateTime.difference(now);
    
    // Show contact info 30 minutes before pickup
    return timeUntilPickup.inMinutes <= 30;
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    if (_isLoading) {
      return Scaffold(
        backgroundColor: AppColors.getBackgroundColor(isDark),
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_bookingData == null) {
      return Scaffold(
        backgroundColor: AppColors.getBackgroundColor(isDark),
        appBar: AppBar(
          backgroundColor: AppColors.getBackgroundColor(isDark),
          title: Text(
            'Booking Details',
            style: TextStyle(color: AppColors.getTextPrimaryColor(isDark)),
          ),
          leading: IconButton(
            icon: Icon(Icons.arrow_back, color: AppColors.getTextPrimaryColor(isDark)),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: Center(
          child: Text(
            'Booking not found',
            style: TextStyle(color: AppColors.getTextPrimaryColor(isDark)),
          ),
        ),
      );
    }

    final scheduledDateTime = (_bookingData!['scheduledDateTime'] as Timestamp).toDate();
    final timeUntilPickup = scheduledDateTime.difference(DateTime.now());
    final isUrgent = timeUntilPickup.inMinutes <= 15;
    final canShowContact = _canShowContactInfo();

    return Scaffold(
      backgroundColor: AppColors.getBackgroundColor(isDark),
      appBar: AppBar(
        backgroundColor: AppColors.getBackgroundColor(isDark),
        elevation: 0,
        title: Text(
          'Scheduled Trip',
          style: TextStyle(color: AppColors.getTextPrimaryColor(isDark)),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: AppColors.getTextPrimaryColor(isDark)),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: SlideTransition(
          position: _slideAnimation,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Status and countdown card
                _buildStatusCard(isDark, scheduledDateTime, timeUntilPickup, isUrgent),
                
                const SizedBox(height: 24),
                
                // Trip details card
                _buildTripDetailsCard(isDark),
                
                const SizedBox(height: 24),
                
                // Contact information card (only shown 30 min before)
                if (canShowContact) ...[
                  _buildContactCard(isDark),
                  const SizedBox(height: 24),
                ],
                
                // Action buttons
                _buildActionButtons(isDark, canShowContact),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusCard(bool isDark, DateTime scheduledDateTime, Duration timeUntilPickup, bool isUrgent) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isUrgent
              ? [Colors.red.shade400, Colors.orange.shade400]
              : [AppColors.primary, AppColors.primary.withOpacity(0.8)],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: (isUrgent ? Colors.red : AppColors.primary).withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(
                isUrgent ? Icons.warning : Icons.schedule,
                color: Colors.white,
                size: 28,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isUrgent ? 'URGENT - Trip Starting Soon!' : 'Scheduled Trip',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '${DateFormat('EEEE, MMMM d, y').format(scheduledDateTime)} at ${DateFormat('HH:mm').format(scheduledDateTime)}',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.9),
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                Text(
                  'Time Until Pickup',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _formatCountdown(timeUntilPickup),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTripDetailsCard(bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.getCardColor(isDark),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.getBorderColor(isDark)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.info_outline,
                color: AppColors.primary,
                size: 24,
              ),
              const SizedBox(width: 12),
              Text(
                'Trip Details',
                style: TextStyle(
                  color: AppColors.getTextPrimaryColor(isDark),
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 20),
          
          _buildDetailRow(
            Icons.location_on,
            'Pickup Location',
            _bookingData!['pickupAddress'] ?? '',
            isDark,
          ),
          
          const SizedBox(height: 16),
          
          _buildDetailRow(
            Icons.location_on_outlined,
            'Dropoff Location',
            _bookingData!['dropoffAddress'] ?? '',
            isDark,
          ),
          
          const SizedBox(height: 16),
          
          _buildDetailRow(
            Icons.directions_car,
            'Vehicle Type',
            _bookingData!['vehicleType'] ?? 'Standard',
            isDark,
          ),
          
          const SizedBox(height: 16),
          
          _buildDetailRow(
            Icons.attach_money,
            'Estimated Fare',
            'R${(_bookingData!['estimatedFare'] ?? 0.0).toStringAsFixed(2)}',
            isDark,
          ),
          
          const SizedBox(height: 16),
          
          _buildDetailRow(
            Icons.payment,
            'Payment Method',
            _bookingData!['paymentType'] ?? 'Cash',
            isDark,
          ),
          
          const SizedBox(height: 16),
          
          _buildDetailRow(
            Icons.people,
            'Passengers',
            '${_bookingData!['passengerCount'] ?? 1}',
            isDark,
          ),
        ],
      ),
    );
  }

  Widget _buildContactCard(bool isDark) {
    final contactData = widget.isDriver ? _passengerData : _driverData;
    
    if (contactData == null) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.getCardColor(isDark),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.getBorderColor(isDark)),
        ),
        child: Column(
          children: [
            Icon(
              Icons.person_outline,
              color: AppColors.getTextHintColor(isDark),
              size: 48,
            ),
            const SizedBox(height: 12),
            Text(
              widget.isDriver ? 'Passenger details not available' : 'Driver not assigned yet',
              style: TextStyle(
                color: AppColors.getTextSecondaryColor(isDark),
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.getCardColor(isDark),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.getBorderColor(isDark)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.contact_phone,
                color: AppColors.primary,
                size: 24,
              ),
              const SizedBox(width: 12),
              Text(
                widget.isDriver ? 'Passenger Contact' : 'Driver Contact',
                style: TextStyle(
                  color: AppColors.getTextPrimaryColor(isDark),
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 20),
          
          _buildContactRow(
            Icons.person,
            'Name',
            widget.isDriver 
                ? (contactData as UserModel?)?.name ?? 'Unknown'
                : (contactData as DriverModel?)?.name ?? 'Unknown',
            isDark,
          ),
          
          const SizedBox(height: 16),
          
          _buildContactRow(
            Icons.phone,
            'Phone',
            widget.isDriver 
                ? (contactData as UserModel?)?.phoneNumber ?? 'Unknown'
                : (contactData as DriverModel?)?.phoneNumber ?? 'Unknown',
            isDark,
            onTap: () => _callContact(
              widget.isDriver 
                  ? (contactData as UserModel?)?.phoneNumber ?? ''
                  : (contactData as DriverModel?)?.phoneNumber ?? ''
            ),
          ),
          
          if ((widget.isDriver 
                  ? (contactData as UserModel?)?.email?.isNotEmpty == true
                  : (contactData as DriverModel?)?.email?.isNotEmpty == true)) ...[
            const SizedBox(height: 16),
            _buildContactRow(
              Icons.email,
              'Email',
              widget.isDriver 
                  ? (contactData as UserModel?)?.email ?? ''
                  : (contactData as DriverModel?)?.email ?? '',
              isDark,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildActionButtons(bool isDark, bool canShowContact) {
    return Column(
      children: [
        if (widget.isDriver && _bookingData!['status'] == 'accepted') ...[
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _startTrip(),
              icon: const Icon(Icons.play_arrow),
              label: const Text('Start Trip'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],
        
        if (!widget.isDriver && _bookingData!['status'] == 'pending') ...[
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _cancelBooking(),
              icon: const Icon(Icons.cancel),
              label: const Text('Cancel Booking'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.red,
                side: const BorderSide(color: Colors.red),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
        
        if (canShowContact) ...[
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _showMap(),
              icon: const Icon(Icons.map),
              label: const Text('View on Map'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                side: BorderSide(color: AppColors.primary),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value, bool isDark) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
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
                label,
                style: TextStyle(
                  color: AppColors.getTextSecondaryColor(isDark),
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                value,
                style: TextStyle(
                  color: AppColors.getTextPrimaryColor(isDark),
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
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

  Widget _buildContactRow(IconData icon, String label, String value, bool isDark, {VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
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
                  label,
                  style: TextStyle(
                    color: AppColors.getTextSecondaryColor(isDark),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  value,
                  style: TextStyle(
                    color: AppColors.getTextPrimaryColor(isDark),
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          if (onTap != null)
            Icon(
              Icons.arrow_forward_ios,
              color: AppColors.getTextSecondaryColor(isDark),
              size: 16,
            ),
        ],
      ),
    );
  }

  String _formatCountdown(Duration duration) {
    if (duration.inDays > 0) {
      return '${duration.inDays}d ${duration.inHours % 24}h ${duration.inMinutes % 60}m';
    } else if (duration.inHours > 0) {
      return '${duration.inHours}h ${duration.inMinutes % 60}m';
    } else if (duration.inMinutes > 0) {
      return '${duration.inMinutes}m ${duration.inSeconds % 60}s';
    } else {
      return '${duration.inSeconds}s';
    }
  }

  void _callContact(String phoneNumber) {
    // Implement phone call functionality
    ModernSnackBar.show(context, message: 'Calling $phoneNumber...');
  }

  void _startTrip() {
    // Implement start trip functionality
    ModernSnackBar.show(context, message: 'Starting trip...');
  }

  void _cancelBooking() {
    // Implement cancel booking functionality
    ModernSnackBar.show(context, message: 'Cancelling booking...');
  }

  void _showMap() {
    // Implement map view functionality
    ModernSnackBar.show(context, message: 'Opening map...');
  }
} 