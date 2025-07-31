import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../constants/app_colors.dart';
import '../../providers/theme_provider.dart';

class LocationInput extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final String label;
  final String hint;
  final IconData icon;
  final Color iconColor;
  final void Function(String) onChanged;
  final VoidCallback? onTapIcon;

  const LocationInput({
    Key? key,
    required this.controller,
    required this.focusNode,
    required this.label,
    required this.hint,
    required this.icon,
    required this.iconColor,
    required this.onChanged,
    this.onTapIcon,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isDark = Provider.of<ThemeProvider>(context).isDarkMode;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.getTextSecondaryColor(isDark),
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: isDark ? Colors.white10 : Colors.black.withOpacity(0.03),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              // Icon button
              Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: onTapIcon,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Icon(
                      icon,
                      color: iconColor,
                      size: 24,
                    ),
                  ),
                ),
              ),

              // Vertical divider
              Container(
                height: 24,
                width: 1,
                color: isDark ? Colors.white12 : Colors.black12,
              ),

              // Text input
              Expanded(
                child: TextField(
                  controller: controller,
                  focusNode: focusNode,
                  onChanged: onChanged,
                  enableInteractiveSelection: true,
                  autocorrect: false,
                  enableSuggestions: false,
                  style: TextStyle(
                    fontSize: 16,
                    color: AppColors.getTextPrimaryColor(isDark),
                  ),
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    hintText: hint,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                    hintStyle: TextStyle(
                      color: AppColors.getTextSecondaryColor(isDark)?.withOpacity(0.5),
                      fontSize: 16,
                    ),
                  ),
                  onTap: () {
                    // Ensure proper focus handling
                    if (!focusNode.hasFocus) {
                      focusNode.requestFocus();
                    }
                  },
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
