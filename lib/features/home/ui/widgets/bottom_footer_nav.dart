import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:meal_app/core/theme/app_theme.dart';
import 'package:meal_app/features/profile/providers/referral_provider.dart';

class BuuttiiFooterNav extends StatelessWidget {
  const BuuttiiFooterNav({
    super.key,
    required this.currentIndex,
    required this.onHomeTap,
    required this.onWeekMenuTap,
    required this.onMealSkipTap,
    required this.onSettingsTap,
  });

  final int currentIndex;
  final VoidCallback onHomeTap;
  final VoidCallback onWeekMenuTap;
  final VoidCallback onMealSkipTap;
  final VoidCallback onSettingsTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfaceColor = isDark ? AppTheme.surfaceDark : Colors.white;
    final referralProvider = context.watch<ReferralProvider>();
    final showSettingsBadge = referralProvider.hasUnclaimedRewards;

    return ColoredBox(
      color: surfaceColor,
      child: SafeArea(
        top: false,
        minimum: EdgeInsets.zero,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            color: surfaceColor,
            border: isDark
                ? null
                : Border(
                    top: BorderSide(
                      color: Colors.grey.withValues(alpha: 0.10),
                    ),
                  ),
          ),
        child: Row(
          children: [
            Expanded(
              child: _FooterNavItem(
                icon: CupertinoIcons.house_fill,
                label: 'Home',
                isActive: currentIndex == 0,
                onTap: onHomeTap,
              ),
            ),
            Expanded(
              child: _FooterNavItem(
                icon: CupertinoIcons.calendar,
                label: 'Week Menu',
                isActive: currentIndex == 1,
                onTap: onWeekMenuTap,
              ),
            ),
            Expanded(
              child: _FooterNavItem(
                icon: CupertinoIcons.calendar_badge_minus,
                label: 'Meal Skip',
                isActive: currentIndex == 2,
                onTap: onMealSkipTap,
              ),
            ),
            Expanded(
              child: _FooterNavItem(
                icon: CupertinoIcons.gear_alt_fill,
                label: 'Settings',
                isActive: currentIndex == 3,
                onTap: onSettingsTap,
                showBadge: showSettingsBadge,
              ),
            ),
          ],
        ),
        ),
      ),
    );
  }
}

class _FooterNavItem extends StatelessWidget {
  const _FooterNavItem({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.isActive,
    this.showBadge = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isActive;
  final bool showBadge;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final activeColor = AppTheme.primaryColor;
    final inactiveColor = isDark ? Colors.white54 : AppTheme.textPrimaryLight.withValues(alpha: 0.55);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: isActive ? null : onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Icon(
                    icon,
                    size: 22,
                    color: isActive ? activeColor : inactiveColor,
                  ),
                  if (showBadge)
                    Positioned(
                      top: -1,
                      right: -2,
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 4),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  label,
                  maxLines: 1,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: isActive ? FontWeight.w800 : FontWeight.w600,
                    color: isActive ? activeColor : inactiveColor,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
