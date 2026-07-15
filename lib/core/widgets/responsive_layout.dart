import 'package:flutter/material.dart';

/// Central helper for responsive breakpoint checks and padding calculation.
class ResponsiveHelper {
  static const double mobileBreakPoint = 650.0;
  static const double tabletBreakPoint = 1024.0;

  static bool isMobile(BuildContext context) =>
      MediaQuery.sizeOf(context).width < mobileBreakPoint;

  static bool isTablet(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= mobileBreakPoint &&
      MediaQuery.sizeOf(context).width < tabletBreakPoint;

  static bool isDesktop(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= tabletBreakPoint;

  /// True if the screen is wide enough to comfortably support side-by-side content.
  static bool isWide(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= 750;

  /// Dynamically computes grid cross-axis count based on screen width.
  static int getGridCrossAxisCount(
    BuildContext context, {
    int mobileCount = 1,
    int tabletCount = 2,
    int desktopCount = 3,
  }) {
    final width = MediaQuery.sizeOf(context).width;
    if (width >= tabletBreakPoint) return desktopCount;
    if (width >= mobileBreakPoint) return tabletCount;
    return mobileCount;
  }
}

/// A container that limits the width of its child on tablets and desktop monitors.
/// Highly recommended for forms, lists, settings, and other single-column pages
/// to prevent stretching and maintain a professional appearance.
class ResponsiveContainer extends StatelessWidget {
  final Widget child;
  final double maxWidth;
  final bool center;
  final EdgeInsets? padding;

  const ResponsiveContainer({
    super.key,
    required this.child,
    this.maxWidth = 650.0,
    this.center = true,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    if (width < ResponsiveHelper.mobileBreakPoint) {
      return Padding(
        padding: padding ?? EdgeInsets.zero,
        child: child,
      );
    }

    Widget result = ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: child,
    );

    if (center) {
      result = Align(
        alignment: Alignment.topCenter,
        child: result,
      );
    }

    return Padding(
      padding: padding ?? EdgeInsets.zero,
      child: result,
    );
  }
}
