import 'package:flutter/material.dart';
import 'package:meal_app/core/theme/app_theme.dart';

class AppLogo extends StatelessWidget {
  const AppLogo({
    super.key,
    this.height = 72,
    this.showFallbackText = true,
  });

  final double height;
  final bool showFallbackText;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/images/logo.png',
      height: height,
      fit: BoxFit.contain,
      errorBuilder: (_, __, ___) {
        if (!showFallbackText) return const SizedBox.shrink();
        return Text(
          'Buuttii',
          style: TextStyle(
            fontSize: height * 0.45,
            fontWeight: FontWeight.w900,
            color: AppTheme.primaryColor,
            letterSpacing: 0.2,
          ),
        );
      },
    );
  }
}
