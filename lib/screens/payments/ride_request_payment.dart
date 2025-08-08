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
  final VoidCallback onPaymentSuccess;

  const RidePaymentScreen({
    Key? key,
    required this.amount,
    required this.email,
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

  Future<void> _pay() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      await PaystackFlutter().pay(
        context: context,
        // TODO: Inject Paystack secret key via secure runtime config (e.g., dart-define or remote config)
        // DO NOT commit secrets to source control
        secretKey: const String.fromEnvironment('PAYSTACK_SECRET_KEY', defaultValue: ''),
        amount: (widget.amount * 100).toDouble(),
        email: widget.email,
        callbackUrl: 'https://callback.com',
        showProgressBar: true,
        paymentOptions: [PaymentOption.card, PaymentOption.bankTransfer],
        currency: Currency.ZAR,
        onSuccess: (callback) async {
          // Payment successful
          widget.onPaymentSuccess();
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
