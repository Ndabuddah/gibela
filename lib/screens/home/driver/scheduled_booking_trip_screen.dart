import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../constants/app_colors.dart';
import '../../../models/user_model.dart';
import '../../../models/driver_model.dart';
import '../../../services/database_service.dart';
import '../../../widgets/common/loading_indicator.dart';
import '../../../widgets/common/modern_alert_dialog.dart';
import '../../../widgets/common/rating_dialog.dart';
import '../../chat/chat_screen.dart';

enum ScheduledTripFlowState {
  navigatingToPickup, // Driver is navigating to pickup location
  arrivedAtPickup, // Driver has arrived, waiting timer active
  waitingForPassenger, // Timer complete, charging R1/min
  inProgress, // Trip has started, going to destination
  completed, // Trip completed, show rating
}

class ScheduledBookingTripScreen extends StatefulWidget {
  final Map<String, dynamic> scheduledRequest;

  const ScheduledBookingTripScreen({Key? key, required this.scheduledRequest}) : super(key: key);

  @override
  _ScheduledBookingTripScreenState createState() => _ScheduledBookingTripScreenState();
}

class _ScheduledBookingTripScreenState extends State<ScheduledBookingTripScreen> with TickerProviderStateMixin {
  final DatabaseService _databaseService = DatabaseService();

  // Trip flow state
  ScheduledTripFlowState _flowState = ScheduledTripFlowState.navigatingToPickup;
  bool _hasNavigatedToPickup = false;
  bool _hasArrived = false;
  bool _isLoading = false;

  // Passenger info
  UserModel? _passenger;

  // Timer variables
  Timer? _waitingTimer;
  Timer? _chargingTimer;
  int _waitingSeconds = 120; // 2 minutes in seconds
  int _extraWaitingSeconds = 0;
  double _waitingCharge = 0.0;

