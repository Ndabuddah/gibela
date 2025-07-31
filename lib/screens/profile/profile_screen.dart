import 'package:flutter/material.dart';
import '../../constants/app_colors.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        backgroundColor: AppColors.primary,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircleAvatar(
              radius: 48,
              backgroundColor: AppColors.primary.withOpacity(0.2),
              child: const Icon(Icons.person, size: 48, color: AppColors.primary),
            ),
            const SizedBox(height: 16),
            Text('Your Name', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.getTextPrimaryColor(isDark))),
            const SizedBox(height: 8),
            Text('your@email.com', style: TextStyle(fontSize: 16, color: AppColors.getTextSecondaryColor(isDark))),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              icon: const Icon(Icons.edit),
              label: const Text('Edit Profile'),
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
              onPressed: () {},
            ),
          ],
        ),
      ),
    );
  }
} 