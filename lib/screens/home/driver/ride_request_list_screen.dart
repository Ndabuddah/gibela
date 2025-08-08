import 'dart:async';
import 'dart:developer' as developer;
import 'package:flutter/foundation.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';

import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' as latlong2;
import '../../../services/database_service.dart';
import '../../../models/ride_model.dart';
import '../../../models/driver_model.dart';
import '../../../services/ride_service.dart';
import '../../../services/auth_service.dart';
import '../../../services/location_service.dart';
import '../../../services/ride_filter_service.dart';
import './active_ride_screen.dart';
import './driver_settings_screen.dart';
import 'dart:ui'; // Added for ImageFilter

import '../../../widgets/common/loading_indicator.dart';
import '../../../constants/app_colors.dart';

class RideRequestListScreen extends StatefulWidget {
  const RideRequestListScreen({Key? key}) : super(key: key);

  @override
  State<RideRequestListScreen> createState() => _RideRequestListScreenState();
}

class _RideRequestListScreenState extends State<RideRequestListScreen> {
  List<String> _processedRequestIds = [];

  Set<String> _processing = {};
  latlong2.LatLng? _currentLatLng;
  final RideFilterService _filterService = RideFilterService();
  DriverModel? _currentDriver;

  @override
  void initState() {
    super.initState();
    _loadLocation();
    _loadCurrentDriver();
    // Refresh location every 30 seconds to ensure accurate filtering
    Timer.periodic(const Duration(seconds: 30), (timer) {
      if (mounted) {
        _loadLocation();
      } else {
        timer.cancel();
      }
    });
  }

