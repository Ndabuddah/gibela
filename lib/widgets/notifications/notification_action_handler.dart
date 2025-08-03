import 'package:flutter/material.dart';
import '../../models/notification_model.dart';
import '../../services/enhanced_notification_service.dart';

class NotificationActionHandler extends StatelessWidget {
  final NotificationModel notification;
  final VoidCallback? onActionComplete;

  const NotificationActionHandler({
    Key? key,
    required this.notification,
    this.onActionComplete,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (notification.actionData == null) {
      return const SizedBox.shrink();
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        if (notification.actionData!['primary_action'] != null)
          _buildActionButton(
            context,
            notification.actionData!['primary_action'],
            notification.actionData!['primary_action_color'] ?? Colors.blue,
            () => _handleAction(context, 'primary'),
          ),
        if (notification.actionData!['secondary_action'] != null)
          _buildActionButton(
            context,
            notification.actionData!['secondary_action'],
            notification.actionData!['secondary_action_color'] ?? Colors.grey,
            () => _handleAction(context, 'secondary'),
          ),
      ],
    );
  }

  Widget _buildActionButton(
    BuildContext context,
    String text,
    Color color,
    VoidCallback onPressed,
  ) {
    return Padding(
      padding: const EdgeInsets.only(left: 8),
      child: TextButton(
        onPressed: onPressed,
        style: TextButton.styleFrom(
          foregroundColor: color,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: color.withOpacity(0.5)),
          ),
        ),
        child: Text(text),
      ),
    );
  }

  Future<void> _handleAction(BuildContext context, String actionType) async {
    try {
      final service = EnhancedNotificationService();
      await service.handleNotificationAction(notification.id, actionType);
      onActionComplete?.call();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error performing action: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}