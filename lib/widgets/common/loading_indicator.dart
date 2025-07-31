// lib/widgets/loading_indicator.dart
import 'package:flutter/material.dart';

import '../../constants/app_colors.dart';
import '../../models/user_model.dart';

class LoadingIndicator extends StatelessWidget {
  final Color? color;
  final String? message;

  const LoadingIndicator({
    Key? key,
    this.color,
    this.message,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      color: Colors.black.withOpacity(0.5),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(
              color: color ?? AppColors.primary,
            ),
            if (message != null)
              Padding(
                padding: const EdgeInsets.only(top: 16.0),
                child: Text(
                  message!,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// lib/widgets/user_avatar.dart

class UserAvatar extends StatelessWidget {
  final UserModel userModel;
  final double size;
  final VoidCallback? onTap;
  final Color? borderColor;
  final double borderWidth;

  const UserAvatar({
    Key? key,
    required this.userModel,
    this.size = 50,
    this.onTap,
    this.borderColor,
    this.borderWidth = 0,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: borderWidth > 0
              ? Border.all(
                  color: borderColor ?? AppColors.primary,
                  width: borderWidth,
                )
              : null,
        ),
        child: _buildAvatar(),
      ),
    );
  }

  Widget _buildAvatar() {
    // If user has a photo URL
    if (userModel.photoUrl != null && userModel.photoUrl!.isNotEmpty) {
      return ClipOval(
        child: Image.network(
          userModel.photoUrl!,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            // Fallback to initials if image fails to load
            return _buildInitialsAvatar();
          },
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return Center(
              child: CircularProgressIndicator(
                color: AppColors.primary,
                value: loadingProgress.expectedTotalBytes != null ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes! : null,
              ),
            );
          },
        ),
      );
    } else {
      // If no photo URL, use initials
      return _buildInitialsAvatar();
    }
  }

  Widget _buildInitialsAvatar() {
    // Get initials from name (first letter of first and last name)
    String initials = '';
    if (userModel.name.isNotEmpty) {
      final nameParts = userModel.name.split(' ');
      if (nameParts.length > 1) {
        // First letter of first name + first letter of last name
        initials = nameParts.first[0] + nameParts.last[0];
      } else {
        // Just first letter of name
        initials = nameParts.first[0];
      }
      initials = initials.toUpperCase();
    }

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: _getAvatarColor(userModel.uid),
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          initials,
          style: TextStyle(
            color: Colors.white,
            fontSize: size * 0.4,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  // Generate a consistent color based on the user ID
  Color _getAvatarColor(String uid) {
    final List<Color> colors = [
      Colors.blueAccent,
      Colors.redAccent,
      Colors.greenAccent,
      Colors.purpleAccent,
      Colors.orangeAccent,
      Colors.tealAccent,
              AppColors.primary,
        AppColors.secondary,
    ];

    // Simple hash function to get a stable index
    int hashCode = uid.hashCode;
    int index = hashCode.abs() % colors.length;

    return colors[index];
  }
}
