import 'package:flutter/cupertino.dart';

/// Minimal premium indicator — verified seal using theme primary.
class SubscriptionBadge extends StatelessWidget {
  final IconData icon;
  final Color? color;
  final double size;

  const SubscriptionBadge({
    super.key,
    this.icon = CupertinoIcons.checkmark_seal_fill,
    this.color,
    this.size = 18,
  });

  @override
  Widget build(BuildContext context) {
    return Icon(
      icon,
      size: size,
      color: color ?? const Color(0xFF22C55E),
    );
  }
}

