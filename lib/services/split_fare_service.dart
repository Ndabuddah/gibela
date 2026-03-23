import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Service for handling split fare payments
class SplitFareService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  /// Create a split fare request
  Future<String> createSplitFareRequest({
    required String rideId,
    required String initiatorId,
    required double totalFare,
    required List<String> participantIds,
    required Map<String, double> amounts, // userId -> amount
  }) async {
    try {
      final splitRequestRef = await _firestore.collection('split_fares').add({
        'rideId': rideId,
        'initiatorId': initiatorId,
        'totalFare': totalFare,
        'participantIds': participantIds,
        'amounts': amounts.map((key, value) => MapEntry(key, value)),
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
        'payments': {},
      });
      
      // Send notifications to participants
      for (var participantId in participantIds) {
        if (participantId != initiatorId) {
          await _sendSplitFareNotification(
            participantId: participantId,
            rideId: rideId,
            amount: amounts[participantId] ?? 0.0,
            splitRequestId: splitRequestRef.id,
          );
        }
      }
      
      return splitRequestRef.id;
    } catch (e) {
      print('Error creating split fare request: $e');
      rethrow;
    }
  }
  
  /// Accept and pay split fare
  Future<bool> paySplitFare({
    required String splitRequestId,
    required String userId,
    required String paymentMethod,
    String? paymentReference,
  }) async {
    try {
      return await _firestore.runTransaction<bool>((transaction) async {
        final splitRequestRef = _firestore.collection('split_fares').doc(splitRequestId);
        final splitRequestDoc = await transaction.get(splitRequestRef);
        
        if (!splitRequestDoc.exists) {
          throw Exception('Split fare request not found');
        }
        
        final data = splitRequestDoc.data()!;
        final payments = Map<String, dynamic>.from(data['payments'] ?? {});
        final amounts = Map<String, dynamic>.from(data['amounts'] ?? {});
        
        // Check if already paid
        if (payments.containsKey(userId)) {
          return false; // Already paid
        }
        
        // Record payment
        payments[userId] = {
          'amount': amounts[userId] ?? 0.0,
          'paymentMethod': paymentMethod,
          'paymentReference': paymentReference,
          'paidAt': FieldValue.serverTimestamp(),
        };
        
        // Check if all participants have paid
        final participantIds = List<String>.from(data['participantIds'] ?? []);
        final allPaid = participantIds.every((id) => payments.containsKey(id));
        
        transaction.update(splitRequestRef, {
          'payments': payments,
          'status': allPaid ? 'completed' : 'partial',
          'updatedAt': FieldValue.serverTimestamp(),
        });
        
        return true;
      });
    } catch (e) {
      print('Error paying split fare: $e');
      return false;
    }
  }
  
  /// Get split fare status
  Future<SplitFareStatus?> getSplitFareStatus(String splitRequestId) async {
    try {
      final doc = await _firestore.collection('split_fares').doc(splitRequestId).get();
      if (!doc.exists) return null;
      
      final data = doc.data()!;
      final payments = Map<String, dynamic>.from(data['payments'] ?? {});
      final participantIds = List<String>.from(data['participantIds'] ?? []);
      final amounts = Map<String, dynamic>.from(data['amounts'] ?? {});
      
      return SplitFareStatus(
        splitRequestId: splitRequestId,
        rideId: data['rideId'] ?? '',
        initiatorId: data['initiatorId'] ?? '',
        totalFare: (data['totalFare'] as num).toDouble(),
        participantIds: participantIds,
        amounts: amounts.map((key, value) => MapEntry(key, (value as num).toDouble())),
        payments: payments.map((key, value) => MapEntry(key, value as Map<String, dynamic>)),
        status: data['status'] ?? 'pending',
      );
    } catch (e) {
      print('Error getting split fare status: $e');
      return null;
    }
  }
  
  /// Get user's pending split fare requests
  Future<List<SplitFareStatus>> getUserPendingSplitFares(String userId) async {
    try {
      final snapshot = await _firestore
          .collection('split_fares')
          .where('participantIds', arrayContains: userId)
          .where('status', whereIn: ['pending', 'partial'])
          .get();
      
      final List<SplitFareStatus> splitFares = [];
      for (var doc in snapshot.docs) {
        final data = doc.data();
        final payments = Map<String, dynamic>.from(data['payments'] ?? {});
        
        // Only include if user hasn't paid yet
        if (!payments.containsKey(userId)) {
          final participantIds = List<String>.from(data['participantIds'] ?? []);
          final amounts = Map<String, dynamic>.from(data['amounts'] ?? {});
          
          splitFares.add(SplitFareStatus(
            splitRequestId: doc.id,
            rideId: data['rideId'] ?? '',
            initiatorId: data['initiatorId'] ?? '',
            totalFare: (data['totalFare'] as num).toDouble(),
            participantIds: participantIds,
            amounts: amounts.map((key, value) => MapEntry(key, (value as num).toDouble())),
            payments: payments.map((key, value) => MapEntry(key, value as Map<String, dynamic>)),
            status: data['status'] ?? 'pending',
          ));
        }
      }
      
      return splitFares;
    } catch (e) {
      print('Error getting user pending split fares: $e');
      return [];
    }
  }
  
  /// Calculate split amounts evenly
  static Map<String, double> calculateEvenSplit({
    required double totalFare,
    required List<String> participantIds,
  }) {
    final amountPerPerson = totalFare / participantIds.length;
    return Map.fromEntries(
      participantIds.map((id) => MapEntry(id, amountPerPerson)),
    );
  }
  
  /// Calculate split amounts by percentage
  static Map<String, double> calculatePercentageSplit({
    required double totalFare,
    required Map<String, double> percentages, // userId -> percentage (0-100)
  }) {
    return percentages.map((key, percentage) => MapEntry(
      key,
      totalFare * (percentage / 100),
    ));
  }
  
  /// Send notification to participant
  Future<void> _sendSplitFareNotification({
    required String participantId,
    required String rideId,
    required double amount,
    required String splitRequestId,
  }) async {
    try {
      await _firestore.collection('notifications').add({
        'userId': participantId,
        'title': 'Split Fare Request',
        'body': 'You have been requested to pay R${amount.toStringAsFixed(2)} for a ride.',
        'type': 'split_fare',
        'data': {
          'rideId': rideId,
          'splitRequestId': splitRequestId,
          'amount': amount,
        },
        'timestamp': FieldValue.serverTimestamp(),
        'isRead': false,
      });
    } catch (e) {
      print('Error sending split fare notification: $e');
    }
  }
}

/// Split fare status model
class SplitFareStatus {
  final String splitRequestId;
  final String rideId;
  final String initiatorId;
  final double totalFare;
  final List<String> participantIds;
  final Map<String, double> amounts;
  final Map<String, Map<String, dynamic>> payments;
  final String status;
  
  SplitFareStatus({
    required this.splitRequestId,
    required this.rideId,
    required this.initiatorId,
    required this.totalFare,
    required this.participantIds,
    required this.amounts,
    required this.payments,
    required this.status,
  });
  
  bool get isCompleted => status == 'completed';
  bool get isPartial => status == 'partial';
  bool get isPending => status == 'pending';
  
  double get paidAmount {
    return payments.values.fold(0.0, (sum, payment) {
      return sum + ((payment['amount'] as num?)?.toDouble() ?? 0.0);
    });
  }
  
  double get remainingAmount => totalFare - paidAmount;
  
  List<String> get unpaidParticipants {
    return participantIds.where((id) => !payments.containsKey(id)).toList();
  }
  
  bool hasUserPaid(String userId) => payments.containsKey(userId);
  double getUserAmount(String userId) => amounts[userId] ?? 0.0;
}


