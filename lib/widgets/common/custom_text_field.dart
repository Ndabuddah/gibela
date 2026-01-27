// lib/widgets/custom_text_field.dart
import 'package:flutter/material.dart';

import '../../constants/app_colors.dart';

class CustomTextField extends StatelessWidget {
  final TextEditingController controller;
  final String? label;
  final String? hintText;
  final IconData? prefixIcon;
  final IconData? suffixIcon;
  final bool obscureText;
  final TextInputType keyboardType;
  final String? Function(String?)? validator;
  final Function()? onSuffixIconPressed;
  final Function(String)? onChanged;
  final int maxLines;
  final bool readOnly;
  final FocusNode? focusNode;
  final VoidCallback? onTap;

  const CustomTextField({
    super.key,
    required this.controller,
    this.label,
    this.hintText,
    this.prefixIcon,
    this.suffixIcon,
    this.obscureText = false,
    this.keyboardType = TextInputType.text,
    this.validator,
    this.onSuffixIconPressed,
    this.onChanged,
    this.maxLines = 1,
    this.readOnly = false,
    this.focusNode,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8.0, left: 4.0),
            child: Text(
              label!,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: AppColors.getTextPrimaryColor(isDark),
                fontSize: 14,
              ),
            ),
          ),
        TextFormField(
          controller: controller,
          focusNode: focusNode,
          obscureText: obscureText,
          keyboardType: keyboardType,
          validator: validator,
          onChanged: onChanged,
          maxLines: maxLines,
          style: TextStyle(
            color: AppColors.getTextPrimaryColor(isDark),
            fontWeight: FontWeight.w500,
          ),
          readOnly: readOnly,
          enableInteractiveSelection: true,
          autocorrect: false,
          enableSuggestions: false,
          decoration: InputDecoration(
            hintText: hintText,
            hintStyle: TextStyle(color: AppColors.getTextHintColor(isDark), fontSize: 14),
            prefixIcon: prefixIcon != null ? Icon(prefixIcon, color: AppColors.getTextHintColor(isDark), size: 20) : null,
            suffixIcon: suffixIcon != null
                ? IconButton(
                    icon: Icon(suffixIcon, color: AppColors.getTextHintColor(isDark), size: 20),
                    onPressed: onSuffixIconPressed,
                  )
                : null,
            filled: true,
            fillColor: isDark ? AppColors.darkCard : const Color(0xFFF5F5F5),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: isDark ? Colors.white10 : Colors.black.withOpacity(0.05)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: AppColors.primary, width: 2),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: AppColors.error, width: 1.5),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: AppColors.error, width: 2),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          ),
          onTap: onTap,
        ),
      ],
    );
  }
}
