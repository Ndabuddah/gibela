import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../constants/app_colors.dart';
import '../../models/user_model.dart';
import '../../providers/theme_provider.dart';
import '../../screens/about_driver/about_driver_screen.dart';
import '../../screens/auth/login_screen.dart';
import '../../screens/driver/ride_history_screen.dart' as driver_history;
import '../../screens/help/help_screen.dart';
import '../../screens/home/driver/driver_scheduled_bookings_screen.dart';
import '../../screens/settings/settings_screen.dart';
import '../../screens/home/driver/driver_settings_screen.dart';
import '../../screens/emergency/panic_alert_screen.dart';
import '../../services/auth_service.dart';
import '../../services/database_service.dart';

class ModernDrawer extends StatefulWidget {
  final UserModel? user;
  final VoidCallback? onProfileTap;
  final VoidCallback? onRidesTap;
  final VoidCallback? onSettingsTap;
  final VoidCallback? onHelpTap;
  final VoidCallback? onLogout;

  const ModernDrawer({
    Key? key,
    this.user,
    this.onProfileTap,
    this.onRidesTap,
    this.onSettingsTap,
    this.onHelpTap,
    this.onLogout,
  }) : super(key: key);

  @override
  State<ModernDrawer> createState() => _ModernDrawerState();
}

class _ModernDrawerState extends State<ModernDrawer> {
  String? _cachedProfileImageUrl;
  bool _isLoadingProfileImage = false;

  @override
  void initState() {
    super.initState();
    _loadProfileImage();
  }

  Future<void> _loadProfileImage() async {
    if (widget.user?.isDriver == true && _cachedProfileImageUrl == null) {
      setState(() {
        _isLoadingProfileImage = true;
      });
      
      try {
        final profileImageUrl = await DatabaseService().getDriverProfileImage(widget.user!.uid);
        if (mounted) {
          setState(() {
            _cachedProfileImageUrl = profileImageUrl;
            _isLoadingProfileImage = false;
          });
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            _isLoadingProfileImage = false;
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;
    final profileImageUrl = widget.user?.profileImageUrl;

    Future<bool> _showLogoutConfirmationDialog(BuildContext context) {
      return showDialog<bool>(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Text('Logout'),
            content: const Text('Are you sure you want to log out?'),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Logout'),
              ),
            ],
          );
        },
      ).then((value) => value ?? false); // Return false if the dialog is dismissed
    }

    ;

    return Stack(
      children: [
        Drawer(
          backgroundColor: AppColors.getSurfaceColor(isDark),
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              UserAccountsDrawerHeader(
                accountName: Text(widget.user?.fullName ?? 'Guest', style: const TextStyle(fontWeight: FontWeight.bold)),
                accountEmail: Text(widget.user?.email ?? '', style: const TextStyle(fontSize: 12)),
                currentAccountPicture: _buildDrawerProfileAvatar(widget.user),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                ),
              ),

              if (widget.user?.isDriver ?? false) ...[
                _DrawerItem(
                  icon: Icons.history,
                  title: 'Ride History',
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => driver_history.RideHistoryScreen()),
                    );
                  },
                  isDark: isDark,
                ),
              ]
              // ... for passengers, you can add:
              // _buildDrawerItem(
              //   icon: Icons.history,
              //   text: 'Ride History',
              //   onTap: () {
              //     Navigator.of(context).push(
              //       MaterialPageRoute(builder: (_) => history.RideHistoryScreen()),
              //     );
              //   },
              //   isDark: isDark,
              // ),
              ,
              if (widget.user?.isDriver ?? false)
                _DrawerItem(
                  icon: Icons.schedule,
                  title: 'Scheduled Bookings',
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => DriverScheduledBookingsScreen(isDark: isDark)),
                  ),
                  isDark: isDark,
                ),
              _DrawerItem(
                icon: Icons.support_agent,
                title: 'Support',
                onTap: () async {
                  const whatsappUrl = 'https://wa.me/27687455976';
                  if (await canLaunch(whatsappUrl)) {
                    await launch(whatsappUrl);
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Could not open WhatsApp.')),
                    );
                  }
                },
                isDark: isDark,
              ),
              if (widget.user?.isDriver ?? false)
                _DrawerItem(
                  icon: Icons.info_outline,
                  title: 'About Driver',
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const AboutDriverScreen()),
                    );
                  },
                  isDark: isDark,
                ),
              _DrawerItem(
                icon: Icons.settings_outlined,
                title: 'Settings',
                onTap: () {
                  if (widget.user?.isDriver ?? false) {
                    // Navigate to driver settings for drivers
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const DriverSettingsScreen()),
                    );
                  } else {
                    // Navigate to regular settings for passengers
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const SettingsScreen()),
                    );
                  }
                },
                isDark: isDark,
              ),
              _DrawerItem(
                icon: Icons.help_outline,
                title: 'Help',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const HelpScreen()),
                ),
                isDark: isDark,
              ),
              const SizedBox(height: 20),
              _DrawerItem(
                icon: Icons.logout,
                title: 'Logout',
                onTap: () async {
                  final shouldLogout = await _showLogoutConfirmationDialog(context);
                  if (shouldLogout) {
                    // Call the logout function from AuthService
                    await Provider.of<AuthService>(context, listen: false).signOut;
                    // Navigate to login screen
                    Navigator.of(context).pushReplacement(
                      MaterialPageRoute(builder: (_) => LoginScreen()),
                    );
                  }
                },
                isDark: isDark,
              ),

