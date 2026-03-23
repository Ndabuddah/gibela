import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/ride_model.dart';

/// Service for generating and managing ride receipts
class ReceiptService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  /// Generate a detailed receipt for a completed ride
  Future<Map<String, dynamic>> generateReceipt(String rideId) async {
    try {
      // Get ride data
      final rideDoc = await _firestore.collection('rides').doc(rideId).get();
      if (!rideDoc.exists) {
        throw Exception('Ride not found');
      }
      
      final rideData = rideDoc.data()!;
      final ride = RideModel.fromMap(rideData, rideId);
      
      // Get passenger details
      final passengerDoc = await _firestore.collection('users').doc(ride.passengerId).get();
      final passengerData = passengerDoc.data() ?? {};
      
      // Get driver details if available
      Map<String, dynamic>? driverData;
      if (ride.driverId != null && ride.driverId!.isNotEmpty) {
        final driverDoc = await _firestore.collection('drivers').doc(ride.driverId).get();
        driverData = driverDoc.data();
      }
      
      // Calculate duration if available
      int? duration;
      if (ride.pickupTime != null && ride.dropoffTime != null) {
        duration = ride.dropoffTime!.difference(ride.pickupTime!).inSeconds;
      }
      
      // Get pricing breakdown from ride data or calculate defaults
      final totalFare = ride.actualFare ?? ride.estimatedFare;
      final baseFare = totalFare * 0.4; // Estimate 40% base fare
      final distanceFare = totalFare * 0.5; // Estimate 50% distance fare
      final timeFare = duration != null ? (duration / 60) * 0.5 : 0.0; // Estimate time fare
      final serviceFee = totalFare * 0.1; // Estimate 10% service fee
      
      // Get payment type from ride data or default
      final paymentType = rideData['paymentType'] ?? 'Cash';
      
      // Build receipt
      final receipt = {
        'rideId': rideId,
        'receiptNumber': _generateReceiptNumber(rideId),
        'date': ride.dropoffTime ?? ride.requestTime,
        'passenger': {
          'id': ride.passengerId,
          'name': passengerData['name'] ?? 'Unknown',
          'email': passengerData['email'] ?? '',
          'phone': passengerData['phone'] ?? '',
        },
        'driver': driverData != null ? {
          'id': ride.driverId,
          'name': driverData['name'] ?? 'Unknown',
          'phone': driverData['phone'] ?? '',
          'licensePlate': driverData['licensePlate'] ?? '',
        } : null,
        'trip': {
          'pickupAddress': ride.pickupAddress,
          'dropoffAddress': ride.dropoffAddress,
          'distance': ride.distance,
          'duration': duration,
          'vehicleType': ride.vehicleType,
        },
        'pricing': {
          'baseFare': baseFare,
          'distanceFare': distanceFare,
          'timeFare': timeFare,
          'surgeMultiplier': rideData['surgeMultiplier'] ?? ride.riskFactor,
          'serviceFee': serviceFee,
          'subtotal': ride.estimatedFare,
          'total': totalFare,
          'paymentMethod': paymentType,
        },
        'status': ride.status.toString(),
      };
      
      // Save receipt to Firestore
      await _firestore.collection('receipts').doc(rideId).set({
        ...receipt,
        'createdAt': FieldValue.serverTimestamp(),
      });
      
      return receipt;
    } catch (e) {
      print('Error generating receipt: $e');
      rethrow;
    }
  }
  
  /// Generate a unique receipt number
  String _generateReceiptNumber(String rideId) {
    // Use first 8 characters of rideId + timestamp
    final timestamp = DateTime.now().millisecondsSinceEpoch.toString();
    return 'GB${rideId.substring(0, rideId.length > 8 ? 8 : rideId.length)}${timestamp.substring(timestamp.length - 6)}';
  }
  
  /// Get receipt by ride ID
  Future<Map<String, dynamic>?> getReceipt(String rideId) async {
    try {
      final receiptDoc = await _firestore.collection('receipts').doc(rideId).get();
      if (!receiptDoc.exists) {
        return null;
      }
      return receiptDoc.data();
    } catch (e) {
      print('Error getting receipt: $e');
      return null;
    }
  }
  
  /// Format receipt as text for sharing/printing
  String formatReceiptAsText(Map<String, dynamic> receipt) {
    final buffer = StringBuffer();
    
    buffer.writeln('═══════════════════════════════════');
    buffer.writeln('          GIBELA RIDE RECEIPT');
    buffer.writeln('═══════════════════════════════════');
    buffer.writeln('');
    buffer.writeln('Receipt #: ${receipt['receiptNumber']}');
    buffer.writeln('Date: ${_formatDate(receipt['date'])}');
    buffer.writeln('');
    
    // Passenger info
    final passenger = receipt['passenger'] as Map<String, dynamic>;
    buffer.writeln('Passenger: ${passenger['name']}');
    if (passenger['phone'] != null && passenger['phone'].toString().isNotEmpty) {
      buffer.writeln('Phone: ${passenger['phone']}');
    }
    buffer.writeln('');
    
    // Driver info
    if (receipt['driver'] != null) {
      final driver = receipt['driver'] as Map<String, dynamic>;
      buffer.writeln('Driver: ${driver['name']}');
      if (driver['licensePlate'] != null && driver['licensePlate'].toString().isNotEmpty) {
        buffer.writeln('Vehicle: ${driver['licensePlate']}');
      }
      buffer.writeln('');
    }
    
    // Trip details
    final trip = receipt['trip'] as Map<String, dynamic>;
    buffer.writeln('FROM: ${trip['pickupAddress']}');
    buffer.writeln('TO: ${trip['dropoffAddress']}');
    buffer.writeln('Distance: ${trip['distance'].toStringAsFixed(2)} km');
    if (trip['duration'] != null) {
      buffer.writeln('Duration: ${_formatDuration(trip['duration'])}');
    }
    buffer.writeln('Vehicle Type: ${trip['vehicleType']}');
    buffer.writeln('');
    
    // Pricing breakdown
    final pricing = receipt['pricing'] as Map<String, dynamic>;
    buffer.writeln('═══════════════════════════════════');
    buffer.writeln('PRICING BREAKDOWN');
    buffer.writeln('═══════════════════════════════════');
    
    if (pricing['baseFare'] != null && (pricing['baseFare'] as num) > 0) {
      buffer.writeln('Base Fare:        R${(pricing['baseFare'] as num).toStringAsFixed(2)}');
    }
    if (pricing['distanceFare'] != null && (pricing['distanceFare'] as num) > 0) {
      buffer.writeln('Distance Fare:    R${(pricing['distanceFare'] as num).toStringAsFixed(2)}');
    }
    if (pricing['timeFare'] != null && (pricing['timeFare'] as num) > 0) {
      buffer.writeln('Time Fare:        R${(pricing['timeFare'] as num).toStringAsFixed(2)}');
    }
    if (pricing['surgeMultiplier'] != null && (pricing['surgeMultiplier'] as num) > 1.0) {
      buffer.writeln('Surge (${(pricing['surgeMultiplier'] as num).toStringAsFixed(2)}x):   Applied');
    }
    if (pricing['serviceFee'] != null && (pricing['serviceFee'] as num) > 0) {
      buffer.writeln('Service Fee:      R${(pricing['serviceFee'] as num).toStringAsFixed(2)}');
    }
    
    buffer.writeln('───────────────────────────────────');
    buffer.writeln('TOTAL:            R${(pricing['total'] as num).toStringAsFixed(2)}');
    buffer.writeln('Payment Method:   ${pricing['paymentMethod']}');
    buffer.writeln('');
    buffer.writeln('═══════════════════════════════════');
    buffer.writeln('Thank you for using Gibela!');
    buffer.writeln('═══════════════════════════════════');
    
    return buffer.toString();
  }
  
  /// Format date for receipt
  String _formatDate(dynamic date) {
    if (date is Timestamp) {
      return date.toDate().toString().substring(0, 19);
    } else if (date is DateTime) {
      return date.toString().substring(0, 19);
    } else if (date is String) {
      return date.substring(0, date.length > 19 ? 19 : date.length);
    }
    return date.toString();
  }
  
  /// Format duration for receipt
  String _formatDuration(int? seconds) {
    if (seconds == null) return 'N/A';
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    return '${minutes}m ${remainingSeconds}s';
  }
}

