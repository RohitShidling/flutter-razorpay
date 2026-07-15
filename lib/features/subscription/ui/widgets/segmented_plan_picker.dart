import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:meal_app/core/theme/app_theme.dart';

class SegmentedPlanPicker extends StatelessWidget {
  final int value; // 0=Trial, 1=Regular
  final ValueChanged<int> onChanged;
  final bool isDark;

  const SegmentedPlanPicker({
    super.key,
    required this.value,
    required this.onChanged,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.surfaceDark : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? Colors.white10 : Colors.grey.withValues(alpha: 0.15)),
      ),
      child: CupertinoSlidingSegmentedControl<int>(
        groupValue: value,
        onValueChanged: (v) {
          if (v == null) return;
          onChanged(v);
        },
        thumbColor: isDark ? Colors.white12 : Colors.white,
        backgroundColor: Colors.transparent,
        children: <int, Widget>{
          0: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Text(
              'Trial',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                color: value == 0
                    ? (isDark ? Colors.white : AppTheme.textPrimaryLight)
                    : (isDark ? Colors.white54 : AppTheme.textSecondaryLight),
              ),
            ),
          ),
          1: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Text(
              'Regular',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                color: value == 1
                    ? (isDark ? Colors.white : AppTheme.textPrimaryLight)
                    : (isDark ? Colors.white54 : AppTheme.textSecondaryLight),
              ),
            ),
          ),
        },
      ),
    );
  }
}

