import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class SavedPlace {
  final String id;
  final String name;
  final String address;
  final double latitude;
  final double longitude;
  final String? placeId;
  final DateTime createdAt;
  final String type; // 'home', 'work', 'favorite', etc.

  SavedPlace({
    required this.id,
    required this.name,
    required this.address,
    required this.latitude,
    required this.longitude,
    this.placeId,
    required this.createdAt,
    this.type = 'favorite',
  });

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'address': address,
      'latitude': latitude,
      'longitude': longitude,
      'placeId': placeId,
      'createdAt': createdAt.toIso8601String(),
      'type': type,
    };
  }

  factory SavedPlace.fromMap(String id, Map<String, dynamic> map) {
    return SavedPlace(
      id: id,
      name: map['name'] ?? '',
      address: map['address'] ?? '',
      latitude: (map['latitude'] as num).toDouble(),
      longitude: (map['longitude'] as num).toDouble(),
      placeId: map['placeId'],
      createdAt: DateTime.parse(map['createdAt']),
      type: map['type'] ?? 'favorite',
    );
  }
}

class SavedPlacesService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  CollectionReference get _savedPlacesCollection {
    final userId = _auth.currentUser?.uid;
    if (userId == null) {
      throw Exception('User not logged in');
    }
    return _firestore.collection('users').doc(userId).collection('saved_places');
  }

  /// Get all saved places
  Stream<List<SavedPlace>> getSavedPlaces() {
    return _savedPlacesCollection
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => SavedPlace.fromMap(doc.id, doc.data() as Map<String, dynamic>))
            .toList());
  }

  /// Add a saved place
  Future<String> addSavedPlace(SavedPlace place) async {
    try {
      final docRef = await _savedPlacesCollection.add(place.toMap());
      return docRef.id;
    } catch (e) {
      throw Exception('Failed to save place: $e');
    }
  }

  /// Update a saved place
  Future<void> updateSavedPlace(String placeId, SavedPlace place) async {
    try {
      await _savedPlacesCollection.doc(placeId).update(place.toMap());
    } catch (e) {
      throw Exception('Failed to update place: $e');
    }
  }

  /// Delete a saved place
  Future<void> deleteSavedPlace(String placeId) async {
    try {
      await _savedPlacesCollection.doc(placeId).delete();
    } catch (e) {
      throw Exception('Failed to delete place: $e');
    }
  }

  /// Get saved place by ID
  Future<SavedPlace?> getSavedPlaceById(String placeId) async {
    try {
      final doc = await _savedPlacesCollection.doc(placeId).get();
      if (doc.exists) {
        return SavedPlace.fromMap(doc.id, doc.data() as Map<String, dynamic>);
      }
      return null;
    } catch (e) {
      throw Exception('Failed to get place: $e');
    }
  }

  /// Get places by type
  Stream<List<SavedPlace>> getPlacesByType(String type) {
    return _savedPlacesCollection
        .where('type', isEqualTo: type)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => SavedPlace.fromMap(doc.id, doc.data() as Map<String, dynamic>))
            .toList());
  }
}

