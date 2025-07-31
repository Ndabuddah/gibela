import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../constants/app_colors.dart';
import '../../services/auth_service.dart';
import '../../services/panic_service.dart';
import '../../screens/emergency/panic_alert_screen.dart';
import '../../screens/settings/panic_settings_screen.dart';
import 'modern_alert_dialog.dart';

class PanicButton extends StatefulWidget {
  final bool showInRide;
  
  const PanicButton({
    super.key,
    this.showInRide = false,
  });

  @override
  State<PanicButton> createState() => _PanicButtonState();
}

class _PanicButtonState extends State<PanicButton> with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  bool _hasTrustedContacts = false;
  bool _isCheckingContacts = true;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.1).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _pulseController.repeat(reverse: true);
    _checkTrustedContacts();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _checkTrustedContacts() async {
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final user = authService.userModel;
      
      if (user != null) {
        final hasContacts = await PanicService.hasTrustedContacts(user.uid);
        if (mounted) {
          setState(() {
            _hasTrustedContacts = hasContacts;
            _isCheckingContacts = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isCheckingContacts = false;
        });
      }
    }
  }

  void _showNoContactsDialog() {
    showDialog(
      context: context,
      builder: (context) => ModernAlertDialog(
        title: 'Emergency Contacts Required',
        message: 'You need to add trusted contacts to use the panic button. These contacts will receive emergency alerts when you activate the panic button.',
        confirmText: 'Add Contacts',
        cancelText: 'Add Later',
        onConfirm: () {
          Navigator.of(context).pop();
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => const PanicSettingsScreen(),
            ),
          );
        },
        onCancel: () => Navigator.of(context).pop(),
        icon: Icons.emergency,
        iconColor: Colors.red,
      ),
    );
  }

  void _showPanicConfirmation() {
    showDialog(
      context: context,
      builder: (context) => ModernAlertDialog(
        title: 'Emergency Panic Alert',
        message: 'Are you sure you want to activate the emergency panic alert? This will send an alert to your trusted contacts with your location and ride details.',
        confirmText: 'Activate Alert',
        cancelText: 'Cancel',
        onConfirm: () {
          Navigator.of(context).pop();
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => const PanicAlertScreen(),
            ),
          );
        },
        onCancel: () => Navigator.of(context).pop(),
        icon: Icons.emergency,
        iconColor: Colors.red,
        isDestructive: true,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isCheckingContacts) {
      return const SizedBox.shrink();
    }

    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _pulseAnimation.value,
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.red.withOpacity(0.4),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: FloatingActionButton(
              onPressed: _hasTrustedContacts ? _showPanicConfirmation : _showNoContactsDialog,
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              elevation: 8,
              child: const Icon(
                Icons.emergency,
                size: 28,
              ),
            ),
          ),
        );
      },
    );
  }
}

// Panic Button for Ride Screens
class RidePanicButton extends StatelessWidget {
  final bool isActive;
  
  const RidePanicButton({
    super.key,
    this.isActive = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(50),
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
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(50),
                onTap: isActive ? () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const PanicAlertScreen(),
                    ),
                  );
                } : null,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.emergency,
                        color: Colors.white,
                        size: 24,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'EMERGENCY',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
} 