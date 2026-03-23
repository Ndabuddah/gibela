import 'package:flutter/material.dart';
import '../../constants/app_colors.dart';
import '../../providers/theme_provider.dart';
import 'package:provider/provider.dart';

/// Widget for displaying empty states with illustrations and helpful messages
class EmptyStateWidget extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final Widget? customIcon;

  const EmptyStateWidget({
    Key? key,
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
    this.customIcon,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isDark = Provider.of<ThemeProvider>(context).isDarkMode;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (customIcon != null)
              customIcon!
            else
              Icon(
                icon,
                size: 80,
                color: isDark ? AppColors.uberGrey : AppColors.uberGreyDark,
              ),
            const SizedBox(height: 24),
            Text(
              title,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: isDark ? AppColors.white : AppColors.black,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              message,
              style: TextStyle(
                fontSize: 16,
                color: isDark ? AppColors.uberGrey : AppColors.uberGreyDark,
              ),
              textAlign: TextAlign.center,
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: onAction,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.black,
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(actionLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Predefined empty states for common scenarios
class EmptyStates {
  static Widget noRideHistory({VoidCallback? onAction}) {
    return EmptyStateWidget(
      icon: Icons.history,
      title: 'No Ride History',
      message: 'You haven\'t taken any rides yet. Book your first ride to get started!',
      actionLabel: 'Book a Ride',
      onAction: onAction,
    );
  }

  static Widget noBookings({VoidCallback? onAction}) {
    return EmptyStateWidget(
      icon: Icons.event_busy,
      title: 'No Scheduled Rides',
      message: 'You don\'t have any scheduled rides. Schedule a ride to plan ahead!',
      actionLabel: 'Schedule Ride',
      onAction: onAction,
    );
  }

  static Widget noNotifications() {
    return EmptyStateWidget(
      icon: Icons.notifications_none,
      title: 'No Notifications',
      message: 'You\'re all caught up! No new notifications.',
    );
  }

  static Widget noDriversAvailable() {
    return EmptyStateWidget(
      icon: Icons.directions_car_outlined,
      title: 'No Drivers Available',
      message: 'We couldn\'t find any available drivers nearby. Please try again in a few moments.',
    );
  }

  static Widget noEarnings() {
    return EmptyStateWidget(
      icon: Icons.account_balance_wallet_outlined,
      title: 'No Earnings Yet',
      message: 'Start accepting rides to see your earnings here!',
    );
  }

  static Widget noRideRequests() {
    return EmptyStateWidget(
      icon: Icons.directions_car_filled_outlined,
      title: 'No Ride Requests',
      message: 'No ride requests available at the moment. Stay online to receive requests!',
    );
  }

  static Widget searchNoResults({String? query}) {
    return EmptyStateWidget(
      icon: Icons.search_off,
      title: 'No Results Found',
      message: query != null
          ? 'We couldn\'t find any results for "$query". Try a different search term.'
          : 'No results found. Try adjusting your search criteria.',
    );
  }

  static Widget connectionError({VoidCallback? onRetry}) {
    return EmptyStateWidget(
      icon: Icons.wifi_off,
      title: 'No Internet Connection',
      message: 'Please check your internet connection and try again.',
      actionLabel: 'Retry',
      onAction: onRetry,
    );
  }

  static Widget errorOccurred({VoidCallback? onRetry}) {
    return EmptyStateWidget(
      icon: Icons.error_outline,
      title: 'Something Went Wrong',
      message: 'An error occurred while loading. Please try again.',
      actionLabel: 'Retry',
      onAction: onRetry,
    );
  }
}
