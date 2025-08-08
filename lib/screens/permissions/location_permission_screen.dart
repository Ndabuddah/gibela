import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:gibelbibela/constants/app_colors.dart';
import 'package:gibelbibela/services/permission_service.dart';
import 'package:gibelbibela/screens/home/driver/driver_home_screen.dart';
import 'package:gibelbibela/screens/home/passenger/passenger_home_screen.dart';
import 'dart:async'; // Added for Timer

class LocationPermissionScreen extends StatefulWidget {
  final bool isDriver;
  final VoidCallback? onPermissionGranted;

  const LocationPermissionScreen({
    super.key, 
    required this.isDriver, 
    this.onPermissionGranted
  });

  @override
  State<LocationPermissionScreen> createState() => _LocationPermissionScreenState();
}

class _LocationPermissionScreenState extends State<LocationPermissionScreen> {
  bool _isLoading = false;
  bool _locationGranted = false;
  bool _backgroundLocationGranted = false;
  bool _locationServiceEnabled = false;
  bool _showPermissionSelection = false;

  @override
  void initState() {
    super.initState();
    // Check permissions immediately and periodically
    _checkInitialPermissions();
    // Set up periodic permission check
    Timer.periodic(const Duration(seconds: 2), (_) {
      if (mounted) {
        _checkPermissionStatus();
      }
    });
  }

  Future<void> _checkInitialPermissions() async {
    final status = await PermissionService.getPermissionStatus();
    if (mounted) {
      setState(() {
        _locationServiceEnabled = status['locationServiceEnabled'] ?? false;
        _locationGranted = status['locationGranted'] ?? false;
        _backgroundLocationGranted = status['backgroundLocationGranted'] ?? false;
      });
    }
  }

