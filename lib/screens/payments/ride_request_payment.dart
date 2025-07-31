import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:paystack_for_flutter/paystack_for_flutter.dart';

import '../../../constants/app_colors.dart';
import '../../../widgets/common/custom_button.dart';

class RidePaymentScreen extends StatefulWidget {
  final double amount;
  final String email;
  final String pickupAddress;
  final List<double> pickupCoordinates;
  final String dropoffAddress;
  final List<double> dropoffCoordinates;
  final String vehicleType;
  final String vehiclePrice;
  final VoidCallback onPaymentSuccess;

  const RidePaymentScreen({
    Key? key,
    required this.amount,
    required this.email,
    required this.pickupAddress,
    required this.pickupCoordinates,
    required this.dropoffAddress,
    required this.dropoffCoordinates,
    required this.vehicleType,
    required this.vehiclePrice,
    required this.onPaymentSuccess,
  }) : super(key: key);

  @override
  State<RidePaymentScreen> createState() => _RidePaymentScreenState();
}

class _RidePaymentScreenState extends State<RidePaymentScreen> with TickerProviderStateMixin {
  bool _isLoading = false;
  String? _error;
  late final AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _createRideRequest() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      final doc = await FirebaseFirestore.instance.collection('requests').add({
        'passengerId': user?.uid,
        'pickupAddress': widget.pickupAddress,
        'pickupCoordinates': widget.pickupCoordinates,
        'dropoffAddress': widget.dropoffAddress,
        'dropoffCoordinates': widget.dropoffCoordinates,
        'vehicleType': widget.vehicleType,
        'price': widget.vehiclePrice,
        'paymentType': 'Card',
        'paymentStatus': 'paid',
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Call the success callback to navigate back or show confirmation
      widget.onPaymentSuccess();
    } catch (e) {
      setState(() {
        _error = 'Failed to create ride request. Please try again.';
        _isLoading = false;
      });
    }
  }

  Future<void> _pay() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      await PaystackFlutter().pay(
        context: context,
        secretKey: 'sk_live_50be0cff4e564295a8723aa3c8432d805895e248',
        amount: (widget.amount * 100).toDouble(),
        email: widget.email,
        callbackUrl: 'https://callback.com',
        showProgressBar: true,
        paymentOptions: [PaymentOption.card, PaymentOption.bankTransfer],
        currency: Currency.ZAR,
        onSuccess: (callback) async {
          // Payment successful, now create the ride request
          await _createRideRequest();
        },
        onCancelled: (callback) {
          setState(() {
            _error = 'Payment was cancelled. Please try again.';
            _isLoading = false;
          });
        },
      );
    } catch (e) {
      setState(() {
        _error = 'An error occurred during payment. Please try again.';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: AppColors.getBackgroundColor(isDark),
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 250.0,
            backgroundColor: AppColors.primary,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              title: const Text(
                'Ride Payment',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              background: Lottie.asset(
                'assets/images/payment.json',
                fit: BoxFit.cover,
                controller: _animationController,
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 20),
                  _buildRideDetailsCard(),
                  const SizedBox(height: 20),
                  _buildPaymentDetailsCard(),
                  const SizedBox(height: 32),
                  if (_error != null) _buildErrorCard(),
                  const SizedBox(height: 32),
                  _buildPaymentButton(),
                  const SizedBox(height: 20),
                  _buildSecurePaymentFooter(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRideDetailsCard() {
    return Card(
      elevation: 6,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.directions_car, color: AppColors.primary, size: 24),
                const SizedBox(width: 8),
                Text(
                  'Ride Details',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Icon(Icons.my_location, color: Colors.green, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'From: ${widget.pickupAddress}',
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.location_on, color: Colors.red, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'To: ${widget.dropoffAddress}',
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Vehicle: ${widget.vehicleType}',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentDetailsCard() {
    return Card(
      elevation: 8,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            colors: [AppColors.primaryLight, AppColors.primary.withOpacity(0.8)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            children: [
              const Text(
                'Total Fare',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'R${widget.amount.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontSize: 48,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              Chip(
                label: Text(
                  'Secure Card Payment',
                  style: TextStyle(color: AppColors.primaryDark),
                ),
                backgroundColor: Colors.white.withOpacity(0.9),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildErrorCard() {
    return Card(
      color: AppColors.error.withOpacity(0.1),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: AppColors.error, width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Icon(Icons.error_outline, color: AppColors.error),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                _error!,
                style: TextStyle(color: AppColors.error, fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentButton() {
    return CustomButton(
      text: _isLoading ? 'Processing Payment...' : 'Pay & Book Ride',
      onPressed: _pay,
      isDisabled: _isLoading,
      icon: Icons.payment,
    );
  }

  Widget _buildSecurePaymentFooter() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.lock, size: 16, color: Colors.grey[600]),
        const SizedBox(width: 8),
        Text(
          'Powered by Paystack',
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey[600],
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
