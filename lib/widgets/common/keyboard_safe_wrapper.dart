import 'package:flutter/material.dart';

/// A wrapper widget that provides safe keyboard handling for the entire app
/// This prevents crashes when the keyboard opens and closes
class KeyboardSafeWrapper extends StatelessWidget {
  final Widget child;
  final bool resizeToAvoidBottomInset;
  final EdgeInsets? padding;
  final bool enableTapToDismiss;

  const KeyboardSafeWrapper({
    super.key,
    required this.child,
    this.resizeToAvoidBottomInset = true,
    this.padding,
    this.enableTapToDismiss = true,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: resizeToAvoidBottomInset,
      body: enableTapToDismiss
          ? GestureDetector(
              onTap: () {
                // Dismiss keyboard when tapping outside
                FocusScope.of(context).unfocus();
              },
              child: _buildBody(),
            )
          : _buildBody(),
    );
  }

  Widget _buildBody() {
    return SafeArea(
      child: SingleChildScrollView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: padding ?? EdgeInsets.zero,
        child: child,
      ),
    );
  }
}

/// A mixin that provides keyboard-safe behavior for StatefulWidgets
mixin KeyboardSafeMixin<T extends StatefulWidget> on State<T> {
  @override
  void initState() {
    super.initState();
    // Add any keyboard-related initialization here
  }

  @override
  void dispose() {
    // Ensure keyboard is dismissed when widget is disposed
    FocusScope.of(context).unfocus();
    super.dispose();
  }

  /// Safely dismiss keyboard
  void dismissKeyboard() {
    FocusScope.of(context).unfocus();
  }

  /// Check if keyboard is visible
  bool get isKeyboardVisible {
    return MediaQuery.of(context).viewInsets.bottom > 0;
  }

  /// Get keyboard height
  double get keyboardHeight {
    return MediaQuery.of(context).viewInsets.bottom;
  }
} 