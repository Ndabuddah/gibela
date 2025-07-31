// lib/screens/messages/welcome_screen.dart
import 'package:flutter/material.dart';

import '../../constants/app_colors.dart';
import '../../constants/app_styles.dart';
import '../../widgets/common/custom_button.dart';
import '../home/passenger/passenger_home_screen.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.darkBackground,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Spacer(flex: 1),

              // App logo
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.3),
                      blurRadius: 20,
                      offset: Offset(0, 10),
                    ),
                  ],
                ),
                child: Center(
                  child: Icon(
                    Icons.chat,
                    size: 60,
                    color: Colors.white,
                  ),
                ),
              ),

              const SizedBox(height: 40),

              Text(
                'Welcome to ConnectMe',
                style: AppStyles.headingStyle,
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 16),

              Text(
                'Your account has been created successfully! You can now start connecting with friends and family.',
                style: AppStyles.bodyTextStyle,
                textAlign: TextAlign.center,
              ),

              const Spacer(flex: 2),

              // Get started button
              CustomButton(
                text: 'Start Messaging',
                onPressed: () {
/*                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(builder: (_) => MessagesListScreen()),
                  );*/
                },
                isFullWidth: true,
              ),

              const SizedBox(height: 16),

              // Explore rides button
              CustomButton(
                text: 'Explore Rides',
                onPressed: () {
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(builder: (_) => PassengerHomeScreen()),
                  );
                },
                isFullWidth: true,
                isOutlined: true,
              ),

              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }
}
