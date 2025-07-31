// lib/utils/navigation.dart
import 'package:flutter/material.dart';

class NavigationUtils {
  // Push a new route
  static Future<T?> push<T>(BuildContext context, Widget page) {
    return Navigator.push<T>(
      context,
      MaterialPageRoute(builder: (context) => page),
    );
  }

  // Push and replace current route
  static Future<T?> pushReplacement<T>(BuildContext context, Widget page) {
    return Navigator.pushReplacement<T, T>(
      context,
      MaterialPageRoute(builder: (context) => page),
    );
  }

  // Push and remove all routes below it
  static Future<T?> pushAndRemoveUntil<T>(BuildContext context, Widget page) {
    return Navigator.pushAndRemoveUntil<T>(
      context,
      MaterialPageRoute(builder: (context) => page),
      (route) => false,
    );
  }

  // Pop to the first route
  static void popToFirst(BuildContext context) {
    Navigator.popUntil(context, (route) => route.isFirst);
  }

  // Pop until a named route
  static void popUntilNamed(BuildContext context, String routeName) {
    Navigator.popUntil(context, ModalRoute.withName(routeName));
  }

  // Pop with result
  static void popWithResult<T>(BuildContext context, T result) {
    Navigator.pop<T>(context, result);
  }

  // Present a modal bottom sheet
  static Future<T?> showBottomSheet<T>(BuildContext context, Widget child, {bool isDismissible = true}) {
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      isDismissible: isDismissible,
      backgroundColor: Colors.transparent,
      builder: (context) => child,
    );
  }

  // Present a dialog
  static Future<T?> showCustomDialog<T>(BuildContext context, Widget child, {bool barrierDismissible = true}) {
    return showDialog<T>(
      context: context,
      barrierDismissible: barrierDismissible,
      builder: (context) => child,
    );
  }
}
