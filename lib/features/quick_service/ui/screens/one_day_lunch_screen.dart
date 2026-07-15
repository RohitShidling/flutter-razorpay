import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:meal_app/core/theme/app_theme.dart';
import 'package:meal_app/features/home/providers/menu_provider.dart';
import 'package:meal_app/features/quick_service/providers/quick_service_provider.dart';
import 'package:meal_app/features/bulk_order/providers/bulk_order_provider.dart';
import 'package:meal_app/features/bulk_order/ui/widgets/bulk_order_address_section.dart';
import 'package:meal_app/features/quick_service/ui/widgets/quick_service_checkout.dart';
import 'package:meal_app/features/bulk_order/data/models/bulk_delivery_address.dart';
import 'package:meal_app/core/utils/time_utils.dart';
import 'package:meal_app/core/widgets/responsive_layout.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Returns true if the current time is BEFORE the cutoff (e.g. "09:00").
/// When false, today ordering is closed.
bool _isTodayOrderOpen(String cutoffHhmm) {
  final parts = cutoffHhmm.split(':');
  if (parts.length < 2) return false;
  final cutoffH = int.tryParse(parts[0]) ?? 0;
  final cutoffM = int.tryParse(parts[1]) ?? 0;
  final now = TimeOfDay.now();
  final nowMins = now.hour * 60 + now.minute;
  final cutoffMins = cutoffH * 60 + cutoffM;
  return nowMins < cutoffMins;
}

/// Returns tomorrow's date as "YYYY-MM-DD".
String _tomorrowYmd() {
  final t = DateTime.now().add(const Duration(days: 1));
  return '${t.year}-${t.month.toString().padLeft(2, '0')}-${t.day.toString().padLeft(2, '0')}';
}

/// Returns true when today is Sunday (no deliveries).
bool _isTodaySunday() => DateTime.now().weekday == DateTime.sunday;

/// Returns true when tomorrow is Sunday (no deliveries).
bool _isTomorrowSunday() =>
    DateTime.now().add(const Duration(days: 1)).weekday == DateTime.sunday;

/// Returns true when the menu map has non-blank item text.
bool _hasMenuItems(Map<String, dynamic>? menu) {
  if (menu == null) return false;
  final items = menu['items']?.toString().trim() ?? '';
  final name = menu['name']?.toString().trim() ?? '';
  return items.isNotEmpty || name.isNotEmpty;
}

// ---------------------------------------------------------------------------
// Screen
// ---------------------------------------------------------------------------

class OneDayLunchScreen extends StatefulWidget {
  const OneDayLunchScreen({super.key});

  @override
  State<OneDayLunchScreen> createState() => _OneDayLunchScreenState();
}

class _OneDayLunchScreenState extends State<OneDayLunchScreen> {
  late String _deliveryType;
  int _quantity = 1;

