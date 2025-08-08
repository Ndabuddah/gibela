import 'package:cloud_firestore/cloud_firestore.dart';

enum RideStatus { requested, accepted, driverArrived, inProgress, completed, cancelled }

class RideModel {
  final double? vehiclePrice;
  final DateTime? cancelledAt; // ADDED
  final String id;
  final String passengerId;
  final String? driverId;
  final String pickupAddress;
  final String dropoffAddress;
  final double pickupLat;
  final double pickupLng;
  final double dropoffLat;
  final double dropoffLng;
  final String? pickupPlaceId;
  final String? dropoffPlaceId;
  final String vehicleType;
  final double distance; // in kilometers
  final double estimatedFare;
  final double? actualFare;
  final DateTime requestTime;
  final DateTime? pickupTime;
  final DateTime? dropoffTime;
  final RideStatus status;
  final bool isPeak;
  final double riskFactor;
  final String? passengerRating;
  final String? driverRating;
  final String? cancellationReason;
  final int passengerCount;
  final bool isAsambeGirl;
  final bool isAsambeStudent;
  final bool isAsambeLuxury;

  RideModel({
    this.vehiclePrice,
    required this.id,
    this.cancelledAt,
    required this.passengerId,
    this.driverId,
    required this.pickupAddress,
    required this.dropoffAddress,
    required this.pickupLat,
    required this.pickupLng,
    required this.dropoffLat,
    required this.dropoffLng,
    this.pickupPlaceId,
    this.dropoffPlaceId,
    required this.vehicleType,
    required this.distance,
    required this.estimatedFare,
    this.actualFare,
    required this.requestTime,
    this.pickupTime,
    this.dropoffTime,
    this.status = RideStatus.requested,
    required this.isPeak,
    required this.riskFactor,
    this.passengerRating,
    this.driverRating,
    this.cancellationReason,
    this.passengerCount = 1,
    this.isAsambeGirl = false,
    this.isAsambeStudent = false,
    this.isAsambeLuxury = false,
  });

