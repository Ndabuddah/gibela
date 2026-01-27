import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../constants/app_colors.dart';
import '../../providers/theme_provider.dart';
import '../../widgets/common/modern_alert_dialog.dart';

class PrivacySettingsScreen extends StatefulWidget {
  const PrivacySettingsScreen({Key? key}) : super(key: key);

  @override
  State<PrivacySettingsScreen> createState() => _PrivacySettingsScreenState();
}

class _PrivacySettingsScreenState extends State<PrivacySettingsScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  bool _shareLocationWithDrivers = true;
  bool _showPhoneNumber = false;
  bool _showEmail = false;
  bool _allowProfileViewing = true;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadPrivacySettings();
  }

  Future<void> _loadPrivacySettings() async {
    setState(() => _isLoading = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final doc = await _firestore.collection('users').doc(user.uid).get();
        if (doc.exists) {
          final data = doc.data()!;
          final privacy = data['privacySettings'] as Map<String, dynamic>? ?? {};
          setState(() {
            _shareLocationWithDrivers = privacy['shareLocationWithDrivers'] ?? true;
            _showPhoneNumber = privacy['showPhoneNumber'] ?? false;
            _showEmail = privacy['showEmail'] ?? false;
            _allowProfileViewing = privacy['allowProfileViewing'] ?? true;
          });
        }
      }
    } catch (e) {
      // Use defaults
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _savePrivacySettings() async {
    setState(() => _isLoading = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await _firestore.collection('users').doc(user.uid).update({
          'privacySettings': {
            'shareLocationWithDrivers': _shareLocationWithDrivers,
            'showPhoneNumber': _showPhoneNumber,
            'showEmail': _showEmail,
            'allowProfileViewing': _allowProfileViewing,
            'updatedAt': FieldValue.serverTimestamp(),
          },
        });
        if (mounted) {
          ModernSnackBar.show(context, message: 'Privacy settings saved');
        }
      }
    } catch (e) {
      if (mounted) {
        ModernSnackBar.show(
          context,
          message: 'Failed to save settings: $e',
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
        title: const Text('Privacy & Security'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: AppColors.getIconColor(isDark)),
      ),
      body: _isLoading && _shareLocationWithDrivers
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildSectionHeader('Location Privacy', isDark),
                const SizedBox(height: 8),
                _buildSwitchTile(
                  'Share Location with Drivers',
                  'Allow drivers to see your location during active rides',
                  _shareLocationWithDrivers,
                  (value) {
                    setState(() => _shareLocationWithDrivers = value);
                    _savePrivacySettings();
                  },
                  Icons.location_on,
                  isDark,
                ),
                const SizedBox(height: 16),
                _buildSectionHeader('Profile Visibility', isDark),
                const SizedBox(height: 8),
                _buildSwitchTile(
                  'Allow Profile Viewing',
                  'Let others view your profile information',
                  _allowProfileViewing,
                  (value) {
                    setState(() => _allowProfileViewing = value);
                    _savePrivacySettings();
                  },
                  Icons.visibility,
                  isDark,
                ),
                const SizedBox(height: 12),
                _buildSwitchTile(
                  'Show Phone Number',
                  'Display your phone number to drivers/passengers',
                  _showPhoneNumber,
                  (value) {
                    setState(() => _showPhoneNumber = value);
                    _savePrivacySettings();
                  },
                  Icons.phone,
                  isDark,
                ),
                const SizedBox(height: 12),
                _buildSwitchTile(
                  'Show Email',
                  'Display your email address to others',
                  _showEmail,
                  (value) {
                    setState(() => _showEmail = value);
                    _savePrivacySettings();
                  },
                  Icons.email,
                  isDark,
                ),
                const SizedBox(height: 24),
                _buildSectionHeader('Data & Security', isDark),
                const SizedBox(height: 8),
                _buildActionTile(
                  'Download My Data',
                  'Request a copy of your data',
                  Icons.download,
                  () {
                    ModernSnackBar.show(
                      context,
                      message: 'Data export feature coming soon',
                    );
                  },
                  isDark,
                ),
                const SizedBox(height: 12),
                _buildActionTile(
                  'Delete Account',
                  'Permanently delete your account and data',
                  Icons.delete_forever,
                  () => _showDeleteAccountDialog(context, isDark),
                  isDark,
                  isDestructive: true,
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
      margin: const EdgeInsets.only(bottom: 12),
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

  Widget _buildActionTile(
    String title,
    String subtitle,
    IconData icon,
    VoidCallback onTap,
    bool isDark, {
    bool isDestructive = false,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.getCardColor(isDark),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.getBorderColor(isDark)),
      ),
      child: ListTile(
        leading: Icon(
          icon,
          color: isDestructive ? AppColors.error : AppColors.primary,
        ),
        title: Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: isDestructive
                ? AppColors.error
                : AppColors.getTextPrimaryColor(isDark),
          ),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(
            color: AppColors.getTextSecondaryColor(isDark),
          ),
        ),
        trailing: Icon(
          Icons.chevron_right,
          color: AppColors.getIconColor(isDark),
        ),
        onTap: onTap,
      ),
    );
  }

  void _showDeleteAccountDialog(BuildContext context, bool isDark) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Account'),
        content: const Text(
          'Are you sure you want to delete your account? This action cannot be undone and all your data will be permanently deleted.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).pushNamed('/delete-account');
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}


