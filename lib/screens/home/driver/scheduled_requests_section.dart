import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../constants/app_colors.dart';
import '../../../models/driver_model.dart';
import '../../../services/database_service.dart';
import '../../../widgets/common/modern_alert_dialog.dart';

import '../../../screens/chat/chat_screen.dart';

class ScheduledRequestsSection extends StatefulWidget {
  final bool isDark;

  const ScheduledRequestsSection({required this.isDark, Key? key}) : super(key: key);

  @override
  State<ScheduledRequestsSection> createState() => _ScheduledRequestsSectionState();
}

class _ScheduledRequestsSectionState extends State<ScheduledRequestsSection> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }
  
  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.getBackgroundColor(widget.isDark),
      appBar: AppBar(
        title: Text(
          'Scheduled Requests',
          style: TextStyle(
            color: AppColors.getTextPrimaryColor(widget.isDark),
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: AppColors.getBackgroundColor(widget.isDark),
        elevation: 0,
        iconTheme: IconThemeData(color: AppColors.getTextPrimaryColor(widget.isDark)),
      ),
      body: FutureBuilder<DriverModel?>(
        future: DatabaseService().getCurrentDriver(),
        builder: (context, driverSnapshot) {
          if (!driverSnapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final driver = driverSnapshot.data!;
          
          // Check if driver is approved
          if (!driver.isApproved) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.lock, size: 60, color: AppColors.primary),
                    const SizedBox(height: 24),
                    Text(
                      'Your account is pending approval.',
                      style: TextStyle(
                        fontSize: 20, 
                        fontWeight: FontWeight.bold, 
                        color: AppColors.getTextPrimaryColor(widget.isDark)
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'You cannot view or accept scheduled requests until your account is approved by an admin.',
                      style: TextStyle(
                        fontSize: 16, 
                        color: AppColors.getTextSecondaryColor(widget.isDark)
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            );
          }
          
          if (driver.towns.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.schedule, color: AppColors.getTextHintColor(widget.isDark), size: 64),
                  const SizedBox(height: 16),
                  Text(
                    'No preferred towns set',
                    style: TextStyle(
                      color: AppColors.getTextSecondaryColor(widget.isDark),
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Set your preferred towns to see scheduled requests',
                    style: TextStyle(color: AppColors.getTextHintColor(widget.isDark), fontSize: 14),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            );
          }

          return Column(
            children: [
              // Tab bar
              Container(
                color: AppColors.getBackgroundColor(widget.isDark),
                child: TabBar(
                  controller: _tabController,
                  labelColor: AppColors.primary,
                  unselectedLabelColor: AppColors.getTextSecondaryColor(widget.isDark),
                  indicatorColor: AppColors.primary,
                  tabs: const [
                    Tab(text: 'Available'),
                    Tab(text: 'Accepted'),
                  ],
                ),
              ),
              
              // Tab content
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildAvailableRequestsTab(driver),
                    _buildAcceptedRequestsTab(driver),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildScheduledRequestCard(Map<String, dynamic> request, bool isDark) {
    final scheduledDateTime = (request['scheduledDateTime'] as Timestamp).toDate();
    final distance = request['distance'] as double? ?? 0.0;
    final timeUntilScheduled = request['timeUntilScheduled'] as int? ?? 0;
    final estimatedFare = request['estimatedFare'] as double? ?? 0.0;
    final pickupAddress = request['pickupAddress'] as String? ?? '';
    final dropoffAddress = request['dropoffAddress'] as String? ?? '';
    
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.getCardColor(isDark),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.getBorderColor(isDark), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with time and urgency
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.schedule,
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
                      'Scheduled Trip',
                      style: TextStyle(
                        color: AppColors.getTextPrimaryColor(isDark),
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '${DateFormat('MMM d, y').format(scheduledDateTime)} at ${DateFormat('HH:mm').format(scheduledDateTime)}',
                      style: TextStyle(
                        color: AppColors.getTextSecondaryColor(isDark),
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _getUrgencyColor(timeUntilScheduled).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  _getUrgencyText(timeUntilScheduled),
                  style: TextStyle(
                    color: _getUrgencyColor(timeUntilScheduled),
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          // Pickup and Dropoff addresses
          _buildLocationRow(
            Icons.location_on,
            'Pickup',
            pickupAddress,
            isDark,
          ),
          const SizedBox(height: 12),
          _buildLocationRow(
            Icons.location_on_outlined,
            'Dropoff',
            dropoffAddress,
            isDark,
          ),
          const SizedBox(height: 16),
          
          // Price and distance
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Distance',
                    style: TextStyle(
                      color: AppColors.getTextSecondaryColor(isDark),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    '${distance.toStringAsFixed(1)} km',
                    style: TextStyle(
                      color: AppColors.getTextPrimaryColor(isDark),
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'Fare',
                    style: TextStyle(
                      color: AppColors.getTextSecondaryColor(isDark),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    'R${estimatedFare.toStringAsFixed(2)}',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),
          
          // Accept button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => _showAcceptConfirmation(request),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
              child: const Text(
                'Accept Request',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
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
          size: 18,
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
                address,
                style: TextStyle(
                  color: AppColors.getTextPrimaryColor(isDark),
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
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

  Color _getUrgencyColor(int timeUntilScheduled) {
    if (timeUntilScheduled <= 5) return Colors.red;
    if (timeUntilScheduled <= 10) return Colors.orange;
    return Colors.green;
  }

  String _getUrgencyText(int timeUntilScheduled) {
    if (timeUntilScheduled <= 5) return 'URGENT';
    if (timeUntilScheduled <= 10) return 'SOON';
    return 'SCHEDULED';
  }

  Future<void> _showAcceptConfirmation(Map<String, dynamic> request) async {
    final scheduledDateTime = (request['scheduledDateTime'] as Timestamp).toDate();
    final estimatedFare = request['estimatedFare'] as double? ?? 0.0;
    final pickupAddress = request['pickupAddress'] as String? ?? '';
    final dropoffAddress = request['dropoffAddress'] as String? ?? '';
    
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.check_circle, color: AppColors.primary),
            const SizedBox(width: 8),
            const Text('Accept Request'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Are you sure you want to accept this scheduled request?',
              style: TextStyle(
                fontSize: 16,
                color: AppColors.getTextPrimaryColor(widget.isDark),
              ),
            ),
            const SizedBox(height: 16),
            _buildConfirmationRow('Date', DateFormat('MMM d, y').format(scheduledDateTime)),
            _buildConfirmationRow('Time', DateFormat('HH:mm').format(scheduledDateTime)),
            _buildConfirmationRow('Pickup', pickupAddress),
            _buildConfirmationRow('Dropoff', dropoffAddress),
            _buildConfirmationRow('Fare', 'R${estimatedFare.toStringAsFixed(2)}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
            child: const Text('Accept'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _acceptScheduledRequest(request);
    }
  }

  Widget _buildConfirmationRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 60,
            child: Text(
              '$label:',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: AppColors.getTextSecondaryColor(widget.isDark),
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 14,
                color: AppColors.getTextPrimaryColor(widget.isDark),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _acceptScheduledRequest(Map<String, dynamic> request) async {
    try {
      print('🔄 Accepting scheduled request: ${request['id']}');
      
      final driver = await DatabaseService().getCurrentDriver();
      if (driver == null) {
        ModernSnackBar.show(context, message: 'Driver profile not found');
        return;
      }

      await DatabaseService().acceptScheduledRequest(request['id'], driver.userId);
      
      print('✅ Scheduled request accepted successfully: ${request['id']}');
      
      // Show success popup with navigation option
      await _showSuccessPopup(request);
      
    } catch (e) {
      print('❌ Error accepting scheduled request: $e');
      ModernSnackBar.show(context, message: 'Error accepting request: $e');
    }
  }

  Future<void> _showSuccessPopup(Map<String, dynamic> request) async {
    final passengerId = request['userId'] as String?;
    if (passengerId == null) return;

    final passenger = await DatabaseService().getUserById(passengerId);
    if (passenger == null) return;

    final action = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green),
            const SizedBox(width: 8),
            const Text('Request Accepted!'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'You have successfully accepted the scheduled request.',
              style: TextStyle(
                fontSize: 16,
                color: AppColors.getTextPrimaryColor(widget.isDark),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Passenger: ${passenger.name}',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: AppColors.getTextSecondaryColor(widget.isDark),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'What would you like to do?',
              style: TextStyle(
                fontSize: 14,
                color: AppColors.getTextSecondaryColor(widget.isDark),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop('navigate'),
            child: const Text('Navigate to Passenger'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop('close'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
            child: const Text('Close'),
          ),
        ],
      ),
    );

    if (action == 'navigate') {
      await _navigateToPassenger(request);
    }
  }

  Future<void> _navigateToPassenger(Map<String, dynamic> request) async {
    try {
      final pickupCoordinates = request['pickupCoordinates'] as List?;
      if (pickupCoordinates == null || pickupCoordinates.length < 2) {
        ModernSnackBar.show(context, message: 'Invalid pickup coordinates');
        return;
      }

      final lat = pickupCoordinates[0].toDouble();
      final lng = pickupCoordinates[1].toDouble();
      
      final url = 'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng&travelmode=driving';
      final uri = Uri.parse(url);
      
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        ModernSnackBar.show(context, message: 'Could not open navigation app');
      }
    } catch (e) {
      ModernSnackBar.show(context, message: 'Error opening navigation: $e');
    }
  }

  Widget _buildAvailableRequestsTab(DriverModel driver) {
    return FutureBuilder<Position?>(
      future: Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high),
      builder: (context, locationSnapshot) {
        if (!locationSnapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final position = locationSnapshot.data!;
        
        return StreamBuilder<List<Map<String, dynamic>>>(
          stream: DatabaseService().getScheduledRequestsForDriver(driver.towns, position)
              .handleError((error) {
                print('⚠️ Using fallback query for scheduled requests');
                return DatabaseService().getScheduledRequestsForDriverFallback(driver.towns, position);
              }),
          builder: (context, requestsSnapshot) {
            final requests = requestsSnapshot.data ?? [];
            
            if (requests.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.schedule, color: AppColors.getTextHintColor(widget.isDark), size: 64),
                    const SizedBox(height: 16),
                    Text(
                      'No available requests',
                      style: TextStyle(
                        color: AppColors.getTextSecondaryColor(widget.isDark),
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Scheduled requests in your preferred towns will appear here',
                      style: TextStyle(color: AppColors.getTextHintColor(widget.isDark), fontSize: 14),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              );
            }

            return Column(
              children: [
                // Header with count
                Container(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Available Requests',
                        style: TextStyle(
                          color: AppColors.getTextPrimaryColor(widget.isDark),
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(
                          '${requests.length}',
                          style: TextStyle(
                            color: AppColors.primary,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Scrollable list
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: requests.length,
                    itemBuilder: (context, index) {
                      final request = requests[index];
                      return _buildScheduledRequestCard(request, widget.isDark);
                    },
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildAcceptedRequestsTab(DriverModel driver) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: DatabaseService().getDriverAcceptedScheduledRequests(driver.userId),
      builder: (context, requestsSnapshot) {
        final requests = requestsSnapshot.data ?? [];
        
        if (requests.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.check_circle, color: AppColors.getTextHintColor(widget.isDark), size: 64),
                const SizedBox(height: 16),
                Text(
                  'No accepted requests',
                  style: TextStyle(
                    color: AppColors.getTextSecondaryColor(widget.isDark),
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Your accepted scheduled requests will appear here',
                  style: TextStyle(color: AppColors.getTextHintColor(widget.isDark), fontSize: 14),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }

        return Column(
          children: [
            // Header with count
            Container(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Accepted Requests',
                    style: TextStyle(
                      color: AppColors.getTextPrimaryColor(widget.isDark),
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      '${requests.length}',
                      style: TextStyle(
                        color: Colors.green,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            // Scrollable list
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: requests.length,
                itemBuilder: (context, index) {
                  final request = requests[index];
                  return _buildAcceptedRequestCard(request, widget.isDark);
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildAcceptedRequestCard(Map<String, dynamic> request, bool isDark) {
    final scheduledDateTime = (request['scheduledDateTime'] as Timestamp).toDate();
    final estimatedFare = request['estimatedFare'] as double? ?? 0.0;
    final pickupAddress = request['pickupAddress'] as String? ?? '';
    final dropoffAddress = request['dropoffAddress'] as String? ?? '';
    final timeUntilScheduled = request['timeUntilScheduled'] as int? ?? 0;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.getCardColor(isDark),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.green.withOpacity(0.3), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with time and status
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.check_circle,
                  color: Colors.green,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Accepted Trip',
                      style: TextStyle(
                        color: AppColors.getTextPrimaryColor(isDark),
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '${DateFormat('MMM d, y').format(scheduledDateTime)} at ${DateFormat('HH:mm').format(scheduledDateTime)}',
                      style: TextStyle(
                        color: AppColors.getTextSecondaryColor(isDark),
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _getUrgencyColor(timeUntilScheduled).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  _getUrgencyText(timeUntilScheduled),
                  style: TextStyle(
                    color: _getUrgencyColor(timeUntilScheduled),
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          // Pickup and Dropoff addresses
          _buildLocationRow(
            Icons.location_on,
            'Pickup',
            pickupAddress,
            isDark,
          ),
          const SizedBox(height: 12),
          _buildLocationRow(
            Icons.location_on_outlined,
            'Dropoff',
            dropoffAddress,
            isDark,
          ),
          const SizedBox(height: 16),
          
          // Price
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Fare:',
                style: TextStyle(
                  color: AppColors.getTextSecondaryColor(isDark),
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                'R${estimatedFare.toStringAsFixed(2)}',
                style: TextStyle(
                  color: AppColors.primary,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          
          // Action buttons
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _navigateToPassenger(request),
                  icon: const Icon(Icons.navigation, size: 18),
                  label: const Text('Navigate'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _openChat(request),
                  icon: const Icon(Icons.message, size: 18),
                  label: const Text('Message'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side: BorderSide(color: AppColors.primary),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _openChat(Map<String, dynamic> request) async {
    try {
      final passengerId = request['userId'] as String?;
      if (passengerId == null) {
        ModernSnackBar.show(context, message: 'Passenger information not found');
        return;
      }

      final chatId = await DatabaseService().getOrCreateChat(passengerId);
      final passenger = await DatabaseService().getUserById(passengerId);
      
      if (passenger == null) {
        ModernSnackBar.show(context, message: 'Passenger not found');
        return;
      }

      if (!mounted) return;
      
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ChatScreen(
            chatId: chatId,
            receiver: passenger,
            currentUserId: FirebaseAuth.instance.currentUser!.uid,
          ),
        ),
      );
    } catch (e) {
      ModernSnackBar.show(context, message: 'Error opening chat: $e');
    }
  }
} 