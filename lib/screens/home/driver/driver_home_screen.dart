import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:gibelbibela/models/driver_model.dart';
import 'package:gibelbibela/models/notification_model.dart';
import 'package:gibelbibela/models/user_model.dart';
import 'package:gibelbibela/screens/auth/login_screen.dart';
import 'package:gibelbibela/screens/driver/ride_history_screen.dart' as driver_history;
import 'package:gibelbibela/screens/home/driver/earnings_screen.dart';
import 'package:gibelbibela/screens/permissions/location_permission_screen.dart';
import 'package:gibelbibela/services/database_service.dart';
import 'package:gibelbibela/services/driver_access_service.dart';
import 'package:gibelbibela/services/permission_service.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  String _currentAddress = 'Getting your location...';
  UserModel? _currentUser;
  double? _currentLat;
  double? _currentLng;
  DriverModel? _driver;
  bool _loading = true;
  bool _showWelcomeAlert = false;

  late AnimationController _fadeController;
  late AnimationController _slideController;
  late AnimationController _statusController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _statusAnimation;

  double todayEarnings = 0.0;
  int ridesCompleted = 0;
  bool isEarningsLoading = true;
  List<Map<String, dynamic>> _recentRides = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this); // Add lifecycle observer
    _initializeAnimations();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Removed _validateDriverAccess() - no need to validate on every startup
      _fetchAndSetUser();
      _fetchRecentRides();
      _loadUserData(); // Add this to load initial online status
      // Removed _checkLocationPermissions() - no need to check permissions on every startup
      // Removed _checkApprovalStatus() - let validation banner handle it
    });
    _getCurrentLocation();
    fetchEarnings();
    _fetchDriver();
    _checkWelcomeAlert();
  }

  Future<void> _fetchAndSetUser() async {
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      await authService.fetchCurrentUser();
      // No setState() needed, provider will notify listeners
    } catch (e) {
      print('Error fetching user: $e');
      // Handle error gracefully - user can still use the app
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
      print('Error fetching driver: $e');
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  bool get _needsProfileCompletion {
    if (_driver == null) {
      // If the driver object itself is null, profile is definitely incomplete.
      return true;
    }
    
    // Check for basic required fields
    final hasBasicInfo = _driver!.name.isNotEmpty && 
                        _driver!.phoneNumber.isNotEmpty && 
                        _driver!.email.isNotEmpty;
    
    if (!hasBasicInfo) {
      return true;
    }
    
    // Check for required driver-specific fields
    final hasRequiredFields = _driver!.idNumber?.isNotEmpty == true &&
                             _driver!.vehicleType != null &&
                             _driver!.vehicleModel != null &&
                             _driver!.licensePlate != null &&
                             (_driver!.towns?.isNotEmpty ?? false);
    
    // Check for required documents
    final hasDocuments = _driver!.documents != null && 
                        _driver!.documents!.isNotEmpty;
    
    return !hasRequiredFields || !hasDocuments;
  }

  // Check if payment is required
  Future<bool> _isPaymentRequired() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return true;
      
      final paymentsQuery = await FirebaseFirestore.instance
          .collection('driver_payments')
          .where('driverId', isEqualTo: user.uid)
          .where('status', isEqualTo: 'success')
          .orderBy('timestamp', descending: true)
          .limit(1)
          .get();

      return paymentsQuery.docs.isEmpty;
    } catch (e) {
      print('Error checking payment status: $e');
      return true; // Assume payment is required if there's an error
    }
  }

  void _initializeAnimations() {
    _fadeController = AnimationController(duration: const Duration(milliseconds: 1000), vsync: this);

    _slideController = AnimationController(duration: const Duration(milliseconds: 800), vsync: this);

    _statusController = AnimationController(duration: const Duration(milliseconds: 500), vsync: this);

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut));

    _slideAnimation = Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero).animate(CurvedAnimation(parent: _slideController, curve: Curves.easeOutCubic));

    _statusAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(CurvedAnimation(parent: _statusController, curve: Curves.easeInOut));

    _fadeController.forward();
    _slideController.forward();
  }

  Future<void> _loadUserData() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    final dbService = Provider.of<DatabaseService>(context, listen: false);
    final userModel = authService.userModel;
    if (userModel != null) {
      // Fetch latest user data from Firestore
      final freshUser = await dbService.getUserById(userModel.uid);
      if (mounted) {
        setState(() {
          _currentUser = freshUser;
          _isOnline = freshUser?.isOnline ?? false;
        });
      }
    }
  }

  Future<void> _checkLocationPermissions() async {
    // Skip permission check if we just came from the permission screen
    if (ModalRoute.of(context)?.settings.name == '/driver_home') {
      return;
    }

    final shouldShow = await PermissionService.shouldShowPermissionScreen();
    if (shouldShow && mounted) {
      // Show permission screen as full screen instead of dialog
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => LocationPermissionScreen(
            isDriver: true,
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
            _currentLat = position.latitude;
            _currentLng = position.longitude;
            _currentAddress = address ?? 'Location not available';
            _isLoading = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _currentAddress = 'Location not available';
            _currentLat = null;
            _currentLng = null;
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _currentAddress = 'Error getting location';
          _currentLat = null;
          _currentLng = null;
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _toggleOnlineStatus() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    final userModel = authService.userModel;

    if (userModel == null) return;

    if (!userModel.isApproved) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('You must be approved to go online.')));
      return;
    }

    setState(() {
      _isOnline = !_isOnline;
    });

    try {
      final dbService = Provider.of<DatabaseService>(context, listen: false);
      await dbService.setUserOnlineStatus(userModel.uid, _isOnline);
      await dbService.setDriverOnlineStatus(userModel.uid, _isOnline);

      // Show feedback to user
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_isOnline ? 'You are now online!' : 'You are now offline'), backgroundColor: _isOnline ? Colors.green : Colors.orange));
    } catch (e) {
      // Revert state if update fails
      setState(() {
        _isOnline = !_isOnline;
      });

      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to update status: ${e.toString()}'), backgroundColor: Colors.red));
    }
  }

  void _openDrawer() {
    _scaffoldKey.currentState?.openDrawer();
  }

  void _viewRideRequests() {
    // Check if driver is approved before allowing access to ride requests
    final user = Provider.of<AuthService>(context, listen: false).userModel;
    if (user?.isApproved != true) {
      // Show modern, beautiful dialog explaining why they can't access ride requests
      showDialog(
        context: context,
        barrierDismissible: true,
        builder: (context) => Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          elevation: 0,
          backgroundColor: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white,
                  Colors.grey.shade50,
                ],
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Icon with background
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.orange.shade400, Colors.orange.shade600],
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.hourglass_empty,
                    color: Colors.white,
                    size: 40,
                  ),
                ),
                const SizedBox(height: 20),
                
                // Title
                const Text(
                  'Account Under Review',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                
                // Message
                const Text(
                  'Your driver account is currently being reviewed by our team. This process typically takes 24-48 hours.',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.black54,
                    height: 1.4,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                
                const Text(
                  'You\'ll be able to view and accept ride requests once your account is approved.',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.black45,
                    height: 1.3,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                
                // Action button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange.shade600,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: const Text(
                      'Got it!',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      return;
    }

    // Driver is approved, proceed to ride requests
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => const RideRequestListScreen(),
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

  Future<void> fetchEarnings() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    final dbService = Provider.of<DatabaseService>(context, listen: false);
    final user = authService.userModel;
    if (user != null) {
      final result = await dbService.getTodaysEarningsAndRides(user.uid);
      setState(() {
        todayEarnings = (result['earnings'] ?? 0.0) as double;
        ridesCompleted = (result['rides'] ?? 0) as int;
        isEarningsLoading = false;
      });
    } else {
      setState(() {
        isEarningsLoading = false;
      });
    }
  }

  Future<void> _checkWelcomeAlert() async {
    final prefs = await SharedPreferences.getInstance();
    final hasSeen = prefs.getBool('driver_seen_welcome_alert') ?? false;
    if (!hasSeen) {
      setState(() {
        _showWelcomeAlert = true;
      });
    }
  }

  Future<void> _dismissWelcomeAlert() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('driver_seen_welcome_alert', true);
    setState(() {
      _showWelcomeAlert = false;
    });
  }

  Future<void> _fetchRecentRides() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    final user = authService.userModel;
    if (user != null) {
      final rides = await Provider.of<DatabaseService>(context, listen: false).getRecentRides(user.uid);
      setState(() {
        _recentRides = rides;
      });
    }
  }

  // Driver validation state
  String? _validationStatus;
  String? _validationMessage;
  bool _showValidationBanner = false;

  // Comprehensive driver validation check - now user-friendly
  Future<void> _validateDriverAccess() async {
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final user = authService.currentUser;
      
      if (user == null) {
        // No user logged in, redirect to login
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const LoginScreen())
        );
        return;
      }

      // Silently check email verification in background
      _silentlyCheckEmailVerification(user);

      // Check driver access using the same logic as splash screen
      final driverAccessService = DriverAccessService();
      final accessCheck = await driverAccessService.checkDriverAccess(user.uid);
      
      print('🔍 Driver access validation results:');
      print('- Can Access: ${accessCheck['canAccess']}');
      print('- Status: ${accessCheck['status']}');
      print('- Reason: ${accessCheck['reason']}');
      
      // Handle different access scenarios - now with user-friendly approach
      switch (accessCheck['status']) {
        case 'signup_required':
          print('📝 Driver signup required, showing banner...');
          setState(() {
            _validationStatus = 'signup_required';
            _validationMessage = 'Complete your driver profile to start earning';
            _showValidationBanner = true;
          });
          return;
          
        case 'payment_required':
          print('💰 Payment required, showing banner...');
          setState(() {
            _validationStatus = 'payment_required';
            _validationMessage = 'Complete payment to activate your driver account';
            _showValidationBanner = true;
          });
          return;
          
        case 'email_verification_required':
          // Check if user's email is actually verified before redirecting
          bool isEmailVerified = user.emailVerified;
          
          // Only reload if not verified (to avoid unnecessary network calls)
          if (!isEmailVerified) {
            await user.reload();
            isEmailVerified = user.emailVerified;
          }
          
          // Only redirect to email verification screen if email is actually not verified
          if (!isEmailVerified) {
            final userModel = await Provider.of<DatabaseService>(context, listen: false).getUserById(user.uid);
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                builder: (context) => EmailVerificationScreen(user: user, isDriver: true),
              ),
            );
            return;
          } else {
            // Email is verified, but driver access service thinks it's not
            // This might be a stale status, so let's re-validate
            print('✅ Email is verified, re-validating driver access');
            _validateDriverAccess();
            return;
          }
          
        case 'error':
          print('❌ Driver access error, redirecting to login');
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (context) => const LoginScreen())
          );
          return;
          
        case 'approved':
        case 'awaiting_approval':
          // Driver can stay on home screen regardless of approval status
          // The home screen will show appropriate banners and UI
          setState(() {
            _showValidationBanner = false;
          });
          break;
          
        default:
          print('⚠️ Unknown driver status: ${accessCheck['status']}, redirecting to login');
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (context) => const LoginScreen())
          );
          return;
      }
    } catch (e) {
      print('❌ Error validating driver access: $e');
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const LoginScreen())
      );
    }
  }

  // Silently check email verification without blocking UI
  void _silentlyCheckEmailVerification(User user) async {
    try {
      bool isVerified = user.emailVerified;
      
      // Only reload if not verified (to avoid unnecessary network calls)
      if (!isVerified) {
        await user.reload();
        isVerified = user.emailVerified;
      }
      
      // If not verified, add it to validation status for subtle UI feedback
      if (!isVerified && mounted) {
        setState(() {
          _validationStatus = 'email_verification_required';
          _validationMessage = 'Please verify your email to access all features';
          _showValidationBanner = true;
        });
      }
    } catch (e) {
      print('❌ Error checking email verification: $e');
      // Don't block user experience on error
    }
  }

  // Handle validation banner actions
  Future<void> _handleValidationAction() async {
    // Handle profile completion (either from validation status or needsProfileCompletion)
    if (_validationStatus == 'signup_required' || _needsProfileCompletion) {
      // Navigate to signup screen
      await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const DriverSignupScreen()),
      );
      // Re-validate after returning from signup
      _validateDriverAccess();
      return;
    }
    
    // Handle payment required
    if (_validationStatus == 'payment_required') {
      // Navigate to payment screen
      final authService = Provider.of<AuthService>(context, listen: false);
      final user = authService.currentUser;
      final userModel = await Provider.of<DatabaseService>(context, listen: false).getUserById(user!.uid);
      
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => PaymentScreen(
            amount: 150.00,
            email: userModel?.email ?? user.email ?? '',
            onPaymentSuccess: () {
              // Payment successful, re-validate
              _validateDriverAccess();
            },
          ),
        ),
      );
      return;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this); // Remove lifecycle observer
    _fadeController.dispose();
    _slideController.dispose();
    _statusController.dispose();
    super.dispose();
  }

  // Periodic validation check (called when app comes to foreground)
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      // Removed _validateDriverAccess() - no need to re-validate when app comes to foreground
      // This was causing unnecessary email verification and permission screens to show
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;

    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    // Don't immediately redirect to DriverSignupScreen - let the validation banner handle it
    // This allows users to see the home screen with the validation banner

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: AppColors.getBackgroundColor(isDark),
      drawer: ModernDrawer(user: Provider.of<AuthService>(context).userModel, onLogout: () => handleDrawerLogout(context)),
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
                      // Header Column for status and toggle
                      Expanded(
                        child: Builder(
                          builder: (context) {
                            final user = Provider.of<AuthService>(context).userModel;
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Approval badge and refresh in a row
                                Row(
                                  children: [
                                    if (user?.isApproved == true)
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(color: Colors.green[600], borderRadius: BorderRadius.circular(12)),
                                        child: Row(
                                          children: const [
                                            Icon(Icons.verified, color: Colors.white, size: 16),
                                            SizedBox(width: 4),
                                            Text(
                                              'Approved',
                                              style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                                            ),
                                          ],
                                        ),
                                      )
                                    else
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(color: Colors.amber[700], borderRadius: BorderRadius.circular(12)),
                                        child: Row(
                                          children: const [
                                            SizedBox(width: 4),
                                            Text(
                                              'Awaiting approval',
                                              style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                                            ),
                                          ],
                                        ),
                                      ),
                                    // Refresh Button
                                  ],
                                ),
                                const SizedBox(height: 12),
                              ],
                            );
                          },
                        ),
                      ),
                      // Profile Image and Notification Icon
                      Row(children: [_buildNotificationIcon(context), const SizedBox(width: 12), _buildProfileAvatar()]),
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
                    // Approval Status Banner - Right under the header
                    Builder(
                      builder: (context) {
                        final user = Provider.of<AuthService>(context).userModel;
                        if (user?.isApproved != true)
                          return FadeTransition(
                            opacity: _fadeAnimation,
                            child: Container(
                              width: double.infinity,
                              margin: const EdgeInsets.only(bottom: 16),
                              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                              decoration: BoxDecoration(
                                color: Colors.orange.withOpacity(0.1),
                                border: Border.all(color: Colors.orange),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.pending, color: Colors.orange),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          'Account Under Review',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: Colors.orange,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          'Your account is awaiting approval. You\'ll be notified once approved.',
                                          style: TextStyle(
                                            color: Colors.orange.shade800,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        return const SizedBox.shrink();
                      },
                    ),

                    // Validation Banner - for incomplete drivers
                    if (_showValidationBanner || _needsProfileCompletion)
                      FadeTransition(
                        opacity: _fadeAnimation,
                        child: Container(
                          width: double.infinity,
                          margin: const EdgeInsets.only(bottom: 16),
                          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                AppColors.primary.withOpacity(0.1),
                                AppColors.primary.withOpacity(0.05),
                              ],
                            ),
                            border: Border.all(color: AppColors.primary.withOpacity(0.3)),
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.primary.withOpacity(0.1),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: AppColors.primary,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Icon(
                                      (_validationStatus == 'signup_required' || _needsProfileCompletion)
                                        ? Icons.person_add 
                                        : Icons.payment,
                                      color: Colors.white,
                                      size: 20,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          (_validationStatus == 'signup_required' || _needsProfileCompletion)
                                            ? 'Complete Your Profile' 
                                            : 'Payment Required',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                            color: AppColors.primary,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          _validationMessage ?? (_needsProfileCompletion 
                                            ? 'Complete your driver profile to start earning' 
                                            : ''),
                                          style: TextStyle(
                                            fontSize: 14,
                                            color: isDark ? Colors.white70 : Colors.black87,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton(
                                  onPressed: _handleValidationAction,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.primary,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                  child: Text(
                                    (_validationStatus == 'signup_required' || _needsProfileCompletion)
                                      ? 'Complete Profile' 
                                      : 'Make Payment',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                    // Incomplete Profile Card
                    FutureBuilder<bool>(
                      future: _isPaymentRequired(),
                      builder: (context, paymentSnapshot) {
                        final isPaymentRequired = paymentSnapshot.data ?? false;
                        final hasMissingFields = (_currentUser?.missingProfileFields.isNotEmpty ?? false);
                        
                        if (hasMissingFields || isPaymentRequired) {
                          return _buildIncompleteProfileCard(isDark);
                        }
                        return const SizedBox.shrink();
                      },
                    ),

                    // Welcome Alert Card
                    if (_showWelcomeAlert)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        child: Card(
                          elevation: 8,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(20),
                              gradient: LinearGradient(colors: [AppColors.primary, AppColors.primaryLight], begin: Alignment.topLeft, end: Alignment.bottomRight),
                              boxShadow: [BoxShadow(color: AppColors.primary.withOpacity(0.15), blurRadius: 24, offset: Offset(0, 8))],
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(24),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      // You can use a Lottie animation here if you want!
                                      Icon(Icons.celebration, color: AppColors.black, size: 32),
                                      const SizedBox(width: 12),
                                      Text(
                                        'Welcome!',
                                        style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.primaryDark),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 14),
                                  Text(
                                    'Your first week is free. After that, you\'ll pay R450 per week. You\'ll receive a reminder to pay.',
                                    style: TextStyle(fontSize: 16, color: AppColors.textDark.withOpacity(0.85), fontWeight: FontWeight.w500),
                                  ),
                                  const SizedBox(height: 24),
                                  Align(
                                    alignment: Alignment.centerRight,
                                    child: ElevatedButton(
                                      onPressed: _dismissWelcomeAlert,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppColors.black,
                                        foregroundColor: Colors.white,
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                                        elevation: 0,
                                      ),
                                      child: const Text('OK, got it', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),

                    // Status Card
                    FadeTransition(
                      opacity: _fadeAnimation,
                      child: SlideTransition(
                        position: _slideAnimation,
                        child: _StatusCard(isOnline: _isOnline, address: _currentAddress, isLoading: _isLoading, onRefresh: _getCurrentLocation, onToggle: _toggleOnlineStatus, isDark: isDark),
                      ),
                    ),

                    const SizedBox(height: 30),

                    // Quick Actions
                    FadeTransition(
                      opacity: _fadeAnimation,
                      child: SlideTransition(
                        position: _slideAnimation,
                        child: _QuickActionsSection(
                          onViewRequests: _viewRideRequests,
                          onViewEarnings: () {
                            Navigator.of(context).push(MaterialPageRoute(builder: (_) => const EarningsScreen()));
                          },
                          isDark: isDark,
                        ),
                      ),
                    ),

                    const SizedBox(height: 30),

                    // Earnings Section
                    FadeTransition(
                      opacity: _fadeAnimation,
                      child: SlideTransition(
                        position: _slideAnimation,
                        child: _EarningsSection(isDark: isDark, todayEarnings: todayEarnings, ridesCompleted: ridesCompleted),
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
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotificationIcon(BuildContext context) {
    final authService = Provider.of<AuthService>(context, listen: false);
    final user = authService.currentUser;

    return StreamBuilder<List<NotificationModel>>(
      stream: user != null ? DatabaseService().getUserNotifications(user.uid) : Stream.value([]),
      builder: (context, snapshot) {
        final notifications = snapshot.data ?? [];
        final unreadCount = notifications.where((n) => !n.isRead).length;

        return Badge(
          isLabelVisible: unreadCount > 0,
          label: Text(unreadCount.toString()),
          child: IconButton(
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () {
              Navigator.of(context).push(MaterialPageRoute(builder: (context) => const NotificationScreen()));
            },
          ),
        );
      },
    );
  }

  Widget _buildProfileAvatar() {
    final user = Provider.of<AuthService>(context).userModel;
    final profileImageUrl = user?.profileImageUrl;

    if (profileImageUrl != null && profileImageUrl.isNotEmpty) {
      return CircleAvatar(radius: 24, backgroundColor: Colors.grey[300], backgroundImage: NetworkImage(profileImageUrl));
    } else if (user != null && user.isDriver) {
      // Try to fetch from drivers collection if not present in users
      return FutureBuilder<String?>(
        future: DatabaseService().getDriverProfileImage(user.uid),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const CircleAvatar(
              radius: 24,
              backgroundColor: Colors.grey,
              child: Icon(Icons.person, size: 28, color: Colors.white),
            );
          }
          final driverImage = snapshot.data;
          if (driverImage != null && driverImage.isNotEmpty) {
            return CircleAvatar(radius: 24, backgroundColor: Colors.grey[300], backgroundImage: NetworkImage(driverImage));
          }
          return const CircleAvatar(
            radius: 24,
            backgroundColor: Colors.grey,
            child: Icon(Icons.person, size: 28, color: Colors.white),
          );
        },
      );
    } else {
      return const CircleAvatar(
        radius: 24,
        backgroundColor: Colors.grey,
        child: Icon(Icons.person, size: 28, color: Colors.white),
      );
    }
  }

  Widget _buildIncompleteProfileCard(bool isDark) {
    return FutureBuilder<bool>(
      future: _isPaymentRequired(),
      builder: (context, paymentSnapshot) {
        final isPaymentRequired = paymentSnapshot.data ?? false;
        final missingFields = _currentUser?.missingProfileFields ?? [];
        final hasOtherMissingFields = missingFields.isNotEmpty;
        
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: Card(
            color: AppColors.warning.withOpacity(0.15),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: AppColors.warning, width: 1.5),
            ),
            elevation: 0,
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.warning_amber_rounded, color: AppColors.warning, size: 28),
                      const SizedBox(width: 12),
                      const Text('Profile Incomplete', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text('Please complete your profile to get approved. You are missing the following:', style: TextStyle(fontSize: 14, color: AppColors.getTextSecondaryColor(isDark))),
                  const SizedBox(height: 12),
                  // Show other missing fields
                  ...missingFields.map(
                    (field) => Padding(
                      padding: const EdgeInsets.only(left: 8.0, bottom: 4.0),
                      child: Row(
                        children: [
                          Icon(Icons.close, color: AppColors.error, size: 16),
                          const SizedBox(width: 8),
                          Text(field, style: const TextStyle(fontWeight: FontWeight.w500)),
                        ],
                      ),
                    ),
                  ),
                  // Show payment requirement in red if only payment is missing
                  if (isPaymentRequired && !hasOtherMissingFields)
                    Padding(
                      padding: const EdgeInsets.only(left: 8.0, bottom: 4.0),
                      child: Row(
                        children: [
                          Icon(Icons.close, color: AppColors.error, size: 16),
                          const SizedBox(width: 8),
                          Text('Payment Required', style: const TextStyle(fontWeight: FontWeight.w500, color: AppColors.error)),
                        ],
                      ),
                    ),
                  // Show payment requirement in red if other fields are also missing
                  if (isPaymentRequired && hasOtherMissingFields)
                    Padding(
                      padding: const EdgeInsets.only(left: 8.0, bottom: 4.0),
                      child: Row(
                        children: [
                          Icon(Icons.close, color: AppColors.error, size: 16),
                          const SizedBox(width: 8),
                          Text('Payment Required', style: const TextStyle(fontWeight: FontWeight.w500, color: AppColors.error)),
                        ],
                      ),
                    ),
                  const SizedBox(height: 20),
                  CustomButton(
                    text: isPaymentRequired && !hasOtherMissingFields ? 'Complete Payment' : 'Complete Your Profile',
                    onPressed: () {
                      if (isPaymentRequired && !hasOtherMissingFields) {
                        Navigator.of(context).push(MaterialPageRoute(
                          builder: (context) => PaymentScreen(
                            amount: 150.0,
                            email: _currentUser?.email ?? '',
                            onPaymentSuccess: () {
                              Navigator.of(context).pop();
                              setState(() {
                                // Refresh the UI after successful payment
                              });
                            },
                          ),
                        ));
                      } else {
                        Navigator.of(context).push(MaterialPageRoute(builder: (context) => const DriverSignupScreen()));
                      }
                    },
                    icon: Icons.arrow_forward,
                    color: AppColors.warning,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildPaymentRequiredCard(bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Card(
        color: AppColors.error.withOpacity(0.15),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: AppColors.error, width: 1.5),
        ),
        elevation: 0,
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.payment, color: AppColors.error, size: 28),
                  const SizedBox(width: 12),
                  const Text('Payment Required', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 16),
              Text('You need to complete payment to start earning as a driver. The registration fee is R150.', style: TextStyle(fontSize: 14, color: AppColors.getTextSecondaryColor(isDark))),
              const SizedBox(height: 20),
              CustomButton(
                text: 'Pay Registration Fee',
                onPressed: () {
                  Navigator.of(context).push(MaterialPageRoute(
                    builder: (context) => PaymentScreen(
                      amount: 150.00,
                      email: _currentUser?.email ?? '',
                      onPaymentSuccess: () {
                        Navigator.of(context).pop(); // Close payment screen
                        // Refresh the page to hide the payment card
                        setState(() {});
                      },
                    ),
                  ));
                },
                icon: Icons.payment,
                color: AppColors.error,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuickActionsSection(bool isDark) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 1.1,
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      children: [
        Builder(
          builder: (context) {
            final user = Provider.of<AuthService>(context).userModel;
            final isApproved = user?.isApproved == true;
            return _ActionCard(
              title: 'Ride Requests', 
              subtitle: isApproved ? 'View available rides' : 'Awaiting approval', 
              icon: Icons.list_alt, 
              color: isApproved ? AppColors.primary : Colors.grey, 
              onTap: _viewRideRequests, 
              isDark: isDark,
              isEnabled: isApproved,
              gradient: isApproved 
                ? LinearGradient(
                    colors: [AppColors.primary.withOpacity(0.1), AppColors.primary.withOpacity(0.05)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : null,
            );
          },
        ),
        _ActionCard(
          title: 'Earnings',
          subtitle: 'View your earnings',
          icon: Icons.attach_money,
          color: AppColors.success,
          onTap: () {
            Navigator.of(context).push(MaterialPageRoute(builder: (_) => const EarningsScreen()));
          },
          isDark: isDark,
          isEnabled: true,
          gradient: LinearGradient(
            colors: [AppColors.success.withOpacity(0.1), AppColors.success.withOpacity(0.05)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
      ],
    );
  }

  Widget _buildRecentRidesSection(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Recent Rides', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            TextButton(
              onPressed: () {
                Navigator.of(context).push(MaterialPageRoute(builder: (_) => driver_history.RideHistoryScreen()));
              },
              child: const Text('View All'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        _recentRides.isEmpty
            ? Center(
                child: Column(
                  children: [
                    Icon(Icons.history, size: 60, color: AppColors.primary.withOpacity(0.18)),
                    const SizedBox(height: 12),
                    Text('No recent rides', style: TextStyle(fontSize: 16, color: AppColors.getTextSecondaryColor(isDark))),
                  ],
                ),
              )
            : Column(
                children: _recentRides.map((ride) {
                  final status = ride['status'];
                  final isCompleted = status == 2;
                  final isCancelled = status == 3;
                  final fare = isCompleted ? ride['fare'] : 0.0;
                  final date = ride['date'] != null ? DateTime.fromMillisecondsSinceEpoch(ride['date']) : null;
                  return Card(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 2,
                    margin: const EdgeInsets.only(bottom: 10),
                    child: ListTile(
                      leading: Icon(
                        isCompleted
                            ? Icons.check_circle
                            : isCancelled
                            ? Icons.cancel
                            : Icons.directions_car,
                        color: isCompleted
                            ? Colors.green
                            : isCancelled
                            ? Colors.red
                            : AppColors.primary,
                      ),
                      title: Text('R ${fare.toStringAsFixed(2)}'),
                      subtitle: Text(date != null ? '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}' : 'No date'),
                      trailing: Text(
                        isCompleted
                            ? 'Completed'
                            : isCancelled
                            ? 'Cancelled'
                            : 'Accepted',
                        style: TextStyle(
                          color: isCompleted
                              ? Colors.green
                              : isCancelled
                              ? Colors.red
                              : AppColors.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
      ],
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

class _OnlineStatusToggle extends StatefulWidget {
  final bool isOnline;
  final VoidCallback onToggle;
  final bool isDark;

  const _OnlineStatusToggle({required this.isOnline, required this.onToggle, required this.isDark});

  @override
  State<_OnlineStatusToggle> createState() => _OnlineStatusToggleState();
}

class _OnlineStatusToggleState extends State<_OnlineStatusToggle> with SingleTickerProviderStateMixin {
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
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: widget.isOnline ? AppColors.success : AppColors.getCardColor(widget.isDark),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: widget.isOnline ? AppColors.success : AppColors.getBorderColor(widget.isDark), width: 1),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(color: widget.isOnline ? AppColors.white : AppColors.getTextHintColor(widget.isDark), shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    widget.isOnline ? 'Online' : 'Offline',
                    style: TextStyle(color: widget.isOnline ? AppColors.white : AppColors.getTextSecondaryColor(widget.isDark), fontSize: 14, fontWeight: FontWeight.w600),
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

class _StatusCard extends StatelessWidget {
  final bool isOnline;
  final String address;
  final bool isLoading;
  final VoidCallback onRefresh;
  final VoidCallback onToggle;
  final bool isDark;

  const _StatusCard({
    required this.isOnline,
    required this.address,
    required this.isLoading,
    required this.onRefresh,
    required this.onToggle,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isOnline ? AppColors.success : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              // Toggle button container with tooltip
              Stack(
                clipBehavior: Clip.none,
                children: [
                  GestureDetector(
                    onTap: onToggle,
                    child: Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: isOnline ? Colors.white.withOpacity(0.2) : AppColors.black.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          // Background circle
                          Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isOnline ? Colors.white : AppColors.black.withOpacity(0.1),
                            ),
                          ),
                          // Inner circle (only visible when online)
                          if (isOnline)
                            Container(
                              width: 16,
                              height: 16,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: AppColors.success,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  // Tooltip with arrow
                  if (!isOnline)
                    Positioned(
                      top: -60,
                      left: -20,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.9),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.arrow_downward,
                              color: Colors.white,
                              size: 16,
                            ),
                            const SizedBox(width: 4),
                            const Text(
                              'Click here to go online',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  // Arrow pointing to button
                  if (!isOnline)
                    Positioned(
                      top: -15,
                      left: 15,
                      child: CustomPaint(
                        size: const Size(20, 15),
                        painter: ArrowPainter(),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isOnline ? 'You\'re Online' : 'You\'re Offline',
                      style: TextStyle(
                        color: isOnline ? Colors.white : AppColors.black,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      isOnline ? 'Ready to accept rides' : 'Go online to start earning',
                      style: TextStyle(
                        color: isOnline ? Colors.white.withOpacity(0.9) : AppColors.black.withOpacity(0.7),
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Location
          Row(
            children: [
              Icon(Icons.my_location, color: AppColors.black, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  address.isNotEmpty ? address : 'Location not available',
                  style: const TextStyle(color: AppColors.black, fontSize: 14, fontWeight: FontWeight.w500),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (isLoading)
                const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: AppColors.black, strokeWidth: 2))
              else
                IconButton(
                  onPressed: onRefresh,
                  icon: const Icon(Icons.refresh, color: AppColors.black, size: 20),
                  tooltip: 'Refresh Location',
                ),
            ],
          ),
        ],
      ),
    );
  }
}

// Custom painter for the arrow
class ArrowPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black.withOpacity(0.9)
      ..style = PaintingStyle.fill;

    final path = Path()
      ..moveTo(size.width / 2, size.height)
      ..lineTo(0, 0)
      ..lineTo(size.width, 0)
      ..close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _QuickActionsSection extends StatelessWidget {
  final VoidCallback onViewRequests;
  final VoidCallback onViewEarnings;
  final bool isDark;

  const _QuickActionsSection({required this.onViewRequests, required this.onViewEarnings, required this.isDark});

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
              child: _ActionCard(title: 'Ride Requests', subtitle: 'View available rides', icon: Icons.list_alt, color: AppColors.primary, onTap: onViewRequests, isDark: isDark),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _ActionCard(title: 'Earnings', subtitle: 'View your earnings', icon: Icons.attach_money, color: AppColors.success, onTap: onViewEarnings, isDark: isDark),
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
  final bool isEnabled;
  final LinearGradient? gradient;

  const _ActionCard({
    required this.title, 
    required this.subtitle, 
    required this.icon, 
    required this.color, 
    required this.onTap, 
    required this.isDark,
    this.isEnabled = true,
    this.gradient,
  });

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
      onTap: widget.isEnabled ? widget.onTap : null,
      onTapDown: widget.isEnabled ? (_) => _controller.forward() : null,
      onTapUp: widget.isEnabled ? (_) => _controller.reverse() : null,
      onTapCancel: widget.isEnabled ? () => _controller.reverse() : null,
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: widget.isEnabled ? _scaleAnimation.value : 1.0,
            child: Container(
              decoration: BoxDecoration(
                gradient: widget.gradient ?? LinearGradient(
                  colors: widget.isEnabled 
                    ? [
                        AppColors.getCardColor(widget.isDark),
                        AppColors.getCardColor(widget.isDark).withOpacity(0.8),
                      ]
                    : [
                        Colors.grey.shade100,
                        Colors.grey.shade50,
                      ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: widget.isEnabled 
                    ? widget.color.withOpacity(0.2)
                    : Colors.grey.withOpacity(0.2), 
                  width: 1.5
                ),
                boxShadow: [
                  BoxShadow(
                    color: widget.isEnabled 
                      ? widget.color.withOpacity(0.1)
                      : Colors.grey.withOpacity(0.1),
                    blurRadius: 15,
                    offset: const Offset(0, 8),
                    spreadRadius: 0,
                  ),
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 5,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Stack(
                  children: [
                    // Background pattern for enabled cards
                    if (widget.isEnabled)
                      Positioned(
                        top: -20,
                        right: -20,
                        child: Container(
                          width: 60,
                          height: 60,
                          decoration: BoxDecoration(
                            color: widget.color.withOpacity(0.05),
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    
                    // Main content
                    Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Icon container with modern design
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              gradient: widget.isEnabled 
                                ? LinearGradient(
                                    colors: [
                                      widget.color.withOpacity(0.15),
                                      widget.color.withOpacity(0.05),
                                    ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  )
                                : LinearGradient(
                                    colors: [
                                      Colors.grey.withOpacity(0.1),
                                      Colors.grey.withOpacity(0.05),
                                    ],
                                  ),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: widget.isEnabled 
                                  ? widget.color.withOpacity(0.2)
                                  : Colors.grey.withOpacity(0.2),
                                width: 1,
                              ),
                            ),
                            child: Icon(
                              widget.icon, 
                              color: widget.isEnabled ? widget.color : Colors.grey.shade400, 
                              size: 32,
                            ),
                          ),
                          const SizedBox(height: 16),
                          
                          // Title with modern typography
                          Text(
                            widget.title,
                            style: TextStyle(
                              color: widget.isEnabled 
                                ? AppColors.getTextPrimaryColor(widget.isDark) 
                                : Colors.grey.shade500, 
                              fontSize: 18, 
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.5,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 6),
                          
                          // Subtitle with refined styling
                          Text(
                            widget.subtitle,
                            style: TextStyle(
                              color: widget.isEnabled 
                                ? AppColors.getTextSecondaryColor(widget.isDark) 
                                : Colors.grey.shade400, 
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              height: 1.3,
                            ),
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          
                          // Status indicator for disabled cards
                          if (!widget.isEnabled) ...[
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.orange.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: Colors.orange.withOpacity(0.3),
                                  width: 1,
                                ),
                              ),
                              child: Text(
                                'Pending',
                                style: TextStyle(
                                  color: Colors.orange.shade700,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _EarningsSection extends StatelessWidget {
  final bool isDark;
  final double todayEarnings;
  final int ridesCompleted;

  const _EarningsSection({required this.isDark, required this.todayEarnings, required this.ridesCompleted});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Today\'s Earnings',
          style: TextStyle(color: AppColors.getTextPrimaryColor(isDark), fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: AppColors.successGradient,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [BoxShadow(color: AppColors.success.withOpacity(0.3), blurRadius: 15, offset: const Offset(0, 8))],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: AppColors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.attach_money, color: AppColors.white, size: 32),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'R ${todayEarnings.toStringAsFixed(2)}',
                        style: const TextStyle(color: AppColors.white, fontSize: 28, fontWeight: FontWeight.bold),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(height: 4),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        '$ridesCompleted rides completed',
                        style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 14),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
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
              Text('Your completed rides will appear here', style: TextStyle(color: AppColors.getTextHintColor(isDark), fontSize: 14)),
            ],
          ),
        ),
      ],
    );
  }
}
