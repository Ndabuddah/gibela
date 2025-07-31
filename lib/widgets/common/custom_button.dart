// lib/widgets/custom_button.dart
import 'package:flutter/material.dart';

import '../../constants/app_colors.dart';

class CustomButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool isFullWidth;
  final bool isOutlined;
  final bool isDisabled;
  final IconData? icon;
  final Color? color;

  const CustomButton({
    Key? key,
    required this.text,
    required this.onPressed,
    this.isFullWidth = false,
    this.isOutlined = false,
    this.isDisabled = false,
    this.icon,
    this.color,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final buttonColor = color ?? AppColors.primary;

    if (isOutlined) {
      return OutlinedButton(
        onPressed: isDisabled ? null : onPressed,
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: isDisabled ? Colors.grey : buttonColor),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: EdgeInsets.symmetric(
            horizontal: 24,
            vertical: 16,
          ),
          minimumSize: isFullWidth ? Size(double.infinity, 0) : null,
        ),
        child: _buildButtonContent(buttonColor),
      );
    } else {
      return ElevatedButton(
        onPressed: isDisabled ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: buttonColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: EdgeInsets.symmetric(
            horizontal: 24,
            vertical: 16,
          ),
          minimumSize: isFullWidth ? Size(double.infinity, 0) : null,
        ),
        child: _buildButtonContent(Colors.white),
      );
    }
  }

  Widget _buildButtonContent(Color contentColor) {
    if (icon != null) {
      return Row(
        mainAxisSize: isFullWidth ? MainAxisSize.max : MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 20,
            color: isDisabled ? Colors.grey : contentColor,
          ),
          SizedBox(width: 8),
          Text(
            text,
            style: TextStyle(
              color: isDisabled ? Colors.grey : contentColor,
              fontWeight: FontWeight.w600,
              fontSize: 16,
            ),
          ),
        ],
      );
    } else {
      return Text(
        text,
        style: TextStyle(
          color: isDisabled ? Colors.grey : contentColor,
          fontWeight: FontWeight.w600,
          fontSize: 16,
        ),
      );
    }
  }
}
