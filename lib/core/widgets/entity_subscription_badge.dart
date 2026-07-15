import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:meal_app/core/utils/subscription_status_normalize.dart';

/// Green tick = serving today; yellow clock = upcoming; nothing = not subscribed.
class EntitySubscriptionBadge extends StatelessWidget {
  final Map<String, dynamic>? statusMap;
  final String entityType;
  final String entityId;
  final double size;

  const EntitySubscriptionBadge({
    super.key,
    required this.statusMap,
    required this.entityType,
    required this.entityId,
    this.size = 18,
  });

  @override
  Widget build(BuildContext context) {
    final state = SubscriptionStatusNormalizer.entityPlanState(
      statusMap,
      entityType,
      entityId,
    );
    if (state == 'none') return const SizedBox.shrink();

    if (state == 'active') {
      return Icon(
        CupertinoIcons.checkmark_seal_fill,
        size: size,
        color: Colors.green.shade600,
      );
    }

    return Icon(
      CupertinoIcons.checkmark_seal_fill,
      size: size,
      color: Colors.amber.shade700,
    );
  }
}
