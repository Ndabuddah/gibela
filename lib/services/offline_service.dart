import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'dart:async';

/// Service for handling offline operations and data persistence
class OfflineService {
  static const String _pendingActionsKey = 'pending_actions';
  static const String _cachedRidesKey = 'cached_rides';
  static const String _cachedUserDataKey = 'cached_user_data';
  
  final Connectivity _connectivity = Connectivity();
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  
  /// Check if device is online
  Future<bool> isOnline() async {
    final result = await _connectivity.checkConnectivity();
    return !result.contains(ConnectivityResult.none);
  }
  
  /// Listen to connectivity changes
  Stream<List<ConnectivityResult>> get connectivityStream => _connectivity.onConnectivityChanged;
  
  /// Initialize offline service
  void initialize() {
    _connectivitySubscription = _connectivity.onConnectivityChanged.listen((results) {
      if (!results.contains(ConnectivityResult.none)) {
        // Connection restored, sync pending actions
        _syncPendingActions();
      }
    });
  }
  
  /// Dispose resources
  void dispose() {
    _connectivitySubscription?.cancel();
  }
  
  /// Queue an action to be executed when online
  Future<void> queueAction({
    required String action,
    required Map<String, dynamic> data,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final pendingActions = await getPendingActions();
      
      pendingActions.add({
        'action': action,
        'data': data,
        'timestamp': DateTime.now().toIso8601String(),
      });
      
      await prefs.setString(_pendingActionsKey, jsonEncode(pendingActions));
    } catch (e) {
      print('Error queueing action: $e');
    }
  }
  
  /// Get all pending actions
  Future<List<Map<String, dynamic>>> getPendingActions() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final actionsJson = prefs.getString(_pendingActionsKey);
      
      if (actionsJson == null || actionsJson.isEmpty) {
        return [];
      }
      
      final List<dynamic> decoded = jsonDecode(actionsJson);
      return decoded.cast<Map<String, dynamic>>();
    } catch (e) {
      print('Error getting pending actions: $e');
      return [];
    }
  }
  
  /// Clear pending actions
  Future<void> clearPendingActions() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_pendingActionsKey);
    } catch (e) {
      print('Error clearing pending actions: $e');
    }
  }
  
  /// Remove a specific pending action
  Future<void> removePendingAction(int index) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final pendingActions = await getPendingActions();
      
      if (index >= 0 && index < pendingActions.length) {
        pendingActions.removeAt(index);
        await prefs.setString(_pendingActionsKey, jsonEncode(pendingActions));
      }
    } catch (e) {
      print('Error removing pending action: $e');
    }
  }
  
  /// Cache ride data locally
  Future<void> cacheRide(Map<String, dynamic> ride) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedRides = await getCachedRides();
      
      // Add or update ride
      final index = cachedRides.indexWhere((r) => r['id'] == ride['id']);
      if (index >= 0) {
        cachedRides[index] = ride;
      } else {
        cachedRides.add(ride);
      }
      
      // Keep only last 50 rides
      if (cachedRides.length > 50) {
        cachedRides.removeRange(0, cachedRides.length - 50);
      }
      
      await prefs.setString(_cachedRidesKey, jsonEncode(cachedRides));
    } catch (e) {
      print('Error caching ride: $e');
    }
  }
  
  /// Get cached rides
  Future<List<Map<String, dynamic>>> getCachedRides() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final ridesJson = prefs.getString(_cachedRidesKey);
      
      if (ridesJson == null || ridesJson.isEmpty) {
        return [];
      }
      
      final List<dynamic> decoded = jsonDecode(ridesJson);
      return decoded.cast<Map<String, dynamic>>();
    } catch (e) {
      print('Error getting cached rides: $e');
      return [];
    }
  }
  
  /// Cache user data locally
  Future<void> cacheUserData(String userId, Map<String, dynamic> userData) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedData = await getCachedUserData();
      
      cachedData[userId] = userData;
      
      await prefs.setString(_cachedUserDataKey, jsonEncode(cachedData));
    } catch (e) {
      print('Error caching user data: $e');
    }
  }
  
  /// Get cached user data
  Future<Map<String, Map<String, dynamic>>> getCachedUserData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final dataJson = prefs.getString(_cachedUserDataKey);
      
      if (dataJson == null || dataJson.isEmpty) {
        return {};
      }
      
      final Map<String, dynamic> decoded = jsonDecode(dataJson);
      return decoded.map((key, value) => MapEntry(key, value as Map<String, dynamic>));
    } catch (e) {
      print('Error getting cached user data: $e');
      return {};
    }
  }
  
  /// Sync pending actions when connection is restored
  Future<void> _syncPendingActions() async {
    if (!await isOnline()) {
      return;
    }
    
    final pendingActions = await getPendingActions();
    if (pendingActions.isEmpty) {
      return;
    }
    
    print('🔄 Syncing ${pendingActions.length} pending actions...');
    
    // Process actions in order
    for (int i = pendingActions.length - 1; i >= 0; i--) {
      final action = pendingActions[i];
      try {
        // Execute action based on type
        // This would typically call the appropriate service method
        // For now, we'll just log it
        print('📤 Syncing action: ${action['action']}');
        
        // Remove successfully synced action
        await removePendingAction(i);
      } catch (e) {
        print('❌ Error syncing action: $e');
        // Keep failed actions for retry
      }
    }
  }
  
  /// Clear all cached data
  Future<void> clearCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_cachedRidesKey);
      await prefs.remove(_cachedUserDataKey);
    } catch (e) {
      print('Error clearing cache: $e');
    }
  }
}


