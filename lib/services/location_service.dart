import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

import '../constants/app_constants.dart';
// Removed: import 'mapbox_service.dart';

class LocationService extends ChangeNotifier {
  Position? _currentPosition;

  LocationService() {
    _getCurrentLocation();
  }

  Position? get currentPosition => _currentPosition;

  Future<Position?> _getCurrentLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return null;

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return null;
      }

      if (permission == LocationPermission.deniedForever) return null;

      _currentPosition = await Geolocator.getCurrentPosition();
      notifyListeners();
      return _currentPosition;
    } catch (e) {
      return null;
    }
  }

  Future<Position?> refreshCurrentLocation() async {
    return await _getCurrentLocation();
  }

  // Request location permission and get current position, with user-friendly error
  Future<Position?> requestAndGetCurrentLocation(BuildContext context) async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      _showLocationError(context, 'Location services are disabled. Please enable them in your device settings.');
      return null;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        _showLocationError(context, 'Location permission denied. Please allow location access.');
        return null;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      _showLocationError(context, 'Location permission permanently denied. Please enable it in your device settings.');
      return null;
    }

    // Check for background location permission
    if (permission == LocationPermission.whileInUse) {
      // Try to request background location permission
      permission = await Geolocator.requestPermission();
    }

    try {
      _currentPosition = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      notifyListeners();
      return _currentPosition;
    } catch (e) {
      _showLocationError(context, 'Failed to get current location.');
      return null;
    }
  }

  void _showLocationError(BuildContext context, String message) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    });
  }

  Future<String?> getAddressFromCoordinates(double lat, double lng) async {
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(lat, lng);
      if (placemarks.isNotEmpty) {
        final place = placemarks.first;
        return '${place.street}, ${place.subLocality}, ${place.locality}';
      }
      return null;
    } catch (e) {
      return null;
    }
  }
}
