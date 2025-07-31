import 'package:flutter/material.dart';
import '../../constants/app_colors.dart';

class PaymentsScreen extends StatelessWidget {
  const PaymentsScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Payments'),
        backgroundColor: AppColors.primary,
      ),
      body: Center(
        child: Text('Your payment methods and history will appear here.', style: TextStyle(fontSize: 18, color: AppColors.getTextPrimaryColor(isDark))),
      ),
    );
  }
} 