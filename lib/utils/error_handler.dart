import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../services/logging_service.dart';
import '../widgets/common/modern_alert_dialog.dart';

/// Centralized error handling utilities
class AppErrorHandler {
  /// Get user-friendly error message
  static String getUserFriendlyMessage(dynamic error) {
    final errorString = error.toString().toLowerCase();

    if (errorString.contains('network') ||
        errorString.contains('internet') ||
        errorString.contains('connection') ||
        errorString.contains('socketexception')) {
      return 'Please check your internet connection and try again.';
    }

    if (errorString.contains('permission') || errorString.contains('denied')) {
      return 'Permission denied. Please check your app permissions.';
    }

    if (errorString.contains('timeout') || errorString.contains('timed out')) {
      return 'Request timed out. Please try again.';
    }

    if (errorString.contains('not found') || errorString.contains('does not exist')) {
      return 'The requested item was not found.';
    }

    if (errorString.contains('unauthorized') || errorString.contains('authentication')) {
      return 'Authentication failed. Please log in again.';
    }

    if (errorString.contains('firestore') && errorString.contains('index')) {
      return 'Database is being set up. Please wait a moment and try again.';
    }

    return 'An unexpected error occurred. Please try again.';
  }

  /// Handle and display error to user
  static void handleError(
    BuildContext context,
    dynamic error, {
    VoidCallback? onRetry,
    String? customMessage,
  }) {
    logger.error('Error occurred', error: error);

    final message = customMessage ?? getUserFriendlyMessage(error);

    ModernSnackBar.show(
      context,
      message: message,
      isError: true,
      actionText: onRetry != null ? 'Retry' : null,
      onAction: onRetry,
    );
  }

  /// Show error dialog
  static void showErrorDialog(
    BuildContext context,
    dynamic error, {
    VoidCallback? onRetry,
    String? title,
  }) {
    logger.error('Error dialog shown', error: error);

    final message = getUserFriendlyMessage(error);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title ?? 'Error'),
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

  /// Wrap async operations with error handling
  static Future<T?> safeAsync<T>(
    BuildContext context,
    Future<T> Function() operation, {
    VoidCallback? onSuccess,
    VoidCallback? onError,
  }) async {
    try {
      final result = await operation();
      if (onSuccess != null) onSuccess();
      return result;
    } catch (e) {
      handleError(context, e);
      if (onError != null) onError();
      return null;
    }
  }
}