  factory RideModel.fromMap(Map<String, dynamic> data, String id) {
    // Handle both old format (rides collection) and new format (requests collection)
    
    print('🔍 RideModel.fromMap called with data: $data');
    
    // Handle passengerId field (could be 'userId' in requests collection)
    final passengerId = data['passengerId'] ?? data['userId'] ?? '';
    
    // Handle coordinates (could be arrays in requests collection)
    double pickupLat = 0.0;
    double pickupLng = 0.0;
    double dropoffLat = 0.0;
    double dropoffLng = 0.0;
    
    if (data['pickupCoordinates'] != null && data['pickupCoordinates'] is List) {
      // New format: coordinates as arrays
      final pickupCoords = data['pickupCoordinates'] as List;
      print('🔍 Pickup coordinates array: $pickupCoords');
      if (pickupCoords.length >= 2) {
        pickupLat = (pickupCoords[0] ?? 0).toDouble();
        pickupLng = (pickupCoords[1] ?? 0).toDouble();
        print('🔍 Parsed pickup coordinates: $pickupLat, $pickupLng');
      }
    } else {
      // Old format: separate lat/lng fields
      pickupLat = (data['pickupLat'] ?? 0).toDouble();
      pickupLng = (data['pickupLng'] ?? 0).toDouble();
      print('🔍 Using old format pickup coordinates: $pickupLat, $pickupLng');
    }
    
    if (data['dropoffCoordinates'] != null && data['dropoffCoordinates'] is List) {
      // New format: coordinates as arrays
      final dropoffCoords = data['dropoffCoordinates'] as List;
      if (dropoffCoords.length >= 2) {
        dropoffLat = (dropoffCoords[0] ?? 0).toDouble();
        dropoffLng = (dropoffCoords[1] ?? 0).toDouble();
      }
    } else {
      // Old format: separate lat/lng fields
      dropoffLat = (data['dropoffLat'] ?? 0).toDouble();
      dropoffLng = (data['dropoffLng'] ?? 0).toDouble();
    }
    
    // Handle request time (could be 'createdAt' in requests collection)
    DateTime requestTime;
    if (data['requestTime'] != null) {
      requestTime = DateTime.fromMillisecondsSinceEpoch(data['requestTime']);
    } else if (data['createdAt'] != null) {
      // Handle Firestore Timestamp
      if (data['createdAt'] is Timestamp) {
        requestTime = (data['createdAt'] as Timestamp).toDate();
      } else {
        requestTime = DateTime.now();
      }
    } else {
      requestTime = DateTime.now();
    }
    
    // Handle status (could be string in requests collection)
    RideStatus status;
    if (data['status'] is String) {
      // New format: status as string
      switch (data['status']) {
        case 'pending':
          status = RideStatus.requested;
          break;
        case 'accepted':
          status = RideStatus.accepted;
          break;
        case 'driver_arrived':
          status = RideStatus.driverArrived;
          break;
        case 'in_progress':
          status = RideStatus.inProgress;
          break;
        case 'completed':
          status = RideStatus.completed;
          break;
        case 'cancelled':
          status = RideStatus.cancelled;
          break;
        default:
          status = RideStatus.requested;
      }
    } else {
      // Old format: status as integer
      status = RideStatus.values[data['status'] ?? 0];
    }
    
    return RideModel(
      id: id,
      passengerId: passengerId,
      driverId: data['driverId'],
      pickupAddress: data['pickupAddress'] ?? '',
      dropoffAddress: data['dropoffAddress'] ?? '',
      pickupLat: pickupLat,
      pickupLng: pickupLng,
      dropoffLat: dropoffLat,
      dropoffLng: dropoffLng,
      pickupPlaceId: data['pickupPlaceId'],
      dropoffPlaceId: data['dropoffPlaceId'],
      vehicleType: data['vehicleType'] ?? 'small',
      distance: (data['distance'] ?? 0).toDouble(),
      estimatedFare: (data['estimatedFare'] ?? 0).toDouble(),
      actualFare: data['actualFare']?.toDouble(),
      requestTime: requestTime,
      pickupTime: data['pickupTime'] != null ? DateTime.fromMillisecondsSinceEpoch(data['pickupTime']) : null,
      dropoffTime: data['dropoffTime'] != null ? DateTime.fromMillisecondsSinceEpoch(data['dropoffTime']) : null,
      status: status,
      isPeak: data['isPeak'] ?? false,
      riskFactor: (data['riskFactor'] ?? 1.0).toDouble(),
      passengerRating: data['passengerRating'],
      driverRating: data['driverRating'],
      cancellationReason: data['cancellationReason'],
      cancelledAt: data['cancelledAt'] != null ? DateTime.fromMillisecondsSinceEpoch(data['cancelledAt']) : null,
      vehiclePrice: data['vehiclePrice'] != null ? double.tryParse(data['vehiclePrice'].toString()) : null,
      passengerCount: data['passengerCount'] ?? 1,
      isAsambeGirl: data['isAsambeGirl'] ?? false,
      isAsambeStudent: data['isAsambeStudent'] ?? false,
      isAsambeLuxury: data['isAsambeLuxury'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'passengerId': passengerId,
      'driverId': driverId,
      'pickupAddress': pickupAddress,
      'dropoffAddress': dropoffAddress,
      'pickupLat': pickupLat,
      'pickupLng': pickupLng,
      'dropoffLat': dropoffLat,
      'dropoffLng': dropoffLng,
      'pickupPlaceId': pickupPlaceId,
      'dropoffPlaceId': dropoffPlaceId,
      'vehicleType': vehicleType,
      'distance': distance,
      'estimatedFare': estimatedFare,
      'actualFare': actualFare,
      'requestTime': requestTime.millisecondsSinceEpoch,
      'pickupTime': pickupTime?.millisecondsSinceEpoch,
      'dropoffTime': dropoffTime?.millisecondsSinceEpoch,
      'status': status.index,
      'isPeak': isPeak,
      'riskFactor': riskFactor,
      'passengerRating': passengerRating,
      'driverRating': driverRating,
      'cancellationReason': cancellationReason,
      'cancelledAt': cancelledAt?.millisecondsSinceEpoch,
      'vehiclePrice': vehiclePrice,
      'passengerCount': passengerCount,
      'isAsambeGirl': isAsambeGirl,
      'isAsambeStudent': isAsambeStudent,
      'isAsambeLuxury': isAsambeLuxury,
    };
  }

  RideModel copyWith({
    double? vehiclePrice,
    DateTime? cancelledAt,
    String? id,
    String? passengerId,
    String? driverId,
    String? pickupAddress,
    String? dropoffAddress,
    double? pickupLat,
    double? pickupLng,
    double? dropoffLat,
    double? dropoffLng,
    String? pickupPlaceId,
    String? dropoffPlaceId,
    String? vehicleType,
    double? distance,
    double? estimatedFare,
    double? actualFare,
    DateTime? requestTime,
    DateTime? pickupTime,
    DateTime? dropoffTime,
    RideStatus? status,
    bool? isPeak,
    double? riskFactor,
    String? passengerRating,
    String? driverRating,
    String? cancellationReason,
    int? passengerCount,
    bool? isAsambeGirl,
    bool? isAsambeStudent,
    bool? isAsambeLuxury,
  }) {
    return RideModel(
      id: id ?? this.id,
      passengerId: passengerId ?? this.passengerId,
      driverId: driverId ?? this.driverId,
      pickupAddress: pickupAddress ?? this.pickupAddress,
      dropoffAddress: dropoffAddress ?? this.dropoffAddress,
      pickupLat: pickupLat ?? this.pickupLat,
      pickupLng: pickupLng ?? this.pickupLng,
      dropoffLat: dropoffLat ?? this.dropoffLat,
      dropoffLng: dropoffLng ?? this.dropoffLng,
      pickupPlaceId: pickupPlaceId ?? this.pickupPlaceId,
      dropoffPlaceId: dropoffPlaceId ?? this.dropoffPlaceId,
      vehicleType: vehicleType ?? this.vehicleType,
      distance: distance ?? this.distance,
      estimatedFare: estimatedFare ?? this.estimatedFare,
      actualFare: actualFare ?? this.actualFare,
      requestTime: requestTime ?? this.requestTime,
      pickupTime: pickupTime ?? this.pickupTime,
      dropoffTime: dropoffTime ?? this.dropoffTime,
      status: status ?? this.status,
      isPeak: isPeak ?? this.isPeak,
      riskFactor: riskFactor ?? this.riskFactor,
      passengerRating: passengerRating ?? this.passengerRating,
      driverRating: driverRating ?? this.driverRating,
      cancellationReason: cancellationReason ?? this.cancellationReason,
      cancelledAt: cancelledAt ?? this.cancelledAt,
      vehiclePrice: vehiclePrice ?? this.vehiclePrice,
      passengerCount: passengerCount ?? this.passengerCount,
      isAsambeGirl: isAsambeGirl ?? this.isAsambeGirl,
      isAsambeStudent: isAsambeStudent ?? this.isAsambeStudent,
      isAsambeLuxury: isAsambeLuxury ?? this.isAsambeLuxury,
    );
  }
}
