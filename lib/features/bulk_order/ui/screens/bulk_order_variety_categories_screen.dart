import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:meal_app/core/theme/app_theme.dart';
import 'package:meal_app/features/bulk_order/data/models/bulk_variety_category.dart';
import 'package:meal_app/features/bulk_order/providers/bulk_order_provider.dart';
import 'package:meal_app/features/bulk_order/ui/screens/bulk_order_cart_screen.dart';
import 'package:meal_app/features/bulk_order/ui/screens/bulk_order_category_meals_screen.dart';
import 'package:meal_app/core/widgets/responsive_layout.dart';

/// Large-event bulk: browse categories and build a cart; pay from the cart screen.
class BulkOrderVarietyCategoriesScreen extends StatefulWidget {
  const BulkOrderVarietyCategoriesScreen({super.key});

  @override
  State<BulkOrderVarietyCategoriesScreen> createState() => _BulkOrderVarietyCategoriesScreenState();
}

class _BulkOrderVarietyCategoriesScreenState extends State<BulkOrderVarietyCategoriesScreen> {
  String? _filterCategoryId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<BulkOrderProvider>().loadVarietyCategories();
    });
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<BulkOrderProvider>();
    final cfg = p.config;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final sum = p.varietyLineSum;
    final categories = p.varietyCategories;
    final filtered = _filterCategoryId == null
        ? categories
        : categories.where((c) => c.id == _filterCategoryId).toList();
    if (cfg == null || (p.isLoading && !cfg.isVarietyActive)) {
      return Scaffold(
        backgroundColor: isDark ? AppTheme.surfaceDark : const Color(0xFFFAF8F5),
        appBar: AppBar(
          backgroundColor: isDark ? AppTheme.surfaceDark : const Color(0xFFF3EBE0),
          elevation: 0,
          centerTitle: true,
          title: Text(
            'Large event bulk',
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
        ),
        body: Center(
          child: p.error != null
              ? Padding(
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
                )
              : const CupertinoActivityIndicator(),
        ),
      );
    }

    if (!cfg.isVarietyActive) {
      return Scaffold(
        backgroundColor: isDark ? AppTheme.surfaceDark : const Color(0xFFFAF8F5),
        appBar: AppBar(
          backgroundColor: isDark ? AppTheme.surfaceDark : const Color(0xFFF3EBE0),
          elevation: 0,
          centerTitle: true,
          title: Text(
            'Large event bulk',
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
        ),
        body: Center(
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
                  'Large event bulk ordering is currently unavailable.',
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
        ),
      );
    }

    final titleText = cfg.varietyTierTitle?.isNotEmpty == true ? cfg.varietyTierTitle! : 'Large event bulk';

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
            titleText,
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
        floatingActionButton: p.bulkCartTotalMeals > 0
            ? FloatingActionButton.extended(
                heroTag: 'variety_cart_fab',
                onPressed: () => Navigator.push(
                  context,
                  CupertinoPageRoute(builder: (_) => const BulkOrderCartScreen()),
                ),
                icon: const Icon(CupertinoIcons.cart_fill),
                label: Text('Cart (${p.bulkCartTotalMeals})', style: const TextStyle(fontWeight: FontWeight.w800)),
              )
            : null,
        floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
        body: SafeArea(
          top: false,
          child: p.isLoading && p.varietyCategories.isEmpty

                  ? const Center(child: CircularProgressIndicator())
                  : ResponsiveContainer(
                      maxWidth: 1000.0,
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                          if (cfg.varietyTierDescription?.isNotEmpty == true)
                            Text(
                              cfg.varietyTierDescription!,
                              style: TextStyle(
                                fontSize: 15,
                                height: 1.4,
                                color: isDark ? Colors.white70 : AppTheme.textSecondaryLight,
                              ),
                            ),
                          const SizedBox(height: 12),
                          Text(
                            'Choose categories and add meal portions. Delivery details are collected when you pay.',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.white70 : AppTheme.textSecondaryLight,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Categories',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 10),
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: [
                                FilterChip(
                                  label: const Text('All'),
                                  selected: _filterCategoryId == null,
                                  onSelected: (_) => setState(() => _filterCategoryId = null),
                                ),
                                ...categories.map(
                                  (c) => Padding(
                                    padding: const EdgeInsets.only(left: 8),
                                    child: FilterChip(
                                      label: Text(c.name),
                                      selected: _filterCategoryId == c.id,
                                      onSelected: (_) => setState(() => _filterCategoryId = c.id),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          if (filtered.isEmpty)
                            Text(
                              'No categories available yet.',
                              style: TextStyle(color: Colors.orange.shade700),
                            )
                          else ...[
                            Builder(
                              builder: (context) {
                                final crossAxisCount = ResponsiveHelper.getGridCrossAxisCount(
                                  context,
                                  mobileCount: 1,
                                  tabletCount: 2,
                                  desktopCount: 3,
                                );
                                if (crossAxisCount == 1) {
                                  return Column(
                                    children: filtered.map((c) => _CategoryCard(
                                      category: c,
                                      isDark: isDark,
                                      onTap: () {
                                        Navigator.push(
                                          context,
                                          CupertinoPageRoute(
                                            builder: (_) => BulkOrderCategoryMealsScreen(
                                              categoryId: c.id,
                                              categoryName: c.name,
                                            ),
                                          ),
                                        );
                                      },
                                    )).toList(),
                                  );
                                } else {
                                  return GridView.builder(
                                    shrinkWrap: true,
                                    physics: const NeverScrollableScrollPhysics(),
                                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                      crossAxisCount: crossAxisCount,
                                      crossAxisSpacing: 16,
                                      mainAxisSpacing: 16,
                                      childAspectRatio: 1.35,
                                    ),
                                    itemCount: filtered.length,
                                    itemBuilder: (context, index) {
                                      final c = filtered[index];
                                      return _CategoryCard(
                                        category: c,
                                        isDark: isDark,
                                        useGridMode: true,
                                        onTap: () {
                                          Navigator.push(
                                            context,
                                            CupertinoPageRoute(
                                              builder: (_) => BulkOrderCategoryMealsScreen(
                                                categoryId: c.id,
                                                categoryName: c.name,
                                              ),
                                            ),
                                          );
                                        },
                                      );
                                    },
                                  );
                                }
                              },
                            ),
                          ],
                          // Extra bottom padding for FAB
                          if (sum > 0) const SizedBox(height: 72),
                        ],
                      ),
                    ),
                    ),
        ),
      ),
    );
  }
}

