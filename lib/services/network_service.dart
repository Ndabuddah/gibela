import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';

class NetworkService {
  static final NetworkService _instance = NetworkService._internal();
  factory NetworkService() => _instance;
  NetworkService._internal();

  // Check if device has internet connectivity
  static Future<bool> hasInternetConnection() async {
    try {
      final result = await InternetAddress.lookup('google.com');
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } on SocketException catch (_) {
      return false;
    }
  }

  // Check connectivity type
  static Future<List<ConnectivityResult>> getConnectivityType() async {
    return await Connectivity().checkConnectivity();
  }

  // Check if connected to WiFi
  static Future<bool> isConnectedToWifi() async {
    final connectivityResult = await Connectivity().checkConnectivity();
    return connectivityResult == ConnectivityResult.wifi;
  }

  // Check if connected to mobile data
  static Future<bool> isConnectedToMobile() async {
    final connectivityResult = await Connectivity().checkConnectivity();
    return connectivityResult == ConnectivityResult.mobile;
  }

  // Get detailed connectivity info
  static Future<Map<String, dynamic>> getConnectivityInfo() async {
    final connectivityResult = await Connectivity().checkConnectivity();
    final hasInternet = await hasInternetConnection();

    return {
      'connectivityType': connectivityResult.toString(),
      'hasInternet': hasInternet,
      'isWifi': connectivityResult == ConnectivityResult.wifi,
      'isMobile': connectivityResult == ConnectivityResult.mobile,
      'isNone': connectivityResult == ConnectivityResult.none,
    };
  }

  // Show network error dialog
  static void showNetworkErrorDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Network Error'),
        content: const Text(
          'No internet connection detected. Please check your network settings and try again.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  // Check network before performing operations
  static Future<bool> checkNetworkBeforeOperation(BuildContext context) async {
    final hasInternet = await hasInternetConnection();
    if (!hasInternet) {
      showNetworkErrorDialog(context);
      return false;
    }
    return true;
  }

  // Log network status for debugging
  static Future<void> logNetworkStatus() async {
    final info = await getConnectivityInfo();
    print('🌐 Network Status:');
    print('   Connectivity Type: ${info['connectivityType']}');
    print('   Has Internet: ${info['hasInternet']}');
    print('   Is WiFi: ${info['isWifi']}');
    print('   Is Mobile: ${info['isMobile']}');
    print('   Is None: ${info['isNone']}');
  }
}
