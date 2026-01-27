import 'dart:async';
import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';

import 'package:gibelbibela/models/driver_model.dart';
import 'package:gibelbibela/models/notification_model.dart';
import 'package:gibelbibela/models/ride_model.dart';
import 'package:gibelbibela/models/user_model.dart';
import 'package:gibelbibela/screens/auth/login_screen.dart';
import 'package:gibelbibela/screens/home/driver/earnings_screen.dart';
import 'package:gibelbibela/screens/home/driver/missing_fields_screen.dart';
import 'package:gibelbibela/screens/permissions/location_permission_screen.dart';
import 'package:gibelbibela/services/database_service.dart';
import 'package:gibelbibela/services/driver_access_service.dart';
import 'package:gibelbibela/services/permission_service.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../services/scheduled_reminder_service.dart';
import '../../../widgets/scheduled_reminder_dialog.dart';
import '../../../widgets/floating_countdown_widget.dart';
import '../../scheduled_booking_details_screen.dart';
import '../../history/comprehensive_ride_history_screen.dart';

import '../../../constants/app_colors.dart';
import '../../../providers/theme_provider.dart';
import '../../../services/auth_service.dart';
import '../../../services/location_service.dart';
import '../../../widgets/common/custom_button.dart';
import '../../../widgets/common/modern_alert_dialog.dart';
import '../../../widgets/common/modern_drawer.dart';
import '../../auth/driver_signup_screen.dart';
import '../../auth/email_verification_screen.dart';
import '../../notifications/notification_screen.dart';
import '../../payments/payment_screen.dart';
import 'ride_request_list_screen.dart';
import 'scheduled_requests_section.dart';
import 'driver_settings_screen.dart';

class DriverHomeScreen extends StatefulWidget {
  const DriverHomeScreen({
    super.key,
  });

  @override
  State<DriverHomeScreen> createState() => _DriverHomeScreenState();
}

class _DriverHomeScreenState extends State<DriverHomeScreen> with TickerProviderStateMixin, WidgetsBindingObserver {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  bool _isLoading = false;
  bool _isOnline = false;
  String _currentAddress = 'Getting location...';
  UserModel? _currentUser;
  double? _currentLat;
  double? _currentLng;
  DriverModel? _driver;
  bool _loading = true;

  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  double todayEarnings = 0.0;
  int ridesCompleted = 0;
  bool isEarningsLoading = true;
  List<Map<String, dynamic>> _recentRides = [];
  String? _cachedProfileImageUrl;
  
