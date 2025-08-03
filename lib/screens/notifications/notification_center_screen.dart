import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../constants/app_colors.dart';
import '../../models/notification_model.dart';
import '../../services/enhanced_notification_service.dart';
import '../../widgets/common/loading_indicator.dart';
import '../../widgets/common/modern_alert_dialog.dart';

class NotificationCenterScreen extends StatefulWidget {
  const NotificationCenterScreen({Key? key}) : super(key: key);

  @override
  State<NotificationCenterScreen> createState() => _NotificationCenterScreenState();
}

class _NotificationCenterScreenState extends State<NotificationCenterScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final EnhancedNotificationService _notificationService = EnhancedNotificationService();
  bool _isLoading = false;
  NotificationCategory _selectedCategory = NotificationCategory.ride;
  final DateFormat _dateFormat = DateFormat('MMM d, y HH:mm');

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: NotificationCategory.values.length, vsync: this);
    _initializeNotifications();
  }

  Future<void> _initializeNotifications() async {
    setState(() => _isLoading = true);
    try {
      await _notificationService.initializePushNotifications();
    } catch (e) {
      _showError('Error initializing notifications');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notification Center'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => _showNotificationSettings(),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: NotificationCategory.values.map((category) {
            return Tab(
              text: _getCategoryName(category),
              icon: Icon(_getCategoryIcon(category)),
            );
          }).toList(),
          onTap: (index) {
            setState(() {
              _selectedCategory = NotificationCategory.values[index];
            });
          },
        ),
      ),
      body: _isLoading
          ? const Center(child: LoadingIndicator())
          : TabBarView(
              controller: _tabController,
              children: NotificationCategory.values.map((category) {
                return _buildNotificationList(category);
              }).toList(),
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showClearConfirmation(),
        child: const Icon(Icons.clear_all),
        tooltip: 'Clear all notifications',
      ),
    );
  }

  Widget _buildNotificationList(NotificationCategory category) {
    return StreamBuilder<List<NotificationModel>>(
      stream: _notificationService.getNotificationsByCategory('currentUserId', category),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        if (!snapshot.hasData) {
          return const Center(child: LoadingIndicator());
        }

        final notifications = snapshot.data!;

        if (notifications.isEmpty) {
          return _buildEmptyState(category);
        }

        return ListView.builder(
          itemCount: notifications.length,
          padding: const EdgeInsets.all(16),
          itemBuilder: (context, index) {
            return _buildNotificationCard(notifications[index]);
          },
        );
      },
    );
  }

  Widget _buildEmptyState(NotificationCategory category) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            _getCategoryIcon(category),
            size: 64,
            color: Colors.grey,
          ),
          const SizedBox(height: 16),
          Text(
            'No ${_getCategoryName(category)} Notifications',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'You\'ll see your ${_getCategoryName(category).toLowerCase()} notifications here',
            style: TextStyle(
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationCard(NotificationModel notification) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Dismissible(
      key: Key(notification.id),
      background: Container(
        color: Colors.red,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 16),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      direction: DismissDirection.endToStart,
      onDismissed: (direction) {
        _notificationService.deleteNotification(notification.id);
      },
      child: Card(
        margin: const EdgeInsets.only(bottom: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: InkWell(
          onTap: () => _handleNotificationTap(notification),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: _getCategoryColor(notification.category).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        _getCategoryIcon(notification.category),
                        color: _getCategoryColor(notification.category),
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            notification.title,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _dateFormat.format(notification.timestamp.toDate()),
                            style: TextStyle(
                              color: AppColors.getTextSecondaryColor(isDark),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (!notification.isRead)
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                        ),
                      ),
                  ],
                ),
                if (notification.body.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    notification.body,
                    style: TextStyle(
                      color: AppColors.getTextSecondaryColor(isDark),
                    ),
                  ),
                ],
                if (notification.imageUrl != null) ...[
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      notification.imageUrl!,
                      width: double.infinity,
                      height: 200,
                      fit: BoxFit.cover,
                    ),
                  ),
                ],
                if (notification.actionData != null) ...[
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => _handleNotificationAction(notification, 'primary'),
                        child: Text(
                          notification.actionData!['primary_action'] ?? 'View',
                          style: TextStyle(color: AppColors.primary),
                        ),
                      ),
                      if (notification.actionData!['secondary_action'] != null)
                        TextButton(
                          onPressed: () => _handleNotificationAction(notification, 'secondary'),
                          child: Text(
                            notification.actionData!['secondary_action'],
                            style: const TextStyle(color: Colors.grey),
                          ),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _handleNotificationTap(NotificationModel notification) async {
    if (!notification.isRead) {
      await _notificationService.markNotificationAsRead(notification.id);
    }
    // Handle navigation or other actions based on notification type
  }

  void _handleNotificationAction(NotificationModel notification, String actionType) async {
    await _notificationService.handleNotificationAction(notification.id, actionType);
  }

  Future<void> _showClearConfirmation() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => const ModernAlertDialog(
        title: 'Clear Notifications',
        message: 'Are you sure you want to clear all notifications?',
        confirmText: 'Clear',
        cancelText: 'Cancel',
        isDestructive: true,
      ),
    );

    if (confirmed == true) {
      await _notificationService.clearAllNotifications('currentUserId');
    }
  }

  void _showNotificationSettings() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => const NotificationSettingsSheet(),
    );
  }

  String _getCategoryName(NotificationCategory category) {
    switch (category) {
      case NotificationCategory.ride:
        return 'Rides';
      case NotificationCategory.payment:
        return 'Payments';
      case NotificationCategory.profile:
        return 'Profile';
      case NotificationCategory.document:
        return 'Documents';
      case NotificationCategory.system:
        return 'System';
      case NotificationCategory.promotion:
        return 'Promotions';
      case NotificationCategory.emergency:
        return 'Emergency';
    }
  }

  IconData _getCategoryIcon(NotificationCategory category) {
    switch (category) {
      case NotificationCategory.ride:
        return Icons.directions_car;
      case NotificationCategory.payment:
        return Icons.payment;
      case NotificationCategory.profile:
        return Icons.person;
      case NotificationCategory.document:
        return Icons.description;
      case NotificationCategory.system:
        return Icons.settings;
      case NotificationCategory.promotion:
        return Icons.local_offer;
      case NotificationCategory.emergency:
        return Icons.warning;
    }
  }

  Color _getCategoryColor(NotificationCategory category) {
    switch (category) {
      case NotificationCategory.ride:
        return Colors.blue;
      case NotificationCategory.payment:
        return Colors.green;
      case NotificationCategory.profile:
        return Colors.purple;
      case NotificationCategory.document:
        return Colors.orange;
      case NotificationCategory.system:
        return Colors.grey;
      case NotificationCategory.promotion:
        return Colors.pink;
      case NotificationCategory.emergency:
        return Colors.red;
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }
}

