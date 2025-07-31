import 'package:cloud_firestore/cloud_firestore.dart';

class DriverMax2Updater {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Updates all existing drivers' isMax2 field to false
  /// This should be run once to ensure all drivers start with isMax2 = false
  static Future<void> updateAllDriversMax2Field() async {
    try {
      print('Starting to update all drivers\' isMax2 field...');
      
      // Get all users who are drivers
      final driversSnapshot = await _firestore
          .collection('users')
          .where('isDriver', isEqualTo: true)
          .get();
      
      print('Found ${driversSnapshot.docs.length} drivers to update');
      
      if (driversSnapshot.docs.isEmpty) {
        print('No drivers found to update');
        return;
      }

      // Use batched writes for efficiency
      final batch = _firestore.batch();
      int batchCount = 0;
      int totalUpdated = 0;

      for (final doc in driversSnapshot.docs) {
        final data = doc.data();
        
        // Only update if isMax2 is not already false or doesn't exist
        if (data['isMax2'] != false) {
          batch.update(doc.reference, {'isMax2': false});
          batchCount++;
          totalUpdated++;
        }

        // Firestore batches are limited to 500 operations
        if (batchCount >= 500) {
          await batch.commit();
          print('Committed batch of $batchCount updates');
          batchCount = 0;
        }
      }

      // Commit any remaining updates
      if (batchCount > 0) {
        await batch.commit();
        print('Committed final batch of $batchCount updates');
      }

      print('Successfully updated isMax2 field for $totalUpdated drivers');
    } catch (e) {
      print('Error updating drivers\' isMax2 field: $e');
      rethrow;
    }
  }

  /// Updates a specific driver's isMax2 field based on their vehicle purposes
  static Future<void> updateDriverMax2Field(String driverId, List<String> vehiclePurposes) async {
    try {
      final isMax2 = vehiclePurposes.contains('1-2 seater');
      
      await _firestore
          .collection('users')
          .doc(driverId)
          .update({'isMax2': isMax2});
      
      print('Updated driver $driverId isMax2 field to: $isMax2');
    } catch (e) {
      print('Error updating driver $driverId isMax2 field: $e');
      rethrow;
    }
  }

  /// Gets all drivers with their current isMax2 status
  static Future<List<Map<String, dynamic>>> getAllDriversMax2Status() async {
    try {
      final driversSnapshot = await _firestore
          .collection('users')
          .where('isDriver', isEqualTo: true)
          .get();

      return driversSnapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'driverId': doc.id,
          'name': data['name'] ?? 'Unknown',
          'isMax2': data['isMax2'] ?? false,
          'vehiclePurposes': List<String>.from(data['vehiclePurposes'] ?? []),
        };
      }).toList();
    } catch (e) {
      print('Error getting drivers\' max2 status: $e');
      rethrow;
    }
  }
} 