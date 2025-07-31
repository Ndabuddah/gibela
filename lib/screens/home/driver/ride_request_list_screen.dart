import 'dart:async';
import 'dart:developer' as developer;

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

  Future<void> _onAcceptRidePressed(String docId, Map<String, dynamic> data, String driverId) async {
    if (!mounted) return;
    
    setState(() => _processing.add(docId));
    
    try {
      // Convert to RideModel
      final ride = RideModel.fromMap(data, docId);
      
      // Use RideService to accept the ride
      final rideService = RideService();
      await rideService.acceptRideRequest(ride.id, driverId);
      
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
    } else {
      // Default to Johannesburg if location not available
      setState(() {
        _currentLatLng = latlong2.LatLng(-26.2041, 28.0473);
      });
    }
  }

  Future<void> _loadCurrentDriver() async {
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final user = authService.userModel;
      if (user != null) {
        final driverDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();
        
        if (driverDoc.exists) {
          final driverData = driverDoc.data() as Map<String, dynamic>;
          setState(() {
            _currentDriver = DriverModel.fromMap(driverData);
          });
        }
      }
    } catch (e) {
      print('Error loading current driver: $e');
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
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
                const SizedBox(height: 16),
                Text(
                  'Error loading ride requests',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[700],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Please check your connection and try again',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          );
        }

        final rides = snapshot.data ?? [];
        
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
                      ride.pickupAddress,
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
                      ride.dropoffAddress.isNotEmpty ? ride.dropoffAddress : 'No dropoff address',
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
                      onPressed: isLoading ? null : () => _onAcceptRidePressed(ride.id, ride.toMap(), _currentDriver!.userId),
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