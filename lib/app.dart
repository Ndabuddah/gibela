import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'providers/theme_provider.dart';
import 'screens/splash/splash_screen.dart';
import 'services/notification_service.dart';
import 'services/scheduled_reminder_service.dart';

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        return MaterialApp(
          title: 'RideApp',
          debugShowCheckedModeBanner: false,
          theme: themeProvider.lightTheme,
          darkTheme: themeProvider.darkTheme,
          themeMode: themeProvider.isDarkMode ? ThemeMode.dark : ThemeMode.light,
          home: const SplashScreen(),
          builder: (context, child) {
            // Initialize notification service
            WidgetsBinding.instance.addPostFrameCallback((_) {
              final notificationService = Provider.of<NotificationService>(context, listen: false);
              notificationService.initialize(context);
            });

            final reminderService = Provider.of<ScheduledReminderService>(context);

            Widget scaffold = MediaQuery(
              data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(1.0)),
              child: child!,
            );

            // Show a simple foreground banner for reminders
            if (reminderService.showReminderDialog && reminderService.currentReminder != null) {
              final reminder = reminderService.currentReminder!;
              final isDriver = reminder['type'] == 'driver';
              final pickup = reminder['pickupAddress'] ?? '';
              final when = reminderService.formatCountdown(reminder['timeUntilPickup'] as Duration);

              scaffold = Stack(
                children: [
                  scaffold,
                  Positioned(
                    left: 12,
                    right: 12,
                    top: MediaQuery.of(context).padding.top + 8,
                    child: Material(
                      elevation: 4,
                      borderRadius: BorderRadius.circular(12),
                      color: Colors.black87,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        child: Row(
                          children: [
                            Icon(Icons.alarm, color: Colors.yellow[600]),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    isDriver ? 'Scheduled pickup in $when' : 'Your pickup in $when',
                                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                                  ),
                                  if (pickup.toString().isNotEmpty)
                                    Text(
                                      pickup,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(color: Colors.white.withOpacity(0.85)),
                                    ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            TextButton(
                              onPressed: () async {
                                await reminderService.dismissReminder();
                              },
                              child: const Text('Dismiss', style: TextStyle(color: Colors.white)),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              );
            }

            return scaffold;
          },
        );
      },
    );
  }
}
