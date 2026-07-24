/// LoadingShimmer — Skeleton loading placeholder
library;

import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import '../constants/app_colors.dart';

class LoadingShimmer extends StatelessWidget {
  final int count;
  final double itemHeight;

  const LoadingShimmer({
    super.key,
    this.count = 6,
    this.itemHeight = 80,
  });

  static Widget grid({int count = 6, double childAspectRatio = 1.0}) {
    return _ShimmerGrid(count: count, childAspectRatio: childAspectRatio);
  }

  static Widget cardList({int count = 5, double height = 90}) {
    return LoadingShimmer(count: count, itemHeight: height);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Shimmer.fromColors(
      baseColor: isDark ? Colors.white.withOpacity(0.06) : AppColors.gray200,
      highlightColor:
          isDark ? Colors.white.withOpacity(0.15) : AppColors.gray50,
      child: ListView.builder(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        itemCount: count,
        itemBuilder: (_, __) => Container(
          margin: const EdgeInsets.only(bottom: 12),
          height: itemHeight,
          decoration: BoxDecoration(
            color: isDark ? Colors.white10 : Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    );
  }
}

class _ShimmerGrid extends StatelessWidget {
  final int count;
  final double childAspectRatio;

  const _ShimmerGrid({required this.count, required this.childAspectRatio});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Shimmer.fromColors(
      baseColor: isDark ? Colors.white.withOpacity(0.06) : AppColors.gray200,
      highlightColor:
          isDark ? Colors.white.withOpacity(0.15) : AppColors.gray50,
      child: GridView.builder(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: childAspectRatio,
        ),
        itemCount: count,
        itemBuilder: (_, __) => Container(
          decoration: BoxDecoration(
            color: isDark ? Colors.white10 : Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    );
  }
}

class ShimmerBox extends StatelessWidget {
  final double width;
  final double height;
  final double radius;

  const ShimmerBox({
    super.key,
    this.width = double.infinity,
    this.height = 16,
    this.radius = 8,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Shimmer.fromColors(
      baseColor: isDark ? Colors.white.withOpacity(0.06) : AppColors.gray200,
      highlightColor:
          isDark ? Colors.white.withOpacity(0.15) : AppColors.gray50,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: isDark ? Colors.white10 : Colors.white,
          borderRadius: BorderRadius.circular(radius),
        ),
      ),
    );
  }
}
