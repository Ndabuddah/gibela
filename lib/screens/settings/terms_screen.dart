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
            children: [
              const Text(
                'Terms & Conditions',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.primaryDark),
              ),
              const SizedBox(height: 24),
              Text(
                '''1. Introduction

Welcome to Gibela Ride App. These Terms and Conditions ("Terms") govern your use of our ride-sharing service. By accessing or using our service, you agree to be bound by these Terms.

2. Use of Service

2.1 Eligibility
You must be at least 18 years old to use our service. By using the app, you represent that you meet this age requirement.

2.2 Account Registration
You are responsible for maintaining the confidentiality of your account credentials and for all activities that occur under your account.

2.3 Service Description
Gibela provides a platform connecting passengers with drivers for transportation services. We act as an intermediary and are not a transportation provider.

3. User Responsibilities

3.1 Passengers
- Provide accurate pickup and dropoff locations
- Be ready at the pickup location at the scheduled time
- Treat drivers with respect and courtesy
- Pay for services as agreed

3.2 Drivers
- Maintain valid driver's license and vehicle registration
- Provide safe and reliable transportation
- Follow all traffic laws and regulations
- Maintain vehicle in good working condition

4. Payments

4.1 Payment Methods
We accept card payments and cash payments. Card payments are processed securely through our payment partners.

4.2 Pricing
Fares are calculated based on distance, vehicle type, time of day, and demand. Prices are displayed before you confirm your ride.

4.3 Refunds
Refund policies vary based on cancellation timing and circumstances. See our Cancellation Policy for details.

5. Cancellation Policy

5.1 Free Cancellation
- Within 10 minutes of booking: Free cancellation
- 30+ minutes before scheduled trip: Full refund

5.2 Cancellation Fees
- Within 30 minutes of scheduled trip: Cancellation fee applies
- After trip has started: No refund

6. Safety and Conduct

6.1 Safety
Your safety is our priority. Report any safety concerns immediately through the app or contact support.

6.2 Prohibited Conduct
- Harassment or abusive behavior
- Damage to vehicles
- Illegal activities
- Violation of these Terms

7. Privacy

Your privacy is important to us. Please review our Privacy Policy to understand how we collect, use, and protect your information.

8. Limitation of Liability

Gibela is not liable for any indirect, incidental, or consequential damages arising from your use of the service.

9. Account Deletion

You may delete your account at any time from the settings screen. Deletion is permanent and cannot be undone.

10. Changes to Terms

We reserve the right to modify these Terms at any time. Continued use of the service after changes constitutes acceptance.

11. Contact

For support, questions, or concerns:
- Email: support@gibela.com
- WhatsApp: Available in-app
- Phone: Available in-app

Last Updated: ${DateTime.now().year}

By using Gibela Ride App, you acknowledge that you have read, understood, and agree to be bound by these Terms and Conditions.''',
                style: TextStyle(fontSize: 16, color: AppColors.textDark, height: 1.6),
              ),
            ],
          ),
        ),
      ),
    );
  }
} 