import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import '../../constants/app_colors.dart';
import '../../providers/theme_provider.dart';
import 'package:provider/provider.dart';

/// Skeleton loader widget for loading states
class SkeletonLoader extends StatelessWidget {
  final double width;
  final double height;
  final BorderRadius? borderRadius;

  const SkeletonLoader({
    Key? key,
    required this.width,
    required this.height,
    this.borderRadius,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isDark = Provider.of<ThemeProvider>(context).isDarkMode;
    
    return Shimmer.fromColors(
      baseColor: isDark ? AppColors.darkCard : AppColors.uberGreyLight,
      highlightColor: isDark ? AppColors.darkSurface : AppColors.white,
      period: const Duration(milliseconds: 1200),
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkCard : AppColors.uberGreyLight,
          borderRadius: borderRadius ?? BorderRadius.circular(8),
        ),
      ),
    );
  }
}

/// Skeleton card for ride history items
class SkeletonRideCard extends StatelessWidget {
  const SkeletonRideCard({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Provider.of<ThemeProvider>(context).isDarkMode
            ? AppColors.darkCard
            : AppColors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const SkeletonLoader(width: 60, height: 60, borderRadius: BorderRadius.all(Radius.circular(30))),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SkeletonLoader(width: 120, height: 16),
                    const SizedBox(height: 8),
                    const SkeletonLoader(width: 80, height: 14),
                  ],
                ),
              ),
              const SkeletonLoader(width: 60, height: 20),
            ],
          ),
          const SizedBox(height: 16),
          const SkeletonLoader(width: double.infinity, height: 1),
          const SizedBox(height: 12),
          const SkeletonLoader(width: 150, height: 14),
        ],
      ),
    );
  }
}

/// Skeleton list for ride history
class SkeletonRideList extends StatelessWidget {
  final int itemCount;
  
  const SkeletonRideList({Key? key, this.itemCount = 5}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: itemCount,
      itemBuilder: (context, index) => const SkeletonRideCard(),
    );
  }
}

/// Skeleton for earnings card
class SkeletonEarningsCard extends StatelessWidget {
  const SkeletonEarningsCard({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Provider.of<ThemeProvider>(context).isDarkMode
            ? AppColors.darkCard
            : AppColors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SkeletonLoader(width: 120, height: 16),
          const SizedBox(height: 16),
          const SkeletonLoader(width: 150, height: 32),
          const SizedBox(height: 8),
          const SkeletonLoader(width: 100, height: 14),
        ],
      ),
    );
  }
}

/// Skeleton for driver card
class SkeletonDriverCard extends StatelessWidget {
  const SkeletonDriverCard({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Provider.of<ThemeProvider>(context).isDarkMode
            ? AppColors.darkCard
            : AppColors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          const SkeletonLoader(width: 60, height: 60, borderRadius: BorderRadius.all(Radius.circular(30))),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SkeletonLoader(width: 150, height: 18),
                const SizedBox(height: 8),
                const SkeletonLoader(width: 100, height: 14),
                const SizedBox(height: 4),
                const SkeletonLoader(width: 80, height: 14),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
