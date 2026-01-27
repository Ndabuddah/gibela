import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

/// Helper extension for adding accessibility to widgets
extension AccessibilityExtension on Widget {
  Widget withSemantics({
    String? label,
    String? hint,
    String? value,
    bool? button,
    bool? header,
    bool? image,
    bool? textField,
    bool? enabled,
    bool? checked,
    bool? selected,
    String? onTapHint,
  }) {
    return Semantics(
      label: label,
      hint: hint,
      value: value,
      button: button,
      header: header,
      image: image,
      textField: textField,
      enabled: enabled,
      checked: checked,
      selected: selected,
      onTapHint: onTapHint,
      child: this,
    );
  }
}

/// Accessible button widget
class AccessibleButton extends StatelessWidget {
  final Widget child;
  final VoidCallback? onPressed;
  final String label;
  final String? hint;
  final bool enabled;

  const AccessibleButton({
    Key? key,
    required this.child,
    required this.onPressed,
    required this.label,
    this.hint,
    this.enabled = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: label,
      hint: hint,
      button: true,
      enabled: enabled,
      child: child,
    );
  }
}

/// Accessible text field
class AccessibleTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String? hint;
  final String? helperText;
  final bool enabled;

  const AccessibleTextField({
    Key? key,
    required this.controller,
    required this.label,
    this.hint,
    this.helperText,
    this.enabled = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: label,
      hint: hint,
      textField: true,
      enabled: enabled,
      child: TextField(
        controller: controller,
        enabled: enabled,
      ),
    );
  }
}

