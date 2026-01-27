// lib/screens/home/passenger/passenger_home_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
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
import '../../../services/reminder_service.dart';
import '../../../services/scheduled_reminder_service.dart';
import '../../../widgets/common/custom_button.dart';
import '../../../widgets/common/modern_alert_dialog.dart';
import '../../../widgets/common/modern_drawer.dart';
import '../../../widgets/scheduled_reminder_dialog.dart';
import '../../../widgets/floating_countdown_widget.dart';
import '../../scheduled_booking_details_screen.dart';
import 'profilescreen.dart';
import 'request_ride_screen.dart';
import 'scheduled_trip_screen.dart';
import 'my_bookings_screen.dart';
import 'saved_places_screen.dart';
import '../../history/comprehensive_ride_history_screen.dart';

class PassengerHomeScreen extends StatefulWidget {
  final bool isFirstTime;
  const PassengerHomeScreen({super.key, this.isFirstTime = false});

  @override
  State<PassengerHomeScreen> createState() => _PassengerHomeScreenState();
}

class _PassengerHomeScreenState extends State<PassengerHomeScreen> with TickerProviderStateMixin {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  bool _isLoading = false;
  String _currentAddress = 'Getting location...';
  UserModel? _currentUser;

  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(duration: const Duration(milliseconds: 1000), vsync: this);
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut));

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchAndSetUser();
      _checkLocationPermissions();
      _startReminderService();
      
      final reminderService = Provider.of<ScheduledReminderService>(context, listen: false);
      reminderService.loadScheduledBookings();
      _fadeController.forward();
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
      WidgetsBinding.instance.addPostFrameCallback((_) {
        showDialog(
          context: context,
          builder: (context) => const ModernAlertDialog(title: 'Welcome!', message: 'Ready for your next journey?', confirmText: 'Let\'s Go!', icon: Icons.celebration_rounded),
        );
        prefs.setBool('isFirstTime', false);
      });
    }
  }

  Future<void> _fetchAndSetUser() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    await authService.fetchCurrentUser();
  }

  Future<void> _startReminderService() async {
    ReminderService().startReminderService(context);
  }

  Future<void> _checkLocationPermissions() async {
    if (ModalRoute.of(context)?.settings.name == '/passenger_home') return;
    final shouldShow = await PermissionService.shouldShowPermissionScreenForPassenger();
    if (shouldShow && mounted) {
      await Navigator.of(context).push(MaterialPageRoute(builder: (context) => LocationPermissionScreen(isDriver: false, onPermissionGranted: () => _getCurrentLocation())));
    }
  }

  Future<void> _getCurrentLocation() async {
    if (mounted) setState(() => _isLoading = true);
    try {
      final loc = Provider.of<LocationService>(context, listen: false);
      final pos = await loc.requestAndGetCurrentLocation(context);
      if (pos != null) {
        final addr = await loc.getAddressFromCoordinates(pos.latitude, pos.longitude);
        if (mounted) setState(() { _currentAddress = addr ?? 'Location available'; _isLoading = false; });
      } else {
        if (mounted) setState(() => _isLoading = false);
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _openDrawer() => _scaffoldKey.currentState?.openDrawer();

  void _requestRide() {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const RequestRideScreen()));
  }

  void _goToProfile() {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ProfileScreen()));
  }

  @override
  void dispose() {
    _fadeController.dispose();
    ReminderService().stopReminderService();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final user = Provider.of<AuthService>(context).userModel;

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: AppColors.getBackgroundColor(isDark),
      drawer: ModernDrawer(user: user, onProfileTap: _goToProfile, onLogout: () => _handleLogout(context)),
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Column(
            children: [
              _buildAppBar(isDark, user),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 10),
                      _buildSearchCard(isDark),
                      const SizedBox(height: 32),
                      _buildQuickActions(isDark),
                      const SizedBox(height: 32),
                      _buildRecentRides(isDark),
                      const SizedBox(height: 32),
                      _buildFeatures(isDark),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAppBar(bool isDark, UserModel? user) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        children: [
          IconButton(
            onPressed: _openDrawer,
            icon: Icon(Icons.menu_rounded, color: AppColors.getIconColor(isDark), size: 28),
            style: IconButton.styleFrom(backgroundColor: isDark ? Colors.white10 : AppColors.uberGrey, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
          ),
          const Spacer(),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('Hello,', style: TextStyle(color: AppColors.getTextSecondaryColor(isDark), fontSize: 12)),
              Text(user?.fullName ?? 'User', style: TextStyle(color: AppColors.getTextPrimaryColor(isDark), fontWeight: FontWeight.w900, fontSize: 16)),
            ],
          ),
          const SizedBox(width: 12),
          GestureDetector(
            onTap: _goToProfile,
            child: Container(
              decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: AppColors.primary, width: 2)),
              child: CircleAvatar(
                radius: 20,
                backgroundColor: AppColors.uberGrey,
                backgroundImage: (user?.profileImageUrl != null && user!.profileImageUrl!.isNotEmpty) ? NetworkImage(user.profileImageUrl!) : null,
                child: (user?.profileImageUrl == null || user!.profileImageUrl!.isEmpty) ? const Icon(Icons.person, color: Colors.grey) : null,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchCard(bool isDark) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 20, offset: const Offset(0, 10))],
        border: Border.all(color: isDark ? Colors.white10 : AppColors.uberGreyLight),
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Where to?', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, letterSpacing: -0.5)),
          const SizedBox(height: 20),
          GestureDetector(
            onTap: _requestRide,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              decoration: BoxDecoration(color: isDark ? Colors.white10 : AppColors.uberGrey, borderRadius: BorderRadius.circular(16)),
              child: Row(
                children: [
                  const Icon(Icons.search_rounded, color: Colors.grey),
                  const SizedBox(width: 12),
                  const Text('Enter destination', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.w500)),
                  const Spacer(),
                  Container(width: 1, height: 24, color: Colors.grey.withOpacity(0.3)),
                  const SizedBox(width: 12),
                  const Icon(Icons.access_time_rounded, color: Colors.grey, size: 20),
                  const SizedBox(width: 4),
                  const Text('Now', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Icon(Icons.my_location_rounded, color: AppColors.success, size: 18),
              const SizedBox(width: 8),
              Expanded(child: Text(_currentAddress, style: TextStyle(color: AppColors.getTextSecondaryColor(isDark), fontSize: 13, fontWeight: FontWeight.w500), maxLines: 1, overflow: TextOverflow.ellipsis)),
              if (_isLoading) const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions(bool isDark) {
    return Row(
      children: [
        Expanded(child: _ActionTile(title: 'History', icon: Icons.history_rounded, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ComprehensiveRideHistoryScreen(isDriver: false))), isDark: isDark)),
        const SizedBox(width: 12),
        Expanded(child: _ActionTile(title: 'Scheduled', icon: Icons.calendar_today_rounded, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ScheduledTripScreen())), isDark: isDark)),
        const SizedBox(width: 12),
        Expanded(child: _ActionTile(title: 'Saved', icon: Icons.bookmark_rounded, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SavedPlacesScreen())), isDark: isDark)),
      ],
    );
  }

  Widget _buildRecentRides(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Recent activity', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
        const SizedBox(height: 16),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(color: isDark ? AppColors.darkCard : AppColors.uberGrey.withOpacity(0.5), borderRadius: BorderRadius.circular(24), border: Border.all(color: isDark ? Colors.white10 : Colors.transparent)),
          child: Column(
            children: [
              Icon(Icons.history_rounded, color: Colors.grey.withOpacity(0.5), size: 40),
              const SizedBox(height: 12),
              const Text('No recent trips yet', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFeatures(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Why choose us', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
        const SizedBox(height: 16),
        _FeatureItem(icon: Icons.shield_rounded, title: 'Safety first', subtitle: 'Verified drivers & trip tracking', isDark: isDark),
        const SizedBox(height: 12),
        _FeatureItem(icon: Icons.flash_on_rounded, title: 'Top tier reliability', subtitle: 'Fast pickup and arrival', isDark: isDark),
      ],
    );
  }

  Future<void> _handleLogout(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => const ModernAlertDialog(title: 'Logout', message: 'Are you sure?', confirmText: 'Logout', cancelText: 'Cancel', isDestructive: true),
    );
    if (confirmed == true) {
      final auth = Provider.of<AuthService>(context, listen: false);
      await auth.signOut();
      Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const LoginScreen()), (_) => false);
    }
  }
}

class _ActionTile extends StatelessWidget {
  final String title;
  final IconData icon;
  final VoidCallback onTap;
  final bool isDark;

  const _ActionTile({required this.title, required this.icon, required this.onTap, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkCard : AppColors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isDark ? Colors.white10 : AppColors.uberGreyLight),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))],
        ),
        child: Column(
          children: [
            Icon(icon, color: AppColors.uberBlack, size: 24),
            const SizedBox(height: 8),
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          ],
        ),
      ),
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
        color: isDark ? AppColors.darkCard : AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? Colors.white10 : AppColors.uberGreyLight),
      ),
      child: Row(
        children: [
          Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(12)), child: Icon(icon, color: AppColors.primaryDark, size: 20)),
          const SizedBox(width: 16),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            Text(subtitle, style: TextStyle(color: Colors.grey, fontSize: 12)),
          ])),
        ],
      ),
    );
  }
}
