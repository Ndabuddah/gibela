import 'package:flutter/material.dart';
import '../../constants/app_colors.dart';

class SupportScreen extends StatelessWidget {
  const SupportScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Support'),
        backgroundColor: AppColors.primary,
      ),
      body: Center(
        child: Text('Support and contact options will appear here.', style: TextStyle(fontSize: 18, color: AppColors.getTextPrimaryColor(isDark))),
      ),
    );
  }
} 