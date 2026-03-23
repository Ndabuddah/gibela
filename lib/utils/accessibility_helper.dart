import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';

/// Helper class for accessibility improvements
class AccessibilityHelper {
  /// Add semantic labels to widgets
  static Widget addSemantics({
    required Widget child,
    required String label,
    String? hint,
    String? value,
    bool? isButton,
    bool? isHeader,
    bool? isImage,
    VoidCallback? onTap,
  }) {
    return Semantics(
      label: label,
      hint: hint,
      value: value,
      button: isButton ?? false,
      header: isHeader ?? false,
      image: isImage ?? false,
      onTap: onTap,
      child: child,
    );
  }
  
  /// Make button accessible
  static Widget accessibleButton({
    required Widget child,
    required String label,
    String? hint,
    required VoidCallback onPressed,
  }) {
    return Semantics(
      label: label,
      hint: hint,
      button: true,
      onTap: onPressed,
      child: child,
    );
  }
  
  /// Make image accessible
  static Widget accessibleImage({
    required Image image,
    required String label,
    String? hint,
  }) {
    return Semantics(
      label: label,
      hint: hint,
      image: true,
      child: image,
    );
  }
  
  /// Make text field accessible
  static Widget accessibleTextField({
    required TextField textField,
    required String label,
    String? hint,
    String? value,
  }) {
    return Semantics(
      label: label,
      hint: hint,
      value: value,
      textField: true,
      child: textField,
    );
  }
  
  /// Announce message to screen readers
  static void announce(BuildContext context, String message, {bool assertiveness = false}) {
    SemanticsService.announce(
      message,
      TextDirection.ltr,
      assertiveness: assertiveness ? Assertiveness.assertive : Assertiveness.polite,
    );
  }
  
  /// Check if accessibility features are enabled
  static bool isAccessibilityEnabled(BuildContext context) {
    return MediaQuery.of(context).accessibleNavigation;
  }
  
  /// Get text scale factor for accessibility
  static double getTextScaleFactor(BuildContext context) {
    return MediaQuery.of(context).textScaleFactor;
  }
  
  /// Check if bold text is enabled
  static bool isBoldTextEnabled(BuildContext context) {
    return MediaQuery.of(context).boldText;
  }
  
  /// Check if high contrast is enabled
  static bool isHighContrastEnabled(BuildContext context) {
    return MediaQuery.of(context).highContrast;
  }
  
  /// Get minimum touch target size (48x48 for accessibility)
  static Size getMinimumTouchTarget() {
    return const Size(48, 48);
  }
  
  /// Ensure widget meets minimum touch target
  static Widget ensureMinimumTouchTarget(Widget child) {
    return SizedBox(
      width: 48,
      height: 48,
      child: Center(child: child),
    );
  }
}

/// Accessible button widget
class AccessibleButton extends StatelessWidget {
  final String label;
  final String? hint;
  final VoidCallback? onPressed;
  final Widget child;
  
  const AccessibleButton({
    Key? key,
    required this.label,
    this.hint,
    this.onPressed,
    required this.child,
  }) : super(key: key);
  
  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: label,
      hint: hint,
      button: true,
      enabled: onPressed != null,
      onTap: onPressed,
      child: child,
    );
  }
}

/// Accessible icon button
class AccessibleIconButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? hint;
  final VoidCallback? onPressed;
  final Color? color;
  
  const AccessibleIconButton({
    Key? key,
    required this.icon,
    required this.label,
    this.hint,
    this.onPressed,
    this.color,
  }) : super(key: key);
  
  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: label,
      hint: hint,
      button: true,
      enabled: onPressed != null,
      onTap: onPressed,
      child: IconButton(
        icon: Icon(icon, color: color),
        onPressed: onPressed,
        tooltip: label, // Also add tooltip for better UX
      ),
    );
  }
}

