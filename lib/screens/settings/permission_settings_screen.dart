import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../../constants/app_colors.dart';
import '../../services/permission_service.dart';
import '../../widgets/common/modern_alert_dialog.dart';

class PermissionSettingsScreen extends StatefulWidget {
  const PermissionSettingsScreen({super.key});

  @override
  State<PermissionSettingsScreen> createState() => _PermissionSettingsScreenState();
}

class _PermissionSettingsScreenState extends State<PermissionSettingsScreen> {
  bool _isLoading = true;
  bool _locationGranted = false;
  bool _backgroundLocationGranted = false;
  bool _locationServiceEnabled = false;
  bool _dontAskAgain = false;

  @override
  void initState() {
    super.initState();
    _loadPermissionStatus();
  }

  Future<void> _loadPermissionStatus() async {
    setState(() => _isLoading = true);
    
    try {
      final status = await PermissionService.getPermissionStatus();
      final dontAskAgain = await PermissionService.hasUserChosenDontAskAgain();
      
      if (mounted) {
        setState(() {
          _locationServiceEnabled = status['locationServiceEnabled'] ?? false;
          _locationGranted = status['locationGranted'] ?? false;
          _backgroundLocationGranted = status['backgroundLocationGranted'] ?? false;
          _dontAskAgain = dontAskAgain;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _resetDontAskAgain() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => const ModernAlertDialog(
        title: 'Reset Permission Settings',
        message: 'This will allow the app to ask for location permissions again. Are you sure?',
        confirmText: 'Reset',
        cancelText: 'Cancel',
        icon: Icons.settings,
      ),
    );

    if (confirmed == true) {
      await PermissionService.resetDontAskAgain();
      await _loadPermissionStatus();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Permission settings reset successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }

  Future<void> _openLocationSettings() async {
    try {
      final canOpen = await Geolocator.openLocationSettings();
      if (!canOpen && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cannot open location settings. Please enable location services manually.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to open location settings. Please enable location services manually.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Location Permissions'),
        backgroundColor: AppColors.primary,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Location Services Status
                Card(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: ListTile(
                    leading: Icon(
                      Icons.location_on,
                      color: _locationServiceEnabled ? Colors.green : Colors.red,
                    ),
                    title: const Text('Location Services'),
                    subtitle: Text(
                      _locationServiceEnabled 
                          ? 'Enabled' 
                          : 'Disabled - Please enable in device settings',
                    ),
                    trailing: _locationServiceEnabled 
                        ? const Icon(Icons.check_circle, color: Colors.green)
                        : IconButton(
                            icon: const Icon(Icons.settings),
                            onPressed: _openLocationSettings,
                          ),
                  ),
                ),
                const SizedBox(height: 12),
                
                // Location Permission Status
                Card(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: ListTile(
                    leading: Icon(
                      Icons.my_location,
                      color: _locationGranted ? Colors.green : Colors.orange,
                    ),
                    title: const Text('Location Permission'),
                    subtitle: Text(
                      _locationGranted 
                          ? 'Granted' 
                          : 'Not granted - Required for basic app functionality',
                    ),
                    trailing: _locationGranted 
                        ? const Icon(Icons.check_circle, color: Colors.green)
                        : const Icon(Icons.warning, color: Colors.orange),
                  ),
                ),
                const SizedBox(height: 12),
                
                // Background Location Status
                Card(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: ListTile(
                    leading: Icon(
                      Icons.location_searching,
                      color: _backgroundLocationGranted ? Colors.green : Colors.grey,
                    ),
                    title: const Text('Background Location'),
                    subtitle: Text(
                      _backgroundLocationGranted 
                          ? 'Granted' 
                          : 'Not granted - Optional for enhanced features',
                    ),
                    trailing: _backgroundLocationGranted 
                        ? const Icon(Icons.check_circle, color: Colors.green)
                        : const Icon(Icons.info_outline, color: Colors.grey),
                  ),
                ),
                const SizedBox(height: 20),
                
                // Don't Ask Again Status
                Card(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: ListTile(
                    leading: Icon(
                      Icons.block,
                      color: _dontAskAgain ? Colors.red : Colors.green,
                    ),
                    title: const Text('Permission Prompts'),
                    subtitle: Text(
                      _dontAskAgain 
                          ? 'Disabled - App won\'t ask for permissions' 
                          : 'Enabled - App can ask for permissions when needed',
                    ),
                    trailing: _dontAskAgain 
                        ? ElevatedButton(
                            onPressed: _resetDontAskAgain,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                            ),
                            child: const Text('Reset'),
                          )
                        : const Icon(Icons.check_circle, color: Colors.green),
                  ),
                ),
                const SizedBox(height: 20),
                
                // Information Card
                Card(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  color: Colors.blue.withOpacity(0.1),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.info_outline, color: Colors.blue),
                            const SizedBox(width: 8),
                            Text(
                              'About Location Permissions',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.blue,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          '• Location Services: Must be enabled in device settings\n'
                          '• Location Permission: Required for finding nearby services\n'
                          '• Background Location: Optional for enhanced tracking\n'
                          '• Permission Prompts: Control whether the app asks for permissions',
                          style: TextStyle(
                            color: Colors.blue[700],
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }
} 