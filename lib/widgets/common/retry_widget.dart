import 'package:flutter/material.dart';
import '../../constants/app_colors.dart';
import '../../providers/theme_provider.dart';
import 'package:provider/provider.dart';

/// Widget that shows retry button for failed operations
class RetryWidget extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  final String? errorDetails;
  final int? retryCount;
  final int maxRetries;

  const RetryWidget({
    Key? key,
    required this.message,
    required this.onRetry,
    this.errorDetails,
    this.retryCount,
    this.maxRetries = 3,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;
    final canRetry = retryCount == null || retryCount! < maxRetries;

    return Center(
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
              message,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppColors.getTextPrimaryColor(isDark),
              ),
              textAlign: TextAlign.center,
            ),
            if (errorDetails != null) ...[
              const SizedBox(height: 8),
              Text(
                errorDetails!,
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.getTextSecondaryColor(isDark),
                ),
                textAlign: TextAlign.center,
              ),
            ],
            if (retryCount != null && retryCount! > 0) ...[
              const SizedBox(height: 8),
              Text(
                'Retry attempt: $retryCount/$maxRetries',
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.getTextSecondaryColor(isDark),
                ),
              ),
            ],
            const SizedBox(height: 24),
            if (canRetry)
              ElevatedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              )
            else
              Text(
                'Maximum retry attempts reached. Please try again later.',
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.getTextSecondaryColor(isDark),
                ),
                textAlign: TextAlign.center,
              ),
          ],
        ),
      ),
    );
  }
}

/// Helper class for retry logic with exponential backoff
class RetryHelper {
  static Future<T> retryWithBackoff<T>({
    required Future<T> Function() operation,
    int maxRetries = 3,
    Duration initialDelay = const Duration(seconds: 1),
    double backoffMultiplier = 2.0,
    bool Function(dynamic error)? shouldRetry,
  }) async {
    int attempt = 0;
    Duration delay = initialDelay;

    while (attempt < maxRetries) {
      try {
        return await operation();
      } catch (e) {
        attempt++;
        
        // Check if we should retry this error
        if (shouldRetry != null && !shouldRetry(e)) {
          rethrow;
        }

        // If this was the last attempt, rethrow the error
        if (attempt >= maxRetries) {
          rethrow;
        }

        // Wait before retrying with exponential backoff
        await Future.delayed(delay);
        delay = Duration(milliseconds: (delay.inMilliseconds * backoffMultiplier).round());
      }
    }

    throw Exception('Retry failed after $maxRetries attempts');
  }
}


