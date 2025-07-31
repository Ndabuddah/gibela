import 'package:flutter/material.dart';
import '../../constants/app_colors.dart';
import '../auth/signup_screen.dart';
import '../auth/driver_signup_screen.dart';

class RoleSelectionScreen extends StatelessWidget {
  const RoleSelectionScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Your Role'),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
          Text(
          'Please select your role',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: AppColors.textDark,
          ),
        ),
        const SizedBox(height: 40),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildRoleCard(context, 'Passenger', Icons.person, () {
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (context) => const SignupScreen()),
              );
            }),
            _buildRoleCard(context, 'Driver', Icons.directions_car, () {
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (context) => const DriverSignupScreen()),
              );
            }),
          ],
        ),],
        ),
      ),

    );
  }

  Widget _buildRoleCard(BuildContext context, String role, IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Card(
        elevation: 4,
        child: SizedBox(
          width: 120,
          height: 120,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 40, color: AppColors.primary),
              const SizedBox(height: 10),
              Text(role, style: TextStyle(fontSize: 18, color: AppColors.textDark)),
            ],
          ),
        ),
      ),
    );
  }
}