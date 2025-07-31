import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../constants/app_colors.dart';
import '../../services/auth_service.dart';
import '../../services/location_service.dart';
import '../../services/notification_service.dart';
import '../../widgets/common/modern_alert_dialog.dart';

class PanicAlertScreen extends StatefulWidget {
  const PanicAlertScreen({super.key});

  @override
  State<PanicAlertScreen> createState() => _PanicAlertScreenState();
}

class _PanicAlertScreenState extends State<PanicAlertScreen> with TickerProviderStateMixin {
  int _countdown = 6;
  bool _isCountingDown = true;
  bool _isAlertSent = false;
  bool _isPasswordVerified = false;
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _pulseAnimation;
  final TextEditingController _passwordController = TextEditingController();
  Timer? _countdownTimer;
  Timer? _pulseTimer;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.1).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    
    _startCountdown();
    _startPulseAnimation();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _pulseTimer?.cancel();
    _animationController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _startCountdown() {
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _countdown--;
        });
        
        if (_countdown <= 0) {
          timer.cancel();
          _sendEmergencyAlert();
        }
      }
    });
  }

  void _startPulseAnimation() {
    _pulseTimer = Timer.periodic(const Duration(milliseconds: 800), (timer) {
      if (mounted && _isCountingDown) {
        _animationController.forward().then((_) {
          _animationController.reverse();
        });
      }
    });
  }

  Future<void> _sendEmergencyAlert() async {
    if (_isAlertSent) return;
    
    setState(() {
      _isAlertSent = true;
      _isCountingDown = false;
    });

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final user = authService.userModel;
      final locationService = Provider.of<LocationService>(context, listen: false);
      final notificationService = Provider.of<NotificationService>(context, listen: false);
      
      if (user != null) {
        // Get current location
        final position = await locationService.refreshCurrentLocation();
        
        // Get current ride details if any
        final currentRide = await _getCurrentRide(user.uid);
        
        // Create alert data
        final alertData = {
          'userId': user.uid,
          'userName': user.name,
          'userEmail': user.email,
          'timestamp': FieldValue.serverTimestamp(),
          'location': {
            'latitude': position?.latitude,
            'longitude': position?.longitude,
            'address': await locationService.getAddressFromCoordinates(
              position?.latitude ?? 0,
              position?.longitude ?? 0,
            ),
          },
          'rideDetails': currentRide,
          'message': 'EMERGENCY ALERT: User activated panic button',
          'status': 'active',
        };

        // Save to Firestore
        await FirebaseFirestore.instance
            .collection('alerts')
            .add(alertData);

        // Send to trusted contacts
        await _sendToTrustedContacts(alertData);
        
        // Send emergency notification
        await notificationService.sendEmergencyAlertNotification(
          userId: user.uid,
          userName: user.name,
          location: {
            'latitude': position?.latitude,
            'longitude': position?.longitude,
            'address': await locationService.getAddressFromCoordinates(
              position?.latitude ?? 0,
              position?.longitude ?? 0,
            ),
          },
          rideDetails: currentRide,
        );

        // Show success message
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Emergency alert sent to trusted contacts!'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error sending alert: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<Map<String, dynamic>?> _getCurrentRide(String userId) async {
    try {
      final ridesQuery = await FirebaseFirestore.instance
          .collection('rides')
          .where('userId', isEqualTo: userId)
          .where('status', whereIn: [1, 2]) // Active or in progress
          .orderBy('timestamp', descending: true)
          .limit(1)
          .get();

      if (ridesQuery.docs.isNotEmpty) {
        return ridesQuery.docs.first.data();
      }
    } catch (e) {
      print('Error getting current ride: $e');
    }
    return null;
  }

  Future<void> _sendToTrustedContacts(Map<String, dynamic> alertData) async {
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final user = authService.userModel;
      
      if (user != null) {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();

        if (userDoc.exists) {
          final userData = userDoc.data() as Map<String, dynamic>;
          final trustedContacts = userData['trustedContacts'] as List<dynamic>? ?? [];

          for (final contact in trustedContacts) {
            final contactEmail = contact['email']?.toString();
            if (contactEmail != null) {
              // Create notification for trusted contact
              await FirebaseFirestore.instance
                  .collection('notifications')
                  .add({
                'userId': contactEmail, // Using email as identifier
                'title': 'EMERGENCY ALERT',
                'body': '${user.name} has activated emergency panic alert!',
                'type': 'emergency',
                'alertData': alertData,
                'timestamp': FieldValue.serverTimestamp(),
                'isRead': false,
              });
            }
          }
        }
      }
    } catch (e) {
      print('Error sending to trusted contacts: $e');
    }
  }

  Future<void> _verifyPassword() async {
    final password = _passwordController.text.trim();
    
    if (password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your password')),
      );
      return;
    }

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        // Re-authenticate user
        final credential = EmailAuthProvider.credential(
          email: user.email!,
          password: password,
        );
        
        await user.reauthenticateWithCredential(credential);
        
        setState(() {
          _isPasswordVerified = true;
        });

        _countdownTimer?.cancel();
        _pulseTimer?.cancel();
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Password verified. Alert cancelled.'),
              backgroundColor: Colors.green,
            ),
          );
          
          // Navigate back
          Navigator.of(context).pop();
        }
      }
    } catch (e) {
      // Password is incorrect - continue countdown silently
      _passwordController.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Incorrect password. Alert will continue.'),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return WillPopScope(
      onWillPop: () async => false, // Prevent back button
      child: Scaffold(
        backgroundColor: Colors.red,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Emergency Icon
                AnimatedBuilder(
                  animation: _scaleAnimation,
                  builder: (context, child) {
                    return Transform.scale(
                      scale: _isCountingDown ? _pulseAnimation.value : 1.0,
                      child: Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.3),
                              blurRadius: 20,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.emergency,
                          size: 60,
                          color: Colors.red,
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 32),

                // Countdown Display
                if (_isCountingDown) ...[
                  Text(
                    'EMERGENCY ALERT',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Alert will be sent in:',
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.white.withOpacity(0.9),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      '$_countdown',
                      style: const TextStyle(
                        fontSize: 48,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Enter your password to cancel',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.white.withOpacity(0.8),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: TextField(
                      controller: _passwordController,
                      obscureText: true,
                      enableInteractiveSelection: true,
                      autocorrect: false,
                      enableSuggestions: false,
                      decoration: const InputDecoration(
                        hintText: 'Enter your password',
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(vertical: 16),
                      ),
                      onSubmitted: (_) => _verifyPassword(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _verifyPassword,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.red,
                      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Cancel Alert',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ] else if (_isAlertSent) ...[
                  const Icon(
                    Icons.check_circle,
                    size: 80,
                    color: Colors.white,
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'EMERGENCY ALERT SENT',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Your trusted contacts have been notified',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.white.withOpacity(0.9),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),
                  ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.red,
                      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Close',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
} 