  // Animation controller
  late final AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(vsync: this, duration: const Duration(milliseconds: 300));
    _loadPassenger();
    _animationController.forward();
  }

  @override
  void dispose() {
    _waitingTimer?.cancel();
    _chargingTimer?.cancel();
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadPassenger() async {
    try {
      final passengerId = widget.scheduledRequest['userId'] as String?;
      if (passengerId != null) {
        final passenger = await _databaseService.getUserById(passengerId);
        if (mounted) {
          setState(() => _passenger = passenger);
        }
      }
    } catch (e) {
      print('Error loading passenger: $e');
    }
  }

  // Navigate to pickup location
  Future<void> _navigateToPickup() async {
    setState(() => _isLoading = true);

    try {
      final pickupLat = widget.scheduledRequest['pickupCoordinates'][0] as double;
      final pickupLng = widget.scheduledRequest['pickupCoordinates'][1] as double;
      final pickupAddress = widget.scheduledRequest['pickupAddress'] as String;

      final Uri mapsUri = Uri(scheme: 'https', host: 'www.google.com', path: '/maps/dir/', queryParameters: {'api': '1', 'origin': 'My Location', 'destination': pickupAddress, 'travelmode': 'driving'});

      if (await canLaunchUrl(mapsUri)) {
        await launchUrl(mapsUri, mode: LaunchMode.externalApplication);
        if (!mounted) return;

        setState(() {
          _hasNavigatedToPickup = true;
          _flowState = ScheduledTripFlowState.arrivedAtPickup;
          _isLoading = false;
        });

        ModernSnackBar.show(context, message: 'Navigation started to pickup location');
      } else {
        throw Exception('Could not launch maps');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ModernSnackBar.show(context, message: 'Error starting navigation: $e', isError: true);
      }
    }
  }

  // Mark as arrived at pickup
  Future<void> _markAsArrived() async {
    setState(() {
      _hasArrived = true;
      _isLoading = true;
    });

    try {
      // Update scheduled request status
      await _databaseService.updateScheduledRequestStatus(widget.scheduledRequest['id'], 'driver_arrived');

      // Start the 2-minute timer
      _waitingTimer?.cancel();
      _waitingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (!mounted) {
          timer.cancel();
          return;
        }
        setState(() {
          if (_waitingSeconds > 0) {
            _waitingSeconds--;
          } else {
            _waitingTimer?.cancel();
            _flowState = ScheduledTripFlowState.waitingForPassenger;
            _startChargingTimer();
          }
        });
      });

      // Send arrival notification
      await _sendArrivalNotification();

      setState(() => _isLoading = false);

      ModernSnackBar.show(context, message: 'Arrival marked! 2-minute free waiting time started');
    } catch (e) {
      setState(() => _isLoading = false);
      ModernSnackBar.show(context, message: 'Error marking arrival: $e', isError: true);
    }
  }

  // Start the trip
  Future<void> _startTrip() async {
    setState(() => _isLoading = true);

    try {
      // Cancel timers
      _waitingTimer?.cancel();
      _chargingTimer?.cancel();

      // Update scheduled request status
      await _databaseService.updateScheduledRequestStatus(widget.scheduledRequest['id'], 'in_progress');

      setState(() {
        _flowState = ScheduledTripFlowState.inProgress;
        _isLoading = false;
      });

      // Navigate to destination
      final dropoffAddress = widget.scheduledRequest['dropoffAddress'] as String;
      final Uri mapsUri = Uri(scheme: 'https', host: 'www.google.com', path: '/maps/dir/', queryParameters: {'api': '1', 'origin': 'My Location', 'destination': dropoffAddress, 'travelmode': 'driving'});

      if (await canLaunchUrl(mapsUri)) {
        await launchUrl(mapsUri, mode: LaunchMode.externalApplication);
      }

      // Send trip started notification
      await _sendTripStartedNotification();

      ModernSnackBar.show(context, message: 'Trip started! Navigating to destination');
    } catch (e) {
      setState(() => _isLoading = false);
      ModernSnackBar.show(context, message: 'Error starting trip: $e', isError: true);
    }
  }

  // Complete the trip
  Future<void> _completeTrip() async {
    try {
      final estimatedFare = widget.scheduledRequest['estimatedFare'] as double? ?? 0.0;
      final paymentType = widget.scheduledRequest['paymentType'] as String? ?? 'Cash';

      // Show fare input dialog
      final actualFare = await _showFareInputDialog(estimatedFare);
      if (actualFare == null) return; // User cancelled

      setState(() => _isLoading = true);

      // Complete the scheduled booking
      await _databaseService.completeScheduledBooking(
        widget.scheduledRequest['id'],
        actualFare + _waitingCharge, // Include waiting charge
      );

      if (!mounted) return;

      setState(() {
        _flowState = ScheduledTripFlowState.completed;
        _isLoading = false;
      });

      // Show completion message based on payment type
      String completionMessage = 'Trip completed! Earnings: R${(actualFare + _waitingCharge).toStringAsFixed(2)}';
      if (paymentType.toLowerCase() == 'card') {
        completionMessage += ' (Card payment already processed)';
      } else {
        completionMessage += ' (Cash payment)';
      }

      ModernSnackBar.show(context, message: completionMessage);

      // Show rating dialog
      _showRatingDialog();
    } catch (e) {
      setState(() => _isLoading = false);
      ModernSnackBar.show(context, message: 'Error completing trip: $e', isError: true);
    }
  }

  // Cancel the scheduled booking
  Future<void> _cancelScheduledBooking() async {
    try {
      final reason = await _showCancellationReasonDialog();
      if (reason == null) return; // User cancelled

      setState(() => _isLoading = true);

      final driverId = FirebaseAuth.instance.currentUser?.uid;
      if (driverId == null) {
        throw Exception('Driver ID not found');
      }

      await _databaseService.cancelScheduledBooking(widget.scheduledRequest['id'], driverId, reason: reason);

      if (!mounted) return;

      ModernSnackBar.show(context, message: 'Scheduled booking cancelled');

      Navigator.of(context).pop(); // Go back to previous screen
    } catch (e) {
      setState(() => _isLoading = false);
      ModernSnackBar.show(context, message: 'Error cancelling booking: $e', isError: true);
    }
  }

  // Open chat with passenger
  Future<void> _openChat() async {
    try {
      final passengerId = widget.scheduledRequest['userId'] as String?;
      if (passengerId == null) {
        ModernSnackBar.show(context, message: 'Passenger information not found');
        return;
      }

      final chatId = await _databaseService.getOrCreateChat(passengerId);
      final passenger = await _databaseService.getUserById(passengerId);

      if (passenger == null) {
        ModernSnackBar.show(context, message: 'Passenger not found');
        return;
      }

      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        ModernSnackBar.show(context, message: 'User not authenticated');
        return;
      }

      if (!mounted) return;

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ChatScreen(chatId: chatId, receiver: passenger, currentUserId: currentUser.uid),
        ),
      );
    } catch (e) {
      ModernSnackBar.show(context, message: 'Error opening chat: $e');
    }
  }

  // Helper methods
  void _startChargingTimer() {
    _chargingTimer?.cancel();
    _chargingTimer = Timer.periodic(const Duration(minutes: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        _extraWaitingSeconds += 60;
        _waitingCharge += 1.0;
      });
    });
  }

  String _formatTime(int seconds) {
    final minutes = (seconds / 60).floor();
    final remainingSeconds = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  Future<void> _sendArrivalNotification() async {
    try {
      final passengerId = widget.scheduledRequest['userId'] as String?;
      if (passengerId != null) {
        final notificationRef = FirebaseFirestore.instance.collection('notifications').doc();
        final notification = {'id': notificationRef.id, 'userId': passengerId, 'title': 'Driver Arrived', 'body': 'Your scheduled ride driver has arrived at the pickup location.', 'timestamp': FieldValue.serverTimestamp(), 'isRead': false, 'category': 'ride', 'priority': 'high'};
        await notificationRef.set(notification);
      }
    } catch (e) {
      print('Error sending arrival notification: $e');
    }
  }

  Future<void> _sendTripStartedNotification() async {
    try {
      final passengerId = widget.scheduledRequest['userId'] as String?;
      if (passengerId != null) {
        final notificationRef = FirebaseFirestore.instance.collection('notifications').doc();
        final notification = {'id': notificationRef.id, 'userId': passengerId, 'title': 'Trip Started', 'body': 'Your scheduled ride has started. You\'re on your way to your destination.', 'timestamp': FieldValue.serverTimestamp(), 'isRead': false, 'category': 'ride', 'priority': 'high'};
        await notificationRef.set(notification);
      }
    } catch (e) {
      print('Error sending trip started notification: $e');
    }
  }

  Future<double?> _showFareInputDialog(double estimatedFare) async {
    final TextEditingController fareController = TextEditingController(text: (estimatedFare + _waitingCharge).toStringAsFixed(2));

    return showDialog<double>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Enter Actual Fare'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Please enter the actual fare collected:'),
            if (_waitingCharge > 0) ...[
              const SizedBox(height: 8),
              Text(
                'Waiting charge: R${_waitingCharge.toStringAsFixed(2)}',
                style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold),
              ),
            ],
            const SizedBox(height: 16),
            TextField(
              controller: fareController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Fare Amount (R)', border: OutlineInputBorder()),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              final fare = double.tryParse(fareController.text);
              if (fare != null && fare > 0) {
                Navigator.of(context).pop(fare);
              } else {
                ModernSnackBar.show(context, message: 'Please enter a valid fare amount', isError: true);
              }
            },
            child: const Text('Complete'),
          ),
        ],
      ),
    );
  }

  Future<String?> _showCancellationReasonDialog() async {
    final TextEditingController reasonController = TextEditingController();

    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancellation Reason'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Please provide a reason for cancellation:'),
            const SizedBox(height: 16),
            TextField(
              controller: reasonController,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'Reason', border: OutlineInputBorder(), hintText: 'e.g., Passenger not available, vehicle issue...'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              final reason = reasonController.text.trim();
              if (reason.isNotEmpty) {
                Navigator.of(context).pop(reason);
              } else {
                ModernSnackBar.show(context, message: 'Please provide a cancellation reason', isError: true);
              }
            },
            child: const Text('Cancel Booking'),
          ),
        ],
      ),
    );
  }

  void _showRatingDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => RatingDialog(
        isDriverRating: true,
        receiverName: _passenger?.name ?? 'the passenger',
        onSubmit: (rating, notes, report) async {
          try {
            // Here you can add rating submission logic if needed
            // For now, just close the dialogs
            Navigator.of(context).pop(); // Close rating dialog
            Navigator.of(context).pop(); // Go back to previous screen

            ModernSnackBar.show(context, message: 'Rating submitted successfully!');
          } catch (e) {
            ModernSnackBar.show(context, message: 'Failed to submit rating: $e', isError: true);
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<DriverModel?>(
      future: _databaseService.getCurrentDriver(),
      builder: (context, driverSnapshot) {
        if (!driverSnapshot.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        
        final driver = driverSnapshot.data;
        if (driver == null) {
          return const Scaffold(
            body: Center(child: Text('Driver data not found')),
          );
        }
        
        if (!driver.isApproved) {
          return Scaffold(
            backgroundColor: Colors.white,
            appBar: AppBar(
              title: const Text('Scheduled Trip'),
              backgroundColor: AppColors.primary,
              elevation: 0,
              foregroundColor: Colors.white,
            ),
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.lock, size: 60, color: AppColors.primary),
                    const SizedBox(height: 24),
                    Text(
                      'Your account is pending approval.',
                      style: const TextStyle(
                        fontSize: 20, 
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'You cannot start scheduled trips until your account is approved by an admin.',
                      style: TextStyle(
                        fontSize: 16, 
                        color: Colors.grey[600],
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          );
        }
        
        return Scaffold(
          backgroundColor: Colors.white,
          appBar: AppBar(
            title: const Text('Scheduled Trip'),
            backgroundColor: AppColors.primary,
            elevation: 0,
            foregroundColor: Colors.white,
          ),
          body: _isLoading
              ? const LoadingIndicator()
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildPassengerInfo(),
                      const SizedBox(height: 24),
                      _buildTripInfo(),
                      const SizedBox(height: 32),
                      _buildActionButtons(),
                    ],
                  ),
                ),
        );
      },
    );
  }

  Widget _buildPassengerInfo() {
    return Column(
      children: [
        Center(
          child: CircleAvatar(
            radius: 48,
            backgroundColor: AppColors.primaryLight.withOpacity(0.2),
            backgroundImage: _passenger?.profileImageUrl != null ? NetworkImage(_passenger!.profileImageUrl!) : null,
            child: _passenger?.profileImageUrl == null ? const Icon(Icons.person, size: 48, color: AppColors.primary) : null,
          ),
        ),
        const SizedBox(height: 16),
        Center(
          child: Column(
            children: [
              Text(_passenger?.name ?? 'Passenger', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              if (_passenger?.phoneNumber != null) ...[const SizedBox(height: 4), Text(_passenger!.phoneNumber!, style: TextStyle(fontSize: 16, color: Colors.grey[600]))],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTripInfo() {
    final pickupAddress = widget.scheduledRequest['pickupAddress'] as String? ?? 'Unknown';
    final dropoffAddress = widget.scheduledRequest['dropoffAddress'] as String? ?? 'Unknown';
    final estimatedFare = widget.scheduledRequest['estimatedFare'] as double? ?? 0.0;
    final scheduledTime = (widget.scheduledRequest['scheduledDateTime'] as Timestamp?)?.toDate() ?? DateTime.now();
    final paymentType = widget.scheduledRequest['paymentType'] as String? ?? 'Cash';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[200] ?? Colors.grey),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildInfoRow(Icons.location_on, 'Pickup', pickupAddress),
          const SizedBox(height: 16),
          _buildInfoRow(Icons.location_on_outlined, 'Dropoff', dropoffAddress),
          const SizedBox(height: 16),
          _buildInfoRow(Icons.schedule, 'Scheduled Time', '${scheduledTime.hour.toString().padLeft(2, '0')}:${scheduledTime.minute.toString().padLeft(2, '0')}'),
          const SizedBox(height: 16),
          _buildInfoRow(Icons.payment, 'Payment', paymentType),
          const SizedBox(height: 16),
          _buildInfoRow(Icons.attach_money, 'Estimated Fare', 'R${estimatedFare.toStringAsFixed(2)}'),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, color: AppColors.primary, size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
              Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons() {
    switch (_flowState) {
      case ScheduledTripFlowState.navigatingToPickup:
        return Column(
          children: [
            _buildActionButton(onPressed: _navigateToPickup, text: 'Navigate to Pickup', icon: Icons.navigation, backgroundColor: AppColors.primary),
            const SizedBox(height: 12),
            _buildActionButton(onPressed: _openChat, text: 'Message Passenger', icon: Icons.message, backgroundColor: Colors.grey[600] ?? Colors.grey),
            const SizedBox(height: 12),
            _buildActionButton(onPressed: _cancelScheduledBooking, text: 'Cancel Booking', icon: Icons.cancel, backgroundColor: Colors.red),
          ],
        );

      case ScheduledTripFlowState.arrivedAtPickup:
        return Column(
          children: [
            if (!_hasArrived) _buildActionButton(onPressed: _markAsArrived, text: 'Mark as Arrived', icon: Icons.check_circle_outline, backgroundColor: Colors.blue) else _buildWaitingSection(),
            const SizedBox(height: 12),
            _buildActionButton(onPressed: _openChat, text: 'Message Passenger', icon: Icons.message, backgroundColor: Colors.grey[600] ?? Colors.grey),
            const SizedBox(height: 12),
            _buildActionButton(onPressed: _cancelScheduledBooking, text: 'Cancel Booking', icon: Icons.cancel, backgroundColor: Colors.red),
          ],
        );

      case ScheduledTripFlowState.waitingForPassenger:
        return Column(
          children: [
            _buildWaitingSection(),
            const SizedBox(height: 12),
            _buildActionButton(onPressed: _startTrip, text: 'Start Trip', icon: Icons.directions_car, backgroundColor: Colors.green),
            const SizedBox(height: 12),
            _buildActionButton(onPressed: _openChat, text: 'Message Passenger', icon: Icons.message, backgroundColor: Colors.grey[600] ?? Colors.grey),
            const SizedBox(height: 12),
            _buildActionButton(onPressed: _cancelScheduledBooking, text: 'Cancel Booking', icon: Icons.cancel, backgroundColor: Colors.red),
          ],
        );

      case ScheduledTripFlowState.inProgress:
        return Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.green.shade100),
              ),
              child: Column(
                children: [
                  Icon(Icons.directions_car, size: 36, color: Colors.green),
                  const SizedBox(height: 8),
                  const Text(
                    'Trip in Progress',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.green),
                  ),
                ],
              ),
            ),
            _buildActionButton(onPressed: _completeTrip, text: 'Complete Trip', icon: Icons.check_circle, backgroundColor: Colors.green),
            const SizedBox(height: 12),
            _buildActionButton(onPressed: _openChat, text: 'Message Passenger', icon: Icons.message, backgroundColor: Colors.grey[600] ?? Colors.grey),
          ],
        );

      case ScheduledTripFlowState.completed:
        return Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue.shade100),
              ),
              child: Column(
                children: [
                  Icon(Icons.check_circle, size: 36, color: Colors.blue),
                  const SizedBox(height: 8),
                  const Text(
                    'Trip Completed!',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.blue),
                  ),
                ],
              ),
            ),
            _buildActionButton(onPressed: () => Navigator.of(context).pop(), text: 'Back to Bookings', icon: Icons.arrow_back, backgroundColor: AppColors.primary),
          ],
        );
    }
  }

  Widget _buildWaitingSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: _waitingSeconds > 0 ? Colors.blue.shade50 : Colors.orange.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _waitingSeconds > 0 ? Colors.blue.shade200 : Colors.orange.shade200),
      ),
      child: Column(
        children: [
          Text(
            _waitingSeconds > 0 ? 'Free waiting time: ${_formatTime(_waitingSeconds)}' : 'Extra waiting time: ${_formatTime(_extraWaitingSeconds)}',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _waitingSeconds > 0 ? Colors.blue.shade700 : Colors.red),
          ),
          if (_waitingSeconds <= 0) ...[
            const SizedBox(height: 8),
            Text(
              'Waiting Charge: R${_waitingCharge.toStringAsFixed(2)}',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.red),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildActionButton({required VoidCallback onPressed, required String text, required IconData icon, required Color backgroundColor}) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 20),
        label: Text(text),
        style: ElevatedButton.styleFrom(
          backgroundColor: backgroundColor,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 0,
        ),
      ),
    );
  }
}