  // Check if driver has profile picture
  Future<void> _checkProfilePicture() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (userDoc.exists) {
        final userData = userDoc.data() as Map<String, dynamic>;
        final profileImage = userData['profileImage'] as String?;
        
        if (profileImage == null || profileImage.isEmpty) {
          // Show profile picture prompt
          if (mounted) {
            _showProfilePicturePrompt();
          }
        }
      }
    } catch (e) {
      print('Error checking profile picture: $e');
    }
  }

  void _showProfilePicturePrompt() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.camera_alt, color: AppColors.primary),
            SizedBox(width: 8),
            Text('Profile Picture Required'),
          ],
        ),
        content: const Text(
          'You need to add a profile picture to view ride requests. This helps passengers identify you.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _navigateToProfilePicture();
            },
            child: const Text('Take Photo Now'),
          ),
        ],
      ),
    );
  }

  void _navigateToProfilePicture() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const DriverSettingsScreen(),
      ),
    );
  }

  @override
  void dispose() {
    super.dispose();
  }

  // Helper function to safely parse numbers from dynamic values
  double _parseDouble(dynamic value, [double defaultValue = 0.0]) {
    if (value == null) return defaultValue;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) {
      return double.tryParse(value) ?? defaultValue;
    }
    return defaultValue;
  }

  void _showErrorSnackBar(String message) {
    if (!mounted) return;
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    } catch (e) {
      developer.log('Failed to show error message: $e', name: 'RideAccept');
    }
  }

  Future<void> _acceptRide(String docId, Map<String, dynamic> data) async {
    // Validate driver ID
    final driverId = FirebaseAuth.instance.currentUser?.uid;
    if (driverId == null) {
      _showErrorSnackBar('Driver authentication error. Please log in again.');
      return;
    }
    
    // Validate driver ID
    if (driverId.isEmpty) {
      _showErrorSnackBar('Driver ID is missing. Please try again.');
      return;
    }
    
    setState(() => _processing.add(docId));
    
    try {
      print('🔄 Accepting ride request: $docId');
      
      // Convert to RideModel
      final ride = RideModel.fromMap(data, docId);
      
      // Use RideService to accept the ride
      final rideService = RideService();
      await rideService.acceptRideRequest(ride.id, driverId);
      
      print('✅ Ride accepted successfully: $docId');
      
      // Navigate to ActiveRideScreen
      if (!mounted) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => ActiveRideScreen(ride: ride.copyWith(
              driverId: driverId,
              status: RideStatus.accepted,
            )),
          ),
        );
      });
      
    } catch (e, stackTrace) {
      print('❌ Error accepting ride: $e');
      developer.log('Error accepting ride: $e', 
        name: 'RideAccept',
        error: e,
        stackTrace: stackTrace,
      );
      if (mounted) {
        _showErrorSnackBar('Failed to accept ride: ${e.toString()}');
      }
    } finally {
      if (mounted) {
        setState(() => _processing.remove(docId));
      }
    }
  }

  void _playSound() async {
    // Sound functionality removed - audioplayers package removed
  }

  Future<void> _loadLocation() async {
    final locationService = Provider.of<LocationService>(context, listen: false);
    final pos = locationService.currentPosition ?? await locationService.refreshCurrentLocation();
    if (pos != null) {
      setState(() {
        _currentLatLng = latlong2.LatLng(pos.latitude, pos.longitude);
      });
      
      // Debug logging for location
      print('📍 Driver location updated: ${pos.latitude}, ${pos.longitude}');
    } else {
      // Default to Johannesburg if location not available
      setState(() {
        _currentLatLng = latlong2.LatLng(-26.2041, 28.0473);
      });
      print('⚠️ Using default Johannesburg location');
    }
  }

  Future<void> _loadCurrentDriver() async {
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final user = authService.userModel;
      if (user != null) {
        print('👤 Loading driver data for user: ${user.uid}');
        final driverDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();
        
        if (driverDoc.exists) {
          final driverData = driverDoc.data() as Map<String, dynamic>;
          final driver = DriverModel.fromMap(driverData);
          setState(() {
            _currentDriver = driver;
          });
          print('✅ Driver loaded successfully: ${driver.name}');
        } else {
          print('❌ Driver document not found for user: ${user.uid}');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Driver profile not found. Please complete your profile.'),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      } else {
        print('❌ No authenticated user found');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Please log in to view ride requests.'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
      
      // Check profile picture after loading driver
      await _checkProfilePicture();
    } catch (e) {
      print('❌ Error loading current driver: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading driver data: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildFilteredRideRequests() {
    if (_currentDriver == null || _currentLatLng == null) {
      return const Center(child: CircularProgressIndicator());
    }

    // Create a Position object for the filter service
    final driverPosition = Position(
      latitude: _currentLatLng!.latitude,
      longitude: _currentLatLng!.longitude,
      timestamp: DateTime.now(),
      accuracy: 0,
      altitude: 0,
      altitudeAccuracy: 0,
      heading: 0,
      headingAccuracy: 0,
      speed: 0,
      speedAccuracy: 0,
    );

    return StreamBuilder<List<RideModel>>(
      stream: _filterService.getPrioritizedRideRequests(
        driverId: _currentDriver!.userId,
        driverLocation: driverPosition,
        driver: _currentDriver!,
      ),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        
        if (snapshot.hasError) {
          final error = snapshot.error;
          print('❌ Ride request list error: $error');
          
          String errorMessage = 'Error loading ride requests';
          String errorDetails = 'Please check your connection and try again';
          
          // Check if it's an index building error
          if (error.toString().contains('FAILED_PRECONDITION') || 
              error.toString().contains('requires an index')) {
            errorMessage = 'Setting up ride requests';
            errorDetails = 'This may take a few minutes. Please wait...';
          } else if (error.toString().contains('permission-denied')) {
            errorMessage = 'Access denied';
            errorDetails = 'Please check your driver approval status';
          } else if (error.toString().contains('unavailable')) {
            errorMessage = 'Service temporarily unavailable';
            errorDetails = 'Please try again in a few moments';
          }
          
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  errorMessage.contains('Setting up') ? Icons.hourglass_empty : Icons.error_outline, 
                  size: 64, 
                  color: errorMessage.contains('Setting up') ? Colors.orange : Colors.red[300]
                ),
                const SizedBox(height: 16),
                Text(
                  errorMessage,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[700],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  errorDetails,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                  textAlign: TextAlign.center,
                ),
                if (errorMessage.contains('Setting up')) ...[
                  const SizedBox(height: 16),
                  const CircularProgressIndicator(),
                ],
              ],
            ),
          );
        }

        final rides = snapshot.data ?? [];
        
        // Debug logging for ride count
        print('🎯 Found ${rides.length} ride requests for driver');
        
        if (rides.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.search_off, size: 64, color: Colors.grey[400]),
                const SizedBox(height: 16),
                Text(
                  'No available ride requests',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[700],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Ride requests will appear here based on your preferences and location',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                // Debug info for developers
                if (kDebugMode) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      children: [
                        Text(
                          'Debug Info:',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue[700],
                          ),
                        ),
                        Text(
                          'Driver Location: ${_currentLatLng?.latitude.toStringAsFixed(4)}, ${_currentLatLng?.longitude.toStringAsFixed(4)}',
                          style: TextStyle(fontSize: 10, color: Colors.blue[600]),
                        ),
                        Text(
                          'Vehicle Type: ${_currentDriver?.vehicleType ?? 'Not set'}',
                          style: TextStyle(fontSize: 10, color: Colors.blue[600]),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          );
        }

        // Detect new requests
        final newRequests = rides.where((ride) => !_processedRequestIds.contains(ride.id)).toList();
        if (newRequests.isNotEmpty) {
          _processedRequestIds.addAll(newRequests.map((ride) => ride.id));
        }

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: rides.length,
          separatorBuilder: (_, __) => const SizedBox(height: 16),
          itemBuilder: (context, index) {
            final ride = rides[index];
            final isLoading = _processing.contains(ride.id);
            
            return _buildRideRequestCard(ride, isLoading);
          },
        );
      },
    );
  }

  Widget _buildRideRequestCard(RideModel ride, bool isLoading) {
    // Calculate distance from driver to pickup
    final distance = RideFilterService.calculateDistance(
      _currentLatLng!.latitude,
      _currentLatLng!.longitude,
      ride.pickupLat,
      ride.pickupLng,
    );

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 300),
      opacity: isLoading ? 0.5 : 1.0,
      child: Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        elevation: 4,
        color: Colors.white,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Distance indicator
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _getDistanceColor(distance).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${distance.toStringAsFixed(1)} km away',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: _getDistanceColor(distance),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              
              // Pickup location
              Row(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.all(10),
                    child: const Icon(Icons.my_location, color: AppColors.primary, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      ride.pickupAddress.isNotEmpty 
                          ? ride.pickupAddress 
                          : '📍 ${ride.pickupLat.toStringAsFixed(4)}, ${ride.pickupLng.toStringAsFixed(4)}',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              
              // Dropoff location
              Row(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.all(10),
                    child: const Icon(Icons.location_on, color: Colors.red, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      ride.dropoffAddress.isNotEmpty 
                          ? ride.dropoffAddress 
                          : '📍 ${ride.dropoffLat.toStringAsFixed(4)}, ${ride.dropoffLng.toStringAsFixed(4)}',
                      style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 15),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              
              // Ride details
              Row(
                children: [
                  _buildRideDetailChip('${ride.passengerCount} passenger${ride.passengerCount > 1 ? 's' : ''}', Icons.person),
                  const SizedBox(width: 8),
                  _buildRideDetailChip(ride.vehicleType.toUpperCase(), Icons.directions_car),
                  if (ride.isAsambeGirl) ...[
                    const SizedBox(width: 8),
                    _buildRideDetailChip('ASAMBE GIRL', Icons.female, Colors.pink),
                  ],
                  if (ride.isAsambeStudent) ...[
                    const SizedBox(width: 8),
                    _buildRideDetailChip('ASAMBE STUDENT', Icons.school, Colors.blue),
                  ],
                  if (ride.isAsambeLuxury) ...[
                    const SizedBox(width: 8),
                    _buildRideDetailChip('ASAMBE LUXURY', Icons.star, Colors.amber),
                  ],
                ],
              ),
              const SizedBox(height: 16),
              
              // Fare and accept button
              Row(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.all(10),
                    child: const Icon(Icons.attach_money, color: Colors.green, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'R${ride.estimatedFare.toStringAsFixed(2)}',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.green),
                  ),
                  const Spacer(),
                  if (_currentDriver?.userId != null)
                    ElevatedButton(
                      onPressed: isLoading ? null : () => _acceptRide(ride.id, ride.toMap()),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      ),
                      child: isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : const Text('Accept', style: TextStyle(fontWeight: FontWeight.bold)),
                    )
                  else
                    const Text('Driver not available', style: TextStyle(color: Colors.red)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRideDetailChip(String label, IconData icon, [Color? color]) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: (color ?? Colors.grey).withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: (color ?? Colors.grey).withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color ?? Colors.grey[700]),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color ?? Colors.grey[700],
            ),
          ),
        ],
      ),
    );
  }

  Color _getDistanceColor(double distance) {
    if (distance <= 1.0) return Colors.green;
    if (distance <= 3.0) return Colors.orange;
    return Colors.red;
  }

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context, listen: false);
    final user = authService.userModel;
    final isDriverApproved = user?.isApproved ?? false;
    final driverId = user?.uid;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Available Ride Requests'),
        backgroundColor: AppColors.primary,
        elevation: 0,
      ),
      body: Stack(
        children: [
          // Map background
          if (_currentLatLng != null)
            FlutterMap(
              options: MapOptions(
                center: _currentLatLng,
                zoom: 14.5,
                interactiveFlags: InteractiveFlag.pinchZoom | InteractiveFlag.drag,
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                  subdomains: const ['a', 'b', 'c'],
                  userAgentPackageName: 'com.rideapp.mobile',
                ),
                MarkerLayer(
                  markers: [
                    Marker(
                      width: 48,
                      height: 48,
                      point: _currentLatLng!,
                      builder: (ctx) => const Icon(Icons.directions_car, color: Colors.blueAccent, size: 40),
                    ),
                  ],
                ),
              ],
            )
          else
            const Center(child: CircularProgressIndicator()),
          // Requests list UI
          Positioned.fill(
            child: Container(
              color: Colors.white.withOpacity(0.85),
              child: _buildFilteredRideRequests(),
            ),
          ),
        ],
      ),
    );
  }
} 