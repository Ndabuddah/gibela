import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';

import '../../../constants/app_colors.dart';
import '../../../models/driver_model.dart';
import '../../../models/ride_model.dart';
import '../../../services/location_service.dart';
import '../../../services/database_service.dart';

class TrackDriverScreen extends StatefulWidget {
  final String rideId;
  final String driverId;
  final String driverName;
  final DriverModel driverDetails;

  const TrackDriverScreen({
    Key? key,
    required this.rideId,
    required this.driverId,
    required this.driverName,
    required this.driverDetails,
  }) : super(key: key);

  @override
  State<TrackDriverScreen> createState() => _TrackDriverScreenState();
}

class _TrackDriverScreenState extends State<TrackDriverScreen> {
  GoogleMapController? _mapController;
  final LocationService _locationService = LocationService();
  final DatabaseService _databaseService = DatabaseService();
  
  // Map state
  LatLng? _passengerLocation;
  LatLng? _driverLocation;
  LatLng? _pickupLocation;
  LatLng? _destinationLocation;
  Set<Marker> _markers = {};
  Set<Polyline> _polylines = {};
  
  // Tracking state
  bool _isTracking = false;
  Timer? _locationTimer;
  StreamSubscription<DocumentSnapshot>? _locationSubscription;
  
  // Ride details
  RideModel? _ride;
  String _estimatedTime = '';
  String _estimatedDistance = '';
  
  @override
  void initState() {
    super.initState();
    _initializeTracking();
  }

  @override
  void dispose() {
    _locationTimer?.cancel();
    _locationSubscription?.cancel();
    _mapController?.dispose();
    super.dispose();
  }

  Future<void> _initializeTracking() async {
    await _loadRideDetails();
    await _getCurrentLocation();
    await _getDriverLocation();
    _startLocationTracking();
  }

  Future<void> _loadRideDetails() async {
    try {
      final ride = await _databaseService.getRideById(widget.rideId);
      if (ride != null) {
        setState(() {
          _ride = ride;
          _pickupLocation = LatLng(ride.pickupLat, ride.pickupLng);
          _destinationLocation = LatLng(ride.dropoffLat, ride.dropoffLng);
        });
        _updateMap();
      }
    } catch (e) {
      print('Error loading ride details: $e');
    }
  }

  Future<void> _getCurrentLocation() async {
    try {
      final position = await _locationService.refreshCurrentLocation();
      if (position != null) {
        setState(() {
          _passengerLocation = LatLng(position.latitude, position.longitude);
        });
        _updateMap();
      }
    } catch (e) {
      print('Error getting current location: $e');
    }
  }

  Future<void> _getDriverLocation() async {
    try {
      // Get driver's current location from Firestore
      final driverDoc = await FirebaseFirestore.instance
          .collection('drivers')
          .doc(widget.driverId)
          .get();
      
      if (driverDoc.exists) {
        final data = driverDoc.data();
        if (data != null && data['currentLocation'] != null) {
          final location = data['currentLocation'];
          setState(() {
            _driverLocation = LatLng(
              location['latitude'] as double,
              location['longitude'] as double,
            );
          });
          _updateMap();
          _calculateRoute();
        }
      }
    } catch (e) {
      print('Error getting driver location: $e');
    }
  }

