import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:gibelbibela/screens/auth/login_screen.dart';
import 'package:provider/provider.dart';

import '../../constants/app_colors.dart';
import '../../providers/theme_provider.dart';
import '../../services/auth_service.dart';
import '../../services/database_service.dart';
import '../../widgets/common/modern_loading_indicator.dart';
import '../auth/email_verification_screen.dart';
import '../auth/passenger_registration_screen.dart';
import '../home/driver/driver_home_screen.dart';
import '../auth/driver_signup_screen.dart';
import '../home/passenger/passenger_home_screen.dart';
import '../onboarding/onboarding_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with TickerProviderStateMixin {
  late AnimationController _logoController;
  late AnimationController _textController;
  late AnimationController _fadeController;

  late Animation<double> _logoScaleAnimation;
  late Animation<double> _logoRotationAnimation;
  late Animation<double> _textSlideAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _startAnimations();
  }

  void _initializeAnimations() {
    // Logo animations
    _logoController = AnimationController(duration: const Duration(milliseconds: 2000), vsync: this);

    _logoScaleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _logoController,
        curve: const Interval(0.0, 0.6, curve: Curves.elasticOut),
      ),
    );

    _logoRotationAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _logoController,
        curve: const Interval(0.0, 0.8, curve: Curves.easeInOut),
      ),
    );

    // Text animation
    _textController = AnimationController(duration: const Duration(milliseconds: 1500), vsync: this);

    _textSlideAnimation = Tween<double>(begin: 50.0, end: 0.0).animate(CurvedAnimation(parent: _textController, curve: Curves.easeOutCubic));

    // Fade animation
    _fadeController = AnimationController(duration: const Duration(milliseconds: 1000), vsync: this);

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut));
  }

  void _startAnimations() async {
    // Start logo animation
    _logoController.forward();

    // Start text animation after logo starts
    await Future.delayed(const Duration(milliseconds: 800));
    _textController.forward();

    // Start fade animation
    await Future.delayed(const Duration(milliseconds: 500));
    _fadeController.forward();

    // Navigate after animations complete
    await Future.delayed(const Duration(milliseconds: 2000));
    _navigateToNextScreen();
  }

  Future<void> _navigateToNextScreen() async {
    if (!mounted) return;

    final authService = Provider.of<AuthService>(context, listen: false);
    final user = authService.currentUser;

    if (user == null) {
      // No user logged in, check for onboarding status
      final hasSeenOnboarding = await _checkOnboardingStatus();
      if (!mounted) return;

      final destination = hasSeenOnboarding ? const LoginScreen() : const OnboardingScreen();
      Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (context) => destination));
    } else {
      // User is logged in, but we need to check their verification and registration status

      // First, check if email is verified
      await user.reload(); // Refresh user data
      final refreshedUser = authService.currentUser;

      if (refreshedUser == null || !refreshedUser.emailVerified) {
        // Email not verified, send to verification screen
        // We need to determine if they're a driver or passenger from their profile
        final userModel = await Provider.of<DatabaseService>(context, listen: false).getUserById(user.uid);
        final isDriver = userModel?.isDriver ?? false;

        if (!mounted) return;
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => EmailVerificationScreen(user: user, isDriver: isDriver),
          ),
        );
        return;
      }

      // Email is verified, now check registration completion
      final userModel = await Provider.of<DatabaseService>(context, listen: false).getUserById(user.uid);

      if (!mounted) return;

      if (userModel == null) {
        // User is authenticated but has no profile data, this is an error state.
        // Send them to the login screen to be safe.
        Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (context) => const LoginScreen()));
        return;
      }

      // Check if registration is complete based on user type
      if (userModel.isDriver) {
        // For drivers, check if they have completed driver registration
        final databaseService = Provider.of<DatabaseService>(context, listen: false);
        final driverModel = await databaseService.getDriverByUserId(user.uid);
        
        // If no driver profile exists or required fields are missing, send to driver registration
        if (driverModel == null || 
            driverModel.idNumber.isEmpty || 
            driverModel.documents.isEmpty ||
            driverModel.vehicleType == null ||
            driverModel.vehicleModel == null ||
            driverModel.vehicleColor == null ||
            driverModel.licensePlate == null ||
            driverModel.towns.isEmpty ||
            !driverModel.isApproved) {
          print('🚗 Driver registration status:');
          print('- Driver model exists: ${driverModel != null}');
          print('- ID Number: ${driverModel?.idNumber.isNotEmpty}');
          print('- Documents: ${driverModel?.documents.isNotEmpty}');
          print('- Vehicle Type: ${driverModel?.vehicleType != null}');
          print('- Vehicle Model: ${driverModel?.vehicleModel != null}');
          print('- Vehicle Color: ${driverModel?.vehicleColor != null}');
          print('- License Plate: ${driverModel?.licensePlate != null}');
          print('- Towns: ${driverModel?.towns.isNotEmpty}');
          print('- Approved: ${driverModel?.isApproved}');
          print('🚗 Driver registration incomplete, redirecting to registration...');
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (context) => const DriverSignupScreen(),
            ),
          );
        } else {
          // Driver registration is complete, go to home screen
          print('✅ Driver registration complete, going to home screen...');
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (context) => const DriverHomeScreen(),
            ),
          );
        }
      } else {
        // For passengers, check if they have completed registration
        // Check for the isRegistered flag that was set in passenger registration
        try {
          final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
          final userData = userDoc.data();
          final isRegistrationComplete = userData?['isRegistered'] == true;

          if (!isRegistrationComplete) {
            // Registration not complete, send to passenger registration
            Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (context) => const PassengerRegistrationScreen()));
          } else {
            // Registration complete, go to home
            Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (context) => const PassengerHomeScreen()));
          }
        } catch (e) {
          // Error checking registration status, send to registration to be safe
          Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (context) => const PassengerRegistrationScreen()));
        }
      }
    }
  }

  Future<bool> _checkOnboardingStatus() async {
    // In a real app, you'd check SharedPreferences or similar
    // For now, we'll assume they haven't seen it
    return false;
  }

  @override
  void dispose() {
    _logoController.dispose();
    _textController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;

    return Scaffold(
      backgroundColor: AppColors.getBackgroundColor(isDark),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [AppColors.getBackgroundColor(isDark), AppColors.primary.withOpacity(0.1)]),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Top section with logo and text
              Expanded(
                flex: 3,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Logo with animations
                    AnimatedBuilder(
                      animation: Listenable.merge([_logoScaleAnimation, _logoRotationAnimation]),
                      builder: (context, child) {
                        return Transform.scale(
                          scale: _logoScaleAnimation.value,
                          child: Transform.rotate(
                            angle: _logoRotationAnimation.value * 2 * 3.14159 * 0.1,
                            child: Container(
                              width: 120,
                              height: 120,
                              decoration: BoxDecoration(
                                gradient: AppColors.primaryGradient,
                                borderRadius: BorderRadius.circular(30),
                                boxShadow: [BoxShadow(color: AppColors.primary.withOpacity(0.3), blurRadius: 30, spreadRadius: 5)],
                              ),
                              child: const Icon(Icons.local_taxi, color: AppColors.black, size: 60),
                            ),
                          ),
                        );
                      },
                    ),

                    const SizedBox(height: 40),

                    // App name with slide animation
                    AnimatedBuilder(
                      animation: _textSlideAnimation,
                      builder: (context, child) {
                        return Transform.translate(
                          offset: Offset(0, _textSlideAnimation.value),
                          child: Column(
                            children: [
                              Text(
                                'RideApp',
                                style: TextStyle(color: AppColors.getTextPrimaryColor(isDark), fontSize: 42, fontWeight: FontWeight.bold, letterSpacing: 2),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Asambe',
                                style: TextStyle(color: AppColors.getTextPrimaryColor(isDark), fontSize: 20, fontWeight: FontWeight.w500, letterSpacing: 1),
                              ),
                            ],
                          ),
                        );
                      },
                    ),

                    const SizedBox(height: 8),

                    // Tagline with fade animation
                    AnimatedBuilder(
                      animation: _fadeAnimation,
                      builder: (context, child) {
                        return Opacity(
                          opacity: _fadeAnimation.value,
                          child: Text(
                            'Your journey, our priority',
                            style: TextStyle(color: AppColors.getTextSecondaryColor(isDark), fontSize: 16, fontWeight: FontWeight.w500),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),

              // Bottom section with loading indicator
              Expanded(
                flex: 1,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const ModernLoadingIndicator(message: 'Loading...', size: 40),
                    const SizedBox(height: 20),
                    Text('Version 1.0.0', style: TextStyle(color: AppColors.getTextHintColor(isDark), fontSize: 12)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