  Future<void> _requestLocationPermission() async {
    setState(() => _isLoading = true);

    try {
      final granted = await PermissionService.requestLocationPermission();
      if (mounted) {
        if (granted) {
          setState(() {
            _locationGranted = true;
            // If location is granted, consider background location also granted
            _backgroundLocationGranted = true;
          });
          await PermissionService.markLocationPermissionExplained();
        }
        await _checkPermissionStatus();
      }
    } catch (e) {
      if (mounted) {
        _showErrorSnackBar('Failed to request location permission');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _requestBackgroundLocationPermission() async {
    setState(() => _isLoading = true);

    try {
      final granted = await PermissionService.requestBackgroundLocationPermission();
      if (mounted) {
        if (granted) {
          setState(() {
            _backgroundLocationGranted = true;
          });
          await PermissionService.markBackgroundLocationPermissionExplained();
        }
        await _checkPermissionStatus();
      }
    } catch (e) {
      if (mounted) {
        _showErrorSnackBar('Failed to request background location permission');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _openLocationSettings() async {
    try {
      final canOpen = await Geolocator.openLocationSettings();
      if (!canOpen && mounted) {
        _showErrorSnackBar('Cannot open location settings. Please enable location services manually.');
      }
      // Wait a bit longer for the user to potentially change settings
      await Future.delayed(const Duration(seconds: 3));
      if (mounted) {
        await _checkPermissionStatus();
      }
    } catch (e) {
      if (mounted) {
        _showErrorSnackBar('Failed to open location settings. Please enable location services manually.');
      }
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  void _navigateToHomeScreen() {
    if (widget.isDriver) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (_) => const DriverHomeScreen(),
          settings: const RouteSettings(name: '/driver_home'),
        ),
        (route) => false,
      );
    } else {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (_) => const PassengerHomeScreen(),
          settings: const RouteSettings(name: '/passenger_home'),
        ),
        (route) => false,
      );
    }
  }

  Future<void> _checkPermissionStatus() async {
    try {
      // First check location service
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      print('Location Service Check: $serviceEnabled');
      
      // Then check permission
      final permission = await Geolocator.checkPermission();
      print('Permission Check: $permission');
      
      if (mounted) {
        setState(() {
          _locationServiceEnabled = serviceEnabled;
          _locationGranted = permission == LocationPermission.whileInUse || 
                           permission == LocationPermission.always;
          _backgroundLocationGranted = _locationGranted;
          
          print('Updated States:');
          print('Location Service Enabled: $_locationServiceEnabled');
          print('Location Granted: $_locationGranted');
        });
      }
    } catch (e) {
      print('Error checking permissions: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    // For passengers, consider permissions granted if location service is enabled and basic location permission is granted
    // Background location is optional for passengers
    final isAllGranted = _locationGranted && _locationServiceEnabled;
    print('Build Check:');
    print('Location Service Enabled: $_locationServiceEnabled');
    print('Location Granted: $_locationGranted');
    print('All Granted: $isAllGranted');

    return WillPopScope(
      onWillPop: () async => false, // Prevent back button
      child: Scaffold(
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.black, Colors.black.withOpacity(0.9)],
            ),
          ),
          child: SafeArea(
            child: Column(
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () {
                          // Allow users to skip if they want
                          _navigateToHomeScreen();
                        },
                        icon: const Icon(Icons.close, color: Colors.white, size: 28),
                      ),
                      const Spacer(),
                      if (isAllGranted)
                        TextButton(
                          onPressed: _navigateToHomeScreen,
                          child: const Text(
                            'Continue',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                // Content
                Expanded(
                  child: SingleChildScrollView(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isAllGranted 
                              ? 'Great! You can now use the app with location features.'
                              : 'Location permissions help us provide better service',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.white.withOpacity(0.7),
                            ),
                          ),
                          const SizedBox(height: 20),
                          _buildPermissionCard(
                            icon: Icons.location_on,
                            title: 'Location Services',
                            description: 'Enable location services in your device settings. This is required for basic app functionality.',
                            isGranted: _locationServiceEnabled,
                            onTap: _openLocationSettings,
                            showButton: !_locationServiceEnabled,
                            buttonText: 'Open Settings',
                            showSettingsButton: false,
                          ),
                          const SizedBox(height: 16),
                          _buildPermissionCard(
                            icon: Icons.my_location,
                            title: 'Location Permission',
                            description: 'Allow app to access your location while using the app. This is necessary for finding nearby services.',
                            isGranted: _locationGranted,
                            onTap: _locationGranted ? null : _requestLocationPermission,
                            showButton: !_locationGranted && _locationServiceEnabled,
                            buttonText: 'Grant Permission',
                            showSettingsButton: !_locationGranted && _locationServiceEnabled,
                          ),
                          const SizedBox(height: 16),
                          _buildPermissionCard(
                            icon: Icons.location_searching,
                            title: 'Background Location (Optional)',
                            description: widget.isDriver
                                ? 'As per Google\'s requirements, background location access is essential for:\n\n'
                                  '• Receiving real-time ride requests even when app is minimized\n'
                                  '• Continuous location updates for accurate driver tracking\n'
                                  '• Safety features and emergency assistance\n'
                                  '• Route optimization and navigation updates\n\n'
                                  'Without this permission, you won\'t receive ride requests when the app is in background.'
                                : 'Background location access is optional for passengers and helps with:\n\n'
                                  '• Continuous ride tracking even when app is minimized\n'
                                  '• Real-time driver location updates\n'
                                  '• Safety features and emergency assistance\n'
                                  '• Accurate pickup and dropoff coordination\n\n'
                                  'You can still use the app without this permission.',
                            isGranted: _backgroundLocationGranted,
                            onTap: _backgroundLocationGranted ? null : _requestBackgroundLocationPermission,
                            showButton: !_backgroundLocationGranted && _locationGranted,
                            buttonText: 'Grant Permission',
                            showSettingsButton: !_backgroundLocationGranted && _locationGranted,
                          ),
                          // Add padding at the bottom for the continue button
                          const SizedBox(height: 100),
                        ],
                      ),
                    ),
                  ),
                ),
                // Bottom section with "Don't ask again" option
                Container(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      // Don't ask again option
                      if (!isAllGranted)
                        TextButton(
                          onPressed: () async {
                            await PermissionService.setDontAskAgain();
                            _navigateToHomeScreen();
                          },
                          child: Text(
                            'Don\'t ask again',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.6),
                              fontSize: 14,
                            ),
                          ),
                        ),
                      const SizedBox(height: 10),
                      // Continue button (only show if basic permissions are granted)
                      if (isAllGranted)
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _navigateToHomeScreen,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: Colors.black,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text(
                              'Continue to App',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPermissionCard({
    required IconData icon,
    required String title,
    required String description,
    required bool isGranted,
    required VoidCallback? onTap,
    required bool showButton,
    required String buttonText,
    required bool showSettingsButton,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isGranted ? Colors.green : Colors.grey[300]!,
          width: 2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                icon,
                color: isGranted ? Colors.green : AppColors.primary,
                size: 24,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isGranted ? Colors.green : Colors.black,
                  ),
                ),
              ),
              if (isGranted)
                const Icon(
                  Icons.check_circle,
                  color: Colors.green,
                  size: 24,
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            description,
            style: TextStyle(
              color: Colors.grey[700],
              fontSize: 14,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 12),
          if (showButton)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : onTap,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  elevation: 2,
                ),
                child: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : Text(
                        buttonText,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
          if (showSettingsButton && !isGranted)
            TextButton(
              onPressed: _isLoading ? null : _openLocationSettings,
              child: Text(
                'Open Settings',
                style: TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
