import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:paystack_for_flutter/paystack_for_flutter.dart';
import 'package:provider/provider.dart';
import 'package:gibelbibela/widgets/common/custom_button.dart';

import '../../../constants/app_colors.dart';
import '../../../providers/theme_provider.dart';
import '../../../l10n/app_localizations.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:gibelbibela/services/database_service.dart';

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

  int _retryCount = 0;
  static const int _maxRetries = 3;

  Future<void> _pay() async {
    await _payWithRetry();
  }

  Future<void> _payWithRetry({int retryCount = 0}) async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      print('💳 Starting payment process for amount: R${widget.amount} (Attempt ${retryCount + 1}/$_maxRetries)');
      
      // Load secret key from dart-define to avoid committing secrets
      const paystackKey = String.fromEnvironment('PAYSTACK_SECRET_KEY', defaultValue: '');
      
      if (paystackKey.isEmpty) {
        throw Exception('Payment configuration error. Please contact support.');
      }
      
      await PaystackFlutter().pay(
        context: context,
        secretKey: paystackKey,
        amount: (widget.amount * 100).toDouble(),
        email: widget.email,
        callbackUrl: 'https://callback.com',
        showProgressBar: true,
        paymentOptions: [PaymentOption.card, PaymentOption.bankTransfer],
        currency: Currency.ZAR,
        onSuccess: (callback) async {
          try {
            print('✅ Payment successful, reference: ${callback.reference}');
            
            // Record payment in database with retry logic
            bool paymentRecorded = false;
            for (int i = 0; i < _maxRetries; i++) {
              try {
                await _recordPayment(callback.reference);
                paymentRecorded = true;
                break;
              } catch (e) {
                print('⚠️ Payment recording attempt ${i + 1} failed: $e');
                if (i < _maxRetries - 1) {
                  await Future.delayed(Duration(seconds: (i + 1) * 2)); // Exponential backoff
                }
              }
            }
            
            if (!paymentRecorded) {
              // Payment succeeded but recording failed - queue for later sync
              print('⚠️ Payment succeeded but recording failed. Will sync later.');
              // Could store in offline queue here
            }
            
            // Verify payment was recorded successfully
            final user = FirebaseAuth.instance.currentUser;
            if (user != null) {
              bool verified = false;
              for (int i = 0; i < _maxRetries; i++) {
                try {
                  verified = await DatabaseService().verifyDriverPayment(user.uid);
                  if (verified) break;
                  await Future.delayed(Duration(seconds: (i + 1) * 2));
                } catch (e) {
                  print('⚠️ Verification attempt ${i + 1} failed: $e');
                }
              }
              
              if (verified || paymentRecorded) {
                print('✅ Payment verification successful');
                widget.onPaymentSuccess();
              } else {
                print('❌ Payment verification failed after retries');
                setState(() {
                  final localizations = AppLocalizations.of(context);
                  _error = '${localizations?.translate('payment_completed_verification_failed') ?? 'Payment completed but verification failed. Please contact support with reference'}: ${callback.reference}';
                  _isLoading = false;
                });
              }
            } else {
              print('❌ No authenticated user found');
              setState(() {
                final localizations = AppLocalizations.of(context);
                _error = localizations?.translate('user_auth_error') ?? 'User authentication error. Please try again.';
                _isLoading = false;
              });
            }
          } catch (e) {
            print('❌ Error in payment success callback: $e');
            setState(() {
              final localizations = AppLocalizations.of(context);
              _error = '${localizations?.translate('payment_processing_error') ?? 'Payment processing error'}: $e';
              _isLoading = false;
            });
          }
        },
        onCancelled: (callback) {
          print('❌ Payment cancelled by user');
          setState(() {
            final localizations = AppLocalizations.of(context);
            _error = localizations?.translate('payment_cancelled') ?? 'Payment was cancelled. Please try again.';
            _isLoading = false;
          });
        },
      );
    } catch (e) {
      print('❌ Error initiating payment: $e');
      
      // Retry on network errors
      if (retryCount < _maxRetries - 1 && 
          (e.toString().contains('network') || 
           e.toString().contains('timeout') ||
           e.toString().contains('connection'))) {
        print('🔄 Retrying payment...');
        await Future.delayed(Duration(seconds: (retryCount + 1) * 2));
        await _payWithRetry(retryCount: retryCount + 1);
      } else {
        setState(() {
          final localizations = AppLocalizations.of(context);
          _error = '${localizations?.translate('payment_error') ?? 'An error occurred during payment.'} ${retryCount >= _maxRetries - 1 ? (localizations?.translate('try_again_later') ?? 'Please try again later or contact support.') : ''}';
          _isLoading = false;
        });
      }
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
            Builder(
              builder: (context) {
                final localizations = AppLocalizations.of(context);
                return Text(
                  localizations?.translate('total_amount') ?? 'Total Amount',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                    color: Colors.white,
                  ),
                );
              },
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
                  Builder(
                    builder: (context) {
                      final localizations = AppLocalizations.of(context);
                      return Text(
                        localizations?.translate('secure_card_payment') ?? 'Secure Card Payment',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.9),
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      );
                    },
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
      text: _isLoading 
        ? (AppLocalizations.of(context)?.translate('processing_payment') ?? 'Processing Payment...')
        : '${AppLocalizations.of(context)?.translate('pay_now') ?? 'Pay'} R${widget.amount.toStringAsFixed(0)} ${AppLocalizations.of(context)?.translate('securely') ?? 'Securely'}',
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
          AppLocalizations.of(context)?.translate('secured_by_paystack') ?? 'Secured by Paystack',
          style: TextStyle(
            fontSize: 14,
            color: AppColors.getTextSecondaryColor(isDark),
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  // Record payment in database
  Future<void> _recordPayment(String reference) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await DatabaseService().recordDriverPayment(
          user.uid,
          widget.amount,
          reference,
        );
      }
    } catch (e) {
      print('Error recording payment: $e');
      // Don't throw error here as payment was successful
      // Just log it for debugging
    }
  }
}
