import 'dart:math'; // This is correct; it allows access to math functions

import 'package:flutter/material.dart';
import 'package:google_maps_webservice/places.dart';

import '../constants/app_constants.dart';
import '../services/pricing_service.dart';

class RideRequestProvider extends ChangeNotifier {
  String? pickupAddress;
  List<double>? pickupCoords;
  String? dropoffAddress;
  List<double>? dropoffCoords;
  double? distanceKm;

  bool isLoadingPickup = false;
  bool isLoadingDropoff = false;
  bool isCalculatingDistance = false;

  List<Map<String, dynamic>> pickupSuggestions = [];
  List<Map<String, dynamic>> dropoffSuggestions = [];

  // Ride request status
  RideRequestStatus requestStatus = RideRequestStatus.idle;
  String? requestError;

  String _vehicleType = 'small';
  String get vehicleType => _vehicleType;
  void setVehicleType(String type) {
    _vehicleType = type;
    notifyListeners();
  }

  void setRequestStatus(RideRequestStatus status, {String? error}) {
    requestStatus = status;
    requestError = error;
    notifyListeners();
  }

  final GoogleMapsPlaces _places = GoogleMapsPlaces(apiKey: AppConstants.googleApiKey);

  void clear() {
    pickupAddress = null;
    pickupCoords = null;
    dropoffAddress = null;
    dropoffCoords = null;
    distanceKm = null;
    pickupSuggestions = [];
    dropoffSuggestions = [];
    _vehicleType = 'small';
    notifyListeners();
  }

  Future<void> searchPickup(String query) async {
    isLoadingPickup = true;
    notifyListeners();
    final response = await _places.autocomplete(query, components: [Component(Component.country, 'ZA')]);
    if (response.isOkay) {
      pickupSuggestions = response.predictions
          .map((p) => {
                'place_id': p.placeId,
                'place_name': p.description,
              })
          .toList();
    } else {
      pickupSuggestions = [];
    }
    isLoadingPickup = false;
    notifyListeners();
  }

  Future<void> searchDropoff(String query) async {
    isLoadingDropoff = true;
    notifyListeners();
    final response = await _places.autocomplete(query, components: [Component(Component.country, 'ZA')]);
    if (response.isOkay) {
      dropoffSuggestions = response.predictions
          .map((p) => {
                'place_id': p.placeId,
                'place_name': p.description,
              })
          .toList();
    } else {
      dropoffSuggestions = [];
    }
    isLoadingDropoff = false;
    notifyListeners();
  }

  Future<void> selectPickup(Map<String, dynamic> place) async {
    pickupAddress = place['place_name'];
    pickupSuggestions = [];
    notifyListeners();
    // Get coordinates for the selected place
    final details = await _places.getDetailsByPlaceId(place['place_id']);
    if (details.isOkay && details.result.geometry != null) {
      final loc = details.result.geometry!.location;
      pickupCoords = [loc.lat, loc.lng];
    }
    notifyListeners();
    _tryCalculateDistance();
  }

  Future<void> selectDropoff(Map<String, dynamic> place) async {
    dropoffAddress = place['place_name'];
    dropoffSuggestions = [];
    notifyListeners();
    // Get coordinates for the selected place
    final details = await _places.getDetailsByPlaceId(place['place_id']);
    if (details.isOkay && details.result.geometry != null) {
      final loc = details.result.geometry!.location;
      dropoffCoords = [loc.lat, loc.lng];
    }
    notifyListeners();
    _tryCalculateDistance();
  }

  Future<void> _tryCalculateDistance() async {
    if (pickupCoords != null && dropoffCoords != null) {
      isCalculatingDistance = true;
      notifyListeners();
      // Calculate straight-line distance (Haversine formula)
      distanceKm = _calculateDistance(
        pickupCoords![0],
        pickupCoords![1],
        dropoffCoords![0],
        dropoffCoords![1],
      );
      isCalculatingDistance = false;
      notifyListeners();
    }
  }

  // Calculate fare for selected vehicle type
  double? calculateFare(String vehicleType) {
    if (distanceKm == null) return null;
    
    return PricingService.calculateFare(
      distanceKm: distanceKm!,
      vehicleType: vehicleType,
      requestTime: DateTime.now(),
    );
  }

  // Get all fares for comparison
  Map<String, double> getAllFares() {
    if (distanceKm == null) return {};
    
    return PricingService.calculateAllFares(
      distanceKm: distanceKm!,
      requestTime: DateTime.now(),
    );
  }

  double _calculateDistance(double lat1, double lng1, double lat2, double lng2) {
    const double R = 6371; // Earth radius in km
    final double dLat = _deg2rad(lat2 - lat1);
    final double dLng = _deg2rad(lng2 - lng1);
    final double a = (sin(dLat / 2) * sin(dLat / 2)) + cos(_deg2rad(lat1)) * cos(_deg2rad(lat2)) * (sin(dLng / 2) * sin(dLng / 2));
    final double c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return R * c;
  }

  double _deg2rad(double deg) => deg * (pi / 180.0);
}

enum RideRequestStatus {
  idle,
  submitting,
  waiting,
  accepted,
  rejected,
  completed,
}
