import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:meal_app/core/providers/meal_provider.dart';
import 'package:meal_app/core/theme/app_theme.dart';
import 'package:meal_app/features/quick_service/providers/quick_service_provider.dart';
import 'package:meal_app/features/quick_service/ui/screens/one_day_lunch_screen.dart';
import 'package:meal_app/features/quick_service/ui/screens/special_dishes_screen.dart';

class QuickOrderSection extends StatefulWidget {
  const QuickOrderSection({super.key, this.forceVertical = false});

  final bool forceVertical;

  @override
  State<QuickOrderSection> createState() => _QuickOrderSectionState();
}

class _QuickOrderSectionState extends State<QuickOrderSection> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<QuickServiceProvider>().loadOneDayConfig();
      context.read<QuickServiceProvider>().loadSpecialConfig();
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final provider = context.watch<QuickServiceProvider>();
    if (provider.error != null) {
      debugPrint('QuickOrderSection load error: ${provider.error}');
    }
    final cfg = provider.oneDayConfig;
    final specialCfg = provider.specialConfig;

    final oneDayActive = cfg?['is_active'] == true;
    final specialActive = specialCfg?['is_active'] == true;

    if (!oneDayActive && !specialActive) {
      return const SizedBox.shrink();
    }

    final status = context.watch<MealProvider>().subscriptionStatusData;
    final hasActive = status?['has_active_subscription'] == true;
    final showSubscriberBadge = !hasActive;

    final todayPrice = double.tryParse(cfg?['today_price']?.toString() ?? '') ?? 100.0;
    final nextDayPrice = double.tryParse(cfg?['next_day_price']?.toString() ?? '') ?? 90.0;
    final cutoff = cfg?['today_cutoff_time']?.toString() ?? '09:00';

    final titleColor = isDark ? Colors.white : AppTheme.textPrimaryLight;
    final cardBg = isDark ? AppTheme.surfaceDark : Colors.white;
    final borderColor = isDark ? AppTheme.borderDark : AppTheme.borderLight;

    final List<Widget> activeCards = [];
    if (oneDayActive) {
      activeCards.add(
        _OneDayLunchCard(
          isDark: isDark,
          cardBg: cardBg,
          borderColor: borderColor,
          todayPrice: todayPrice,
          nextDayPrice: nextDayPrice,
          cutoff: cutoff,
          enabled: true,
          onOrder: () {
            Navigator.push(
              context,
              CupertinoPageRoute(builder: (_) => const OneDayLunchScreen()),
            );
          },
        ),
      );
    }

    if (specialActive) {
      activeCards.add(
        _SpecialsCard(
          isDark: isDark,
          onTap: () {
            Navigator.push(
              context,
              CupertinoPageRoute(builder: (_) => const SpecialDishesScreen()),
            );
          },
        ),
      );
    }

    final isVertical = widget.forceVertical || (MediaQuery.sizeOf(context).width < 360);

    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Quick Order',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: titleColor,
                ),
              ),
              if (showSubscriberBadge) ...[
                const SizedBox(width: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFDCFCE7),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'No active plan?',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF166534),
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),
          if (isVertical)
            Column(
              children: [
                if (activeCards.isNotEmpty)
                  activeCards.length == 1
                      ? SizedBox(height: 220, child: activeCards[0])
                      : activeCards[0],
                if (activeCards.length > 1) ...[
                  const SizedBox(height: 12),
                  activeCards[1],
                ],
              ],
            )
          else
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (activeCards.length == 1)
                    Expanded(child: activeCards[0])
                  else ...[
                    Expanded(child: activeCards[0]),
                    const SizedBox(width: 12),
                    Expanded(child: activeCards[1]),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _OneDayLunchCard extends StatelessWidget {
  const _OneDayLunchCard({
    required this.isDark,
    required this.cardBg,
    required this.borderColor,
    required this.todayPrice,
    required this.nextDayPrice,
    required this.cutoff,
    required this.enabled,
    required this.onOrder,
  });

  final bool isDark;
  final Color cardBg;
  final Color borderColor;
  final double todayPrice;
  final double nextDayPrice;
  final String cutoff;
  final bool enabled;
  final VoidCallback onOrder;

  @override
  Widget build(BuildContext context) {
    final titleColor = isDark ? Colors.white : AppTheme.textPrimaryLight;
    final subtitleColor = isDark ? Colors.white60 : const Color(0xFF64748B);
    final purpleColor = const Color(0xFF7C3AED);

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: enabled ? onOrder : null,
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: borderColor, width: 1.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            color: const Color(0xFFF3E8FF),
                            shape: BoxShape.circle,
                            border: Border.all(color: purpleColor.withValues(alpha: 0.3)),
                          ),
                          child: Icon(CupertinoIcons.bag, size: 16, color: purpleColor),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'One Day Lunch',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: titleColor,
                            ),
                          ),
                        ),
                        Icon(CupertinoIcons.chevron_right, size: 14, color: Colors.grey.shade500),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Choose today or tomorrow, size, time, and address.',
                      style: TextStyle(fontSize: 13, height: 1.35, color: subtitleColor),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: purpleColor.withValues(alpha: isDark ? 0.2 : 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    'Order now',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: purpleColor,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SpecialsCard extends StatelessWidget {
  const _SpecialsCard({
    required this.isDark,
    required this.onTap,
  });

  final bool isDark;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bg = isDark ? AppTheme.surfaceDark : Colors.white;
    final borderCol = isDark ? AppTheme.borderDark : AppTheme.borderLight;
    final titleColor = isDark ? Colors.white : AppTheme.textPrimaryLight;
    final subtitleColor = isDark ? Colors.white60 : const Color(0xFF64748B);
    final orangeColor = const Color(0xFFFF5722);
    final lightOrange = orangeColor.withValues(alpha: 0.12);

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: borderCol, width: 1.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            color: lightOrange,
                            shape: BoxShape.circle,
                            border: Border.all(color: orangeColor.withValues(alpha: 0.3)),
                          ),
                          child: Icon(CupertinoIcons.star_fill, size: 16, color: orangeColor),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Buuttii Specials',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: titleColor,
                            ),
                          ),
                        ),
                        Icon(CupertinoIcons.chevron_right, size: 14, color: Colors.grey.shade500),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Special dishes with categories, prices & quantities.',
                      style: TextStyle(fontSize: 13, height: 1.35, color: subtitleColor),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: lightOrange,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    'Browse & order',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: orangeColor,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
