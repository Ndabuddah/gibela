import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../constants/app_colors.dart';

class FloatingCountdownWidget extends StatefulWidget {
  final Map<String, dynamic> scheduledBooking;
  final VoidCallback onTap;

  const FloatingCountdownWidget({
    required this.scheduledBooking,
    required this.onTap,
    Key? key,
  }) : super(key: key);

  @override
  State<FloatingCountdownWidget> createState() => _FloatingCountdownWidgetState();
}

class _FloatingCountdownWidgetState extends State<FloatingCountdownWidget>
    with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late AnimationController _pulseController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _pulseAnimation;
  late Animation<Offset> _slideAnimation;
  
  Timer? _countdownTimer;
  Duration _timeUntilPickup = Duration.zero;
  bool _isVisible = true;

  @override
  void initState() {
    super.initState();
    
    // Initialize animations
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeInOut,
    ));
    
    _pulseAnimation = Tween<double>(
      begin: 1.0,
      end: 1.05,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));
    
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutBack,
    ));
    
    // Start animations
    _fadeController.forward();
    _slideController.forward();
    
    // Initialize countdown
    final scheduledDateTime = (widget.scheduledBooking['scheduledDateTime'] as Timestamp).toDate();
    _timeUntilPickup = scheduledDateTime.difference(DateTime.now());
    _startCountdown();
    
    // Start pulsing if within 30 minutes
    if (_timeUntilPickup.inMinutes <= 30) {
      _pulseController.repeat(reverse: true);
    }
  }

  void _startCountdown() {
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _timeUntilPickup = _timeUntilPickup - const Duration(seconds: 1);
          
          // Start pulsing when within 30 minutes
          if (_timeUntilPickup.inMinutes <= 30 && !_pulseController.isAnimating) {
            _pulseController.repeat(reverse: true);
          }
          
          // Hide when time is up
          if (_timeUntilPickup.isNegative) {
            _hideWidget();
            timer.cancel();
          }
        });
      }
    });
  }

  void _hideWidget() {
    setState(() {
      _isVisible = false;
    });
    _fadeController.reverse().then((_) {
      if (mounted) {
        // Widget will be removed by parent
      }
    });
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _pulseController.dispose();
    _slideController.dispose();
    _countdownTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isVisible) return const SizedBox.shrink();
    
    final isUrgent = _timeUntilPickup.inMinutes <= 15;
    final isSoon = _timeUntilPickup.inMinutes <= 30;
    
    return AnimatedBuilder(
      animation: Listenable.merge([_fadeAnimation, _pulseAnimation, _slideAnimation]),
      builder: (context, child) {
        return FadeTransition(
          opacity: _fadeAnimation,
          child: SlideTransition(
            position: _slideAnimation,
                         child: Transform.scale(
               scale: isSoon ? _pulseAnimation.value : 1.0,
               child: Container(
                 margin: const EdgeInsets.only(top: 100, right: 16),
                 child: GestureDetector(
                  onTap: widget.onTap,
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 200),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: isUrgent
                            ? [
                                Colors.red.shade400,
                                Colors.orange.shade400,
                              ]
                            : [
                                AppColors.primary,
                                AppColors.primary.withOpacity(0.8),
                              ],
                      ),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: (isUrgent ? Colors.red : AppColors.primary).withOpacity(0.3),
                          blurRadius: 15,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header
                        Row(
                          children: [
                            Icon(
                              isUrgent ? Icons.warning : Icons.schedule,
                              color: Colors.white,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                isUrgent ? 'URGENT' : 'Scheduled',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        
                        const SizedBox(height: 8),
                        
                        // Countdown
                        Text(
                          _formatCountdown(_timeUntilPickup),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        
                        const SizedBox(height: 4),
                        
                        // Time info
                        Text(
                          'until pickup',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.8),
                            fontSize: 10,
                          ),
                        ),
                        
                        const SizedBox(height: 8),
                        
                        // Tap indicator
                        Row(
                          children: [
                            Icon(
                              Icons.touch_app,
                              color: Colors.white.withOpacity(0.7),
                              size: 14,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Tap for details',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.7),
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  String _formatCountdown(Duration duration) {
    if (duration.inDays > 0) {
      return '${duration.inDays}d ${duration.inHours % 24}h';
    } else if (duration.inHours > 0) {
      return '${duration.inHours}h ${duration.inMinutes % 60}m';
    } else if (duration.inMinutes > 0) {
      return '${duration.inMinutes}m';
    } else {
      return '${duration.inSeconds}s';
    }
  }
} 