import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

import '../../constants/app_colors.dart';

class ScheduledReminderDialog extends StatefulWidget {
  final Map<String, dynamic> reminder;
  final VoidCallback onDismiss;
  final VoidCallback onViewDetails;

  const ScheduledReminderDialog({
    required this.reminder,
    required this.onDismiss,
    required this.onViewDetails,
    Key? key,
  }) : super(key: key);

  @override
  State<ScheduledReminderDialog> createState() => _ScheduledReminderDialogState();
}

class _ScheduledReminderDialogState extends State<ScheduledReminderDialog>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late AnimationController _pulseController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;
  late Animation<double> _pulseAnimation;
  
  Timer? _countdownTimer;
  Duration _timeUntilPickup = Duration.zero;

  @override
  void initState() {
    super.initState();
    
    // Initialize animations
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    
    _scaleAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.elasticOut,
    ));
    
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
    
    _pulseAnimation = Tween<double>(
      begin: 1.0,
      end: 1.1,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));
    
    // Start animations
    _animationController.forward();
    _pulseController.repeat(reverse: true);
    
    // Initialize countdown
    _timeUntilPickup = widget.reminder['timeUntilPickup'] as Duration;
    _startCountdown();
  }

  void _startCountdown() {
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _timeUntilPickup = _timeUntilPickup - const Duration(seconds: 1);
          if (_timeUntilPickup.isNegative) {
            timer.cancel();
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    _pulseController.dispose();
    _countdownTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scheduledDateTime = (widget.reminder['scheduledDateTime'] as Timestamp).toDate();
    final isUrgent = _timeUntilPickup.inMinutes <= 15;
    
    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return FadeTransition(
          opacity: _fadeAnimation,
          child: ScaleTransition(
            scale: _scaleAnimation,
            child: Dialog(
              backgroundColor: Colors.transparent,
              child: Container(
                constraints: const BoxConstraints(maxWidth: 400),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: isUrgent
                        ? [
                            Colors.red.shade50,
                            Colors.orange.shade50,
                          ]
                        : [
                            AppColors.primary.withOpacity(0.1),
                            AppColors.primary.withOpacity(0.05),
                          ],
                  ),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: isUrgent ? Colors.red.shade300 : AppColors.primary.withOpacity(0.3),
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Header with urgency indicator
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: isUrgent
                              ? [Colors.red.shade400, Colors.orange.shade400]
                              : [AppColors.primary, AppColors.primary.withOpacity(0.8)],
                        ),
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(22),
                          topRight: Radius.circular(22),
                        ),
                      ),
                      child: Row(
                        children: [
                          AnimatedBuilder(
                            animation: _pulseAnimation,
                            builder: (context, child) {
                              return Transform.scale(
                                scale: isUrgent ? _pulseAnimation.value : 1.0,
                                child: Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: Icon(
                                    isUrgent ? Icons.warning : Icons.schedule,
                                    color: Colors.white,
                                    size: 28,
                                  ),
                                ),
                              );
                            },
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  isUrgent ? 'URGENT REMINDER' : 'Scheduled Trip Reminder',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${DateFormat('MMM d, y').format(scheduledDateTime)} at ${DateFormat('HH:mm').format(scheduledDateTime)}',
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.9),
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    // Content
                    Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        children: [
                          // Countdown timer
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: isUrgent 
                                  ? Colors.red.shade100 
                                  : AppColors.primary.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: isUrgent 
                                    ? Colors.red.shade300 
                                    : AppColors.primary.withOpacity(0.3),
                              ),
                            ),
                            child: Column(
                              children: [
                                Text(
                                  'Time Until Pickup',
                                  style: TextStyle(
                                    color: isUrgent 
                                        ? Colors.red.shade700 
                                        : AppColors.primary,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  _formatCountdown(_timeUntilPickup),
                                  style: TextStyle(
                                    color: isUrgent 
                                        ? Colors.red.shade700 
                                        : AppColors.primary,
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          
                          const SizedBox(height: 20),
                          
                          // Trip details
                          _buildDetailRow(
                            Icons.location_on,
                            'Pickup',
                            widget.reminder['pickupAddress'] ?? '',
                            isDark,
                          ),
                          const SizedBox(height: 12),
                          _buildDetailRow(
                            Icons.location_on_outlined,
                            'Dropoff',
                            widget.reminder['dropoffAddress'] ?? '',
                            isDark,
                          ),
                          const SizedBox(height: 12),
                          _buildDetailRow(
                            Icons.directions_car,
                            'Vehicle',
                            widget.reminder['vehicleType'] ?? 'Standard',
                            isDark,
                          ),
                          const SizedBox(height: 12),
                          _buildDetailRow(
                            Icons.attach_money,
                            'Fare',
                            'R${(widget.reminder['estimatedFare'] ?? 0.0).toStringAsFixed(2)}',
                            isDark,
                          ),
                          
                          const SizedBox(height: 24),
                          
                          // Action buttons
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: widget.onDismiss,
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(vertical: 16),
                                    side: BorderSide(
                                      color: isUrgent 
                                          ? Colors.red.shade300 
                                          : AppColors.primary.withOpacity(0.5),
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  child: Text(
                                    'Dismiss',
                                    style: TextStyle(
                                      color: isUrgent 
                                          ? Colors.red.shade700 
                                          : AppColors.primary,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: widget.onViewDetails,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: isUrgent 
                                        ? Colors.red.shade600 
                                        : AppColors.primary,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(vertical: 16),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    elevation: 4,
                                  ),
                                  child: const Text(
                                    'View Details',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value, bool isDark) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            color: AppColors.primary,
            size: 20,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: AppColors.getTextSecondaryColor(isDark),
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                value,
                style: TextStyle(
                  color: AppColors.getTextPrimaryColor(isDark),
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _formatCountdown(Duration duration) {
    if (duration.inDays > 0) {
      return '${duration.inDays}d ${duration.inHours % 24}h ${duration.inMinutes % 60}m';
    } else if (duration.inHours > 0) {
      return '${duration.inHours}h ${duration.inMinutes % 60}m';
    } else if (duration.inMinutes > 0) {
      return '${duration.inMinutes}m ${duration.inSeconds % 60}s';
    } else {
      return '${duration.inSeconds}s';
    }
  }
} 