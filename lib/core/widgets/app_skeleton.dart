import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:meal_app/core/theme/app_theme.dart';

/// Shared shimmer “bone” used for modern skeleton placeholders.
class SkeletonBone extends StatelessWidget {
  final double? width;
  final double height;
  final BorderRadius borderRadius;

  const SkeletonBone({
    super.key,
    this.width,
    required this.height,
    this.borderRadius = const BorderRadius.all(Radius.circular(8)),
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final base = isDark ? Colors.white.withValues(alpha: 0.08) : Colors.grey.withValues(alpha: 0.22);
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: base,
        borderRadius: borderRadius,
      ),
    )
        .animate(onPlay: (c) => c.repeat())
        .shimmer(duration: 1600.ms, color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.white.withValues(alpha: 0.65));
  }
}

/// Row-shaped skeleton matching [HomeScreen] feature cards.
class FeatureCardSkeleton extends StatelessWidget {
  final bool isDark;

  const FeatureCardSkeleton({super.key, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 2),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.surfaceDark : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isDark ? Colors.white10 : Colors.grey.withValues(alpha: 0.1)),
      ),
      child: Row(
        children: [
          const SkeletonBone(width: 52, height: 52, borderRadius: BorderRadius.all(Radius.circular(18))),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SkeletonBone(width: MediaQuery.sizeOf(context).width * 0.45, height: 16, borderRadius: BorderRadius.circular(6)),
                const SizedBox(height: 8),
                SkeletonBone(width: MediaQuery.sizeOf(context).width * 0.62, height: 12, borderRadius: BorderRadius.circular(6)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Placeholder matching subscription upgrade entity cards.
class EntityUpgradeCardSkeleton extends StatelessWidget {
  final bool isDark;

  const EntityUpgradeCardSkeleton({super.key, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.surfaceDark : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isDark ? Colors.white10 : Colors.grey.withValues(alpha: 0.1)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const SkeletonBone(width: 48, height: 48, borderRadius: BorderRadius.all(Radius.circular(14))),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SkeletonBone(width: MediaQuery.sizeOf(context).width * 0.5, height: 18, borderRadius: BorderRadius.circular(6)),
                    const SizedBox(height: 8),
                    SkeletonBone(width: MediaQuery.sizeOf(context).width * 0.35, height: 12, borderRadius: BorderRadius.circular(6)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(child: SkeletonBone(height: 44, borderRadius: BorderRadius.circular(12))),
              const SizedBox(width: 10),
              Expanded(child: SkeletonBone(height: 44, borderRadius: BorderRadius.circular(12))),
            ],
          ),
        ],
      ),
    );
  }
}

/// Skeleton for trial/regular plan blocks (segment + two variant rows).
class PlanCatalogSkeleton extends StatelessWidget {
  final bool isDark;

  const PlanCatalogSkeleton({super.key, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SkeletonBone(width: 140, height: 18, borderRadius: BorderRadius.circular(6)),
        const SizedBox(height: 8),
        SkeletonBone(width: 220, height: 12, borderRadius: BorderRadius.circular(6)),
        const SizedBox(height: 16),
        SkeletonBone(height: 44, borderRadius: BorderRadius.circular(14)),
        const SizedBox(height: 16),
        _variantBlock(isDark),
        const SizedBox(height: 12),
        _variantBlock(isDark),
      ],
    );
  }

  Widget _variantBlock(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.surfaceDark : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.grey.withValues(alpha: 0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SkeletonBone(width: 160, height: 14, borderRadius: BorderRadius.circular(6)),
                    const SizedBox(height: 6),
                    SkeletonBone(width: 120, height: 12, borderRadius: BorderRadius.circular(6)),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  SkeletonBone(width: 72, height: 22, borderRadius: BorderRadius.circular(6)),
                  const SizedBox(height: 4),
                  SkeletonBone(width: 48, height: 10, borderRadius: BorderRadius.circular(6)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: SkeletonBone(height: 40, borderRadius: BorderRadius.circular(14))),
              const SizedBox(width: 10),
              Expanded(child: SkeletonBone(height: 40, borderRadius: BorderRadius.circular(14))),
            ],
          ),
        ],
      ),
    );
  }
}

