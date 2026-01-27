// lib/screens/auth/email_verification_screen.dart
import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:gibelbibela/screens/auth/signup_screen.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../services/database_service.dart';
import '../../constants/app_colors.dart';
import '../../widgets/common/modern_alert_dialog.dart';
import '../../widgets/common/custom_button.dart';
import 'driver_signup_screen.dart';
import 'passenger_registration_screen.dart';
import 'no_car_application_screen.dart';
import 'owner_application_screen.dart';

class EmailVerificationScreen extends StatefulWidget {
  final User user;
  final bool isDriver;
  const EmailVerificationScreen({Key? key, required this.user, required this.isDriver}) : super(key: key);

  @override
  State<EmailVerificationScreen> createState() => _EmailVerificationScreenState();
}

class _EmailVerificationScreenState extends State<EmailVerificationScreen> {
  bool _isVerified = false;
  bool _isLoading = false;
  bool _isNavigating = false;
  late final FirebaseAuth _auth;
  late final bool _isDriver;
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    _auth = FirebaseAuth.instance;
    _isDriver = widget.isDriver;
    _checkInitialVerificationStatus();
  }

  void _checkInitialVerificationStatus() async {
    final currentUser = _auth.currentUser;
    if (currentUser != null) {
      await currentUser.reload();
      final refreshedUser = _auth.currentUser;
      if (refreshedUser != null && refreshedUser.emailVerified) {
        _handleVerificationSuccess();
      } else {
        _startPolling();
      }
    }
  }

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 3), (_) async {
      if (_isNavigating) return;
      try {
        final currentUser = _auth.currentUser;
        if (currentUser != null) {
          await currentUser.reload();
          final refreshedUser = _auth.currentUser;
          if (refreshedUser != null && refreshedUser.emailVerified) {
            _handleVerificationSuccess();
          }
        }
      } catch (e) {
        print('Error checking verification status: $e');
      }
    });
  }

  void _handleVerificationSuccess() async {
    if (_isNavigating) return;
    _isNavigating = true;
    _pollTimer?.cancel();

    if (mounted) {
      setState(() => _isVerified = true);
      await Future.delayed(const Duration(milliseconds: 1500));
      if (!mounted) return;

      try {
        final databaseService = Provider.of<DatabaseService>(context, listen: false);
        final userModel = await databaseService.getUserById(widget.user.uid);
        
        if (userModel != null) {
          if (userModel.userRole == 'driver_no_car') {
            Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => NoCarApplicationScreen(user: widget.user, userModel: userModel)));
          } else if (userModel.userRole == 'car_owner') {
            Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => OwnerApplicationScreen(user: widget.user, userModel: userModel)));
          } else if (userModel.isDriver) {
            Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const DriverSignupScreen()));
          } else {
            Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const PassengerRegistrationScreen()));
          }
        } else {
          Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => _isDriver ? const DriverSignupScreen() : const PassengerRegistrationScreen()));
        }
      } catch (e) {
        _isNavigating = false;
        setState(() => _isVerified = false);
      }
    }
  }

  void _manualCheck() async {
    if (_isNavigating) return;
    setState(() => _isLoading = true);
    try {
      final currentUser = _auth.currentUser;
      if (currentUser != null) {
        await currentUser.reload();
        if (_auth.currentUser!.emailVerified) {
          _handleVerificationSuccess();
        } else {
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Email not verified yet.')));
        }
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _contactSupport() async {
    final whatsappUrl = 'https://wa.me/27728965810?text=${Uri.encodeComponent('My Gibela sign up is not working.')}';
    if (await canLaunchUrl(Uri.parse(whatsappUrl))) await launchUrl(Uri.parse(whatsappUrl));
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _resendEmail() async {
    if (_isLoading) return;
    setState(() => _isLoading = true);
    try {
      await _auth.currentUser?.sendEmailVerification();
      if (mounted) {
        showDialog(context: context, builder: (context) => const ModernAlertDialog(title: 'Email Sent', message: 'A new verification link has been sent.', confirmText: 'OK'));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currentUser = _auth.currentUser;

    if (currentUser == null) return const Scaffold(body: Center(child: Text('Session expired. Please log in.')));

    return Scaffold(
      backgroundColor: AppColors.getBackgroundColor(isDark),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(color: (_isVerified ? Colors.green : AppColors.primary).withOpacity(0.1), shape: BoxShape.circle),
                child: Icon(_isVerified ? Icons.check_circle_rounded : Icons.email_outlined, size: 80, color: _isVerified ? Colors.green : AppColors.primary),
              ),
              const SizedBox(height: 32),
              Text(_isVerified ? 'Email Verified!' : 'Verify Your Email', style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900, letterSpacing: -0.5)),
              const SizedBox(height: 16),
              Text(_isVerified ? 'Redirecting you to the next step...' : 'A verification link has been sent to ${currentUser.email}. Please check your inbox.', textAlign: TextAlign.center, style: const TextStyle(fontSize: 16, color: Colors.grey)),
              if (!_isVerified) ...[
                const SizedBox(height: 48),
                CustomButton(text: 'Resend Verification Email', onPressed: _isLoading ? null : _resendEmail, isFullWidth: true),
                const SizedBox(height: 12),
                CustomButton(text: 'I\'ve Verified, Check Again', onPressed: _isLoading ? null : _manualCheck, isFullWidth: true, isOutlined: true),
                const SizedBox(height: 24),
                TextButton(onPressed: _contactSupport, child: const Text('Contact Support via WhatsApp', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.primaryDark))),
                TextButton(onPressed: () => _auth.signOut().then((_) => Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const SignupScreen()))), child: const Text('Cancel and Try Again', style: TextStyle(color: Colors.red))),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
