import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../constants/app_colors.dart';
import '../../providers/theme_provider.dart';
import '../../services/enhanced_notification_service.dart';
import '../../widgets/common/modern_alert_dialog.dart';

class NotificationsSettingsScreen extends StatefulWidget {
  const NotificationsSettingsScreen({Key? key}) : super(key: key);

  @override
  State<NotificationsSettingsScreen> createState() => _NotificationsSettingsScreenState();
}

class _NotificationsSettingsScreenState extends State<NotificationsSettingsScreen> {
  final EnhancedNotificationService _notificationService = EnhancedNotificationService();
  bool _pushNotifications = true;
  bool _rideUpdates = true;
  bool _promotions = false;
  bool _reminders = true;
  bool _chatMessages = true;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    setState(() => _isLoading = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final preferences = await _notificationService.getNotificationPreferences(user.uid);
        setState(() {
          _pushNotifications = preferences['pushNotifications'] ?? true;
          _rideUpdates = preferences['rideUpdates'] ?? true;
          _promotions = preferences['promotions'] ?? false;
          _reminders = preferences['reminders'] ?? true;
          _chatMessages = preferences['chatMessages'] ?? true;
        });
      }
    } catch (e) {
      // Use defaults if loading fails
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _savePreferences() async {
    setState(() => _isLoading = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await _notificationService.updateNotificationPreferences(
          user.uid,
          {
            'pushNotifications': _pushNotifications,
            'rideUpdates': _rideUpdates,
            'promotions': _promotions,
            'reminders': _reminders,
            'chatMessages': _chatMessages,
          },
        );
        if (mounted) {
          ModernSnackBar.show(context, message: 'Notification preferences saved');
        }
      }
    } catch (e) {
      if (mounted) {
        ModernSnackBar.show(
          context,
          message: 'Failed to save preferences: $e',
          isError: true,
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;

    return Scaffold(
      backgroundColor: AppColors.getBackgroundColor(isDark),
      appBar: AppBar(
        title: const Text('Notification Settings'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: AppColors.getIconColor(isDark)),
      ),
      body: _isLoading && _pushNotifications
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildSectionHeader('Push Notifications', isDark),
                const SizedBox(height: 8),
                _buildSwitchTile(
                  'Enable Push Notifications',
                  'Receive notifications on your device',
                  _pushNotifications,
                  (value) {
                    setState(() => _pushNotifications = value);
                    _savePreferences();
                  },
                  Icons.notifications,
                  isDark,
                ),
                const SizedBox(height: 16),
                _buildSectionHeader('Notification Types', isDark),
                const SizedBox(height: 8),
                _buildSwitchTile(
                  'Ride Updates',
                  'Get notified about ride status changes',
                  _rideUpdates,
                  (value) {
                    setState(() => _rideUpdates = value);
                    _savePreferences();
                  },
                  Icons.directions_car,
                  isDark,
                ),
                const SizedBox(height: 12),
                _buildSwitchTile(
                  'Chat Messages',
                  'Get notified when you receive messages',
                  _chatMessages,
                  (value) {
                    setState(() => _chatMessages = value);
                    _savePreferences();
                  },
                  Icons.chat,
                  isDark,
                ),
                const SizedBox(height: 12),
                _buildSwitchTile(
                  'Reminders',
                  'Get reminders for scheduled rides',
                  _reminders,
                  (value) {
                    setState(() => _reminders = value);
                    _savePreferences();
                  },
                  Icons.alarm,
                  isDark,
                ),
                const SizedBox(height: 12),
                _buildSwitchTile(
                  'Promotions & Offers',
                  'Receive promotional notifications',
                  _promotions,
                  (value) {
                    setState(() => _promotions = value);
                    _savePreferences();
                  },
                  Icons.local_offer,
                  isDark,
                ),
              ],
            ),
    );
  }

  Widget _buildSectionHeader(String title, bool isDark) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: AppColors.getTextPrimaryColor(isDark),
      ),
    );
  }

  Widget _buildSwitchTile(
    String title,
    String subtitle,
    bool value,
    ValueChanged<bool> onChanged,
    IconData icon,
    bool isDark,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.getCardColor(isDark),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.getBorderColor(isDark)),
      ),
      child: ListTile(
        leading: Icon(icon, color: AppColors.primary),
        title: Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: AppColors.getTextPrimaryColor(isDark),
          ),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(
            color: AppColors.getTextSecondaryColor(isDark),
          ),
        ),
        trailing: Switch(
          value: value,
          onChanged: onChanged,
          activeColor: AppColors.primary,
        ),
      ),
    );
  }
}