  void _startLocationTracking() {
    setState(() {
      _isTracking = true;
    });

    // Update driver location every 3 seconds
    _locationTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (mounted) {
        _getDriverLocation();
      } else {
        timer.cancel();
      }
    });

    // Listen to driver location changes in real-time
    _locationSubscription = FirebaseFirestore.instance
        .collection('drivers')
        .doc(widget.driverId)
        .snapshots()
        .listen((snapshot) {
      if (snapshot.exists && mounted) {
        final data = snapshot.data();
        if (data != null && data['currentLocation'] != null) {
          final location = data['currentLocation'];
          final newLocation = LatLng(
            location['latitude'] as double,
            location['longitude'] as double,
          );
          
          setState(() {
            _driverLocation = newLocation;
          });
          
          _updateMap();
          _calculateRoute();
        }
      }
    });
  }

  void _updateMap() {
    if (_mapController == null) return;

    final markers = <Marker>{};
    final polylines = <Polyline>{};

    // Add passenger marker
    if (_passengerLocation != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('passenger'),
          position: _passengerLocation!,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
          infoWindow: const InfoWindow(title: 'Your Location'),
        ),
      );
    }

    // Add driver marker
    if (_driverLocation != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('driver'),
          position: _driverLocation!,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
          infoWindow: InfoWindow(title: '${widget.driverName}'),
          rotation: _calculateBearing(_driverLocation!, _passengerLocation ?? _driverLocation!),
        ),
      );
    }

    // Add pickup location marker
    if (_pickupLocation != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('pickup'),
          position: _pickupLocation!,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange),
          infoWindow: const InfoWindow(title: 'Pickup Location'),
        ),
      );
    }

    // Add destination marker
    if (_destinationLocation != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('destination'),
          position: _destinationLocation!,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
          infoWindow: const InfoWindow(title: 'Destination'),
        ),
      );
    }

    // Add polyline from driver to passenger
    if (_driverLocation != null && _passengerLocation != null) {
      polylines.add(
        Polyline(
          polylineId: const PolylineId('driver_to_passenger'),
          points: [_driverLocation!, _passengerLocation!],
          color: Colors.blue,
          width: 4,
          geodesic: true,
        ),
      );
    }

    // Add polyline from passenger to pickup
    if (_passengerLocation != null && _pickupLocation != null) {
      polylines.add(
        Polyline(
          polylineId: const PolylineId('passenger_to_pickup'),
          points: [_passengerLocation!, _pickupLocation!],
          color: Colors.orange,
          width: 3,
          geodesic: true,
        ),
      );
    }

    // Add polyline from pickup to destination
    if (_pickupLocation != null && _destinationLocation != null) {
      polylines.add(
        Polyline(
          polylineId: const PolylineId('pickup_to_destination'),
          points: [_pickupLocation!, _destinationLocation!],
          color: Colors.red,
          width: 3,
          geodesic: true,
        ),
      );
    }

    setState(() {
      _markers = markers;
      _polylines = polylines;
    });

    // Fit map to show all markers
    _fitMapToMarkers();
  }

  void _fitMapToMarkers() {
    if (_markers.isEmpty || _mapController == null) return;

    final bounds = _calculateBounds();
    _mapController!.animateCamera(
      CameraUpdate.newLatLngBounds(bounds, 50),
    );
  }

  LatLngBounds _calculateBounds() {
    double? minLat, maxLat, minLng, maxLng;

    for (final marker in _markers) {
      final lat = marker.position.latitude;
      final lng = marker.position.longitude;

      minLat = minLat == null ? lat : min(minLat, lat);
      maxLat = maxLat == null ? lat : max(maxLat, lat);
      minLng = minLng == null ? lng : min(minLng, lng);
      maxLng = maxLng == null ? lng : max(maxLng, lng);
    }

    return LatLngBounds(
      southwest: LatLng(minLat!, minLng!),
      northeast: LatLng(maxLat!, maxLng!),
    );
  }

  double _calculateBearing(LatLng start, LatLng end) {
    final lat1 = start.latitude * pi / 180;
    final lat2 = end.latitude * pi / 180;
    final dLng = (end.longitude - start.longitude) * pi / 180;

    final y = sin(dLng) * cos(lat2);
    final x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLng);

    final bearing = atan2(y, x) * 180 / pi;
    return (bearing + 360) % 360;
  }

  void _calculateRoute() {
    if (_driverLocation == null || _passengerLocation == null) return;

    final distance = Geolocator.distanceBetween(
      _driverLocation!.latitude,
      _driverLocation!.longitude,
      _passengerLocation!.latitude,
      _passengerLocation!.longitude,
    );

    final estimatedTime = distance / 500; // Assuming 500 meters per minute

    setState(() {
      _estimatedDistance = '${(distance / 1000).toStringAsFixed(1)} km';
      _estimatedTime = '${estimatedTime.toInt()} min';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text('Track ${widget.driverName}'),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(_isTracking ? Icons.pause : Icons.play_arrow),
            onPressed: () {
              setState(() {
                _isTracking = !_isTracking;
              });
              if (_isTracking) {
                _startLocationTracking();
              } else {
                _locationTimer?.cancel();
                _locationSubscription?.cancel();
              }
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Status Card
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(25),
                  ),
                  child: Icon(
                    Icons.directions_car,
                    color: AppTheme.primaryColor,
                    size: 30,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.driverName,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '${widget.driverDetails.vehicleModel} • ${widget.driverDetails.vehicleColor}',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      _estimatedTime.isNotEmpty ? _estimatedTime : '--',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primaryColor,
                      ),
                    ),
                    Text(
                      _estimatedDistance.isNotEmpty ? _estimatedDistance : '--',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          // Map
          Expanded(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: GoogleMap(
                  onMapCreated: (controller) {
                    _mapController = controller;
                    _updateMap();
                  },
                  initialCameraPosition: CameraPosition(
                    target: _passengerLocation ?? const LatLng(-26.2041, 28.0473), // Johannesburg
                    zoom: 15,
                  ),
                  markers: _markers,
                  polylines: _polylines,
                  myLocationEnabled: true,
                  myLocationButtonEnabled: false,
                  zoomControlsEnabled: false,
                  mapToolbarEnabled: false,
                ),
              ),
            ),
          ),
          
          // Bottom Info
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline,
                  color: AppTheme.primaryColor,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Driver is on the way',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[800],
                        ),
                      ),
                      Text(
                        'Location updates every 3 seconds',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _isTracking ? Colors.green : Colors.grey,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _isTracking ? 'LIVE' : 'PAUSED',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
} 