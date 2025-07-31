// lib/screens/home/driver/active_ride_screen.dart
import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:gibelbibela/models/ride_model.dart';
import 'package:gibelbibela/services/chat_service.dart';
import 'package:gibelbibela/services/database_service.dart';
import 'package:gibelbibela/services/ride_service.dart';
import 'package:url_launcher/url_launcher.dart';

// import 'package:rideapp/utils/constants.dart'; // Removed: file does not exist

import '../../../constants/app_colors.dart';
import '../../../models/user_model.dart';
import '../../../widgets/common/cancellation_dialog.dart';
import '../../../widgets/common/loading_indicator.dart';
import '../../../widgets/common/rating_dialog.dart';
import '../../chat/chat_screen.dart';
import 'driver_home_screen.dart';

class ActiveRideScreen extends StatefulWidget {
  final RideModel ride;

  const ActiveRideScreen({
    Key? key,
    required this.ride,
  }) : super(key: key);

  @override
  _ActiveRideScreenState createState() => _ActiveRideScreenState();
}

enum RideFlowState {
  navigatingToPickup, // Driver is navigating to pickup location
  arrivedAtPickup, // Driver has arrived, waiting timer active
  waitingForPassenger, // Timer complete, charging R1/min
  inProgress, // Trip has started, going to destination
  completed, // Trip completed, show rating
}

class _ActiveRideScreenState extends State<ActiveRideScreen> with TickerProviderStateMixin {
  UserModel? _passenger;
  final DatabaseService _firestoreService = DatabaseService();
  final ChatService _chatService = ChatService();

  // Ride flow state
  RideFlowState _flowState = RideFlowState.navigatingToPickup;
  bool _hasNavigatedToPickup = false;
  bool _hasArrived = false;

  // Loading state
  bool _isLoading = false;

  // Timer variables
  Timer? _waitingTimer;
  Timer? _chargingTimer;
  int _waitingSeconds = 120; // 2 minutes in seconds
  int _extraWaitingSeconds = 0;
  double _waitingCharge = 0.0;

  // Animation controller for UI effects
  late final AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _loadPassenger();
    _initializeFlowState();
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
    final user = await _firestoreService.getUserById(widget.ride.passengerId);
    if (mounted) setState(() => _passenger = user);
  }

  Future<void> _loadPassengerData() async {
    setState(() => _isLoading = true);

    try {
      final passenger = await _firestoreService.getUserById(widget.ride.passengerId);

      setState(() {
        _passenger = passenger;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading passenger data: $e')),
      );
    }
  }

  Future<void> _updateRideStatus(
    String newStatus, {
    Map<String, dynamic>? additionalData,
  }) async {
    setState(() => _isLoading = true);

    try {
      // Update the ride status in Firestore
      final updatedRide = widget.ride.copyWith(
        status: RideStatus.values.firstWhere((e) => e.name == newStatus, orElse: () => RideStatus.requested),
        // Add more fields as needed from additionalData
      );
      await _firestoreService.updateRide(updatedRide);

      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });

      // Show rating dialog when ride is completed
      if (newStatus == 'completed') {
        _showRatingDialog();
      }
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating ride status: $e')),
      );
    }
  }

  Future<void> _cancelRide() async {
    print('Cancel ride button pressed'); // Debug log
    
    // Validate ride data
    if (widget.ride.driverId == null || widget.ride.driverId!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Error: Driver ID is missing'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    
    // Show modern cancellation dialog with predefined options
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => CancellationDialog(
        isDriver: true,
        onConfirm: (String reason) async {
          if (!mounted) return;
          setState(() => _isLoading = true);

          try {
            print('Attempting to cancel ride with ID: ${widget.ride.id}'); // Debug log
            print('Driver ID: ${widget.ride.driverId}'); // Debug log
            print('Cancellation reason: $reason'); // Debug log
            
            // Use the new cancellation method that tracks earnings
            final rideService = RideService();
            await rideService.cancelRide(
              widget.ride.id,
              reason: reason,
              isDriver: true,
            );

            print('Ride cancelled successfully'); // Debug log

            if (!mounted) return;
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (context) => const DriverHomeScreen()),
              (route) => false,
            );

            // Show success message after navigation
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Ride cancelled. The passenger has been notified.'),
                  backgroundColor: Colors.green,
                ),
              );
            }
          } catch (e) {
            print('Error cancelling ride: $e'); // Debug log
            if (!mounted) return;
            setState(() => _isLoading = false);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Failed to cancel ride: ${e.toString()}'),
                backgroundColor: Colors.red,
              ),
            );
          }
        },
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
            await _firestoreService.ratePassenger(
              rideId: widget.ride.id,
              passengerId: widget.ride.passengerId,
              rating: rating,
              notes: notes,
              report: report,
            );

            if (!mounted) return;
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                builder: (_) => const DriverHomeScreen(),
              ),
            );
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Rating submitted successfully!'),
                backgroundColor: Colors.green,
              ),
            );
          } catch (e) {
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Failed to submit rating: ${e.toString()}'),
                backgroundColor: Colors.red,
              ),
            );
          }
        },
      ),
    );
  }

  Future<void> _callPassenger() async {
    if (_passenger?.phoneNumber == null) return;

    final Uri phoneUri = Uri(
      scheme: 'tel',
      path: _passenger!.phoneNumber,
    );

    if (await canLaunchUrl(phoneUri)) {
      await launchUrl(phoneUri);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not launch dialer')),
      );
    }
  }

  // Navigation to pickup location
  // Navigation to pickup location - UPDATED TO USE DRIVER'S LOCATION AS START
