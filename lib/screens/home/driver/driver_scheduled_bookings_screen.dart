import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../constants/app_colors.dart';
import '../../../models/driver_model.dart';
import '../../../screens/chat/chat_screen.dart';
import '../../../services/database_service.dart';
import '../../../widgets/common/modern_alert_dialog.dart';
import 'scheduled_booking_trip_screen.dart';
import 'scheduled_requests_section.dart';

class DriverScheduledBookingsScreen extends StatefulWidget {
  final bool isDark;

  const DriverScheduledBookingsScreen({required this.isDark, Key? key}) : super(key: key);

  @override
  State<DriverScheduledBookingsScreen> createState() => _DriverScheduledBookingsScreenState();
}

class _DriverScheduledBookingsScreenState extends State<DriverScheduledBookingsScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.getBackgroundColor(widget.isDark),
      appBar: AppBar(
        title: Text(
          'My Scheduled Bookings',
          style: TextStyle(color: AppColors.getTextPrimaryColor(widget.isDark), fontSize: 20, fontWeight: FontWeight.bold),
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
                      'You cannot view your scheduled bookings until your account is approved by an admin.',
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
          
          return StreamBuilder<List<Map<String, dynamic>>>(
            stream: DatabaseService().getDriverAcceptedScheduledRequests(driver.userId),
            builder: (context, requestsSnapshot) {
              final requests = requestsSnapshot.data ?? [];

              if (requests.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.schedule_outlined, color: AppColors.getTextHintColor(widget.isDark), size: 80),
                      const SizedBox(height: 24),
                      Text(
                        'No Scheduled Bookings',
                        style: TextStyle(color: AppColors.getTextPrimaryColor(widget.isDark), fontSize: 24, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Your accepted scheduled bookings will appear here',
                        style: TextStyle(color: AppColors.getTextSecondaryColor(widget.isDark), fontSize: 16),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 32),
                      ElevatedButton.icon(
                        onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => ScheduledRequestsSection(isDark: widget.isDark))),
                        icon: const Icon(Icons.add),
                        label: const Text('View Available Requests'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ],
                  ),
                );
              }

              return Column(
                children: [
                  // Header with stats
                  Container(
                    margin: const EdgeInsets.all(16),
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: [AppColors.primary.withOpacity(0.1), AppColors.primary.withOpacity(0.05)], begin: Alignment.topLeft, end: Alignment.bottomRight),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.primary.withOpacity(0.2), width: 1),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                          child: Icon(Icons.schedule, color: AppColors.primary, size: 24),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Active Bookings',
                                style: TextStyle(color: AppColors.getTextPrimaryColor(widget.isDark), fontSize: 16, fontWeight: FontWeight.w600),
                              ),
                              const SizedBox(height: 4),
                              Text('${requests.length} scheduled trips', style: TextStyle(color: AppColors.getTextSecondaryColor(widget.isDark), fontSize: 14)),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(20)),
                          child: Text(
                            '${requests.length}',
                            style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Bookings list
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: requests.length,
                      itemBuilder: (context, index) {
                        final request = requests[index];
                        return _buildBookingCard(request, widget.isDark);
                      },
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildBookingCard(Map<String, dynamic> request, bool isDark) {
    final scheduledDateTime = (request['scheduledDateTime'] as Timestamp).toDate();
    final estimatedFare = request['estimatedFare'] as double? ?? 0.0;
    final pickupAddress = request['pickupAddress'] as String? ?? '';
    final dropoffAddress = request['dropoffAddress'] as String? ?? '';
    final timeUntilScheduled = request['timeUntilScheduled'] as int? ?? 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppColors.getCardColor(isDark),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 20, offset: const Offset(0, 8))],
      ),
      child: Column(
        children: [
          // Header with time and status
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [_getUrgencyColor(timeUntilScheduled).withOpacity(0.1), _getUrgencyColor(timeUntilScheduled).withOpacity(0.05)], begin: Alignment.topLeft, end: Alignment.bottomRight),
              borderRadius: const BorderRadius.only(topLeft: Radius.circular(20), topRight: Radius.circular(20)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: _getUrgencyColor(timeUntilScheduled).withOpacity(0.2), borderRadius: BorderRadius.circular(12)),
                  child: Icon(Icons.schedule, color: _getUrgencyColor(timeUntilScheduled), size: 24),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Scheduled Trip',
                        style: TextStyle(color: AppColors.getTextPrimaryColor(isDark), fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text('${DateFormat('MMM d, y').format(scheduledDateTime)} at ${DateFormat('HH:mm').format(scheduledDateTime)}', style: TextStyle(color: AppColors.getTextSecondaryColor(isDark), fontSize: 14)),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(color: _getUrgencyColor(timeUntilScheduled), borderRadius: BorderRadius.circular(20)),
                  child: Text(
                    _getTimeRemainingText(timeUntilScheduled),
                    style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),

          // Content
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                // Pickup and Dropoff
                _buildLocationRow(Icons.location_on, 'Pickup', pickupAddress, isDark, Colors.green),
                const SizedBox(height: 16),
                _buildLocationRow(Icons.location_on_outlined, 'Dropoff', dropoffAddress, isDark, Colors.red),
                const SizedBox(height: 20),

                // Price
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Fare',
                        style: TextStyle(color: AppColors.getTextSecondaryColor(isDark), fontSize: 16, fontWeight: FontWeight.w500),
                      ),
                      Text(
                        'R${estimatedFare.toStringAsFixed(2)}',
                        style: TextStyle(color: AppColors.primary, fontSize: 24, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Action buttons
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _startScheduledTrip(request),
                        icon: const Icon(Icons.directions_car, size: 20),
                        label: const Text('Start Trip'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          elevation: 0,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _openChat(request),
                        icon: const Icon(Icons.message, size: 20),
                        label: const Text('Message'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.primary,
                          side: BorderSide(color: AppColors.primary),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLocationRow(IconData icon, String label, String address, bool isDark, Color iconColor) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: iconColor.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
          child: Icon(icon, color: iconColor, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(color: AppColors.getTextSecondaryColor(isDark), fontSize: 12, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 4),
              Text(
                address,
                style: TextStyle(color: AppColors.getTextPrimaryColor(isDark), fontSize: 16, fontWeight: FontWeight.w500),
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
    if (timeUntilScheduled <= 30) return Colors.red;
    if (timeUntilScheduled <= 60) return Colors.orange;
    return Colors.green;
  }

  String _getTimeRemainingText(int timeUntilScheduled) {
    if (timeUntilScheduled <= 0) return 'NOW';
    if (timeUntilScheduled < 60) return '${timeUntilScheduled}m';
    final hours = timeUntilScheduled ~/ 60;
    final minutes = timeUntilScheduled % 60;
    if (minutes == 0) return '${hours}h';
    return '${hours}h ${minutes}m';
  }

  Future<void> _startScheduledTrip(Map<String, dynamic> request) async {
    try {
      Navigator.push(context, MaterialPageRoute(builder: (_) => ScheduledBookingTripScreen(scheduledRequest: request)));
    } catch (e) {
      ModernSnackBar.show(context, message: 'Error starting trip: $e');
    }
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
          builder: (_) => ChatScreen(chatId: chatId, receiver: passenger, currentUserId: FirebaseAuth.instance.currentUser!.uid),
        ),
      );
    } catch (e) {
      ModernSnackBar.show(context, message: 'Error opening chat: $e');
    }
  }
}
