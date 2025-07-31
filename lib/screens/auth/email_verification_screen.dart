import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:gibelbibela/screens/auth/signup_screen.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../constants/app_colors.dart';
import '../../widgets/common/modern_alert_dialog.dart';
import 'driver_signup_screen.dart';
import 'passenger_registration_screen.dart';

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
  bool _showLeaveWarning = false;
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
    // Check if already verified when screen loads
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
    _pollTimer?.cancel(); // Cancel any existing timer
    _pollTimer = Timer.periodic(const Duration(seconds: 3), (_) async {
      if (_isNavigating) return; // Prevent multiple navigation attempts

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
    if (_isNavigating) return; // Prevent multiple navigation attempts

    _isNavigating = true;
    _pollTimer?.cancel();

    if (mounted) {
      setState(() => _isVerified = true);

      // Add a small delay to show the success message
      await Future.delayed(const Duration(milliseconds: 1500));

      if (!mounted) return;

      try {
        if (_isDriver) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (_) => const DriverSignupScreen(),
              settings: const RouteSettings(name: '/driver_signup'),
            ),
          );
        } else {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (_) => const PassengerRegistrationScreen(),
              settings: const RouteSettings(name: '/passenger_registration'),
            ),
          );
        }
      } catch (e) {
        print('Navigation error: $e');
        if (mounted) {
          _isNavigating = false;
          setState(() => _isVerified = false);
        }
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
        final refreshedUser = _auth.currentUser;

        if (refreshedUser != null && refreshedUser.emailVerified) {
          _handleVerificationSuccess();
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Email not verified yet. Please check your inbox and try again.'),
                duration: Duration(seconds: 3),
              ),
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error checking verification: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _contactSupport() async {
    final message = Uri.encodeComponent('My sign up is not working.');
    final whatsappUrl = 'https://wa.me/27728965810?text=$message';

    try {
      if (await canLaunch(whatsappUrl)) {
        await launch(whatsappUrl);
      } else {
        throw 'Could not launch WhatsApp';
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not open WhatsApp. Please contact support manually.'),
            duration: Duration(seconds: 3),
          ),
        );
      }
    }
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
      final currentUser = _auth.currentUser;
      if (currentUser != null && !currentUser.emailVerified) {
        await currentUser.sendEmailVerification();

        if (mounted) {
          showDialog(
            context: context,
            builder: (context) => ModernAlertDialog(
              title: 'Verification Email Sent',
              message: 'A new verification link has been sent to your email address.',
              confirmText: 'OK',
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => ModernAlertDialog(
            title: 'Error',
            message: 'Failed to resend verification email. Please try again later.',
            confirmText: 'OK',
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<bool> _onWillPop() async {
    if (_isNavigating) return false;

    showDialog(
      context: context,
      builder: (context) => ModernAlertDialog(
        title: 'Please Wait',
        message: 'Please verify your email first. This screen will automatically redirect you once verification is complete.',
        confirmText: 'OK',
      ),
    );
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currentUser = _auth.currentUser;

    if (currentUser == null) {
      return Scaffold(
        backgroundColor: AppColors.getBackgroundColor(isDark),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.warning, color: Colors.orange, size: 80),
                const SizedBox(height: 32),
                const Text(
                  'Session Expired',
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Please log in again to complete verification.',
                  style: TextStyle(fontSize: 16),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.of(context).pushReplacementNamed('/login');
                  },
                  icon: const Icon(Icons.login),
                  label: const Text('Go to Login'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        backgroundColor: AppColors.getBackgroundColor(isDark),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  _isVerified ? Icons.check_circle : Icons.email,
                  color: _isVerified ? Colors.green : AppColors.primary,
                  size: 80,
                ),
                const SizedBox(height: 32),
                Text(
                  _isVerified ? 'Email Verified!' : 'Verify Your Email',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: _isVerified ? Colors.green : null,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Text(
                  _isVerified ? 'Your email has been verified successfully. Redirecting...' : 'A verification link has been sent to ${currentUser.email}. Please check your email and click the verification link.',
                  style: const TextStyle(fontSize: 16),
                  textAlign: TextAlign.center,
                ),
                if (!_isVerified) ...[
                  const SizedBox(height: 12),
                  TextButton.icon(
                    icon: const Icon(Icons.arrow_back),
                    label: const Text('Go back to signup and edit details'),
                    onPressed: _isLoading
                        ? null
                        : () async {
                            setState(() => _isLoading = true);
                            try {
                              await _auth.signOut();
                              if (!mounted) return;
                              Navigator.of(context).pushAndRemoveUntil(
                                MaterialPageRoute(builder: (_) => const SignupScreen()),
                                (route) => false,
                              );
                            } catch (e) {
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Error: ${e.toString()}')),
                                );
                              }
                            } finally {
                              if (mounted) setState(() => _isLoading = false);
                            }
                          },
                    style: TextButton.styleFrom(foregroundColor: Colors.red),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'This page will automatically redirect you once your email is verified. You can also manually check by tapping "Check Again" below.',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.getTextSecondaryColor(isDark),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),
                  ElevatedButton.icon(
                    onPressed: _isLoading ? null : _resendEmail,
                    icon: _isLoading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.refresh),
                    label: const Text('Resend Email'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: _isLoading ? null : _manualCheck,
                    icon: _isLoading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.check_circle_outline),
                    label: const Text('Check Again'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: _contactSupport,
                    child: const Text('Contact Support via WhatsApp'),
                    style: TextButton.styleFrom(foregroundColor: AppColors.primary),
                  ),
                ] else ...[
                  const SizedBox(height: 24),
                  const CircularProgressIndicator(),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
