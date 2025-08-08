import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../constants/app_colors.dart';
import '../../services/auth_service.dart';
import '../../services/permission_service.dart';
import '../../widgets/common/modern_alert_dialog.dart';
import '../auth/login_screen.dart';
import 'terms_screen.dart';
import 'delete_account_screen.dart';
import 'admin_dashboard_screen.dart';
import 'panic_settings_screen.dart';
import 'permission_settings_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context, listen: false);
    final user = authService.userModel;
    final isAdmin = user?.email == 'ngemangemangema@gmail.com' || 
                   user?.email == 'asamberyde@gmail.com';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: AppColors.primary,
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          // Admin Dashboard Button (only for admin users)
          if (isAdmin) ...[
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: ListTile(
                leading: const Icon(Icons.admin_panel_settings, color: Colors.purple),
                title: const Text('Admin Dashboard', style: TextStyle(color: Colors.purple, fontWeight: FontWeight.bold)),
                subtitle: const Text('Manage users, drivers, and system settings'),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const AdminDashboardScreen()),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
          ],
          
          // Panic Settings - Highlighted Emergency Section
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: const LinearGradient(
                colors: [Colors.red, Colors.redAccent],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.red.withOpacity(0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Card(
              color: Colors.transparent,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  color: Colors.white.withOpacity(0.95),
                ),
                child: ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.emergency, color: Colors.white, size: 24),
                  ),
                  title: const Text(
                    'Emergency Panic Settings',
                    style: TextStyle(
                      color: Colors.red,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  subtitle: const Text(
                    'Add trusted contacts for emergency alerts',
                    style: TextStyle(color: Colors.redAccent),
                  ),
                  trailing: const Icon(Icons.arrow_forward_ios, color: Colors.red),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const PanicSettingsScreen()),
                    );
                  },
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: ListTile(
              leading: const Icon(Icons.privacy_tip, color: AppColors.primary),
              title: const Text('Privacy Policy'),
              onTap: () async {
                const url = 'https://sites.google.com/view/ride-app/home';
                if (await canLaunchUrl(Uri.parse(url))) {
                  await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Could not open Privacy Policy.')),
                  );
                }
              },
            ),
          ),
          const SizedBox(height: 16),
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: ListTile(
              leading: const Icon(Icons.description, color: AppColors.primary),
              title: const Text('Terms & Conditions'),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const TermsScreen()),
                );
              },
            ),
          ),
          const SizedBox(height: 16),
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: ListTile(
              leading: const Icon(Icons.location_on, color: AppColors.primary),
              title: const Text('Location Permissions'),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const PermissionSettingsScreen()),
                );
              },
            ),
          ),
          const SizedBox(height: 16),
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: ListTile(
              leading: const Icon(Icons.delete_forever, color: Colors.red),
              title: const Text('Delete Account', style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const DeleteAccountScreen()),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
} 