import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:google_maps_flutter/google_maps_flutter.dart' as gmaps;
import '../constants/app_constants.dart';

/// Service for enhanced map routing with traffic and route options
class MapRouteService {
  /// Get route with traffic information using Google Directions API
  Future<RouteInfo?> getRouteWithTraffic({
    required gmaps.LatLng origin,
    required gmaps.LatLng destination,
    bool avoidTolls = false,
    bool avoidHighways = false,
  }) async {
    try {
      // Build Google Directions API URL
      final originStr = '${origin.latitude},${origin.longitude}';
      final destStr = '${destination.latitude},${destination.longitude}';
      
      final avoid = <String>[];
      if (avoidTolls) avoid.add('tolls');
      if (avoidHighways) avoid.add('highways');
      
      final avoidStr = avoid.isNotEmpty ? '&avoid=${avoid.join('|')}' : '';
      final trafficModel = '&traffic_model=best_guess';
      final departureTime = '&departure_time=${DateTime.now().millisecondsSinceEpoch ~/ 1000}';
      
      final url = Uri.parse(
        'https://maps.googleapis.com/maps/api/directions/json?'
        'origin=$originStr'
        '&destination=$destStr'
        '&key=${AppConstants.googleApiKey}'
        '$avoidStr'
        '$trafficModel'
        '$departureTime'
        '&alternatives=true',
      );
      
      final response = await http.get(url);
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        
        if (data['status'] == 'OK' && data['routes'] != null) {
          final routes = data['routes'] as List;
          if (routes.isNotEmpty) {
            final route = routes.first as Map<String, dynamic>;
            final legs = route['legs'] as List;
            if (legs.isNotEmpty) {
              final leg = legs.first as Map<String, dynamic>;
              final distance = leg['distance'] as Map<String, dynamic>;
              final duration = leg['duration'] as Map<String, dynamic>;
              final durationInTraffic = leg['duration_in_traffic'] as Map<String, dynamic>?;
              
              return RouteInfo(
                polylinePoints: route['overview_polyline']?['points'] ?? '',
                distance: (distance['value'] as num).toDouble() / 1000, // Convert to km
                duration: (duration['value'] as num).toInt(), // in seconds
                durationInTraffic: durationInTraffic != null 
                    ? (durationInTraffic['value'] as num).toInt()
                    : (duration['value'] as num).toInt(),
                startAddress: leg['start_address'] ?? '',
                endAddress: leg['end_address'] ?? '',
                steps: (leg['steps'] as List?)?.map((step) {
                  final stepMap = step as Map<String, dynamic>;
                  return RouteStep(
                    distance: ((stepMap['distance'] as Map)['value'] as num).toDouble() / 1000,
                    duration: ((stepMap['duration'] as Map)['value'] as num).toInt(),
                    instruction: stepMap['html_instructions'] ?? '',
                    polyline: stepMap['polyline']?['points'] ?? '',
                  );
                }).toList() ?? [],
                trafficLevel: _calculateTrafficLevel(
                  (duration['value'] as num).toInt(),
                  durationInTraffic != null ? (durationInTraffic['value'] as num).toInt() : null,
                ),
              );
            }
          }
        }
      }
      
      return null;
    } catch (e) {
      print('Error getting route with traffic: $e');
      return null;
    }
  }
  
  /// Get multiple route options
  Future<List<RouteInfo>> getRouteOptions({
    required gmaps.LatLng origin,
    required gmaps.LatLng destination,
  }) async {
    final routes = <RouteInfo>[];
    
    // Get default route
    final defaultRoute = await getRouteWithTraffic(
      origin: origin,
      destination: destination,
    );
    if (defaultRoute != null) {
      routes.add(defaultRoute);
    }
    
    // Get route avoiding tolls
    final noTollsRoute = await getRouteWithTraffic(
      origin: origin,
      destination: destination,
      avoidTolls: true,
    );
    if (noTollsRoute != null && noTollsRoute.distance != defaultRoute?.distance) {
      routes.add(noTollsRoute);
    }
    
    // Get route avoiding highways
    final noHighwaysRoute = await getRouteWithTraffic(
      origin: origin,
      destination: destination,
      avoidHighways: true,
    );
    if (noHighwaysRoute != null && noHighwaysRoute.distance != defaultRoute?.distance) {
      routes.add(noHighwaysRoute);
    }
    
    // Sort by duration
    routes.sort((a, b) => a.durationInTraffic.compareTo(b.durationInTraffic));
    
    return routes;
  }
  
  /// Calculate traffic level based on duration difference
  TrafficLevel _calculateTrafficLevel(int normalDuration, int? trafficDuration) {
    if (trafficDuration == null) return TrafficLevel.normal;
    
    final difference = trafficDuration - normalDuration;
    final percentage = (difference / normalDuration) * 100;
    
    if (percentage < 5) return TrafficLevel.light;
    if (percentage < 15) return TrafficLevel.normal;
    if (percentage < 30) return TrafficLevel.moderate;
    return TrafficLevel.heavy;
  }
  
  /// Decode polyline string to list of LatLng points
  List<gmaps.LatLng> decodePolyline(String encoded) {
    final List<gmaps.LatLng> points = [];
    int index = 0;
    int lat = 0;
    int lng = 0;
    
    while (index < encoded.length) {
      int shift = 0;
      int result = 0;
      int byte;
      
      do {
        byte = encoded.codeUnitAt(index++) - 63;
        result |= (byte & 0x1F) << shift;
        shift += 5;
      } while (byte >= 0x20);
      
      final dlat = ((result & 1) != 0) ? ~(result >> 1) : (result >> 1);
      lat += dlat;
      
      shift = 0;
      result = 0;
      
      do {
        byte = encoded.codeUnitAt(index++) - 63;
        result |= (byte & 0x1F) << shift;
        shift += 5;
      } while (byte >= 0x20);
      
      final dlng = ((result & 1) != 0) ? ~(result >> 1) : (result >> 1);
      lng += dlng;
      
      points.add(gmaps.LatLng(lat / 1e5, lng / 1e5));
    }
    
    return points;
  }
}

