import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../models/driver_model.dart';

class DriverProfileService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final CollectionReference _driversCollection = FirebaseFirestore.instance.collection('drivers');

  // Calculate profile completion percentage
  double calculateProfileCompletion(DriverModel driver) {
    int totalFields = 0;
    int completedFields = 0;

    // Basic Information
    final basicFields = {
      'name': driver.name,
      'phoneNumber': driver.phoneNumber,
      'email': driver.email,
      'idNumber': driver.idNumber,
      'profileImage': driver.profileImage,
    };

    totalFields += basicFields.length;
    completedFields += basicFields.values.where((value) => value != null && value.toString().isNotEmpty).length;

    // Vehicle Information
    final vehicleFields = {
      'vehicleType': driver.vehicleType,
      'vehicleModel': driver.vehicleModel,
      'vehicleColor': driver.vehicleColor,
      'licensePlate': driver.licensePlate,
    };

    totalFields += vehicleFields.length;
    completedFields += vehicleFields.values.where((value) => value != null && value.toString().isNotEmpty).length;

    // Documents
    if (driver.documents.isNotEmpty) {
      totalFields += driver.documents.length;
      completedFields += driver.documents.values.where((value) => value.isNotEmpty).length;
    }

    // Service Areas
    if (driver.serviceAreaPreferences.isNotEmpty) {
      totalFields++;
      completedFields++;
    }

    // Working Hours
    if (driver.workingHours.isNotEmpty) {
      totalFields++;
      completedFields++;
    }

    return (completedFields / totalFields) * 100;
  }

  // Update document management
  Future<void> updateDocument(String driverId, String documentType, File file) async {
    try {
      final ref = _storage.ref('driver_documents/$driverId/$documentType');
      await ref.putFile(file);
      final url = await ref.getDownloadURL();

      await _driversCollection.doc(driverId).update({
        'documents.$documentType': url,
        'documentVerificationStatus.$documentType': false,
        'documentExpiryDates.$documentType': DateTime.now().add(const Duration(days: 365)).toIso8601String(),
      });
    } catch (e) {
      rethrow;
    }
  }

  // Update vehicle information
  Future<void> updateVehicleInformation(String driverId, Map<String, dynamic> vehicleInfo) async {
    try {
      await _driversCollection.doc(driverId).update({
        'vehicleInformation': vehicleInfo,
      });
    } catch (e) {
      rethrow;
    }
  }

  // Update service area preferences
  Future<void> updateServiceAreas(String driverId, Map<String, List<String>> areas) async {
    try {
      await _driversCollection.doc(driverId).update({
        'serviceAreaPreferences': areas,
      });
    } catch (e) {
      rethrow;
    }
  }

  // Update working hours
  Future<void> updateWorkingHours(String driverId, Map<String, List<String>> hours) async {
    try {
      await _driversCollection.doc(driverId).update({
        'workingHours': hours,
      });
    } catch (e) {
      rethrow;
    }
  }

  // Update profile photo
  Future<void> updateProfilePhoto(String driverId, File photo) async {
    try {
      final ref = _storage.ref('driver_profiles/$driverId/profile_photo');
      await ref.putFile(photo);
      final url = await ref.getDownloadURL();

      await _driversCollection.doc(driverId).update({
        'profileImage': url,
      });
    } catch (e) {
      rethrow;
    }
  }

  // Update driver preferences
  Future<void> updateDriverPreferences(String driverId, Map<String, dynamic> preferences) async {
    try {
      await _driversCollection.doc(driverId).update({
        'driverPreferences': preferences,
      });
    } catch (e) {
      rethrow;
    }
  }

  // Get document verification status
  Future<Map<String, bool>> getDocumentVerificationStatus(String driverId) async {
    try {
      final doc = await _driversCollection.doc(driverId).get();
      final data = doc.data() as Map<String, dynamic>;
      return Map<String, bool>.from(data['documentVerificationStatus'] ?? {});
    } catch (e) {
      rethrow;
    }
  }

  // Get document expiry dates
  Future<Map<String, DateTime>> getDocumentExpiryDates(String driverId) async {
    try {
      final doc = await _driversCollection.doc(driverId).get();
      final data = doc.data() as Map<String, dynamic>;
      final expiryDates = data['documentExpiryDates'] as Map<String, dynamic>? ?? {};
      return expiryDates.map((key, value) => MapEntry(key, DateTime.parse(value as String)));
    } catch (e) {
      rethrow;
    }
  }
}