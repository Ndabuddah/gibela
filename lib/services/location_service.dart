import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

import '../constants/app_constants.dart';
import 'address_cache_service.dart';
// Removed: import 'mapbox_service.dart';

class LocationService extends ChangeNotifier {
  Position? _currentPosition;
  final AddressCacheService _addressCache = AddressCacheService();

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
      // Use cached address service for better performance
      final address = await _addressCache.getAddressFromCoordinates(lat, lng);
      if (address != null) {
        return address;
      }
      
      // Fallback to coordinates if address lookup fails
      return AddressCacheService.getCoordinatesDisplay(lat, lng);
    } catch (e) {
      // Return coordinates as fallback
      return AddressCacheService.getCoordinatesDisplay(lat, lng);
    }
  }

  // Get coordinates as primary identifier (fast, no network calls)
  String getCoordinatesDisplay(double lat, double lng) {
    return AddressCacheService.getCoordinatesDisplay(lat, lng);
  }

  // Check if coordinates are valid
  bool isValidCoordinates(double lat, double lng) {
    return AddressCacheService.isValidCoordinates(lat, lng);
  }

  // Get address with coordinates fallback
  Future<String> getAddressWithCoordinatesFallback(double lat, double lng) async {
    final address = await getAddressFromCoordinates(lat, lng);
    if (address != null && address.isNotEmpty) {
      return address;
    }
    return getCoordinatesDisplay(lat, lng);
  }
}
