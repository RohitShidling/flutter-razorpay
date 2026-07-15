import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Time formatting helpers for meal delivery times.
///
/// The backend can return delivery time in two flavors:
///   • 24-hour `HH:mm` / `HH:mm:ss` (e.g. "13:00" / "13:00:00")
///   • 12-hour `h:mm a` / `hh:mm a` (e.g. "1:00 PM" / "01:00 PM")
///
/// The UI must always display 12-hour format with AM/PM (e.g. "1:00 PM").
class TimeUtils {
  TimeUtils._();

  /// Formats any backend time string to professional 12-hour `h:mm a` form.
  /// Returns `--:--` for null/empty input. Returns the original string if
  /// it cannot be parsed (defensive — never crashes the UI).
  static String formatToDisplay(String? timeStr) {
    if (timeStr == null) return '--:--';
    final raw = timeStr.trim();
    if (raw.isEmpty) return '--:--';

    // Already in 12-hour AM/PM form ("1:00 PM" / "01:00 pm" / "9:30 a.m.").
    final ampm = _parseAmPm(raw);
    if (ampm != null) return _format12(ampm.hour, ampm.minute);

    // 24-hour "HH:mm" or "HH:mm:ss".
    final parts = raw.split(':');
    if (parts.isNotEmpty) {
      final h = int.tryParse(parts[0].trim());
      final m = parts.length > 1 ? int.tryParse(parts[1].trim()) : 0;
      if (h != null && h >= 0 && h <= 23 && m != null && m >= 0 && m <= 59) {
        return _format12(h, m);
      }
    }
    return raw;
  }

  /// Converts a Flutter [TimeOfDay] to backend `HH:mm` (24-hour).
  static String toBackendFormat(TimeOfDay time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  /// Parses API / form values into `HH:mm` for storage and PUT payloads.
  static String? tryParseToBackend(String? raw, {String? fallback}) {
    if (raw == null || raw.trim().isEmpty) return fallback;
    final norm = normalizeBackendTime(raw);
    if (norm.isNotEmpty && RegExp(r'^\d{2}:\d{2}$').hasMatch(norm)) return norm;
    final ampm = _parseAmPm(formatToDisplay(raw));
    if (ampm != null) {
      return toBackendFormat(TimeOfDay(hour: ampm.hour, minute: ampm.minute));
    }
    return fallback;
  }

  /// Normalizes `HH:mm` / `HH:mm:ss` to `HH:mm` for equality checks.
  static String normalizeBackendTime(String? raw) {
    if (raw == null) return '';
    final t = raw.trim();
    if (t.isEmpty) return '';
    final parts = t.split(':');
    if (parts.length >= 2) {
      final h = parts[0].trim().padLeft(2, '0');
      final m = parts[1].trim().padLeft(2, '0');
      return '$h:$m';
    }
    return t;
  }

  // ─── internal ────────────────────────────────────────────────────────────

  static String _format12(int hour24, int minute) {
    final dt = DateTime(2000, 1, 1, hour24, minute);
    return DateFormat('h:mm a').format(dt);
  }

  /// Parses strings like "1:00 PM", "01:00 pm", "9 AM", "9:30 a.m.".
  static _AmPmTime? _parseAmPm(String raw) {
    final normalized = raw.toUpperCase().replaceAll('.', '');
    final match = RegExp(r'^(\d{1,2})(?::(\d{1,2}))?\s*(AM|PM)$').firstMatch(normalized);
    if (match == null) return null;
    var h = int.tryParse(match.group(1) ?? '') ?? -1;
    final m = int.tryParse(match.group(2) ?? '0') ?? 0;
    final period = match.group(3);
    if (h < 1 || h > 12 || m < 0 || m > 59) return null;
    if (period == 'AM' && h == 12) h = 0;
    if (period == 'PM' && h != 12) h += 12;
    return _AmPmTime(h, m);
  }
}

class _AmPmTime {
  final int hour; // 0..23
  final int minute; // 0..59
  const _AmPmTime(this.hour, this.minute);
}
