import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import '../../constants/app_colors.dart';
import '../../services/receipt_service.dart';
import '../../providers/theme_provider.dart';
import 'package:provider/provider.dart';

class RideReceiptScreen extends StatefulWidget {
  final String rideId;

  const RideReceiptScreen({
    Key? key,
    required this.rideId,
  }) : super(key: key);

  @override
  State<RideReceiptScreen> createState() => _RideReceiptScreenState();
}

class _RideReceiptScreenState extends State<RideReceiptScreen> {
  final ReceiptService _receiptService = ReceiptService();
  Map<String, dynamic>? _receipt;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadReceipt();
  }

  Future<void> _loadReceipt() async {
    setState(() => _isLoading = true);
    try {
      // Try to get existing receipt
      _receipt = await _receiptService.getReceipt(widget.rideId);
      
      // If no receipt exists, generate one
      if (_receipt == null) {
        _receipt = await _receiptService.generateReceipt(widget.rideId);
      }
    } catch (e) {
      print('Error loading receipt: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _shareReceipt() async {
    if (_receipt == null) return;
    
    try {
      final receiptText = _receiptService.formatReceiptAsText(_receipt!);
      await Share.share(receiptText, subject: 'Ride Receipt - ${_receipt!['receiptNumber']}');
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error sharing receipt: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Provider.of<ThemeProvider>(context).isDarkMode;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.uberGreyLight,
      appBar: AppBar(
        title: const Text('Ride Receipt'),
        backgroundColor: isDark ? AppColors.darkCard : AppColors.white,
        foregroundColor: isDark ? AppColors.white : AppColors.black,
        elevation: 0,
        actions: [
          if (_receipt != null)
            IconButton(
              icon: const Icon(Icons.share),
              onPressed: _shareReceipt,
              tooltip: 'Share Receipt',
            ),
        ],
      ),
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(
                color: AppColors.primary,
              ),
            )
          : _receipt == null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.receipt_long, size: 64, color: AppColors.uberGrey),
                      const SizedBox(height: 16),
                      Text(
                        'Receipt not found',
                        style: TextStyle(
                          fontSize: 18,
                          color: isDark ? AppColors.white : AppColors.black,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ElevatedButton(
                        onPressed: _loadReceipt,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: AppColors.black,
                        ),
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Receipt Header
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: isDark ? AppColors.darkCard : AppColors.white,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Column(
                          children: [
                            Text(
                              'GIBELA',
                              style: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                                color: AppColors.primary,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'RIDE RECEIPT',
                              style: TextStyle(
                                fontSize: 16,
                                color: isDark ? AppColors.white : AppColors.black,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Divider(color: AppColors.uberGrey),
                            const SizedBox(height: 16),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Receipt #',
                                  style: TextStyle(
                                    color: isDark ? AppColors.uberGrey : AppColors.uberGreyDark,
                                  ),
                                ),
                                Text(
                                  _receipt!['receiptNumber'] ?? 'N/A',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: isDark ? AppColors.white : AppColors.black,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Date',
                                  style: TextStyle(
                                    color: isDark ? AppColors.uberGrey : AppColors.uberGreyDark,
                                  ),
                                ),
                                Text(
                                  _formatDate(_receipt!['date']),
                                  style: TextStyle(
                                    color: isDark ? AppColors.white : AppColors.black,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      
                      // Trip Details
                      _buildSection(
                        title: 'Trip Details',
                        isDark: isDark,
                        child: _buildTripDetails(_receipt!['trip'], isDark),
                      ),
                      const SizedBox(height: 20),
                      
                      // Pricing Breakdown
                      _buildSection(
                        title: 'Pricing Breakdown',
                        isDark: isDark,
                        child: _buildPricingBreakdown(_receipt!['pricing'], isDark),
                      ),
                      const SizedBox(height: 20),
                      
                      // Payment Info
                      _buildSection(
                        title: 'Payment Information',
                        isDark: isDark,
                        child: _buildPaymentInfo(_receipt!['pricing'], isDark),
                      ),
                    ],
                  ),
                ),
    );
  }

  Widget _buildSection({
    required String title,
    required bool isDark,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: isDark ? AppColors.white : AppColors.black,
            ),
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }

  Widget _buildTripDetails(Map<String, dynamic> trip, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildDetailRow('From', trip['pickupAddress'] ?? 'N/A', isDark),
        const SizedBox(height: 12),
        _buildDetailRow('To', trip['dropoffAddress'] ?? 'N/A', isDark),
        const SizedBox(height: 12),
        _buildDetailRow('Distance', '${(trip['distance'] as num?)?.toStringAsFixed(2) ?? '0.00'} km', isDark),
        if (trip['duration'] != null) ...[
          const SizedBox(height: 12),
          _buildDetailRow('Duration', _formatDuration(trip['duration']), isDark),
        ],
        const SizedBox(height: 12),
        _buildDetailRow('Vehicle Type', trip['vehicleType'] ?? 'N/A', isDark),
      ],
    );
  }

  Widget _buildPricingBreakdown(Map<String, dynamic> pricing, bool isDark) {
    final baseFare = (pricing['baseFare'] as num?)?.toDouble() ?? 0.0;
    final distanceFare = (pricing['distanceFare'] as num?)?.toDouble() ?? 0.0;
    final timeFare = (pricing['timeFare'] as num?)?.toDouble() ?? 0.0;
    final serviceFee = (pricing['serviceFee'] as num?)?.toDouble() ?? 0.0;
    final surgeMultiplier = (pricing['surgeMultiplier'] as num?)?.toDouble() ?? 1.0;
    final total = (pricing['total'] as num?)?.toDouble() ?? 0.0;

    return Column(
      children: [
        if (baseFare > 0)
          _buildPriceRow('Base Fare', baseFare, isDark),
        if (distanceFare > 0)
          _buildPriceRow('Distance Fare', distanceFare, isDark),
        if (timeFare > 0)
          _buildPriceRow('Time Fare', timeFare, isDark),
        if (surgeMultiplier > 1.0)
          _buildPriceRow('Surge (${surgeMultiplier.toStringAsFixed(2)}x)', 0, isDark, isInfo: true),
        if (serviceFee > 0)
          _buildPriceRow('Service Fee', serviceFee, isDark),
        const Divider(height: 24),
        _buildPriceRow('TOTAL', total, isDark, isTotal: true),
      ],
    );
  }

  Widget _buildPaymentInfo(Map<String, dynamic> pricing, bool isDark) {
    return Column(
      children: [
        _buildDetailRow('Payment Method', pricing['paymentMethod'] ?? 'Cash', isDark),
        _buildDetailRow('Status', 'Paid', isDark),
      ],
    );
  }

  Widget _buildDetailRow(String label, String value, bool isDark) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            color: isDark ? AppColors.uberGrey : AppColors.uberGreyDark,
            fontSize: 14,
          ),
        ),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: TextStyle(
              color: isDark ? AppColors.white : AppColors.black,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPriceRow(String label, double amount, bool isDark, {bool isTotal = false, bool isInfo = false}) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: isTotal ? 4 : 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: isDark ? AppColors.white : AppColors.black,
              fontSize: isTotal ? 18 : 14,
              fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          if (!isInfo)
            Text(
              'R${amount.toStringAsFixed(2)}',
              style: TextStyle(
                color: isTotal ? AppColors.primary : (isDark ? AppColors.white : AppColors.black),
                fontSize: isTotal ? 20 : 14,
                fontWeight: isTotal ? FontWeight.bold : FontWeight.w500,
              ),
            ),
        ],
      ),
    );
  }

  String _formatDate(dynamic date) {
    if (date == null) return 'N/A';
    try {
      DateTime dateTime;
      if (date is DateTime) {
        dateTime = date;
      } else if (date is String) {
        dateTime = DateTime.parse(date);
      } else {
        return date.toString();
      }
      return '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return date.toString();
    }
  }

  String _formatDuration(int? seconds) {
    if (seconds == null) return 'N/A';
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    return '${minutes}m ${remainingSeconds}s';
  }
}

