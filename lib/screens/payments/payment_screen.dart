import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:paystack_for_flutter/paystack_for_flutter.dart';
import 'package:provider/provider.dart';
import 'package:gibelbibela/widgets/common/custom_button.dart';

import '../../../constants/app_colors.dart';
import '../../../providers/theme_provider.dart';

class PaymentScreen extends StatefulWidget {
  final double amount;
  final String email;
  final VoidCallback onPaymentSuccess;

  const PaymentScreen({
    Key? key,
    required this.amount,
    required this.email,
    required this.onPaymentSuccess,
  }) : super(key: key);

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> with TickerProviderStateMixin {
  bool _isLoading = false;
  String? _error;
  late final AnimationController _animationController;
  late final AnimationController _fadeController;
  late final Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeInOut,
    ));
    _animationController.forward();
    _fadeController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _fadeController.dispose();
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
        secretKey: 'YOUR_SECRET_KEY', // Replace with your key from secure storage
        amount: (widget.amount * 100).toDouble(),
        email: widget.email,
        callbackUrl: 'https://callback.com',
        showProgressBar: true,
        paymentOptions: [PaymentOption.card, PaymentOption.bankTransfer],
        currency: Currency.ZAR,
        onSuccess: (callback) {
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
    final isDark = Provider.of<ThemeProvider>(context).isDarkMode;

    return Scaffold(
      backgroundColor: AppColors.getBackgroundColor(isDark),
      body: Stack(
        children: [
          // Background with blur effect
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: isDark 
                  ? [Color(0xFF1a1a1a), Color(0xFF2d2d2d)]
                  : [Color(0xFFf8f9fa), Color(0xFFe9ecef)],
              ),
            ),
          ),
          
          // Main content
          CustomScrollView(
            slivers: [
              SliverAppBar(
                expandedHeight: 200.0,
                backgroundColor: Colors.transparent,
                elevation: 0,
                pinned: true,
                flexibleSpace: FlexibleSpaceBar(
                  title: Text(
                    'Secure Payment',
                    style: TextStyle(
                      color: AppColors.getTextPrimaryColor(isDark),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  background: Stack(
                    fit: StackFit.expand,
                    children: [
                      ClipRect(
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  AppColors.primary.withOpacity(0.8),
                                  AppColors.primary.withOpacity(0.4),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      Center(
                        child: Lottie.asset(
                          'assets/images/payment.json',
                          controller: _animationController,
                          width: 200,
                          height: 200,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const SizedBox(height: 24),
                        _buildPaymentDetailsCard(isDark),
                        if (_error != null) ...[
                          const SizedBox(height: 20),
                          _buildErrorCard(),
                        ],
                        const SizedBox(height: 32),
                        _buildPaymentButton(),
                        const SizedBox(height: 20),
                        _buildSecurePaymentFooter(isDark),
                        const SizedBox(height: 32),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentDetailsCard(bool isDark) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          colors: [
            AppColors.primary,
            AppColors.primary.withOpacity(0.8),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.3),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            const Text(
              'Total Amount',
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
                letterSpacing: -1,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.white.withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.credit_card, color: Colors.white.withOpacity(0.9), size: 18),
                  const SizedBox(width: 8),
                  Text(
                    'Secure Card Payment',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.9),
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorCard() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.error.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.error.withOpacity(0.3)),
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: AppColors.error),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _error!,
              style: TextStyle(
                color: AppColors.error,
                fontWeight: FontWeight.w500,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentButton() {
    return CustomButton(
      text: _isLoading ? 'Processing Payment...' : 'Pay Securely',
      onPressed: _isLoading ? null : _pay,
      isDisabled: _isLoading,
      icon: Icons.lock_outline,
    );
  }

  Widget _buildSecurePaymentFooter(bool isDark) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.shield_outlined,
          size: 18,
          color: AppColors.getTextSecondaryColor(isDark),
        ),
        const SizedBox(width: 8),
        Text(
          'Secured by Paystack',
          style: TextStyle(
            fontSize: 14,
            color: AppColors.getTextSecondaryColor(isDark),
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
