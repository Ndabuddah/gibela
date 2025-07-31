import 'package:flutter/material.dart';

import '../../../../constants/app_colors.dart';

class AnimatedLoadingOverlay extends StatelessWidget {
  final String message;
  final bool isDark;

  const AnimatedLoadingOverlay({
    Key? key,
    this.message = 'Loading...',
    this.isDark = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black54,
      child: Center(
        child: Card(
          color: AppColors.getCardColor(true),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 15),
                Text(
                  message,
                  style: TextStyle(fontSize: 16, color: AppColors.getTextPrimaryColor(true)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