  @override
  void initState() {
    super.initState();
    // Set a smart initial delivery type before config loads:
    // - If today is Saturday, tomorrow is Sunday (no delivery) → start with 'today'
    // - Otherwise default to 'next_day'
    _deliveryType = _isTomorrowSunday() ? 'today' : 'next_day';
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadData());
  }

  Future<void> _loadData() async {
      if (!mounted) return;
      final p = context.read<QuickServiceProvider>();
      final bulk = context.read<BulkOrderProvider>();
      final menu = context.read<MenuProvider>();

      // Always force-refresh config — cutoff time is real-time admin data.
      // Running in parallel with the other fetches for speed.
      await Future.wait([
        p.loadOneDayConfig(),                          // always fresh
        bulk.loadSavedDeliveryAddress(),
        if (menu.todayMenu == null) menu.fetchTodayMenu(silent: true),
        menu.fetchWeeklyMenuSilent(),
      ]);

      if (!mounted) return;
      final addr = bulk.deliveryAddress;
      if (addr != null) {
        final addressWithoutTime = BulkDeliveryAddress(
          id: addr.id,
          label: addr.label,
          stateId: addr.stateId,
          cityId: addr.cityId,
          addressLine: addr.addressLine,
          pincode: addr.pincode,
          stateName: addr.stateName,
          cityName: addr.cityName,
          isDefault: addr.isDefault,
          deliveryTime: null,
          phoneNumber: addr.phoneNumber,
          altPhoneNumber: addr.altPhoneNumber,
        );
        bulk.setDeliveryAddress(addressWithoutTime);
        p.setAddress(addressWithoutTime);
      }

      final todayMenu = menu.todayMenu;
      p.setTodayMenu(todayMenu == null ? null : Map<String, dynamic>.from(todayMenu));

      // Re-evaluate cutoff now that fresh config is loaded.
      if (mounted) {
        final cfg = p.oneDayConfig;
        final cutoff = cfg?['today_cutoff_time']?.toString() ?? '09:00';
        final todayOpen = _isTodayOrderOpen(cutoff);
        final todaySunday = _isTodaySunday();
        final tomorrowSunday = _isTomorrowSunday();

        setState(() {
          if (tomorrowSunday) {
            // Next-day is Sunday (no delivery) → must use today
            // Only switch to today if the order window is still open AND today isn't Sunday
            if (todayOpen && !todaySunday) {
              _deliveryType = 'today';
            } else {
              // Both options unavailable; keep next_day so the UI correctly shows "closed"
              _deliveryType = 'next_day';
            }
          } else if (_deliveryType == 'today' && (!todayOpen || todaySunday)) {
            // Today's window closed or today is Sunday → switch to next_day
            _deliveryType = 'next_day';
          }
        // If next_day is fine and currently selected, keep it.
        });
      }
  }


  Future<void> _pay() async {
    await QuickServiceCheckout.payOneDayLunch(
      context,
      deliveryType: _deliveryType,
      quantity: _quantity,
      skipAddressPrompt: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final pageBg = isDark ? AppTheme.backgroundDark : Colors.white;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: AppTheme.overlayFor(background: pageBg, isDark: isDark),
      child: Scaffold(
      backgroundColor: pageBg,
      appBar: AppBar(
        title: const Text('One Day Lunch'),
        backgroundColor: pageBg,
        surfaceTintColor: Colors.transparent,
        systemOverlayStyle: AppTheme.overlayFor(background: pageBg, isDark: isDark),
      ),
      body: SafeArea(
        top: false,
        child: Selector<QuickServiceProvider,
            ({bool isLoading, Map<String, dynamic>? cfg, Map<String, dynamic>? menu, String? error})>(
          selector: (_, p) => (
            isLoading: p.isLoading,
            cfg: p.oneDayConfig,
            menu: p.todayMenu,
            error: p.error,
          ),
          builder: (context, data, _) {
            if (data.isLoading && data.cfg == null) {
              return const Center(child: CircularProgressIndicator());
            }
            if (data.cfg == null) {
              return Center(child: Text(data.error ?? 'Service unavailable'));
            }
            // Pick tomorrow's menu from weekly list
            final weeklyMenu = context.read<MenuProvider>().weeklyMenu;
            final tomorrowYmd = _tomorrowYmd();
            Map<String, dynamic>? tomorrowMenu;
            for (final entry in weeklyMenu) {
              if (entry is! Map) continue;
              final raw = entry['menu_date'] ?? entry['date'] ?? entry['delivery_date'] ?? entry['for_date'];
              final dateStr = raw?.toString() ?? '';
              final ymd = dateStr.contains('T') ? dateStr.split('T').first : dateStr;
              if (ymd == tomorrowYmd) {
                tomorrowMenu = Map<String, dynamic>.from(entry);
                break;
              }
            }

            return ResponsiveContainer(
              child: _OneDayLunchBody(
                cfg: data.cfg!,
                todayMenu: data.menu,
                tomorrowMenu: tomorrowMenu,
                isDark: isDark,
                deliveryType: _deliveryType,
                quantity: _quantity,
                isLoading: data.isLoading,
                onDeliveryTypeChanged: (v) => setState(() => _deliveryType = v),
                onQuantityChanged: (v) => setState(() => _quantity = v),
                onPay: _pay,
              ),
            );
          },
        ),
      ),
    ),
    );
  }
}

// ---------------------------------------------------------------------------
// Body — separated so address section stays mounted on setState
// ---------------------------------------------------------------------------

