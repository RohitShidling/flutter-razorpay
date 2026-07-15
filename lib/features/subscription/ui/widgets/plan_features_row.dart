import 'package:flutter/material.dart';
import 'package:meal_app/core/theme/app_theme.dart';

/// Horizontal, scrollable plan feature chips (single row).
class PlanFeaturesRow extends StatelessWidget {
  final List<String> features;
  final bool isDark;

  const PlanFeaturesRow({
    super.key,
    required this.features,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    if (features.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      height: 34,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: features.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final text = features[i].trim();
          if (text.isEmpty) return const SizedBox.shrink();
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF282828) : const Color(0xFFF0EBE1),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isDark ? const Color(0xFF383838) : const Color(0xFFE0D8C8),
              ),
            ),
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white.withValues(alpha: 0.92) : AppTheme.textPrimaryLight,
              ),
            ),
          );
        },
      ),
    );
  }
}
