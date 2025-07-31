import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/auth_service.dart';
import '../services/panic_service.dart';
import '../widgets/common/modern_alert_dialog.dart';
import '../screens/settings/panic_settings_screen.dart';

class PanicAlertService {
  static const String _hasShownAlertKey = 'has_shown_panic_alert';
  
  // Show panic alert dialog if user hasn't added trusted contacts
  static Future<void> showPanicAlertIfNeeded(BuildContext context) async {
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final user = authService.userModel;
      
      if (user != null) {
        // Check if user has trusted contacts
        final hasContacts = await PanicService.hasTrustedContacts(user.uid);
        
        if (!hasContacts) {
          // Check if we've already shown the alert for this session
          final prefs = await SharedPreferences.getInstance();
          final hasShownAlert = prefs.getBool(_hasShownAlertKey) ?? false;
          
          if (!hasShownAlert && context.mounted) {
            // Show the alert dialog
            _showPanicAlertDialog(context);
            
            // Mark that we've shown the alert
            await prefs.setBool(_hasShownAlertKey, true);
          }
        }
      }
    } catch (e) {
      print('Error showing panic alert: $e');
    }
  }
  
  // Reset the alert flag (call this when user adds contacts)
  static Future<void> resetAlertFlag() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_hasShownAlertKey, false);
    } catch (e) {
      print('Error resetting alert flag: $e');
    }
  }
  
  // Show the panic alert dialog
  static void _showPanicAlertDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => ModernAlertDialog(
        title: 'Emergency Safety Feature',
        message: 'Add trusted contacts to your emergency panic settings. In case of emergency, these contacts will receive your location and ride details immediately.',
        confirmText: 'Add Contacts',
        cancelText: 'Add Later',
        onConfirm: () {
          Navigator.of(context).pop();
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => const PanicSettingsScreen(),
            ),
          );
        },
        onCancel: () => Navigator.of(context).pop(),
        icon: Icons.emergency,
        iconColor: Colors.red,
      ),
    );
  }
  
  // Check and show alert on app startup
  static Future<void> checkAndShowAlertOnStartup(BuildContext context) async {
    // Add a small delay to ensure the app is fully loaded
    await Future.delayed(const Duration(seconds: 2));
    
    if (context.mounted) {
      await showPanicAlertIfNeeded(context);
    }
  }
} 