/// Route information with traffic data
class RouteInfo {
  final String polylinePoints;
  final double distance; // in km
  final int duration; // in seconds
  final int durationInTraffic; // in seconds
  final String startAddress;
  final String endAddress;
  final List<RouteStep> steps;
  final TrafficLevel trafficLevel;
  
  RouteInfo({
    required this.polylinePoints,
    required this.distance,
    required this.duration,
    required this.durationInTraffic,
    required this.startAddress,
    required this.endAddress,
    required this.steps,
    required this.trafficLevel,
  });
  
  String get formattedDistance => '${distance.toStringAsFixed(1)} km';
  String get formattedDuration => _formatDuration(duration);
  String get formattedDurationInTraffic => _formatDuration(durationInTraffic);
  
  String _formatDuration(int seconds) {
    final minutes = seconds ~/ 60;
    if (minutes < 60) {
      return '${minutes}min';
    }
    final hours = minutes ~/ 60;
    final remainingMinutes = minutes % 60;
    return '${hours}h ${remainingMinutes}min';
  }
}

/// Route step information
class RouteStep {
  final double distance; // in km
  final int duration; // in seconds
  final String instruction;
  final String polyline;
  
  RouteStep({
    required this.distance,
    required this.duration,
    required this.instruction,
    required this.polyline,
  });
}

/// Traffic level enum
enum TrafficLevel {
  light,
  normal,
  moderate,
  heavy,
}

extension TrafficLevelExtension on TrafficLevel {
  String get label {
    switch (this) {
      case TrafficLevel.light:
        return 'Light Traffic';
      case TrafficLevel.normal:
        return 'Normal Traffic';
      case TrafficLevel.moderate:
        return 'Moderate Traffic';
      case TrafficLevel.heavy:
        return 'Heavy Traffic';
    }
  }
  
  int get colorValue {
    switch (this) {
      case TrafficLevel.light:
        return 0xFF4CAF50; // Green
      case TrafficLevel.normal:
        return 0xFF2196F3; // Blue
      case TrafficLevel.moderate:
        return 0xFFFF9800; // Orange
      case TrafficLevel.heavy:
        return 0xFFF44336; // Red
    }
  }
}
