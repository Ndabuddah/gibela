import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../constants/app_colors.dart';
import '../../../providers/theme_provider.dart';
import '../../../services/pricing_service.dart';
import 'package:provider/provider.dart';

class ScheduledConfirmation extends StatefulWidget {
  final DateTime selectedDate;
  final TimeOfDay selectedTime;
  final String pickupAddress;
  final String dropoffAddress;
  final String selectedVehicleType;
  final String selectedVehiclePrice;
  final bool isLoading;
  final VoidCallback onConfirm;
  final double distanceKm;
  final Function(bool removeCancellationFee)? onCancellationFeeChanged;

  const ScheduledConfirmation({
    Key? key,
    required this.selectedDate,
    required this.selectedTime,
    required this.pickupAddress,
    required this.dropoffAddress,
    required this.selectedVehicleType,
    required this.selectedVehiclePrice,
    required this.isLoading,
    required this.onConfirm,
    required this.distanceKm,
    this.onCancellationFeeChanged,
  }) : super(key: key);

  @override
  State<ScheduledConfirmation> createState() => _ScheduledConfirmationState();
}

class _ScheduledConfirmationState extends State<ScheduledConfirmation> {
  bool _removeCancellationFee = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Provider.of<ThemeProvider>(context).isDarkMode;
    
    // Calculate proper pricing using the algorithm
    final calculatedPrice = PricingService.calculateFare(
      distanceKm: widget.distanceKm,
      vehicleType: widget.selectedVehicleType,
      requestTime: DateTime(widget.selectedDate.year, widget.selectedDate.month, widget.selectedDate.day, widget.selectedTime.hour, widget.selectedTime.minute),
    );
    
    // Calculate cancellation fee (15% of total) - can be removed with checkbox
    final cancellationFee = _removeCancellationFee ? 0.0 : calculatedPrice * 0.15;
    final totalPrice = calculatedPrice + cancellationFee;
    
