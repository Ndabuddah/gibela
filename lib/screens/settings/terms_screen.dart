import 'package:flutter/material.dart';
import '../../constants/app_colors.dart';

class TermsScreen extends StatelessWidget {
  const TermsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Terms & Conditions'),
        backgroundColor: AppColors.primary,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Text(
                'Terms & Conditions',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.primaryDark),
              ),
              SizedBox(height: 24),
              Text(
                '1. Introduction\n\nThis is a placeholder for your full terms and conditions. Please replace this text with your actual legal content.\n\n2. Use of Service\n\nBy using this app, you agree to abide by all rules and regulations...\n\n3. Payments\n\nAll payments are processed securely.\n\n4. Account Deletion\n\nYou may delete your account at any time from the settings screen.\n\n5. Contact\n\nFor support, contact us via WhatsApp.\n\n... (add more as needed) ...',
                style: TextStyle(fontSize: 16, color: AppColors.textDark, height: 1.6),
              ),
            ],
          ),
        ),
      ),
    );
  }
} 