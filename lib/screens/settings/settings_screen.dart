import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../constants/app_colors.dart';
import '../../services/auth_service.dart';
import '../../services/permission_service.dart';
import '../../widgets/common/modern_alert_dialog.dart';
import '../../providers/locale_provider.dart';
import '../../l10n/app_localizations.dart';
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
    final localizations = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(localizations?.settings ?? 'Settings'),
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
                title: Text(localizations?.translate('admin_dashboard') ?? 'Admin Dashboard', style: const TextStyle(color: Colors.purple, fontWeight: FontWeight.bold)),
                subtitle: Text(localizations?.translate('manage_users_drivers') ?? 'Manage users, drivers, and system settings'),
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
                  title: Text(
                    localizations?.translate('emergency_panic_settings') ?? 'Emergency Panic Settings',
                    style: const TextStyle(
                      color: Colors.red,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  subtitle: Text(
                    localizations?.translate('add_trusted_contacts') ?? 'Add trusted contacts for emergency alerts',
                    style: const TextStyle(color: Colors.redAccent),
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
              title: Text(localizations?.translate('privacy_policy') ?? 'Privacy Policy'),
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
              title: Text(localizations?.translate('terms_conditions') ?? 'Terms & Conditions'),
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
              title: Text(localizations?.translate('location_permissions') ?? 'Location Permissions'),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const PermissionSettingsScreen()),
                );
              },
            ),
          ),
          const SizedBox(height: 16),
          Consumer<LocaleProvider>(
            builder: (context, localeProvider, child) {
              final localizations = AppLocalizations.of(context);
              return Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: ListTile(
                  leading: const Icon(Icons.language, color: AppColors.primary),
                  title: Text(localizations?.translate('language') ?? 'Language'),
                  subtitle: Text(localeProvider.currentLanguageName),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () {
                    _showLanguageSelector(context, localeProvider);
                  },
                ),
              );
            },
          ),
          const SizedBox(height: 16),
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: ListTile(
              leading: const Icon(Icons.delete_forever, color: Colors.red),
              title: Text(localizations?.translate('delete_account') ?? 'Delete Account', style: const TextStyle(color: Colors.red)),
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
  
  void _showLanguageSelector(BuildContext context, LocaleProvider localeProvider) {
    final localizations = AppLocalizations.of(context);
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              localizations?.translate('select_language') ?? 'Select Language',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            ...AppLocalizations.supportedLocales.map((locale) {
              final isSelected = localeProvider.locale.languageCode == locale.languageCode;
              return ListTile(
                leading: Icon(
                  isSelected ? Icons.check_circle : Icons.circle_outlined,
                  color: isSelected ? AppColors.primary : Colors.grey,
                ),
                title: Text(
                  localeProvider.getLanguageName(locale.languageCode),
                  style: TextStyle(
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    color: isSelected ? AppColors.primary : null,
                  ),
                ),
                onTap: () {
                  localeProvider.setLocale(locale);
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Language changed to ${localeProvider.getLanguageName(locale.languageCode)}'),
                      duration: const Duration(seconds: 2),
                    ),
                  );
                },
              );
            }),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }
} 