import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_map/flutter_map.dart' as flutter_map;

import '../../../constants/app_colors.dart';
import '../../../models/ride_model.dart';
import '../../../providers/theme_provider.dart';
import '../../../services/database_service.dart';
import '../../../services/ride_notification_service.dart';
import '../../../widgets/common/modern_alert_dialog.dart';
import '../../../widgets/common/modern_loading_indicator.dart';
import '../../../widgets/common/cancellation_dialog.dart';
import '../../../widgets/common/rating_dialog.dart';
import '../../../widgets/common/panic_button.dart';
import '../../../models/user_model.dart';
import '../../../models/driver_model.dart';
import '../passenger/passenger_home_screen.dart';
import '../../chat/chat_screen.dart';
import 'request_ride_screen.dart';

class RideProgressScreen extends StatefulWidget {
  final String rideId;
  final String pickupAddress;
  final String dropoffAddress;
  
  const RideProgressScreen({
    super.key,
    required this.rideId,
    required this.pickupAddress,
    required this.dropoffAddress,
  });

  @override
  State<RideProgressScreen> createState() => _RideProgressScreenState();
}

class _RideProgressScreenState extends State<RideProgressScreen>
    with TickerProviderStateMixin {
  bool _isLoading = false;
  String _rideStatus = 'Finding driver...';
  String _driverName = '';
  String _driverRating = '';
  String _driverPlate = '';
  String _driverVehicle = '';
  String _driverImageUrl = '';
  String _estimatedTime = '5-10 min';
  double _progress = 0.0;
  
  RideModel? _currentRide;
  StreamSubscription<RideModel>? _rideSubscription;
  final DatabaseService _databaseService = DatabaseService();

  late AnimationController _fadeController;
  late AnimationController _slideController;
  late AnimationController _progressController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _progressAnimation;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _startListeningToRideUpdates();
  }

  void _initializeAnimations() {
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    _slideController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _progressController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeInOut,
    ));

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutCubic,
    ));

    _progressAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _progressController,
      curve: Curves.easeInOut,
    ));

    _fadeController.forward();
    _slideController.forward();
  }

  void _startListeningToRideUpdates() {
    _rideSubscription = _databaseService.listenToRideUpdates(widget.rideId).listen((updatedRide) {
      if (mounted) {
        setState(() {
          _currentRide = updatedRide;
        });
        _updateRideStatus(updatedRide);
      }
    });
  }

  void _updateRideStatus(RideModel ride) {
    switch (ride.status) {
      case RideStatus.requested:
        if (_currentRide?.status == RideStatus.cancelled) {
          // This means the ride was cancelled and is now being reset to find a new driver
          setState(() {
            _rideStatus = 'Looking for new driver...';
            _driverName = '';
            _driverRating = '';
            _estimatedTime = '5-10 min';
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Looking for a new driver...'),
              backgroundColor: Colors.blue,
            ),
          );
        } else {
          setState(() {
            _rideStatus = 'Finding driver...';
            _driverName = '';
            _driverRating = '';
            _estimatedTime = '5-10 min';
          });
        }
        break;
      case RideStatus.accepted:
        setState(() {
          _rideStatus = 'Driver found!';
          _estimatedTime = '3-5 min';
        });
        _progressController.forward();
        _loadDriverInfo(ride.driverId!);
        break;
      case RideStatus.driverArrived:
        setState(() {
          _rideStatus = 'Driver arrived!';
          _estimatedTime = 'Ready to go';
        });
        break;
      case RideStatus.inProgress:
        setState(() {
          _rideStatus = 'Ride in progress...';
          _estimatedTime = '8-12 min';
        });
        break;
      case RideStatus.completed:
        setState(() {
          _rideStatus = 'Ride completed!';
          _estimatedTime = 'Thank you for riding with us';
        });
        _showRideCompletedDialog();
        break;
      case RideStatus.cancelled:
        setState(() {
          _rideStatus = 'Driver cancelled';
          _estimatedTime = 'Looking for another driver...';
        });
        _showDriverCancelledDialog();
        break;
    }
  }

  Future<void> _loadDriverInfo(String driverId) async {
    try {
      final driver = await _databaseService.getDriverByUserId(driverId);
      if (driver != null && mounted) {
        setState(() {
          _driverName = driver.name;
          _driverRating = '${driver.averageRating.toStringAsFixed(1)} ★';
          _driverPlate = driver.licensePlate ?? '';
          final vehicleParts = [driver.vehicleModel, driver.vehicleColor]
              .where((e) => (e ?? '').trim().isNotEmpty)
              .map((e) => e!.trim())
              .toList();
          _driverVehicle = vehicleParts.isNotEmpty ? vehicleParts.join(' • ') : '';
          _driverImageUrl = driver.profileImage ?? '';
        });
      }
    } catch (e) {
      print('Error loading driver info: $e');
    }
  }

  void _showDriverCancelledDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Driver Cancelled'),
        content: const Text('Your driver has cancelled the ride. We\'re looking for another driver for you.'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _requestNewDriver();
            },
            child: const Text('Request New Driver'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _goBackToHome();
            },
            child: const Text('Cancel Ride'),
          ),
        ],
      ),
    );
  }

  void _showRideCompletedDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Ride Completed'),
        content: const Text('Your ride has been completed successfully!'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _showRatingDialog();
            },
            child: const Text('Rate Driver'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _goBackToHome();
            },
            child: const Text('Skip'),
          ),
        ],
      ),
    );
  }

  void _showRatingDialog() {
    if (_currentRide?.driverId == null) {
      _goBackToHome();
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => RatingDialog(
        isDriverRating: false,
        receiverName: _driverName.isNotEmpty ? _driverName : 'your driver',
        onSubmit: (rating, notes, report) async {
          try {
            await _databaseService.rateDriver(
              rideId: _currentRide!.id,
              driverId: _currentRide!.driverId!,
              rating: rating,
              notes: notes,
              report: report,
            );

            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Rating submitted successfully!'),
                backgroundColor: Colors.green,
              ),
            );
            _goBackToHome();
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

  void _requestNewDriver() {
    // Reset the ride status to requested so it appears in the request list again
    if (_currentRide != null) {
      final updatedRide = _currentRide!.copyWith(
        status: RideStatus.requested,
        driverId: null,
        cancellationReason: null,
        cancelledAt: null,
      );
      _databaseService.updateRide(updatedRide).then((_) {
        // Show a message that we're looking for a new driver
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Looking for a new driver...'),
            backgroundColor: Colors.blue,
          ),
        );
      }).catchError((error) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error requesting new driver: $error'),
            backgroundColor: Colors.red,
          ),
        );
      });
    }
  }

  void _goBackToHome() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => const PassengerHomeScreen()),
      (route) => false,
    );
  }

  void _cancelRide() async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => CancellationDialog(
        isDriver: false,
        onConfirm: (String reason) async {
          if (mounted) {
            // Update the ride with cancellation reason
            if (_currentRide != null) {
              try {
                final updatedRide = _currentRide!.copyWith(
                  status: RideStatus.cancelled,
                  cancellationReason: reason,
                  cancelledAt: DateTime.now(),
                );
                await _databaseService.updateRide(updatedRide);
                
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Ride cancelled successfully'),
                    backgroundColor: Colors.green,
                  ),
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Error cancelling ride: $e'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            }
            
        Navigator.of(context).pushReplacement(
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) =>
                const PassengerHomeScreen(),
            transitionsBuilder: (context, animation, secondaryAnimation, child) {
              return FadeTransition(opacity: animation, child: child);
            },
            transitionDuration: const Duration(milliseconds: 500),
          ),
        );
      }
        },
      ),
    );
  }


  void _openChat() async {
    if (_currentRide?.driverId == null) {
      ModernSnackBar.show(
        context,
        message: 'Driver information not available',
      );
      return;
    }

    try {
      // Get driver information - try driver collection first, then user collection
      DriverModel? driverModel = await _databaseService.getDriverByUserId(_currentRide!.driverId!);
      UserModel? driverUser;
      
      if (driverModel != null) {
        // Convert DriverModel to UserModel for chat
        driverUser = UserModel(
          uid: driverModel.userId,
          email: driverModel.email,
          name: driverModel.name,
          surname: '', // Driver model doesn't have surname
          phoneNumber: driverModel.phoneNumber,
          isDriver: true,
          isApproved: driverModel.isApproved,
          savedAddresses: const [],
          recentRides: const [],
          isOnline: driverModel.status == DriverStatus.online,
          rating: driverModel.averageRating,
          missingProfileFields: const [],
          referrals: 0,
          referralAmount: 0.0,
          lastReferral: null,
          isGirl: driverModel.isFemale ?? false,
          isStudent: driverModel.isForStudents ?? false,
          profileImage: driverModel.profileImage,
          photoUrl: driverModel.profileImage,
        );
      } else {
        // Fallback to user collection
        driverUser = await _databaseService.getUserById(_currentRide!.driverId!);
      }
      
      if (driverUser == null) {
        ModernSnackBar.show(
          context,
          message: 'Driver information not found',
        );
        return;
      }

      // Get current user ID
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        ModernSnackBar.show(
          context,
          message: 'User not logged in',
        );
        return;
      }

      // Create or get chat ID
      final participants = [currentUser.uid, _currentRide!.driverId!]..sort();
      final chatId = participants.join('_');

      // Navigate to chat screen
      if (mounted && driverUser != null) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => ChatScreen(
              chatId: chatId,
              receiver: driverUser!,
              currentUserId: currentUser.uid,
            ),
          ),
        );
      }
    } catch (e) {
      ModernSnackBar.show(
        context,
        message: 'Error opening chat: $e',
      );
    }
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    _progressController.dispose();
    _rideSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;

    return Scaffold(
      backgroundColor: AppColors.getBackgroundColor(isDark),
      floatingActionButton: const PanicButton(),
      body: SafeArea(
        child: Column(
          children: [
            // Header
            FadeTransition(
              opacity: _fadeAnimation,
              child: SlideTransition(
                position: _slideAnimation,
                child: Container(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      IconButton(
                        icon: Icon(
                          Icons.arrow_back,
                          color: AppColors.getIconColor(isDark),
                        ),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                      Expanded(
                        child: Text(
                          'Ride Progress',
                          style: TextStyle(
                            color: AppColors.getTextPrimaryColor(isDark),
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      IconButton(
                        icon: Icon(
                          Icons.cancel,
                          color: AppColors.error,
                        ),
                        onPressed: _cancelRide,
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Map Section (REPLACED)
            Expanded(
              flex: 2,
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 20),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.getShadowColor(isDark),
                      blurRadius: 15,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    color: isDark ? Colors.black : Colors.white,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        ModernLoadingIndicator(),
                        const SizedBox(height: 24),
                        Text(
                          _rideStatus == 'Finding driver...'
                              ? 'Looking for a driver nearby...'
                              : _rideStatus == 'Driver found!'
                                  ? 'Driver is on the way!'
                                  : _rideStatus == 'Driver arrived!'
                                      ? 'Your driver is arriving shortly.'
                                      : 'Enjoy your ride!',
                          style: TextStyle(
                            color: AppColors.getTextPrimaryColor(isDark),
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 12),
                        AnimatedOpacity(
                          opacity: _rideStatus == 'Finding driver...' ? 1.0 : 0.0,
                          duration: const Duration(milliseconds: 500),
                          child: Text(
                            'Hang tight, we’re finding the best match for you!',
                            style: TextStyle(
                              color: AppColors.getTextSecondaryColor(isDark),
                              fontSize: 15,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Status Section
            Expanded(
              flex: 1,
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 20),
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: SlideTransition(
                    position: _slideAnimation,
                    child: Column(
                      children: [
                        // Status Card
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            gradient: AppColors.primaryGradient,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.primary.withOpacity(0.3),
                                blurRadius: 15,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: Column(
                            children: [
                              // Status Text
                              Text(
                                _rideStatus,
                                style: const TextStyle(
                                  color: AppColors.black,
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              
                              const SizedBox(height: 16),
                              
                              // Progress Bar
                              AnimatedBuilder(
                                animation: _progressAnimation,
                                builder: (context, child) {
                                  return Container(
                                    height: 6,
                                    decoration: BoxDecoration(
                                      color: AppColors.black.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(3),
                                    ),
                                    child: FractionallySizedBox(
                                      alignment: Alignment.centerLeft,
                                      widthFactor: _progressAnimation.value,
                                      child: Container(
                                        decoration: BoxDecoration(
                                          color: AppColors.black,
                                          borderRadius: BorderRadius.circular(3),
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                              
                              const SizedBox(height: 16),
                              
                              // Driver Info (if driver found)
                              if (_driverName.isNotEmpty) ...[
                                Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 25,
                                      backgroundColor: AppColors.black.withOpacity(0.1),
                                      backgroundImage: _driverImageUrl.isNotEmpty ? NetworkImage(_driverImageUrl) : null,
                                      child: _driverImageUrl.isEmpty
                                          ? const Icon(Icons.person, color: AppColors.black, size: 30)
                                          : null,
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            _driverName,
                                            style: const TextStyle(
                                              color: AppColors.black,
                                              fontSize: 16,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          if (_driverVehicle.isNotEmpty)
                                            Text(
                                              _driverVehicle,
                                              style: TextStyle(
                                                color: AppColors.black.withOpacity(0.8),
                                                fontSize: 14,
                                              ),
                                            ),
                                          if (_driverPlate.isNotEmpty) ...[
                                            const SizedBox(height: 2),
                                            Text(
                                              'Plate: $_driverPlate',
                                              style: TextStyle(
                                                color: AppColors.black.withOpacity(0.8),
                                                fontSize: 13,
                                              ),
                                            ),
                                          ],
                                          const SizedBox(height: 4),
                                          if (_driverRating.isNotEmpty)
                                            Text(
                                              _driverRating,
                                              style: TextStyle(
                                                color: AppColors.black.withOpacity(0.7),
                                                fontSize: 13,
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),

                                  ],
                                ),
                              ],
                              
                              const SizedBox(height: 16),
                              
                              // Estimated Time
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.access_time,
                                    color: AppColors.black,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Estimated arrival: $_estimatedTime',
                                    style: const TextStyle(
                                      color: AppColors.black,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 20),

                        // Action Buttons
                        Row(
                          children: [
                            Expanded(
                              child: _ActionButton(
                                icon: Icons.message,
                                text: 'Message',
                                onPressed: _openChat,
                                isDark: isDark,
                              ),
                            ),

                            const SizedBox(width: 16),
                            Expanded(
                              child: _ActionButton(
                                icon: Icons.share_location,
                                text: 'Share',
                                onPressed: () {
                                  // TODO: Implement share location
                                  ModernSnackBar.show(
                                    context,
                                    message: 'Share location feature coming soon!',
                                  );
                                },
                                isDark: isDark,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

class _ActionButton extends StatefulWidget {
  final IconData icon;
  final String text;
  final VoidCallback onPressed;
  final bool isDark;

  const _ActionButton({
    required this.icon,
    required this.text,
    required this.onPressed,
    required this.isDark,
  });

  @override
  State<_ActionButton> createState() => _ActionButtonState();
}

class _ActionButtonState extends State<_ActionButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.95,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _controller.forward(),
      onTapUp: (_) => _controller.reverse(),
      onTapCancel: () => _controller.reverse(),
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                color: AppColors.getCardColor(widget.isDark),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.getBorderColor(widget.isDark),
                  width: 1,
                ),
              ),
              child: Column(
                children: [
                  Icon(
                    widget.icon,
                    color: AppColors.primary,
                    size: 24,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.text,
                    style: TextStyle(
                      color: AppColors.getTextPrimaryColor(widget.isDark),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
