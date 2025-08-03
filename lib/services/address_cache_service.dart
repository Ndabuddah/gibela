import 'dart:convert';
import 'package:geocoding/geocoding.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AddressCacheService {
  static const String _cacheKey = 'address_cache';
  static const int _maxCacheSize = 1000; // Maximum number of cached addresses
  static const Duration _cacheExpiry = Duration(days: 7); // Cache for 7 days

  // Cache structure: { "lat_lng": { "address": "...", "timestamp": 1234567890 } }
  Map<String, Map<String, dynamic>> _cache = {};

  AddressCacheService() {
    _loadCache();
  }

  // Generate cache key from coordinates
  String _generateCacheKey(double lat, double lng) {
    // Round to 4 decimal places (approximately 11 meters precision)
    final roundedLat = (lat * 10000).round() / 10000;
    final roundedLng = (lng * 10000).round() / 10000;
    return '${roundedLat}_${roundedLng}';
  }

  // Load cache from SharedPreferences
  Future<void> _loadCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheString = prefs.getString(_cacheKey);
      if (cacheString != null) {
        final cacheData = json.decode(cacheString) as Map<String, dynamic>;
        _cache = Map<String, Map<String, dynamic>>.from(cacheData);
        _cleanExpiredEntries();
      }
    } catch (e) {
      print('Error loading address cache: $e');
      _cache = {};
    }
  }

  // Save cache to SharedPreferences
  Future<void> _saveCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheString = json.encode(_cache);
      await prefs.setString(_cacheKey, cacheString);
    } catch (e) {
      print('Error saving address cache: $e');
    }
  }

  // Clean expired cache entries
  void _cleanExpiredEntries() {
    final now = DateTime.now().millisecondsSinceEpoch;
    final expiryTime = _cacheExpiry.inMilliseconds;
    
    _cache.removeWhere((key, value) {
      final timestamp = value['timestamp'] as int? ?? 0;
      return (now - timestamp) > expiryTime;
    });
  }

  // Get address from cache or fetch from geocoding service
  Future<String?> getAddressFromCoordinates(double lat, double lng) async {
    final cacheKey = _generateCacheKey(lat, lng);
    
    // Check cache first
    if (_cache.containsKey(cacheKey)) {
      final cachedData = _cache[cacheKey]!;
      final timestamp = cachedData['timestamp'] as int? ?? 0;
      final now = DateTime.now().millisecondsSinceEpoch;
      
      // Check if cache is still valid
      if ((now - timestamp) < _cacheExpiry.inMilliseconds) {
        return cachedData['address'] as String?;
      } else {
        // Remove expired entry
        _cache.remove(cacheKey);
      }
    }

    // Fetch from geocoding service
    try {
      final placemarks = await placemarkFromCoordinates(lat, lng);
      if (placemarks.isNotEmpty) {
        final place = placemarks.first;
        final address = _formatAddress(place);
        
        // Cache the result
        _cache[cacheKey] = {
          'address': address,
          'timestamp': DateTime.now().millisecondsSinceEpoch,
        };
        
        // Limit cache size
        if (_cache.length > _maxCacheSize) {
          _removeOldestEntries();
        }
        
        // Save cache
        await _saveCache();
        
        return address;
      }
      return null;
    } catch (e) {
      print('Error fetching address for coordinates ($lat, $lng): $e');
      return null;
    }
  }

  // Format address from Placemark
  String _formatAddress(Placemark place) {
    final parts = <String>[];
    
    if (place.street?.isNotEmpty == true) parts.add(place.street!);
    if (place.subLocality?.isNotEmpty == true) parts.add(place.subLocality!);
    if (place.locality?.isNotEmpty == true) parts.add(place.locality!);
    
    if (parts.isEmpty) {
      // Fallback to coordinates if no address parts available
      return '${place.latitude?.toStringAsFixed(4)}, ${place.longitude?.toStringAsFixed(4)}';
    }
    
    return parts.join(', ');
  }

  // Remove oldest cache entries when cache is full
  void _removeOldestEntries() {
    final entries = _cache.entries.toList();
    entries.sort((a, b) {
      final timestampA = a.value['timestamp'] as int? ?? 0;
      final timestampB = b.value['timestamp'] as int? ?? 0;
      return timestampA.compareTo(timestampB);
    });
    
    // Remove oldest 20% of entries
    final removeCount = (_maxCacheSize * 0.2).round();
    for (int i = 0; i < removeCount && i < entries.length; i++) {
      _cache.remove(entries[i].key);
    }
  }

  // Clear all cache
  Future<void> clearCache() async {
    _cache.clear();
    await _saveCache();
  }

  // Get cache statistics
  Map<String, dynamic> getCacheStats() {
    return {
      'size': _cache.length,
      'maxSize': _maxCacheSize,
      'expiryDays': _cacheExpiry.inDays,
    };
  }

  // Get coordinates as fallback display
  static String getCoordinatesDisplay(double lat, double lng) {
    return '${lat.toStringAsFixed(4)}, ${lng.toStringAsFixed(4)}';
  }

  // Check if coordinates are valid
  static bool isValidCoordinates(double lat, double lng) {
    return lat >= -90 && lat <= 90 && lng >= -180 && lng <= 180;
  }
} 