    // Check if booking is at least 2 hours from now
    final now = DateTime.now();
    final scheduledDateTime = DateTime(widget.selectedDate.year, widget.selectedDate.month, widget.selectedDate.day, widget.selectedTime.hour, widget.selectedTime.minute);
    final timeDifference = scheduledDateTime.difference(now);
    final isAtLeast2Hours = timeDifference.inHours >= 2;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.getCardColor(isDark),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle bar
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),
          
          Text(
            'Confirm Your Scheduled Trip',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppColors.getTextPrimaryColor(isDark),
            ),
          ),
          const SizedBox(height: 16),
          
          // Time validation warning
          if (!isAtLeast2Hours)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange),
              ),
              child: Row(
                children: [
                  Icon(Icons.warning, color: Colors.orange, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Scheduled trips must be at least 2 hours from now',
                      style: TextStyle(
                        color: Colors.orange[800],
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          
          if (!isAtLeast2Hours) const SizedBox(height: 16),
          
          // Trip Details
          _buildTripDetails(context, isDark, calculatedPrice, cancellationFee, totalPrice),
          
          const SizedBox(height: 20),
          
          // Cancellation Fee Checkbox
          _buildCancellationFeeCheckbox(isDark, cancellationFee),
          
          const SizedBox(height: 20),
          
          // Cancellation Policy
          _buildCancellationPolicy(isDark, cancellationFee, totalPrice),
          
          const SizedBox(height: 20),
          
          // Payment Method
          Text(
            'Payment Method',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.getTextPrimaryColor(isDark),
            ),
          ),
          const SizedBox(height: 8),
          
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.primary),
            ),
            child: Row(
              children: [
                Icon(Icons.credit_card, color: AppColors.primary, size: 18),
                const SizedBox(width: 12),
                Text(
                  'Card Payment',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.getTextPrimaryColor(isDark),
                  ),
                ),
                const Spacer(),
                Icon(Icons.check_circle, color: AppColors.primary, size: 18),
              ],
            ),
          ),
          
          const SizedBox(height: 20),
          
          // Confirm Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: (widget.isLoading || !isAtLeast2Hours) ? null : widget.onConfirm,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 2,
              ),
              child: Text(
                widget.isLoading 
                  ? 'Processing...' 
                  : !isAtLeast2Hours 
                    ? 'Minimum 2 hours required'
                    : 'Confirm & Pay R${totalPrice.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCancellationFeeCheckbox(bool isDark, double cancellationFee) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.orange.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline, color: Colors.orange, size: 16),
              const SizedBox(width: 8),
              Text(
                'Cancellation Fee',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.getTextPrimaryColor(isDark),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Checkbox(
                value: _removeCancellationFee,
                onChanged: (value) {
                  setState(() {
                    _removeCancellationFee = value ?? false;
                    widget.onCancellationFeeChanged?.call(_removeCancellationFee);
                  });
                },
                activeColor: AppColors.primary,
              ),
              Expanded(
                child: Text(
                  'Remove cancellation fee (R${cancellationFee.toStringAsFixed(2)})',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.getTextPrimaryColor(isDark),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Note: Removing the cancellation fee means you will be charged the full amount even if you cancel the trip.',
            style: TextStyle(
              fontSize: 12,
              color: AppColors.getTextSecondaryColor(isDark),
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTripDetails(BuildContext context, bool isDark, double calculatedPrice, double cancellationFee, double totalPrice) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.getBackgroundColor(isDark),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.getBorderColor(isDark)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(Icons.schedule, color: AppColors.primary, size: 16),
              const SizedBox(width: 8),
              Text(
                'Scheduled for:',
                style: TextStyle(
                  color: AppColors.getTextSecondaryColor(isDark),
                  fontWeight: FontWeight.w500,
                  fontSize: 14,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${DateFormat('MMM d').format(widget.selectedDate)} at ${widget.selectedTime.format(context)}',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppColors.getTextPrimaryColor(isDark),
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(Icons.my_location, color: Colors.green, size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  widget.pickupAddress,
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                    color: AppColors.getTextPrimaryColor(isDark),
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.location_on, color: Colors.red, size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  widget.dropoffAddress,
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                    color: AppColors.getTextPrimaryColor(isDark),
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(Icons.directions_car, color: AppColors.primary, size: 16),
              const SizedBox(width: 8),
              Text(
                'Vehicle:',
                style: TextStyle(
                  color: AppColors.getTextSecondaryColor(isDark),
                  fontWeight: FontWeight.w500,
                  fontSize: 14,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                widget.selectedVehicleType,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppColors.getTextPrimaryColor(isDark),
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.attach_money, color: AppColors.primary, size: 16),
              const SizedBox(width: 8),
              Text(
                'Base Fare:',
                style: TextStyle(
                  color: AppColors.getTextSecondaryColor(isDark),
                  fontWeight: FontWeight.w500,
                  fontSize: 14,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'R${calculatedPrice.toStringAsFixed(2)}',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppColors.getTextPrimaryColor(isDark),
                  fontSize: 14,
                ),
              ),
            ],
          ),
          if (cancellationFee > 0) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.warning, color: Colors.orange, size: 16),
                const SizedBox(width: 8),
                Text(
                  'Cancellation Fee:',
                  style: TextStyle(
                    color: AppColors.getTextSecondaryColor(isDark),
                    fontWeight: FontWeight.w500,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'R${cancellationFee.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.orange,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.attach_money, color: AppColors.primary, size: 16),
              const SizedBox(width: 8),
              Text(
                'Total:',
                style: TextStyle(
                  color: AppColors.getTextSecondaryColor(isDark),
                  fontWeight: FontWeight.w500,
                  fontSize: 14,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'R${totalPrice.toStringAsFixed(2)}',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCancellationPolicy(bool isDark, double cancellationFee, double totalPrice) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline, color: Colors.blue, size: 16),
              const SizedBox(width: 8),
              Text(
                'Cancellation Policy',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.getTextPrimaryColor(isDark),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            cancellationFee > 0 
              ? '• Cancellation fee: R${cancellationFee.toStringAsFixed(2)} (15% of total)\n'
                '• Full refund if cancelled 30+ minutes before trip\n'
                '• No refund if cancelled within 30 minutes\n'
                '• Free cancellation within 10 minutes of booking'
              : '• No cancellation fee applied\n'
                '• Full refund if cancelled 30+ minutes before trip\n'
                '• No refund if cancelled within 30 minutes\n'
                '• Free cancellation within 10 minutes of booking',
            style: TextStyle(
              fontSize: 13,
              color: AppColors.getTextSecondaryColor(isDark),
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
} 