import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:meal_app/core/theme/app_theme.dart';
import 'package:meal_app/features/bulk_order/providers/bulk_order_provider.dart';
import 'package:meal_app/features/bulk_order/ui/screens/bulk_order_standard_screen.dart';
import 'package:meal_app/features/bulk_order/ui/screens/bulk_order_variety_categories_screen.dart';
import 'package:meal_app/features/bulk_order/ui/widgets/bulk_order_widgets.dart';
import 'package:meal_app/core/widgets/responsive_layout.dart';

/// Entry point: user picks standard (< threshold) or large variety (50+) flow.
class BulkOrderHubScreen extends StatefulWidget {
  const BulkOrderHubScreen({super.key});

  @override
  State<BulkOrderHubScreen> createState() => _BulkOrderHubScreenState();
}

class _BulkOrderHubScreenState extends State<BulkOrderHubScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final p = context.read<BulkOrderProvider>();
      await p.loadSavedDeliveryAddress();
      await p.loadConfig(force: true);
      await p.loadCartFromServer();
      final cfg = p.config;
      if (cfg != null && cfg.earliestDeliveryDate.length >= 10) {
        await p.loadMenusForDate(cfg.earliestDeliveryDate);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<BulkOrderProvider>();
    final cfg = p.config;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: AppTheme.overlayFor(
        background: isDark ? AppTheme.surfaceDark : const Color(0xFFF3EBE0),
        isDark: isDark,
        navigationBarColor: isDark ? AppTheme.surfaceDark : const Color(0xFFFAF8F5),
      ),
      child: Scaffold(
        backgroundColor: isDark ? AppTheme.surfaceDark : const Color(0xFFFAF8F5),
        appBar: AppBar(
          backgroundColor: isDark ? AppTheme.surfaceDark : const Color(0xFFF3EBE0),
          elevation: 0,
          scrolledUnderElevation: 0,
          centerTitle: true,
          title: Text(
            'Bulk Order',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: isDark ? Colors.white : const Color(0xFF5A4D42),
            ),
          ),
          leading: IconButton(
            icon: const Icon(CupertinoIcons.back, color: Color(0xFF8B7A66)),
            onPressed: () => Navigator.pop(context),
          ),
          systemOverlayStyle: AppTheme.overlayFor(
            background: isDark ? AppTheme.surfaceDark : const Color(0xFFF3EBE0),
            isDark: isDark,
            navigationBarColor: isDark ? AppTheme.surfaceDark : const Color(0xFFFAF8F5),
          ),
        ),
        body: SafeArea(
          top: false,
          child: Column(
            children: [
            Expanded(
              child: cfg == null || (p.isLoading && !cfg.isStandardActive && !cfg.isVarietyActive)
                  ? (p.error != null
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24.0),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  CupertinoIcons.exclamationmark_triangle_fill,
                                  size: 48,
                                  color: isDark ? Colors.orangeAccent : Colors.orange.shade700,
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  p.error!,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: isDark ? Colors.white70 : const Color(0xFF5A4D42),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      : const Center(child: CupertinoActivityIndicator()))
                  : (!cfg.isStandardActive && !cfg.isVarietyActive)
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24.0),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  CupertinoIcons.info_circle_fill,
                                  size: 48,
                                  color: isDark ? Colors.white54 : const Color(0xFF8B7A66),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'Bulk ordering is currently unavailable.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: isDark ? Colors.white70 : const Color(0xFF5A4D42),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      : ResponsiveContainer(
                              child: SingleChildScrollView(
                                padding: const EdgeInsets.all(20),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                  Text(
                                    cfg.hubIntroText?.isNotEmpty == true
                                        ? cfg.hubIntroText!
                                        : 'Choose the type of bulk order that fits your group size.',
                                    style: TextStyle(
                                      fontSize: 15,
                                      height: 1.45,
                                      color: isDark ? Colors.white70 : AppTheme.textSecondaryLight,
                                    ),
                                  ),
                                  const SizedBox(height: 24),
                                  if (cfg.isStandardActive) ...[
                                    BulkOrderTypeCard(
                                      title: cfg.standardTierTitle?.isNotEmpty == true
                                          ? cfg.standardTierTitle!
                                          : 'Standard bulk',
                                      subtitle: cfg.standardTierSubtitle?.isNotEmpty == true
                                          ? cfg.standardTierSubtitle!
                                          : '${cfg.minQuantity}+ meals',
                                      detail: cfg.standardTierDescription?.isNotEmpty == true
                                          ? cfg.standardTierDescription!
                                          : 'One meal for your delivery date — the same dish for everyone.',
                                      icon: CupertinoIcons.person_3_fill,
                                      color: AppTheme.primaryColor,
                                      onTap: () => Navigator.push(
                                        context,
                                        CupertinoPageRoute(
                                          builder: (_) => const BulkOrderStandardScreen(),
                                        ),
                                      ),
                                    ),
                                    if (cfg.isVarietyActive) const SizedBox(height: 16),
                                  ],
                                  if (cfg.isVarietyActive) ...[
                                    BulkOrderTypeCard(
                                      title: cfg.varietyTierTitle?.isNotEmpty == true
                                          ? cfg.varietyTierTitle!
                                          : 'Large event bulk',
                                      subtitle: cfg.varietyTierSubtitle?.isNotEmpty == true
                                          ? cfg.varietyTierSubtitle!
                                          : '${cfg.tierThreshold}+ meals',
                                      detail: cfg.varietyTierDescription?.isNotEmpty == true
                                          ? cfg.varietyTierDescription!
                                          : 'Browse meal categories and set portions for each dish.',
                                      icon: CupertinoIcons.square_stack_3d_up_fill,
                                      color: Colors.deepOrange,
                                      onTap: () => Navigator.push(
                                        context,
                                        CupertinoPageRoute(
                                          builder: (_) => const BulkOrderVarietyCategoriesScreen(),
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
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
