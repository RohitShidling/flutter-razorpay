import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:meal_app/core/theme/app_theme.dart';

/// Paints status bar + nav bar regions with a solid screen background (no transparency).
class SystemUiScaffold extends StatelessWidget {
  const SystemUiScaffold({
    super.key,
    required this.child,
    this.backgroundColor,
    this.bottomNavigationBar,
    this.floatingActionButton,
    this.appBar,
    this.body,
  });

  final Widget? child;
  final Color? backgroundColor;
  final Widget? bottomNavigationBar;
  final Widget? floatingActionButton;
  final PreferredSizeWidget? appBar;
  final Widget? body;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = backgroundColor ?? (isDark ? AppTheme.backgroundDark : Colors.white);
    final navBarColor = bottomNavigationBar != null
        ? (isDark ? AppTheme.surfaceDark : Colors.white)
        : bg;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: AppTheme.overlayFor(background: bg, isDark: isDark, navigationBarColor: navBarColor),
      child: Scaffold(
        backgroundColor: bg,
        extendBody: false,
        extendBodyBehindAppBar: false,
        appBar: appBar,
        bottomNavigationBar: bottomNavigationBar,
        floatingActionButton: floatingActionButton,
        body: body ?? child ?? const SizedBox.shrink(),
      ),
    );
  }
}

/// Edge-to-edge content with only the minimum top inset (flush under status bar icons).
class FlushTopPadding extends StatelessWidget {
  const FlushTopPadding({
    super.key,
    required this.child,
    this.horizontal = 20,
    this.bottom = 0,
  });

  final Widget child;
  final double horizontal;
  final double bottom;

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    return Padding(
      padding: EdgeInsets.fromLTRB(horizontal, top, horizontal, bottom),
      child: child,
    );
  }
}
