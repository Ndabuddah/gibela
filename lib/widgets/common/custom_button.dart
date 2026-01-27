// lib/widgets/custom_button.dart
import 'package:flutter/material.dart';

import '../../constants/app_colors.dart';

class CustomButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool isFullWidth;
  final bool isOutlined;
  final bool isDisabled;
  final bool isSecondary;
  final IconData? icon;
  final Color? color;
  final String? semanticLabel;
  final String? semanticHint;

  const CustomButton({
    Key? key,
    required this.text,
    required this.onPressed,
    this.isFullWidth = false,
    this.isOutlined = false,
    this.isDisabled = false,
    this.isSecondary = false,
    this.icon,
    this.color,
    this.semanticLabel,
    this.semanticHint,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    
    // Uber-like primary color is Black in Light mode and White in Dark mode
    final Color defaultPrimary = isDark ? AppColors.uberWhite : AppColors.uberBlack;
    final Color defaultOnPrimary = isDark ? AppColors.uberBlack : AppColors.uberWhite;
    
    final buttonColor = color ?? (isSecondary ? AppColors.primary : defaultPrimary);
    final onButtonColor = color != null ? AppColors.white : (isSecondary ? AppColors.uberBlack : defaultOnPrimary);

    Widget button;
    if (isOutlined) {
      button = OutlinedButton(
        onPressed: isDisabled ? null : onPressed,
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: isDisabled ? Colors.grey : buttonColor, width: 1.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: 24,
            vertical: 18,
          ),
          minimumSize: isFullWidth ? const Size(double.infinity, 56) : const Size(0, 56),
          elevation: 0,
        ),
        child: _buildButtonContent(buttonColor),
      );
    } else {
      button = Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          boxShadow: isDisabled ? [] : [
            BoxShadow(
              color: (color ?? defaultPrimary).withOpacity(0.2),
              blurRadius: 15,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: ElevatedButton(
          onPressed: isDisabled ? null : onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: buttonColor,
            foregroundColor: onButtonColor,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.symmetric(
              horizontal: 24,
              vertical: 18,
            ),
            minimumSize: isFullWidth ? const Size(double.infinity, 56) : const Size(0, 56),
          ),
          child: _buildButtonContent(onButtonColor),
        ),
      );
    }

    return Semantics(
      label: semanticLabel ?? text,
      hint: semanticHint,
      button: true,
      enabled: !isDisabled,
      child: button,
    );
  }

  Widget _buildButtonContent(Color contentColor) {
    return Row(
      mainAxisSize: isFullWidth ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (icon != null) ...[
          Icon(
            icon,
            size: 20,
            color: isDisabled ? Colors.grey : contentColor,
          ),
          const SizedBox(width: 10),
        ],
        Text(
          text,
          style: TextStyle(
            color: isDisabled ? Colors.grey : contentColor,
            fontWeight: FontWeight.bold,
            fontSize: 16,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }
}
