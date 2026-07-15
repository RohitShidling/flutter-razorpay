import 'package:flutter/material.dart';
import 'package:meal_app/core/models/lookup_models.dart';
import 'package:meal_app/core/utils/time_utils.dart';

class DeliveryTimeWindow {
  const DeliveryTimeWindow._();

  static bool allows(TimeOfDay time, DeliveryTimeSettingsModel? settings) {
    if (settings == null || !settings.isEnabled) return true;
    return settings.allows(time);
  }

  /// Error message shown when the user picks a time outside the allowed window.
  static String message(DeliveryTimeSettingsModel? settings) {
    if (settings == null || !settings.isEnabled) return '';
    final start = TimeUtils.formatToDisplay(settings.startTime);
    final end = TimeUtils.formatToDisplay(settings.endTime);
    return 'Please select a delivery time between $start and $end.';
  }

  /// Hint text shown on the time field so the user knows the allowed range upfront.
  /// Returns null when no restriction is active (no hint needed).
  static String? hint(DeliveryTimeSettingsModel? settings) {
    if (settings == null || !settings.isEnabled) return null;
    final start = TimeUtils.formatToDisplay(settings.startTime);
    final end = TimeUtils.formatToDisplay(settings.endTime);
    return 'Select delivery time from $start to $end';
  }
}
