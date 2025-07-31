// lib/screens/home/passenger/passenger_home_screen.dart
import 'package:flutter/material.dart';
import 'package:gibelbibela/models/user_model.dart';
import 'package:gibelbibela/screens/auth/login_screen.dart';
import 'package:gibelbibela/screens/permissions/location_permission_screen.dart';
import 'package:gibelbibela/services/permission_service.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../constants/app_colors.dart';
import '../../../providers/theme_provider.dart';
import '../../../services/auth_service.dart';
import '../../../services/location_service.dart';
import '../../../widgets/common/modern_alert_dialog.dart';
import '../../../widgets/common/modern_drawer.dart';
import 'profilescreen.dart';
import 'request_ride_screen.dart';

class PassengerHomeScreen extends StatefulWidget {
  final bool isFirstTime;
  const PassengerHomeScreen({super.key, this.isFirstTime = false});

  @override
  State<PassengerHomeScreen> createState() => _PassengerHomeScreenState();
}

class _PassengerHomeScreenState extends State<PassengerHomeScreen> with TickerProviderStateMixin {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  bool _isLoading = false;
  String _currentAddress = 'Getting your location...';
  UserModel? _currentUser;

  late AnimationController _fadeController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchAndSetUser();
      _checkLocationPermissions();
    });
    _getCurrentLocation();
    if (widget.isFirstTime) {
      _showWelcomeDialog();
    }
  }

  Future<void> _showWelcomeDialog() async {
    final prefs = await SharedPreferences.getInstance();
    final isFirstTime = prefs.getBool('isFirstTime') ?? true;

    if (isFirstTime) {
      // Use WidgetsBinding to show dialog after the build is complete
      WidgetsBinding.instance.addPostFrameCallback((_) {
        showDialog(
          context: context,
          builder: (context) => const ModernAlertDialog(title: 'Welcome to RideApp!', message: 'We are excited to have you on board. Your journey with us starts now. Let\'s ride!', confirmText: 'Let\'s Go!', icon: Icons.celebration_rounded),
        );
        // Set the flag to false so it doesn't show again
        prefs.setBool('isFirstTime', false);
      });
    }
  }

  void _initializeAnimations() {
    _fadeController = AnimationController(duration: const Duration(milliseconds: 1000), vsync: this);

    _slideController = AnimationController(duration: const Duration(milliseconds: 800), vsync: this);

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut));

    _slideAnimation = Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero).animate(CurvedAnimation(parent: _slideController, curve: Curves.easeOutCubic));

    _fadeController.forward();
    _slideController.forward();
  }

  Future<void> _loadUserData() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    final userModel = authService.userModel;
    if (userModel != null) {
      setState(() {
        _currentUser = userModel;
      });
    }
  }

  Future<void> _fetchAndSetUser() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    await authService.fetchCurrentUser();
    // No setState() needed, provider will notify listeners
  }

  Future<void> _checkLocationPermissions() async {
    // Skip permission check if we just came from the permission screen
    if (ModalRoute.of(context)?.settings.name == '/passenger_home') {
      return;
    }

    final shouldShow = await PermissionService.shouldShowPermissionScreen();
    if (shouldShow && mounted) {
      // Show permission screen as full screen instead of dialog
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => LocationPermissionScreen(
            isDriver: false,
            onPermissionGranted: () {
              // Refresh location after permissions are granted
              _getCurrentLocation();
            },
          ),
        ),
      );
    }
  }

  Future<void> _getCurrentLocation() async {
    setState(() => _isLoading = true);

    try {
      final locationService = Provider.of<LocationService>(context, listen: false);
      final position = await locationService.requestAndGetCurrentLocation(context);

      if (position != null) {
        final address = await locationService.getAddressFromCoordinates(position.latitude, position.longitude);
        if (mounted) {
          setState(() {
            _currentAddress = address ?? 'Location not available';
            _isLoading = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _currentAddress = 'Location not available';
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _currentAddress = 'Error getting location';
          _isLoading = false;
        });
      }
    }
  }

  void _openDrawer() {
    _scaffoldKey.currentState?.openDrawer();
  }

  void _requestRide() {
    print('Request Ride tapped');
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => const RequestRideScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return SlideTransition(
            position: Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero).animate(animation),
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 300),
      ),
    );
  }

  void _goToProfile() {
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => const ProfileScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return SlideTransition(
            position: Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero).animate(animation),
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 300),
      ),
    );
  }

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => const ModernAlertDialog(title: 'Logout', message: 'Are you sure you want to logout?', confirmText: 'Logout', cancelText: 'Cancel', icon: Icons.logout, isDestructive: true),
    );

    if (confirmed == true) {
      print('Logout confirmed. Attempting to sign out...');
      final authService = Provider.of<AuthService>(context, listen: false);
      try {
        await authService.signOut();
        print('Sign out successful. Navigating to login screen...');
      } catch (e) {
        print('Sign out error: ' + e.toString());
        // Optionally show a snackbar or dialog
      } finally {
        if (!mounted) return;
        // Close any open drawers
        if (_scaffoldKey.currentState?.isDrawerOpen ?? false) {
          Navigator.of(context).pop();
          await Future.delayed(const Duration(milliseconds: 200));
        }
        Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(MaterialPageRoute(builder: (context) => const LoginScreen()), (route) => false);
      }
    }
  }

  Future<void> handleDrawerLogout(BuildContext context) async {
    // Close the drawer first
    Navigator.of(context).pop();
    // Wait for the drawer to close
    await Future.delayed(const Duration(milliseconds: 200));

    // Now show the alert dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Sign Out'),
        content: Text('Do you really want to sign out of your account?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text('Logout', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final authService = Provider.of<AuthService>(context, listen: false);
      await authService.signOut();
      Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(MaterialPageRoute(builder: (context) => const LoginScreen()), (route) => false);
    }
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: AppColors.getBackgroundColor(isDark),
      drawer: ModernDrawer(user: Provider.of<AuthService>(context).userModel, onProfileTap: _goToProfile, onLogout: () => handleDrawerLogout(context)),
      body: SafeArea(
        child: Column(
          children: [
            // Header
            FadeTransition(
              opacity: _fadeAnimation,
              child: SlideTransition(
                position: _slideAnimation,
                child: Container(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      // Menu Button
                      _ModernIconButton(icon: Icons.menu, onPressed: _openDrawer, isDark: isDark),

                      const SizedBox(width: 16),

                      // Welcome Text
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Welcome back!', style: TextStyle(color: AppColors.getTextSecondaryColor(isDark), fontSize: 14)),
                            const SizedBox(height: 4),
                            Text(
                              Provider.of<AuthService>(context).userModel?.fullName ?? 'User',
                              style: TextStyle(color: AppColors.getTextPrimaryColor(isDark), fontSize: 20, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),

                      // Profile Avatar Button
                      GestureDetector(
                        onTap: _goToProfile,
                        child: CircleAvatar(
                          radius: 20,
                          backgroundColor: Colors.white,
                          backgroundImage: (_currentUser?.profileImageUrl != null && _currentUser!.profileImageUrl!.isNotEmpty) ? NetworkImage(_currentUser!.profileImageUrl!) : null,
                          child: (_currentUser?.profileImageUrl == null || _currentUser!.profileImageUrl!.isEmpty) ? Icon(Icons.person_outline, color: AppColors.primary, size: 24) : null,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Main Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  children: [
                    // Location Card
                    FadeTransition(
                      opacity: _fadeAnimation,
                      child: SlideTransition(
                        position: _slideAnimation,
                        child: _LocationCard(address: _currentAddress, isLoading: _isLoading, onRefresh: _getCurrentLocation, isDark: isDark),
                      ),
                    ),

                    const SizedBox(height: 30),

                    // Quick Actions
                    FadeTransition(
                      opacity: _fadeAnimation,
                      child: SlideTransition(
                        position: _slideAnimation,
                        child: _QuickActionsSection(onRequestRide: _requestRide, isDark: isDark),
                      ),
                    ),

                    const SizedBox(height: 30),

                    // Recent Rides
                    FadeTransition(
                      opacity: _fadeAnimation,
                      child: SlideTransition(
                        position: _slideAnimation,
                        child: _RecentRidesSection(isDark: isDark),
                      ),
                    ),

                    const SizedBox(height: 30),

                    // Features Section
                    FadeTransition(
                      opacity: _fadeAnimation,
                      child: SlideTransition(
                        position: _slideAnimation,
                        child: _FeaturesSection(isDark: isDark),
                      ),
                    ),

                    const SizedBox(height: 30),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ModernIconButton extends StatefulWidget {
  final IconData icon;
  final VoidCallback onPressed;
  final bool isDark;

  const _ModernIconButton({required this.icon, required this.onPressed, required this.isDark});

  @override
  State<_ModernIconButton> createState() => _ModernIconButtonState();
}

class _ModernIconButtonState extends State<_ModernIconButton> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(duration: const Duration(milliseconds: 150), vsync: this);
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.9).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: AppColors.getCardColor(widget.isDark),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.getBorderColor(widget.isDark), width: 1),
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: widget.onPressed,
                  borderRadius: BorderRadius.circular(12),
                  child: Icon(widget.icon, color: AppColors.getIconColor(widget.isDark), size: 24),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _LocationCard extends StatelessWidget {
  final String address;
  final bool isLoading;
  final VoidCallback onRefresh;
  final bool isDark;

  const _LocationCard({required this.address, required this.isLoading, required this.onRefresh, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: AppColors.primary.withOpacity(0.3), blurRadius: 20, offset: const Offset(0, 10))],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: AppColors.black.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
            child: const Icon(Icons.my_location, color: AppColors.black, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Current Location',
                  style: TextStyle(color: AppColors.black.withOpacity(0.7), fontSize: 14, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 4),
                if (isLoading)
                  const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: AppColors.black, strokeWidth: 2))
                else
                  Text(
                    address,
                    style: const TextStyle(color: AppColors.black, fontSize: 16, fontWeight: FontWeight.w600),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          IconButton(
            onPressed: onRefresh,
            icon: const Icon(Icons.refresh, color: AppColors.black, size: 24),
          ),
        ],
      ),
    );
  }
}

class _QuickActionsSection extends StatelessWidget {
  final VoidCallback onRequestRide;
  final bool isDark;

  const _QuickActionsSection({required this.onRequestRide, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Quick Actions',
          style: TextStyle(color: AppColors.getTextPrimaryColor(isDark), fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _ActionCard(title: 'Request Ride', subtitle: 'Book a ride now', icon: Icons.local_taxi, color: AppColors.primary, onTap: onRequestRide, isDark: isDark),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _ActionCard(
                title: 'Ride History',
                subtitle: 'View past rides',
                icon: Icons.history,
                color: AppColors.secondary,
                onTap: () {
                  // TODO: Implement ride history
                  ModernSnackBar.show(context, message: 'Ride history coming soon!');
                },
                isDark: isDark,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _ActionCard extends StatefulWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final bool isDark;

  const _ActionCard({required this.title, required this.subtitle, required this.icon, required this.color, required this.onTap, required this.isDark});

  @override
  State<_ActionCard> createState() => _ActionCardState();
}

class _ActionCardState extends State<_ActionCard> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(duration: const Duration(milliseconds: 150), vsync: this);
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _controller.forward(),
      onTapUp: (_) {
        _controller.reverse();
        widget.onTap();
      },
      onTapCancel: () => _controller.reverse(),
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.getCardColor(widget.isDark),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.getBorderColor(widget.isDark), width: 1),
                boxShadow: [BoxShadow(color: AppColors.getShadowColor(widget.isDark), blurRadius: 10, offset: const Offset(0, 4))],
              ),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: widget.color.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                    child: Icon(widget.icon, color: widget.color, size: 32),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    widget.title,
                    style: TextStyle(color: AppColors.getTextPrimaryColor(widget.isDark), fontSize: 16, fontWeight: FontWeight.w600),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.subtitle,
                    style: TextStyle(color: AppColors.getTextSecondaryColor(widget.isDark), fontSize: 12),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _RecentRidesSection extends StatelessWidget {
  final bool isDark;

  const _RecentRidesSection({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Recent Rides',
              style: TextStyle(color: AppColors.getTextPrimaryColor(isDark), fontSize: 20, fontWeight: FontWeight.bold),
            ),
            TextButton(
              onPressed: () {
                // TODO: Implement view all rides
                ModernSnackBar.show(context, message: 'View all rides coming soon!');
              },
              child: Text(
                'View All',
                style: TextStyle(color: AppColors.primary, fontSize: 14, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.getCardColor(isDark),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.getBorderColor(isDark), width: 1),
          ),
          child: Column(
            children: [
              Icon(Icons.history, color: AppColors.getTextHintColor(isDark), size: 48),
              const SizedBox(height: 12),
              Text(
                'No recent rides',
                style: TextStyle(color: AppColors.getTextSecondaryColor(isDark), fontSize: 16, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 4),
              Text('Your ride history will appear here', style: TextStyle(color: AppColors.getTextHintColor(isDark), fontSize: 14)),
            ],
          ),
        ),
      ],
    );
  }
}

class _FeaturesSection extends StatelessWidget {
  final bool isDark;

  const _FeaturesSection({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Features',
          style: TextStyle(color: AppColors.getTextPrimaryColor(isDark), fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        _FeatureItem(icon: Icons.security, title: 'Safe & Secure', subtitle: 'All drivers are verified', isDark: isDark),
        const SizedBox(height: 12),
        _FeatureItem(icon: Icons.speed, title: 'Fast & Reliable', subtitle: 'Quick pickup and drop-off', isDark: isDark),
        const SizedBox(height: 12),
        _FeatureItem(icon: Icons.payment, title: 'Easy Payments', subtitle: 'Multiple payment options', isDark: isDark),
      ],
    );
  }
}

class _FeatureItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool isDark;

  const _FeatureItem({required this.icon, required this.title, required this.subtitle, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.getCardColor(isDark),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.getBorderColor(isDark), width: 1),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
            child: Icon(icon, color: AppColors.primary, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(color: AppColors.getTextPrimaryColor(isDark), fontSize: 16, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                Text(subtitle, style: TextStyle(color: AppColors.getTextSecondaryColor(isDark), fontSize: 14)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