class _CategoryCard extends StatelessWidget {
  const _CategoryCard({
    required this.category,
    required this.isDark,
    required this.onTap,
    this.useGridMode = false,
  });

  final BulkVarietyCategory category;
  final bool isDark;
  final VoidCallback onTap;
  final bool useGridMode;

  @override
  Widget build(BuildContext context) {
    final double imageHeight = useGridMode ? 120 : 180;

    final Widget imageWidget = category.imageUrl != null && category.imageUrl!.isNotEmpty
        ? CachedNetworkImage(
            imageUrl: category.imageUrl!,
            fit: BoxFit.cover,
            placeholder: (context, url) => const Center(
              child: CircularProgressIndicator(),
            ),
            errorWidget: (context, url, error) => Container(
              color: AppTheme.primaryColor.withValues(alpha: 0.08),
              child: Icon(CupertinoIcons.square_grid_2x2, color: AppTheme.primaryColor, size: 40),
            ),
          )
        : Container(
            color: AppTheme.primaryColor.withValues(alpha: 0.08),
            child: Icon(CupertinoIcons.square_grid_2x2, color: AppTheme.primaryColor, size: 40),
          );

    return Padding(
      padding: EdgeInsets.only(bottom: useGridMode ? 0 : 12),
      child: Material(
        color: isDark ? AppTheme.surfaceDark : Colors.white,
        borderRadius: BorderRadius.circular(14),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Ink(
            decoration: BoxDecoration(
              border: Border.all(color: isDark ? AppTheme.borderDark : AppTheme.borderLight, width: 1.5),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                useGridMode
                    ? Expanded(child: imageWidget)
                    : SizedBox(
                        height: imageHeight,
                        width: double.infinity,
                        child: imageWidget,
                      ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              category.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${category.mealCount} meal${category.mealCount == 1 ? '' : 's'}',
                              style: TextStyle(
                                fontSize: 13,
                                color: isDark ? Colors.white60 : AppTheme.textSecondaryLight,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(CupertinoIcons.chevron_right, color: Colors.grey),
                    ],
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