/// Home “today’s meal” card — image area + text/button placeholders.
class TodayMealCardSkeleton extends StatelessWidget {
  final bool isDark;

  const TodayMealCardSkeleton({super.key, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            colors: isDark
                ? [const Color(0xFF1E293B), const Color(0xFF0F172A)]
                : [Colors.white, const Color(0xFFF8FAFC)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.grey.withValues(alpha: 0.1)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              child: const SkeletonBone(height: 140, borderRadius: BorderRadius.zero),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(child: SkeletonBone(height: 20, borderRadius: BorderRadius.circular(6))),
                      const SizedBox(width: 8),
                      SkeletonBone(width: 52, height: 22, borderRadius: BorderRadius.circular(8)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SkeletonBone(width: MediaQuery.sizeOf(context).width * 0.55, height: 12, borderRadius: BorderRadius.circular(6)),
                  const SizedBox(height: 14),
                  SkeletonBone(height: 44, borderRadius: BorderRadius.circular(14)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Weekly menu list card image + text placeholders.
class WeeklyMealCardSkeleton extends StatelessWidget {
  final double imageHeight;

  const WeeklyMealCardSkeleton({super.key, this.imageHeight = 112});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final width = MediaQuery.sizeOf(context).width;
    final bool useVerticalLayout = width > 750;

    if (useVerticalLayout) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        decoration: BoxDecoration(
          color: isDark ? AppTheme.surfaceDark : Colors.white,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.grey.withValues(alpha: 0.1), width: 1.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SkeletonBone(
              height: 180,
              width: double.infinity,
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      SkeletonBone(width: 50, height: 13, borderRadius: BorderRadius.circular(4)),
                      const Spacer(),
                      SkeletonBone(width: 80, height: 11, borderRadius: BorderRadius.circular(4)),
                    ],
                  ),
                  const SizedBox(height: 10),
                  SkeletonBone(width: double.infinity, height: 18, borderRadius: BorderRadius.circular(6)),
                  const SizedBox(height: 6),
                  SkeletonBone(width: width * 0.4, height: 18, borderRadius: BorderRadius.circular(6)),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      SkeletonBone(width: 70, height: 26, borderRadius: BorderRadius.circular(14)),
                      const SizedBox(width: 8),
                      SkeletonBone(width: 60, height: 26, borderRadius: BorderRadius.circular(14)),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    } else {
      return Container(
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(
          color: isDark ? AppTheme.surfaceDark : Colors.white,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.grey.withValues(alpha: 0.1), width: 1.5),
        ),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SkeletonBone(
                width: 112,
                height: 112,
                borderRadius: BorderRadius.all(Radius.circular(20)),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        SkeletonBone(width: 50, height: 13, borderRadius: BorderRadius.circular(4)),
                        const Spacer(),
                        SkeletonBone(width: 80, height: 11, borderRadius: BorderRadius.circular(4)),
                      ],
                    ),
                    const SizedBox(height: 10),
                    SkeletonBone(width: double.infinity, height: 18, borderRadius: BorderRadius.circular(6)),
                    const SizedBox(height: 6),
                    SkeletonBone(width: width * 0.3, height: 18, borderRadius: BorderRadius.circular(6)),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        SkeletonBone(width: 70, height: 26, borderRadius: BorderRadius.circular(14)),
                        const SizedBox(width: 8),
                        SkeletonBone(width: 60, height: 26, borderRadius: BorderRadius.circular(14)),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }
  }
}

/// Compact home row while cart totals are loading.
class HomeCartSummarySkeleton extends StatelessWidget {
  final bool isDark;

  const HomeCartSummarySkeleton({super.key, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.surfaceDark : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: isDark ? Colors.white10 : Colors.grey.withValues(alpha: 0.1)),
      ),
      child: Row(
        children: [
          const SkeletonBone(width: 44, height: 44, borderRadius: BorderRadius.all(Radius.circular(14))),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SkeletonBone(width: 120, height: 14, borderRadius: BorderRadius.circular(6)),
                const SizedBox(height: 8),
                SkeletonBone(width: MediaQuery.sizeOf(context).width * 0.45, height: 12, borderRadius: BorderRadius.circular(6)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
