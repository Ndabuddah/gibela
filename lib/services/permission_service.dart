import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PermissionService {
  static const String _locationPermissionKey = 'location_permission_explained';
  static const String _backgroundLocationPermissionKey = 'background_location_permission_explained';
  static const String _dontAskAgainKey = 'location_permission_dont_ask_again';

  // Check if location permission is granted
  static Future<bool> isLocationPermissionGranted() async {
    try {
      final permission = await Geolocator.checkPermission();
      print('Location Permission Status: $permission');
      return permission == LocationPermission.whileInUse || 
             permission == LocationPermission.always;
    } catch (e) {
      print('Error checking location permission: $e');
      return false;
    }
  }

  // Check if background location permission is granted
  static Future<bool> isBackgroundLocationPermissionGranted() async {
    try {
      final permission = await Geolocator.checkPermission();
      print('Background Location Permission Status: $permission');
      return permission == LocationPermission.always;
    } catch (e) {
      print('Error checking background location permission: $e');
      return false;
    }
  }

  // Check if location services are enabled
  static Future<bool> isLocationServiceEnabled() async {
    try {
      final enabled = await Geolocator.isLocationServiceEnabled();
      print('Location Service Enabled: $enabled');
      return enabled;
    } catch (e) {
      print('Error checking location service: $e');
      return false;
    }
  }

  // Request location permission
  static Future<bool> requestLocationPermission() async {
    try {
      final permission = await Geolocator.requestPermission();
      print('Location Permission Request Result: $permission');
      return permission == LocationPermission.whileInUse || 
             permission == LocationPermission.always;
    } catch (e) {
      print('Error requesting location permission: $e');
      return false;
    }
  }

  // Request background location permission
  static Future<bool> requestBackgroundLocationPermission() async {
    try {
      // First ensure we have basic location permission
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      
      // For background location, we need to request again specifically for "always" permission
      if (permission == LocationPermission.whileInUse || permission == LocationPermission.always) {
        // On Android, we need to request background separately
        permission = await Geolocator.requestPermission();
        
        // Give a moment for the system to process the permission
        await Future.delayed(const Duration(milliseconds: 500));
        
        // Check the final permission status
        permission = await Geolocator.checkPermission();
      }
      
      return permission == LocationPermission.always;
    } catch (e) {
      print('Error requesting background location: $e');
      return false;
    }
  }

  // Check if we should show permission explanation
  static Future<bool> shouldShowLocationPermissionExplanation() async {
    final prefs = await SharedPreferences.getInstance();
    final dontAskAgain = prefs.getBool(_dontAskAgainKey) ?? false;
    if (dontAskAgain) return false;
    return !(prefs.getBool(_locationPermissionKey) ?? false);
  }

  // Check if we should show background location permission explanation
  static Future<bool> shouldShowBackgroundLocationPermissionExplanation() async {
    final prefs = await SharedPreferences.getInstance();
    final dontAskAgain = prefs.getBool(_dontAskAgainKey) ?? false;
    if (dontAskAgain) return false;
    return !(prefs.getBool(_backgroundLocationPermissionKey) ?? false);
  }

  // Mark location permission as explained
  static Future<void> markLocationPermissionExplained() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_locationPermissionKey, true);
  }

  // Mark background location permission as explained
  static Future<void> markBackgroundLocationPermissionExplained() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_backgroundLocationPermissionKey, true);
  }

  // Mark as "don't ask again"
  static Future<void> setDontAskAgain() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_dontAskAgainKey, true);
  }

  // Reset "don't ask again" (useful for testing or user changes mind)
  static Future<void> resetDontAskAgain() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_dontAskAgainKey, false);
  }

  // Get comprehensive permission status
  static Future<Map<String, bool>> getPermissionStatus() async {
    try {
      final locationServiceEnabled = await isLocationServiceEnabled();
      if (!locationServiceEnabled) {
        return {
          'locationGranted': false,
          'backgroundLocationGranted': false,
          'locationServiceEnabled': false,
        };
      }

      final permission = await Geolocator.checkPermission();
      final locationGranted = permission == LocationPermission.whileInUse || 
                            permission == LocationPermission.always;
      final backgroundLocationGranted = permission == LocationPermission.always;

      return {
        'locationGranted': locationGranted,
        'backgroundLocationGranted': backgroundLocationGranted,
        'locationServiceEnabled': locationServiceEnabled,
      };
    } catch (e) {
      print('Error getting permission status: $e');
      return {
        'locationGranted': false,
        'backgroundLocationGranted': false,
        'locationServiceEnabled': false,
      };
    }
  }

  // Check if all required permissions are granted
  static Future<bool> areAllPermissionsGranted() async {
    final locationGranted = await isLocationPermissionGranted();
    final backgroundLocationGranted = await isBackgroundLocationPermissionGranted();
    final locationServiceEnabled = await isLocationServiceEnabled();

    // For both drivers and passengers, we need location services and basic location permission
    // Background location is required for both to track rides in background
    return locationGranted && backgroundLocationGranted && locationServiceEnabled;
  }

  // Check if we should show permission screen (considers "don't ask again")
  static Future<bool> shouldShowPermissionScreen() async {
    // First check if all permissions are already granted
    final allGranted = await areAllPermissionsGranted();
    if (allGranted) return false;
    
    // If not all granted, check if user has chosen "don't ask again"
    final prefs = await SharedPreferences.getInstance();
    final dontAskAgain = prefs.getBool(_dontAskAgainKey) ?? false;
    
    // Only show if not all granted and user hasn't chosen "don't ask again"
    return !dontAskAgain;
  }
} 