import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/painting.dart';

/// Service for performance optimizations
class PerformanceService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  // Cache for frequently accessed data
  final Map<String, dynamic> _cache = {};
  final Map<String, DateTime> _cacheTimestamps = {};
  static const Duration _cacheExpiry = Duration(minutes: 5);
  
  /// Get cached data or fetch if expired
  Future<T?> getCachedOrFetch<T>({
    required String cacheKey,
    required Future<T> Function() fetchFunction,
    Duration? expiry,
  }) async {
    // Check cache
    if (_cache.containsKey(cacheKey)) {
      final timestamp = _cacheTimestamps[cacheKey];
      if (timestamp != null && 
          DateTime.now().difference(timestamp) < (expiry ?? _cacheExpiry)) {
        return _cache[cacheKey] as T?;
      }
    }
    
    // Fetch fresh data
    try {
      final data = await fetchFunction();
      _cache[cacheKey] = data;
      _cacheTimestamps[cacheKey] = DateTime.now();
      return data;
    } catch (e) {
      // Return cached data even if expired if fetch fails
      if (_cache.containsKey(cacheKey)) {
        return _cache[cacheKey] as T?;
      }
      rethrow;
    }
  }
  
  /// Clear cache
  void clearCache({String? key}) {
    if (key != null) {
      _cache.remove(key);
      _cacheTimestamps.remove(key);
    } else {
      _cache.clear();
      _cacheTimestamps.clear();
    }
  }
  
  /// Preload images for better performance
  /// Note: Requires BuildContext, use ImageCacheManager.cacheImage instead
  static Future<void> preloadImages(BuildContext context, List<String> imageUrls) async {
    for (var url in imageUrls) {
      try {
        await precacheImage(CachedNetworkImageProvider(url), context);
      } catch (e) {
        print('Error preloading image $url: $e');
      }
    }
  }
  
  /// Batch Firestore queries for better performance
  static Future<List<DocumentSnapshot>> batchGetDocuments({
    required List<DocumentReference> references,
    int batchSize = 10,
  }) async {
    final results = <DocumentSnapshot>[];
    
    for (var i = 0; i < references.length; i += batchSize) {
      final batch = references.skip(i).take(batchSize).toList();
      final snapshots = await Future.wait(
        batch.map((ref) => ref.get()),
      );
      results.addAll(snapshots);
    }
    
    return results;
  }
  
  /// Optimize Firestore query with pagination
  static Query paginateQuery(Query query, {
    int pageSize = 20,
    DocumentSnapshot? lastDocument,
  }) {
    Query paginatedQuery = query.limit(pageSize);
    
    if (lastDocument != null) {
      paginatedQuery = paginatedQuery.startAfterDocument(lastDocument);
    }
    
    return paginatedQuery;
  }
  
  /// Debounce function calls
  static Timer? _debounceTimer;
  
  static void debounce({
    required Duration delay,
    required VoidCallback action,
  }) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(delay, action);
  }
  
  /// Throttle function calls
  static DateTime? _lastThrottleCall;
  
  static bool throttle({
    required Duration delay,
    required VoidCallback action,
  }) {
    final now = DateTime.now();
    if (_lastThrottleCall == null || 
        now.difference(_lastThrottleCall!) >= delay) {
      _lastThrottleCall = now;
      action();
      return true;
    }
    return false;
  }
  
  /// Measure execution time
  static Future<T> measureTime<T>({
    required Future<T> Function() action,
    String? label,
  }) async {
    final stopwatch = Stopwatch()..start();
    try {
      final result = await action();
      stopwatch.stop();
      print('${label ?? "Operation"} took ${stopwatch.elapsedMilliseconds}ms');
      return result;
    } catch (e) {
      stopwatch.stop();
      print('${label ?? "Operation"} failed after ${stopwatch.elapsedMilliseconds}ms: $e');
      rethrow;
    }
  }
}

/// Image cache manager
class ImageCacheManager {
  static final Map<String, DateTime> _imageCacheTimestamps = {};
  static const int _maxCacheSize = 100; // Max number of cached images
  
  /// Preload and cache image
  static Future<void> cacheImage(String url) async {
    try {
      if (_imageCacheTimestamps.length >= _maxCacheSize) {
        // Remove oldest cached image
        final oldestKey = _imageCacheTimestamps.entries
            .reduce((a, b) => a.value.isBefore(b.value) ? a : b)
            .key;
        _imageCacheTimestamps.remove(oldestKey);
      }
      
      // Track URL for cache management
      // Actual image caching is handled by CachedNetworkImage widget
      _imageCacheTimestamps[url] = DateTime.now();
    } catch (e) {
      print('Error caching image: $e');
    }
  }
  
  /// Clear image cache
  static void clearImageCache() {
    _imageCacheTimestamps.clear();
    imageCache.clear();
    imageCache.clearLiveImages();
  }
}