  Timer? _locationUpdateTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    
    _fadeController = AnimationController(duration: const Duration(milliseconds: 1000), vsync: this);
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut));

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchAndSetUser();
      _fetchRecentRides();
      _loadUserData();
      
      final reminderService = Provider.of<ScheduledReminderService>(context, listen: false);
      reminderService.loadScheduledBookings();
      _fadeController.forward();
    });
    
    _getCurrentLocation();
    fetchEarnings();
    _fetchDriver();
    
    final auth = Provider.of<AuthService>(context, listen: false);
    if (auth.userModel?.uid != null) {
      _loadProfileImage(auth.userModel!.uid);
    }
  }

  Future<void> _fetchAndSetUser() async {
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      await authService.fetchCurrentUser();
    } catch (e) {
      print('Error fetching user: $e');
    }
  }

  Future<void> _fetchDriver() async {
    try {
      final driver = await DatabaseService().getCurrentDriver();
      if (mounted) {
        setState(() {
          _driver = driver;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  bool get _needsProfileCompletion {
    if (_loading) return false;
    if (_currentUser?.isApproved == true) return false;
    if (_driver == null) return true;
    
    final hasBasicInfo = _driver!.name.isNotEmpty && _driver!.phoneNumber.isNotEmpty && _driver!.email.isNotEmpty;
    if (!hasBasicInfo) return true;
    
    final hasRequiredFields = _driver!.idNumber?.isNotEmpty == true &&
                             _driver!.vehicleType != null &&
                             _driver!.vehicleModel != null &&
                             _driver!.licensePlate != null;
    
    return !hasRequiredFields || (_driver!.documents.isEmpty);
  }

  void _startLocationUpdatesWhenOnline() {
    _locationUpdateTimer?.cancel();
    if (_isOnline) {
      _locationUpdateTimer = Timer.periodic(const Duration(seconds: 15), (timer) async {
        if (!mounted || !_isOnline) {
          timer.cancel();
          return;
        }
        
        try {
          final loc = Provider.of<LocationService>(context, listen: false);
          final pos = await loc.refreshCurrentLocation();
          
          if (pos != null) {
            final auth = Provider.of<AuthService>(context, listen: false);
            if (auth.userModel != null) {
              final db = Provider.of<DatabaseService>(context, listen: false);
              await db.updateDriverLocation(auth.userModel!.uid, pos.latitude, pos.longitude);
              if (mounted) setState(() { _currentLat = pos.latitude; _currentLng = pos.longitude; });
            }
          }
        } catch (_) {}
      });
    }
  }

  Future<void> _loadUserData() async {
    final auth = Provider.of<AuthService>(context, listen: false);
    final db = Provider.of<DatabaseService>(context, listen: false);
    if (auth.userModel != null) {
      final freshUser = await db.getUserById(auth.userModel!.uid);
      if (mounted) {
        final wasOnline = _isOnline;
        setState(() {
          _currentUser = freshUser;
          _isOnline = freshUser?.isOnline ?? false;
        });
        if (_isOnline != wasOnline) {
          if (_isOnline) _startLocationUpdatesWhenOnline();
          else _locationUpdateTimer?.cancel();
        }
      }
    }
  }

  Future<void> _getCurrentLocation() async {
    if (mounted) setState(() => _isLoading = true);
    try {
      final loc = Provider.of<LocationService>(context, listen: false);
      final pos = await loc.requestAndGetCurrentLocation(context);
      if (pos != null) {
        final addr = await loc.getAddressFromCoordinates(pos.latitude, pos.longitude);
        if (mounted) {
          setState(() {
            _currentLat = pos.latitude; _currentLng = pos.longitude;
            _currentAddress = addr ?? 'Location available';
            _isLoading = false;
          });
        }
      } else {
        if (mounted) setState(() => _isLoading = false);
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _toggleOnlineStatus() async {
    final auth = Provider.of<AuthService>(context, listen: false);
    if (auth.userModel == null) return;

    if (!auth.userModel!.isApproved) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Account must be approved to go online.')));
      return;
    }

    final newStatus = !_isOnline;
    setState(() => _isOnline = newStatus);

    try {
      final db = Provider.of<DatabaseService>(context, listen: false);
      await db.setUserOnlineStatus(auth.userModel!.uid, newStatus);
      await db.setDriverOnlineStatus(auth.userModel!.uid, newStatus);

      if (newStatus && _currentLat != null && _currentLng != null) {
        await db.updateDriverLocation(auth.userModel!.uid, _currentLat!, _currentLng!);
      }
      
      if (newStatus) _startLocationUpdatesWhenOnline();
      else _locationUpdateTimer?.cancel();

      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(newStatus ? 'You are now Online' : 'You are now Offline'),
        backgroundColor: newStatus ? AppColors.success : AppColors.uberBlack,
        behavior: SnackBarBehavior.floating,
      ));
    } catch (e) {
      setState(() => _isOnline = !newStatus);
    }
  }

  void _openDrawer() => _scaffoldKey.currentState?.openDrawer();

  void _viewRideRequests() {
    final user = Provider.of<AuthService>(context, listen: false).userModel;
    if (user?.isApproved != true) {
      _showApprovalPendingDialog();
      return;
    }
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const RideRequestListScreen()));
  }

  void _showApprovalPendingDialog() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.1), shape: BoxShape.circle),
                child: const Icon(Icons.hourglass_top_rounded, color: AppColors.primary, size: 48),
              ),
              const SizedBox(height: 24),
              const Text('Account Under Review', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
              const SizedBox(height: 12),
              const Text('Our team is currently reviewing your application. You\'ll be notified once you\'re cleared to drive.', style: TextStyle(color: Colors.grey), textAlign: TextAlign.center),
              const SizedBox(height: 32),
              CustomButton(text: 'Understood', onPressed: () => Navigator.pop(context), isFullWidth: true),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> fetchEarnings() async {
    try {
      final auth = Provider.of<AuthService>(context, listen: false);
      final db = Provider.of<DatabaseService>(context, listen: false);
      if (auth.userModel != null) {
        final res = await db.getTodaysEarningsAndRides(auth.userModel!.uid);
        if (mounted) {
          setState(() {
            todayEarnings = ((res['earnings'] ?? 0) as num).toDouble();
            ridesCompleted = ((res['rides'] ?? 0) as num).toInt();
            isEarningsLoading = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            isEarningsLoading = false;
          });
        }
      }
    } catch (e) {
      print('Error fetching earnings: $e');
      if (mounted) {
        setState(() {
          todayEarnings = 0.0;
          ridesCompleted = 0;
          isEarningsLoading = false;
        });
      }
    }
  }

  Future<void> _fetchRecentRides() async {
    final auth = Provider.of<AuthService>(context, listen: false);
    if (auth.userModel != null) {
      final rides = await Provider.of<DatabaseService>(context, listen: false).getRecentRides(auth.userModel!.uid);
      if (mounted) setState(() => _recentRides = rides);
    }
  }

  Future<void> _loadProfileImage(String userId) async {
    try {
      final url = await DatabaseService().getDriverProfileImage(userId);
      if (mounted) setState(() => _cachedProfileImageUrl = url);
    } catch (_) {}
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _locationUpdateTimer?.cancel();
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final user = Provider.of<AuthService>(context).userModel;

    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator(color: AppColors.uberBlack)));

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: AppColors.getBackgroundColor(isDark),
      drawer: ModernDrawer(user: user, onLogout: () => _handleLogout(context)),
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Column(
            children: [
              _buildAppBar(isDark, user),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: () async {
                    await _fetchRecentRides();
                    await fetchEarnings();
                    await _loadUserData();
                  },
                  color: AppColors.uberBlack,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (user?.isApproved == false) _buildApprovalBanner(isDark),
                        _buildWelcomeSection(isDark, user),
                        const SizedBox(height: 24),
                        _buildStatusCard(isDark),
                        const SizedBox(height: 32),
                        _buildEarningsCard(isDark),
                        const SizedBox(height: 32),
                        _buildQuickActions(isDark),
                        const SizedBox(height: 32),
                        _buildRecentRides(isDark),
                        const SizedBox(height: 40),
                      ],
                    ),
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
          _buildNotificationBadge(isDark, user),
          const SizedBox(width: 12),
          GestureDetector(
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DriverSettingsScreen())),
            child: _buildAvatar(user),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatar(UserModel? user) {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.primary, width: 2),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 8, offset: const Offset(0, 4))],
      ),
      child: CircleAvatar(
        radius: 22,
        backgroundColor: AppColors.uberGrey,
        backgroundImage: (_cachedProfileImageUrl != null && _cachedProfileImageUrl!.isNotEmpty)
            ? NetworkImage(_cachedProfileImageUrl!)
            : (user?.profileImage != null && user!.profileImage!.isNotEmpty ? NetworkImage(user.profileImage!) : null),
        child: (_cachedProfileImageUrl == null && (user?.profileImage == null || user!.profileImage!.isEmpty))
            ? const Icon(Icons.person, color: Colors.grey)
            : null,
      ),
    );
  }

  Widget _buildNotificationBadge(bool isDark, UserModel? user) {
    return StreamBuilder<List<NotificationModel>>(
      stream: user != null ? DatabaseService().getUserNotifications(user.uid) : Stream.value([]),
      builder: (context, snapshot) {
        final count = (snapshot.data ?? []).where((n) => !n.isRead).length;
        return Stack(
          children: [
            IconButton(
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationScreen())),
              icon: Icon(Icons.notifications_none_rounded, color: AppColors.getIconColor(isDark), size: 28),
              style: IconButton.styleFrom(backgroundColor: isDark ? Colors.white10 : AppColors.uberGrey, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            ),
            if (count > 0)
              Positioned(
                right: 8, top: 8,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(color: AppColors.error, shape: BoxShape.circle),
                  constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                  child: Text(count.toString(), style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildWelcomeSection(bool isDark, UserModel? user) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Welcome,', style: TextStyle(color: AppColors.getTextSecondaryColor(isDark), fontSize: 16, fontWeight: FontWeight.w500)),
        const SizedBox(height: 4),
        Text(user?.name ?? 'Driver', style: TextStyle(color: AppColors.getTextPrimaryColor(isDark), fontSize: 28, fontWeight: FontWeight.w900, letterSpacing: -0.5)),
      ],
    );
  }

  Widget _buildApprovalBanner(bool isDark) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline_rounded, color: AppColors.primaryDark),
          const SizedBox(width: 12),
          const Expanded(child: Text('Your account is under review. Some features may be restricted.', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13))),
        ],
      ),
    );
  }

  Widget _buildStatusCard(bool isDark) {
    final bgColor = _isOnline ? AppColors.uberBlack : (isDark ? AppColors.darkCard : AppColors.white);
    final textColor = _isOnline ? Colors.white : AppColors.getTextPrimaryColor(isDark);
    
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(_isOnline ? 0.2 : 0.05),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
        border: Border.all(color: _isOnline ? Colors.transparent : (isDark ? Colors.white10 : AppColors.uberGreyLight)),
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_isOnline ? "You're Online" : "You're Offline", 
                    style: TextStyle(color: textColor, fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: -0.5)),
                  const SizedBox(height: 4),
                  Text(_isOnline ? "Ready for ride requests" : "Go online to start earning", 
                    style: TextStyle(color: _isOnline ? Colors.white70 : AppColors.getTextSecondaryColor(isDark), fontSize: 14)),
                ],
              ),
              Switch.adaptive(
                value: _isOnline,
                onChanged: (_) => _toggleOnlineStatus(),
                activeColor: AppColors.primary,
                activeTrackColor: Colors.white24,
              ),
            ],
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _isOnline ? Colors.white.withOpacity(0.1) : AppColors.uberGrey.withOpacity(isDark ? 0.05 : 1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Icon(Icons.location_on_rounded, color: _isOnline ? AppColors.primary : Colors.grey, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(_currentAddress, 
                    style: TextStyle(color: textColor, fontWeight: FontWeight.w500, fontSize: 13), 
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                ),
                if (_isLoading) 
                  const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary))
                else 
                  IconButton(onPressed: _getCurrentLocation, icon: Icon(Icons.refresh_rounded, color: _isOnline ? Colors.white54 : Colors.grey, size: 18), padding: EdgeInsets.zero, constraints: const BoxConstraints()),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEarningsCard(bool isDark) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: isDark ? Colors.white10 : AppColors.uberGreyLight),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 15, offset: const Offset(0, 8))],
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("Today's Earnings", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.grey)),
              GestureDetector(
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const EarningsScreen())),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
                  child: const Text('Details', style: TextStyle(color: AppColors.primaryDark, fontWeight: FontWeight.bold, fontSize: 12)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          isEarningsLoading 
            ? const LinearProgressIndicator(backgroundColor: Colors.transparent, color: AppColors.primary)
            : Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('R ${todayEarnings.toStringAsFixed(2)}', style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: AppColors.getTextPrimaryColor(isDark))),
                  const SizedBox(width: 12),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text('$ridesCompleted Rides', style: const TextStyle(color: AppColors.success, fontWeight: FontWeight.bold, fontSize: 14)),
                  ),
                ],
              ),
        ],
      ),
    );
  }

  Widget _buildQuickActions(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Quick Actions', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(child: _ActionTile(title: 'Requests', icon: Icons.explore_rounded, color: AppColors.uberBlack, onTap: _viewRideRequests, isDark: isDark)),
            const SizedBox(width: 12),
            Expanded(child: _ActionTile(title: 'Scheduled', icon: Icons.calendar_today_rounded, color: AppColors.uberBlack, onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => ScheduledRequestsSection(isDark: isDark)));
            }, isDark: isDark)),
            const SizedBox(width: 12),
            Expanded(child: _ActionTile(title: 'History', icon: Icons.history_rounded, color: AppColors.uberBlack, onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const ComprehensiveRideHistoryScreen(isDriver: true)));
            }, isDark: isDark)),
          ],
        ),
      ],
    );
  }

  Widget _buildRecentRides(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Recent Activity', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
        const SizedBox(height: 16),
        _recentRides.isEmpty 
          ? _buildEmptyState(isDark)
          : ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _recentRides.length > 3 ? 3 : _recentRides.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, i) => _buildRideItem(_recentRides[i], isDark),
            ),
      ],
    );
  }

  Widget _buildRideItem(Map<String, dynamic> ride, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? Colors.white10 : AppColors.uberGreyLight),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: AppColors.uberGrey.withOpacity(isDark ? 0.1 : 1), borderRadius: BorderRadius.circular(12)),
            child: const Icon(Icons.directions_car_rounded, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(ride['dropoffAddress'] ?? 'Trip', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14), maxLines: 1, overflow: TextOverflow.ellipsis),
                Text(DateFormat('MMM d, h:mm a').format((ride['timestamp'] as Timestamp).toDate()), style: const TextStyle(color: Colors.grey, fontSize: 12)),
              ],
            ),
          ),
          Text('R${ride['fare'] ?? '0'}', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
        ],
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(color: isDark ? AppColors.darkCard : AppColors.uberGrey.withOpacity(0.5), borderRadius: BorderRadius.circular(24), border: Border.all(color: isDark ? Colors.white10 : Colors.transparent, style: BorderStyle.solid)),
      child: Column(
        children: [
          Icon(Icons.history_rounded, color: Colors.grey.withOpacity(0.5), size: 40),
          const SizedBox(height: 12),
          const Text('No recent trips yet', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.w600)),
        ],
      ),
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

  Widget _buildReminderDialog(ScheduledReminderService svc) {
    return ScheduledReminderDialog(
      reminder: svc.currentReminder!,
      onDismiss: () => svc.dismissReminder(),
      onViewDetails: () => _openBookingDetails(svc.currentReminder!['id']),
    );
  }

  void _openBookingDetails(String bookingId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ScheduledBookingDetailsScreen(
          bookingId: bookingId,
          isDriver: true,
        ),
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final bool isDark;

  const _ActionTile({required this.title, required this.icon, required this.color, required this.onTap, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 12),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkCard : AppColors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isDark ? Colors.white10 : AppColors.uberGreyLight),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))],
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.1), shape: BoxShape.circle),
              child: Icon(icon, color: AppColors.uberBlack, size: 24),
            ),
            const SizedBox(height: 12),
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: -0.2)),
          ],
        ),
      ),
    );
  }
}