class NotificationSettingsSheet extends StatefulWidget {
  const NotificationSettingsSheet({Key? key}) : super(key: key);

  @override
  State<NotificationSettingsSheet> createState() => _NotificationSettingsSheetState();
}

class _NotificationSettingsSheetState extends State<NotificationSettingsSheet> {
  final EnhancedNotificationService _notificationService = EnhancedNotificationService();
  Map<String, dynamic> _preferences = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    try {
      final prefs = await _notificationService.getNotificationPreferences('currentUserId');
      setState(() {
        _preferences = prefs;
        _isLoading = false;
      });
    } catch (e) {
      // Handle error
    }
  }

  Future<void> _updatePreference(String key, dynamic value) async {
    try {
      setState(() {
        _preferences[key] = value;
      });
      await _notificationService.updateNotificationPreferences('currentUserId', _preferences);
    } catch (e) {
      // Handle error
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const Text(
                'Notification Settings',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),
              Expanded(
                child: _isLoading
                    ? const Center(child: LoadingIndicator())
                    : ListView(
                        controller: scrollController,
                        children: [
                          _buildCategorySection('Rides', [
                            _buildSwitchTile(
                              'New Ride Requests',
                              _preferences['ride_requests'] ?? true,
                              (value) => _updatePreference('ride_requests', value),
                            ),
                            _buildSwitchTile(
                              'Ride Updates',
                              _preferences['ride_updates'] ?? true,
                              (value) => _updatePreference('ride_updates', value),
                            ),
                            _buildSwitchTile(
                              'Ride Completion',
                              _preferences['ride_completion'] ?? true,
                              (value) => _updatePreference('ride_completion', value),
                            ),
                          ]),
                          _buildCategorySection('Payments', [
                            _buildSwitchTile(
                              'Payment Received',
                              _preferences['payment_received'] ?? true,
                              (value) => _updatePreference('payment_received', value),
                            ),
                            _buildSwitchTile(
                              'Weekly Earnings',
                              _preferences['weekly_earnings'] ?? true,
                              (value) => _updatePreference('weekly_earnings', value),
                            ),
                          ]),
                          _buildCategorySection('Documents', [
                            _buildSwitchTile(
                              'Document Expiry',
                              _preferences['document_expiry'] ?? true,
                              (value) => _updatePreference('document_expiry', value),
                            ),
                            _buildSwitchTile(
                              'Verification Status',
                              _preferences['verification_status'] ?? true,
                              (value) => _updatePreference('verification_status', value),
                            ),
                          ]),
                          _buildCategorySection('System', [
                            _buildSwitchTile(
                              'App Updates',
                              _preferences['app_updates'] ?? true,
                              (value) => _updatePreference('app_updates', value),
                            ),
                            _buildSwitchTile(
                              'Maintenance Alerts',
                              _preferences['maintenance_alerts'] ?? true,
                              (value) => _updatePreference('maintenance_alerts', value),
                            ),
                          ]),
                          _buildCategorySection('Promotions', [
                            _buildSwitchTile(
                              'Special Offers',
                              _preferences['special_offers'] ?? true,
                              (value) => _updatePreference('special_offers', value),
                            ),
                            _buildSwitchTile(
                              'News & Updates',
                              _preferences['news_updates'] ?? true,
                              (value) => _updatePreference('news_updates', value),
                            ),
                          ]),
                        ],
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCategorySection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        ...children,
        const Divider(),
      ],
    );
  }

  Widget _buildSwitchTile(String title, bool value, Function(bool) onChanged) {
    return SwitchListTile(
      title: Text(title),
      value: value,
      onChanged: onChanged,
      activeColor: AppColors.primary,
    );
  }
}