// Navigation to pickup location - UPDATED TO USE ADDRESS
  Future<void> _navigateToPickup() async {
    setState(() => _isLoading = true);

    try {
      // Google Maps URL with current location as start and pickup address as destination
      final Uri mapsUri = Uri(
        scheme: 'https',
        host: 'www.google.com',
        path: '/maps/dir/',
        queryParameters: {
          'api': '1',
          'origin': 'My Location', // This will use user's current location
          'destination': widget.ride.pickupAddress,
          'travelmode': 'driving',
        },
      );

      if (await canLaunchUrl(mapsUri)) {
        await launchUrl(mapsUri, mode: LaunchMode.externalApplication);
        if (!mounted) return;

        setState(() {
          _hasNavigatedToPickup = true;
          _flowState = RideFlowState.arrivedAtPickup;
          _isLoading = false;
        });
      } else {
        if (!mounted) return;
        throw Exception('Could not launch maps');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

// Start the trip (after arriving at pickup) - UPDATED TO USE ADDRESS
  Future<void> _startTrip() async {
    // Cancel timers
    _waitingTimer?.cancel();
    _chargingTimer?.cancel();

    // If there's a waiting charge, save it to the user's owing field
    if (_waitingCharge > 0) {
      try {
        await _firestoreService.updateUserOwing(
          widget.ride.passengerId,
          _waitingCharge,
        );
      } catch (e) {
        print('Error updating user owing: $e');
      }
    }

    setState(() => _isLoading = true);

    try {
      await _updateRideStatus(RideStatus.inProgress.name);

      if (!mounted) return;

      setState(() {
        _flowState = RideFlowState.inProgress;
        _isLoading = false;
      });

      final Uri mapsUri = Uri(
        scheme: 'https',
        host: 'www.google.com',
        path: '/maps/dir/',
        queryParameters: {
          'api': '1',
          'origin': 'My Location',
          'destination': widget.ride.dropoffAddress,
          'travelmode': 'driving',
        },
      );

      if (await canLaunchUrl(mapsUri)) {
        await launchUrl(mapsUri, mode: LaunchMode.externalApplication);
      }

      await _chatService.sendRideStatusMessage(
        rideId: widget.ride.id,
        driverId: widget.ride.driverId!,
        passengerId: widget.ride.passengerId,
        message: '🚗 Trip to ${widget.ride.dropoffAddress} has started',
        type: 'trip_started',
        metadata: {
          'eventType': 'trip_started',
          'timestamp': FieldValue.serverTimestamp(),
          'waitingCharge': _waitingCharge > 0 ? 'Additional waiting charge: R${_waitingCharge.toStringAsFixed(2)}' : null,
        },
      );
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error starting trip: ${e.toString()}'), backgroundColor: Colors.red),
        );
      }
    }
  }

  // End the trip and show rating dialog
  Future<void> _endTrip() async {
    setState(() => _isLoading = true);

    try {
      // Calculate total fare including additional charges
      final baseFare = widget.ride.actualFare ?? widget.ride.estimatedFare;
      final totalFare = baseFare + _waitingCharge;

      // Use the new completion method that tracks earnings
      final rideService = RideService();
      await rideService.completeRide(widget.ride.id, totalFare);

      if (!mounted) return;

      // Update local state
      setState(() {
        _flowState = RideFlowState.completed;
        _isLoading = false;
      });

      // Show rating dialog
      _showRatingDialog();
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error completing trip: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Active Ride'),
        backgroundColor: AppColors.primary,
        elevation: 0,
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
                  _buildRideInfo(),
                  const SizedBox(height: 32),
                  _buildActionButtons(),
                ],
              ),
            ),
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
          child: Text(
            _passenger?.name ?? 'Passenger',
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            // --- Modern Chat Button with Unread Badge for Driver ---
            if (_passenger != null) ...[
              StreamBuilder<int>(
                stream: _firestoreService.getUnreadCountForChat(
                  passengerId: _passenger!.uid,
                  driverId: widget.ride.driverId!,
                ),
                builder: (context, snapshot) {
                  final unread = snapshot.data ?? 0;
                  return Stack(
                    alignment: Alignment.topRight,
                    children: [
                      _buildCommunicationButton(
                        icon: Icons.message_rounded,
                        label: 'Chat',
                        onPressed: () async {
                          // Get or create chatId for this pair
                          final chatId = await _firestoreService.createOrGetChat(
                            widget.ride.driverId!,
                            _passenger!.uid,
                          );
                          if (!mounted) return;
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ChatScreen(
                                chatId: chatId,
                                receiver: _passenger!,
                                currentUserId: FirebaseAuth.instance.currentUser!.uid,
                              ),
                            ),
                          );
                          // Optionally: mark messages as read
                          _firestoreService.markMessagesAsRead(chatId, widget.ride.driverId!);
                        },
                      ),
                      if (unread > 0)
                        Positioned(
                          right: 2,
                          top: 2,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Colors.redAccent,
                              shape: BoxShape.circle,
                              boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 4)],
                            ),
                            constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                            child: Text(
                              unread > 9 ? '9+' : unread.toString(),
                              style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
            ],
            _buildCommunicationButton(
              icon: Icons.call_rounded,
              label: 'Call',
              onPressed: () {
                if (_passenger?.phoneNumber != null) {
                  launchUrl(Uri.parse('tel:${_passenger!.phoneNumber}'));
                }
              },
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildCommunicationButton({required IconData icon, required String label, required VoidCallback onPressed}) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 20),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        foregroundColor: AppColors.primary,
        backgroundColor: AppColors.primaryLight.withOpacity(0.15),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
      ),
    );
  }

  Widget _buildRideInfo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.my_location, color: AppColors.primary),
            const SizedBox(width: 8),
            Expanded(child: Text(widget.ride.pickupAddress, style: const TextStyle(fontWeight: FontWeight.bold))),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            const Icon(Icons.location_on, color: Colors.red),
            const SizedBox(width: 8),
            Expanded(child: Text(widget.ride.dropoffAddress, style: const TextStyle(fontWeight: FontWeight.w500))),
          ],
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            const Icon(Icons.attach_money, color: AppColors.primary),
            const SizedBox(width: 4),
            Text(
              () {
                if (widget.ride.vehiclePrice != null) {
                  return 'R${widget.ride.vehiclePrice!.toStringAsFixed(2)}';
                } else if (widget.ride.estimatedFare != null) {
                  return 'R${widget.ride.estimatedFare.toStringAsFixed(2)}';
                } else if (widget.ride.actualFare != null) {
                  return 'R${widget.ride.actualFare!.toStringAsFixed(2)}';
                } else {
                  return 'R--';
                }
              }(),
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppColors.primary),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPassengerCard() {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.darkerBackground,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 30,
            backgroundColor: AppTheme.primaryColor.withOpacity(0.2),
            child: Text(
              _passenger!.name.substring(0, 1).toUpperCase(),
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: AppTheme.primaryColor,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_passenger?.name ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                const SizedBox(height: 4),
                if (_passenger?.phoneNumber != null && _passenger!.phoneNumber!.isNotEmpty)
                  Row(
                    children: [
                      const Icon(Icons.phone, size: 16, color: AppColors.primary),
                      const SizedBox(width: 4),
                      Text(_passenger!.phoneNumber!, style: const TextStyle(fontSize: 15)),
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLocationItem({
    required IconData icon,
    required String title,
    required String address,
    required Color iconColor,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 25,
          height: 25,
          decoration: BoxDecoration(
            color: iconColor.withOpacity(0.2),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Icon(
              icon,
              size: 16,
              color: iconColor,
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  color: AppTheme.greyText,
                ),
              ),
              Text(
                address,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required String value,
    required String label,
  }) {
    return Column(
      children: [
        Icon(
          icon,
          color: AppTheme.primaryColor,
          size: 24,
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
            fontSize: 16,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: AppTheme.greyText,
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons() {
    return Column(
      children: [
        // Navigation Button (changes based on state)
        if (_flowState == RideFlowState.navigatingToPickup)
          _buildNavigationButton(
            onPressed: _navigateToPickup,
            text: 'Navigate to Pickup',
            icon: Icons.navigation,
          )
        else if (_flowState == RideFlowState.arrivedAtPickup || _flowState == RideFlowState.waitingForPassenger)
          _buildArrivalSection()
        else if (_flowState == RideFlowState.inProgress)
          _buildInProgressSection()
        else if (_flowState == RideFlowState.completed)
          _buildCompletedSection(),

        const SizedBox(height: 16),

        // Debug button to test cancel functionality
        ElevatedButton(
          onPressed: () {
            print('Debug: Current flow state: $_flowState');
            print('Debug: Ride status: ${widget.ride.status}');
            print('Debug: Ride status index: ${widget.ride.status.index}');
            print('Debug: Ride ID: ${widget.ride.id}');
            print('Debug: Driver ID: ${widget.ride.driverId}');
            print('Debug: All RideStatus values: ${RideStatus.values}');
            print('Debug: RideStatus.cancelled index: ${RideStatus.cancelled.index}');
          },
          child: const Text('Debug Info'),
        ),

        const SizedBox(height: 16),

        // Cancel Ride Button (shown in all states except completed)
        if (_flowState != RideFlowState.completed)
          TextButton(
            onPressed: _cancelRide,
            child: const Text(
              'Cancel Ride',
              style: TextStyle(color: Colors.red),
            ),
          ),
      ],
    );
  }

  Widget _buildNavigationButton({
    required VoidCallback onPressed,
    required String text,
    required IconData icon,
    Color? backgroundColor,
    bool isLoading = false,
  }) {
    return isLoading
        ? const Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          )
        : ElevatedButton.icon(
            onPressed: onPressed,
            icon: Icon(icon),
            label: Text(text),
            style: ElevatedButton.styleFrom(
              backgroundColor: backgroundColor ?? AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
              ),
            ),
          );
  }

  Widget _buildArrivalSection() {
    return Column(
      children: [
        // Show Arrived button if not yet arrived
        if (!_hasArrived)
          _buildNavigationButton(
            onPressed: _markAsArrived,
            text: 'Mark as Arrived',
            icon: Icons.check_circle_outline,
            backgroundColor: Colors.blue,
          )
        else
          // Timer and Waiting Charge Section
          Container(
            padding: const EdgeInsets.all(16),
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: _waitingSeconds > 0 ? Colors.blue.shade50 : Colors.orange.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _waitingSeconds > 0 ? Colors.blue.shade200 : Colors.orange.shade200,
              ),
            ),
            child: Column(
              children: [
                // Timer Display
                Text(
                  _waitingSeconds > 0
                    ? 'Free waiting time: ${_formatTime(_waitingSeconds)}'
                    : 'Extra waiting time: ${_formatTime(_extraWaitingSeconds)}',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: _waitingSeconds > 0 ? Colors.blue.shade700 : Colors.red,
                  ),
                ),
                if (_waitingSeconds <= 0) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Waiting Charge: R${_waitingCharge.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.red,
                    ),
                  ),
                ],
              ],
            ),
          ),

        // Start Trip Button
        _buildNavigationButton(
          onPressed: _startTrip,
          text: 'Start Trip',
          icon: Icons.directions_car,
          backgroundColor: Colors.green,
        ),
      ],
    );
  }

  Widget _buildInProgressSection() {
    return Column(
      children: [
        // Trip in Progress Status
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
              SizedBox(height: 8),
              Text(
                'Trip in Progress',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue[800],
                ),
              ),
              SizedBox(height: 8),
              Text(
                'Drive safely to the destination',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.blue[700],
                ),
              ),
            ],
          ),
        ),

        // End Trip Button
        _buildNavigationButton(
          onPressed: _endTrip,
          text: 'End Trip',
          icon: Icons.flag,
          backgroundColor: Colors.green,
        ),
      ],
    );
  }

  Widget _buildCompletedSection() {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 16),
      child: Column(
        children: [
          Icon(Icons.check_circle, size: 48, color: Colors.green),
          SizedBox(height: 16),
          Text(
            'Trip Completed!',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 8),
          Text(
            'Thank you for driving with us',
            style: TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }

  String _formatSeconds(int seconds) {
    final minutes = (seconds / 60).floor();
    final remainingSeconds = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  String _formatMinutes(int seconds) {
    final minutes = (seconds / 60).ceil();
    return '$minutes ${minutes == 1 ? 'minute' : 'minutes'}';
  }

  void _startWaitingTimer() {
    _waitingTimer?.cancel();
    _chargingTimer?.cancel();
    _waitingSeconds = 120;
    _extraWaitingSeconds = 0;
    _waitingCharge = 0.0;
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
          _flowState = RideFlowState.waitingForPassenger;
          _startChargingTimer();
        }
      });
    });
  }

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

  void _initializeFlowState() {
    // Initialize flow state based on the ride's current status
    switch (widget.ride.status) {
      case RideStatus.accepted:
        _flowState = RideFlowState.navigatingToPickup;
        break;
      case RideStatus.driverArrived:
        _flowState = RideFlowState.arrivedAtPickup;
        _hasNavigatedToPickup = true;
        break;
      case RideStatus.inProgress:
        _flowState = RideFlowState.inProgress;
        break;
      case RideStatus.completed:
        _flowState = RideFlowState.completed;
        break;
      case RideStatus.cancelled:
        _flowState = RideFlowState.completed; // Show completed state for cancelled rides
        break;
      default:
        _flowState = RideFlowState.navigatingToPickup;
        break;
    }
  }

  void _sendArrivalNotification() async {
    try {
      await _chatService.sendDriverArrivalMessage(
        rideId: widget.ride.id,
        driverId: widget.ride.driverId!,
        passengerId: widget.ride.passengerId,
        message: '🚗 I\'ve arrived at the pickup location. You have 2 minutes of free waiting time.',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to send arrival notification'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _markAsArrived() async {
    setState(() {
      _hasArrived = true;
    });

    // Start the 2-minute timer
    _waitingTimer?.cancel(); // Cancel any existing timer
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
          _startChargingTimer();
        }
      });
    });

    // Update ride status and notify passenger
    try {
      final updatedRide = widget.ride.copyWith(
        status: RideStatus.driverArrived,
      );
      await _firestoreService.updateRide(updatedRide);
      _sendArrivalNotification();
    } catch (e) {
      print('Error updating ride status: $e');
    }
  }

  String _formatTime(int seconds) {
    final minutes = (seconds / 60).floor();
    final remainingSeconds = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
  }
}