class _OneDayLunchBody extends StatelessWidget {
  const _OneDayLunchBody({
    required this.cfg,
    required this.todayMenu,
    required this.tomorrowMenu,
    required this.isDark,
    required this.deliveryType,
    required this.quantity,
    required this.isLoading,
    required this.onDeliveryTypeChanged,
    required this.onQuantityChanged,
    required this.onPay,
  });

  final Map<String, dynamic> cfg;
  final Map<String, dynamic>? todayMenu;
  final Map<String, dynamic>? tomorrowMenu;
  final bool isDark;
  final String deliveryType;
  final int quantity;
  final bool isLoading;
  final ValueChanged<String> onDeliveryTypeChanged;
  final ValueChanged<int> onQuantityChanged;
  final VoidCallback onPay;

  @override
  Widget build(BuildContext context) {
    final todayPrice = double.tryParse(cfg['today_price']?.toString() ?? '') ?? 100.0;
    final nextDayPrice = double.tryParse(cfg['next_day_price']?.toString() ?? '') ?? 90.0;
    final cutoff = cfg['today_cutoff_time']?.toString() ?? '09:00';
    final todayCutoffOpen = _isTodayOrderOpen(cutoff);
    final todaySunday = _isTodaySunday();
    final tomorrowSunday = _isTomorrowSunday();

    // Today option is disabled when: cutoff passed OR today is Sunday
    final todayDisabled = !todayCutoffOpen || todaySunday;
    // Next-day option is disabled when tomorrow is Sunday
    final nextDayDisabled = tomorrowSunday;

    final selectedPrice = deliveryType == 'today' ? todayPrice : nextDayPrice;
    final total = selectedPrice * quantity;
    final activeMenu = deliveryType == 'today' ? todayMenu : tomorrowMenu;

    // Determine subtitle messages
    String todaySubtitle;
    if (todaySunday) {
      todaySubtitle = 'No delivery on Sundays';
    } else if (!todayCutoffOpen) {
      todaySubtitle = 'Order window closed';
    } else {
      todaySubtitle = '₹${todayPrice.toStringAsFixed(0)} / meal · order before ${TimeUtils.formatToDisplay(cutoff)}';
    }

    final nextDaySubtitle = tomorrowSunday
        ? 'No delivery on Sundays'
        : '₹${nextDayPrice.toStringAsFixed(0)} / meal';

    // Pay is only allowed when menu is available AND selected day is not Sunday
    final selectedDaySunday =
        (deliveryType == 'today' && todaySunday) ||
        (deliveryType == 'next_day' && tomorrowSunday);
    final menuAvailable = _hasMenuItems(activeMenu);
    final canPay = !isLoading && menuAvailable && !selectedDaySunday;

    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              // ── Meal card ─────────────────────────────────────────────
              _MenuCard(
                menu: activeMenu,
                label: deliveryType == 'today' ? "Today's meal" : "Tomorrow's meal",
                isDark: isDark,
                isSunday: selectedDaySunday,
              ),
              const SizedBox(height: 16),

              // ── Delivery type ─────────────────────────────────────────
              _OptionTile(
                title: 'Next Day',
                subtitle: nextDaySubtitle,
                selected: deliveryType == 'next_day',
                disabled: nextDayDisabled,
                onTap: nextDayDisabled ? null : () => onDeliveryTypeChanged('next_day'),
              ),
              const SizedBox(height: 10),
              _OptionTile(
                title: 'Today',
                subtitle: todaySubtitle,
                selected: deliveryType == 'today',
                disabled: todayDisabled,
                onTap: todayDisabled ? null : () => onDeliveryTypeChanged('today'),
              ),
              const SizedBox(height: 20),

              // ── Quantity ──────────────────────────────────────────────
              Row(
                children: [
                  const Text('Quantity', style: TextStyle(fontWeight: FontWeight.w700)),
                  const Spacer(),
                  IconButton(
                    onPressed: quantity > 1 ? () => onQuantityChanged(quantity - 1) : null,
                    icon: const Icon(CupertinoIcons.minus_circle),
                  ),
                  Text('$quantity',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                  IconButton(
                    onPressed: () => onQuantityChanged(quantity + 1),
                    icon: const Icon(CupertinoIcons.plus_circle),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // ── Delivery address — single const widget, stays alive ───
              const BulkOrderAddressSection(showDeliveryTime: true),
              const SizedBox(height: 20),

              // ── Total ─────────────────────────────────────────────────
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    const Text('Total', style: TextStyle(fontWeight: FontWeight.w700)),
                    const Spacer(),
                    Text(
                      '₹${total.toStringAsFixed(0)}',
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: AppTheme.primaryColor,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // ── Pay button ────────────────────────────────────────────
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: canPay ? onPay : null,
                  child: isLoading
                      ? const SizedBox(
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : Text(
                          selectedDaySunday
                              ? 'No Delivery on Sunday'
                              : (!menuAvailable ? 'Menu Not Available' : 'Pay & Order'),
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                        ),
                ),
              ),
              const SizedBox(height: 16),
            ]),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Menu card widget
// ---------------------------------------------------------------------------

class _MenuCard extends StatelessWidget {
  const _MenuCard({
    required this.menu,
    required this.label,
    required this.isDark,
    this.isSunday = false,
  });

  final Map<String, dynamic>? menu;
  final String label;
  final bool isDark;
  final bool isSunday;

  @override
  Widget build(BuildContext context) {
    final subtitleColor = isDark ? Colors.white60 : const Color(0xFF64748B);
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppTheme.surfaceDark : const Color(0xFFFAF8F5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.white10 : Colors.grey.withValues(alpha: 0.15),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (menu?['image_url'] != null)
            ColoredBox(
              color: isDark ? AppTheme.surfaceDark : const Color(0xFFF7F2EA),
              child: CachedNetworkImage(
                imageUrl: menu!['image_url'].toString(),
                height: 150,
                width: double.infinity,
                fit: BoxFit.contain,
                placeholder: (_, __) => const SizedBox(
                  height: 150,
                  width: double.infinity,
                  child: Center(child: CupertinoActivityIndicator()),
                ),
                errorWidget: (_, __, ___) => const SizedBox(
                  height: 150,
                  width: double.infinity,
                  child: Center(child: Icon(CupertinoIcons.photo, color: Colors.grey)),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.primaryColor,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  isSunday
                      ? 'No deliveries on Sundays'
                      : (menu != null
                          ? (menu!['items']?.toString() ??
                              menu!['name']?.toString() ??
                              'Menu available')
                          : 'Menu not available yet'),
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: isSunday
                        ? Colors.orange.shade700
                        : (isDark ? Colors.white : const Color(0xFF1B1C1C)),
                  ),
                ),
                if (isSunday)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      'Please select a weekday for delivery.',
                      style: TextStyle(fontSize: 12, color: subtitleColor),
                    ),
                  )
                else if (menu == null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      'Check back later for the menu.',
                      style: TextStyle(fontSize: 12, color: subtitleColor),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Option tile
// ---------------------------------------------------------------------------

class _OptionTile extends StatelessWidget {
  const _OptionTile({
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.disabled,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final bool selected;
  final bool disabled;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final effectiveColor = disabled
        ? Colors.grey.shade400
        : (selected ? AppTheme.primaryColor : Colors.grey);

    // Dark-mode safe background for unselected/disabled tiles
    final tileBg = isDark
        ? Colors.white.withValues(alpha: 0.06)
        : Colors.grey.shade100;

    return GestureDetector(
      onTap: disabled ? null : onTap,
      child: Container(
        decoration: BoxDecoration(
          color: disabled
              ? tileBg
              : (selected
                  ? AppTheme.primaryColor.withValues(alpha: isDark ? 0.14 : 0.1)
                  : tileBg),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected && !disabled
                ? AppTheme.primaryColor.withValues(alpha: 0.4)
                : Colors.transparent,
            width: 1.5,
          ),
        ),
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Icon(
              selected && !disabled
                  ? CupertinoIcons.checkmark_circle_fill
                  : CupertinoIcons.circle,
              color: effectiveColor,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                      color: disabled
                          ? (isDark ? Colors.white38 : Colors.grey.shade500)
                          : null,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: disabled
                          ? (isDark ? Colors.white30 : Colors.grey.shade400)
                          : (isDark ? Colors.white60 : Colors.grey.shade700),
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            if (disabled)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Closed',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: Colors.grey.shade600,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
