import 'package:flutter/material.dart';
import '../../constants/app_colors.dart';
import '../../providers/theme_provider.dart';
import 'package:provider/provider.dart';
import 'retry_widget.dart';

/// Error boundary widget that catches errors and displays a user-friendly message
class ErrorBoundary extends StatefulWidget {
  final Widget child;
  final Widget? fallback;

  const ErrorBoundary({
    Key? key,
    required this.child,
    this.fallback,
  }) : super(key: key);

  @override
  State<ErrorBoundary> createState() => _ErrorBoundaryState();
}

class _ErrorBoundaryState extends State<ErrorBoundary> {
  bool hasError = false;
  Object? error;
  StackTrace? stackTrace;

  @override
  void initState() {
    super.initState();
    // Catch Flutter errors
    FlutterError.onError = (FlutterErrorDetails details) {
      if (mounted) {
        setState(() {
          hasError = true;
          error = details.exception;
          stackTrace = details.stack;
        });
      }
    };
  }

  @override
  Widget build(BuildContext context) {
    if (hasError) {
      return widget.fallback ?? _buildErrorWidget();
    }

    return widget.child;
  }

  Widget _buildErrorWidget() {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;

    return Scaffold(
      backgroundColor: AppColors.getBackgroundColor(isDark),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline,
                size: 64,
                color: AppColors.error,
              ),
              const SizedBox(height: 16),
              Text(
                'Something went wrong',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.getTextPrimaryColor(isDark),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'An unexpected error occurred. Please try again.',
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.getTextSecondaryColor(isDark),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    hasError = false;
                    error = null;
                    stackTrace = null;
                  });
                },
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Helper class for centralized error handling
class ErrorHandler {
  static String getUserFriendlyMessage(dynamic error) {
    if (error.toString().contains('network') ||
        error.toString().contains('internet') ||
        error.toString().contains('connection')) {
      return 'Please check your internet connection and try again.';
    }

    if (error.toString().contains('permission')) {
      return 'Permission denied. Please check your settings.';
    }

    if (error.toString().contains('timeout')) {
      return 'Request timed out. Please try again.';
    }

    if (error.toString().contains('not found')) {
      return 'The requested item was not found.';
    }

    return 'An error occurred. Please try again.';
  }

  static void handleError(BuildContext context, dynamic error, {VoidCallback? onRetry}) {
    final message = getUserFriendlyMessage(error);
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Error'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
          if (onRetry != null)
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                onRetry();
              },
              child: const Text('Retry'),
            ),
        ],
      ),
    );
  }
}


