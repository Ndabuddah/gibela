import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../constants/app_colors.dart';
import '../../providers/theme_provider.dart';
import 'modern_loading_indicator.dart';

/// Skeleton loader for list items
class SkeletonListLoader extends StatelessWidget {
  final int itemCount;
  final double itemHeight;
  final EdgeInsets? padding;

  const SkeletonListLoader({
    Key? key,
    this.itemCount = 5,
    this.itemHeight = 100,
    this.padding,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;

    return ListView.builder(
      padding: padding ?? const EdgeInsets.all(16),
      itemCount: itemCount,
      itemBuilder: (context, index) {
        return SkeletonCard(
          height: itemHeight,
          isDark: isDark,
        );
      },
    );
  }
}

/// Skeleton card widget
class SkeletonCard extends StatelessWidget {
  final double height;
  final bool isDark;

  const SkeletonCard({
    Key? key,
    this.height = 100,
    required this.isDark,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      height: height,
      decoration: BoxDecoration(
        color: AppColors.getCardColor(isDark),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.getBorderColor(isDark)),
      ),
      child: ShimmerLoading(
        isLoading: true,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  SkeletonBox(width: 60, height: 60, isDark: isDark),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SkeletonBox(width: double.infinity, height: 16, isDark: isDark),
                        const SizedBox(height: 8),
                        SkeletonBox(width: 150, height: 12, isDark: isDark),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SkeletonBox(width: double.infinity, height: 12, isDark: isDark),
              const SizedBox(height: 8),
              SkeletonBox(width: 200, height: 12, isDark: isDark),
            ],
          ),
        ),
      ),
    );
  }
}

/// Simple skeleton box
class SkeletonBox extends StatelessWidget {
  final double width;
  final double height;
  final bool isDark;
  final BorderRadius? borderRadius;

  const SkeletonBox({
    Key? key,
    required this.width,
    required this.height,
    required this.isDark,
    this.borderRadius,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[800] : Colors.grey[300],
        borderRadius: borderRadius ?? BorderRadius.circular(8),
      ),
    );
  }
}

/// Skeleton loader for ride card
class SkeletonRideCard extends StatelessWidget {
  final bool isDark;

  const SkeletonRideCard({
    Key? key,
    required this.isDark,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.getCardColor(isDark),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.getBorderColor(isDark)),
      ),
      child: ShimmerLoading(
        isLoading: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                SkeletonBox(width: 80, height: 20, isDark: isDark),
                const Spacer(),
                SkeletonBox(width: 60, height: 16, isDark: isDark),
              ],
            ),
            const SizedBox(height: 16),
            SkeletonBox(width: 200, height: 18, isDark: isDark),
            const SizedBox(height: 12),
            Row(
              children: [
                SkeletonBox(width: 16, height: 16, isDark: isDark),
                const SizedBox(width: 8),
                Expanded(
                  child: SkeletonBox(width: double.infinity, height: 14, isDark: isDark),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                SkeletonBox(width: 16, height: 16, isDark: isDark),
                const SizedBox(width: 8),
                Expanded(
                  child: SkeletonBox(width: double.infinity, height: 14, isDark: isDark),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                SkeletonBox(width: 100, height: 14, isDark: isDark),
                const Spacer(),
                SkeletonBox(width: 80, height: 20, isDark: isDark),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