// Function to show confirmation dialog

              // Theme Toggle
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 20),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.getCardColor(isDark),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppColors.getBorderColor(isDark),
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      isDark ? Icons.dark_mode : Icons.light_mode,
                      color: AppColors.getIconColor(isDark),
                      size: 24,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        'Dark Mode',
                        style: TextStyle(
                          color: AppColors.getTextPrimaryColor(isDark),
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    Switch(
                      value: isDark,
                      onChanged: (value) => themeProvider.toggleTheme(),
                      activeColor: AppColors.primary,
                      activeTrackColor: AppColors.primary.withOpacity(0.3),
                      inactiveThumbColor: AppColors.getIconColor(isDark),
                      inactiveTrackColor: AppColors.getDividerColor(isDark),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
        // Panic button (floating, bottom right)
        Positioned(
          right: 24,
          bottom: 36,
          child: FloatingActionButton.extended(
            heroTag: 'drawer_panic',
            backgroundColor: Colors.red.shade700,
            icon: const Icon(Icons.warning_amber_rounded, color: Colors.white),
            label: const Text('Panic', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const PanicAlertScreen(),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildDrawerProfileAvatar(UserModel? user) {
    // If passenger, always use profileImageUrl (profileImage or photoUrl)
    if (user != null && !user.isDriver) {
      final profileImageUrl = user.profileImageUrl;
      if (profileImageUrl != null && profileImageUrl.isNotEmpty) {
        return CircleAvatar(
          backgroundColor: Colors.white,
          backgroundImage: NetworkImage(profileImageUrl),
        );
      } else {
        return const CircleAvatar(
          backgroundColor: Colors.white,
          child: Icon(Icons.person, size: 40, color: AppColors.primary),
        );
      }
    }
    
    // For drivers, use cached profile image
    if (user?.isDriver == true && _cachedProfileImageUrl != null && _cachedProfileImageUrl!.isNotEmpty) {
      return CircleAvatar(
        backgroundColor: Colors.white,
        backgroundImage: NetworkImage(_cachedProfileImageUrl!),
      );
    }
    
    // Use regular profile image URL for drivers
    final profileImageUrl = user?.profileImageUrl;
    if (profileImageUrl != null && profileImageUrl.isNotEmpty) {
      return CircleAvatar(
        backgroundColor: Colors.white,
        backgroundImage: NetworkImage(profileImageUrl),
      );
    }
    
    // Show loading or default avatar for drivers
    if (user?.isDriver == true && _isLoadingProfileImage) {
      return const CircleAvatar(
        backgroundColor: Colors.white,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
        ),
      );
    }
    
    return const CircleAvatar(
      backgroundColor: Colors.white,
      child: Icon(Icons.person, size: 40, color: AppColors.primary),
    );
  }
}

class _DrawerItem extends StatefulWidget {
  final IconData icon;
  final String title;
  final VoidCallback? onTap;
  final bool isDark;
  final bool isDestructive;

  const _DrawerItem({
    required this.icon,
    required this.title,
    this.onTap,
    required this.isDark,
    this.isDestructive = false,
  });

  @override
  State<_DrawerItem> createState() => _DrawerItemState();
}

class _DrawerItemState extends State<_DrawerItem> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.95,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final iconColor = widget.isDestructive ? AppColors.error : AppColors.getIconColor(widget.isDark);

    final textColor = widget.isDestructive ? AppColors.error : AppColors.getTextPrimaryColor(widget.isDark);

    return GestureDetector(
      onTapDown: (_) => _controller.forward(),
      onTapUp: (_) => _controller.reverse(),
      onTapCancel: () => _controller.reverse(),
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: widget.onTap,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          widget.icon,
                          color: iconColor,
                          size: 24,
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Text(
                            widget.title,
                            style: TextStyle(
                              color: textColor,
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        Icon(
                          Icons.chevron_right,
                          color: AppColors.getTextHintColor(widget.isDark),
                          size: 20,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
