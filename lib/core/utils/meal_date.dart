import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

/// Centralized helpers for meal subscription start-date rules.
///
/// Business rule:
///   • Meal delivery never starts today — it always starts the next calendar
///     day or later. So the lower bound for any start date selection is
///     tomorrow at local midnight.
///
/// All helpers in this file return values in the device's local timezone,
/// matching what the backend expects (`yyyy-MM-dd`).
class MealDate {
  MealDate._();

  static bool _tzDataLoaded = false;

  /// Loads IANA DB once; required for [sessionTodayYmd].
  static void ensureSessionTimezoneData() {
    if (_tzDataLoaded) return;
    tz_data.initializeTimeZones();
    _tzDataLoaded = true;
  }

  /// Calendar `yyyy-MM-dd` in **Asia/Kolkata** — matches backend `parseSessionToday()`.
  static String sessionTodayYmd() {
    try {
      ensureSessionTimezoneData();
      final loc = tz.getLocation('Asia/Kolkata');
      final now = tz.TZDateTime.now(loc);
      return formatYmd(DateTime(now.year, now.month, now.day));
    } catch (_) {
      final n = DateTime.now();
      return formatYmd(DateTime(n.year, n.month, n.day));
    }
  }

  /// Extracts `yyyy-MM-dd` from an ISO string (date or datetime).
  /// Returns null if not long enough.
  static String? _toYmd(String? iso) {
    if (iso == null) return null;
    final s = iso.trim();
    if (s.length < 10) return null;
    return s.substring(0, 10);
  }

  /// Tomorrow in session calendar (Asia/Kolkata) — matches backend eligibility.
  /// Adjusted to skip Sunday.
  static DateTime firstSelectableStartDate() {
    final today = parseYmdLocal(sessionTodayYmd()) ?? DateTime.now();
    final tomorrow = today.add(const Duration(days: 1));
    var firstDate = DateTime(tomorrow.year, tomorrow.month, tomorrow.day);
    if (firstDate.weekday == DateTime.sunday) {
      firstDate = firstDate.add(const Duration(days: 1));
    }
    return firstDate;
  }

  /// Parse `yyyy-MM-dd` as a timezone-neutral calendar date (no UTC shift).
  static DateTime? parseYmdLocal(String? iso) {
    final ymd = _toYmd(iso);
    if (ymd == null) return null;
    final parts = ymd.split('-');
    if (parts.length != 3) return null;
    final y = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    final d = int.tryParse(parts[2]);
    if (y == null || m == null || d == null) return null;
    return DateTime(y, m, d);
  }

  /// Default duration window the user can pick from (60 days from tomorrow).
  static DateTime lastSelectableStartDate() {
    return firstSelectableStartDate().add(const Duration(days: 60));
  }

  /// Formats a [DateTime] as backend-friendly `yyyy-MM-dd`.
  static String formatYmd(DateTime date) {
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '${date.year}-$m-$d';
  }

  /// Returns tomorrow as a `yyyy-MM-dd` string.
  static String tomorrowYmd() => formatYmd(firstSelectableStartDate());

  /// Returns true if [iso] is a valid `yyyy-MM-dd` and is on/after tomorrow.
  /// Returns false for null / unparseable / today / past dates / Sundays.
  static bool isValidFutureStartDate(String? iso) {
    if (iso == null || iso.trim().isEmpty) return false;
    final parsed = parseYmdLocal(iso);
    if (parsed == null) return false;
    if (parsed.weekday == DateTime.sunday) return false;
    return !parsed.isBefore(firstSelectableStartDate());
  }

  /// Parses [iso] (yyyy-MM-dd) into a normalized DateTime,
  /// clamping to tomorrow if missing/past/Sunday.
  static DateTime parseOrTomorrow(String? iso) {
    if (iso == null || iso.trim().isEmpty) return firstSelectableStartDate();
    var parsed = parseYmdLocal(iso);
    if (parsed == null) return firstSelectableStartDate();
    if (parsed.isBefore(firstSelectableStartDate())) return firstSelectableStartDate();
    if (parsed.weekday == DateTime.sunday) {
      parsed = parsed.add(const Duration(days: 1));
    }
    return parsed;
  }

  /// Display format: `dd MMM yyyy` (e.g. 08 May 2026) without intl dependency.
  static String formatDisplay(String? iso) {
    if (iso == null || iso.trim().isEmpty) return '—';
    final parsed = parseYmdLocal(iso);
    if (parsed == null) return iso;
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    final d = parsed.day.toString().padLeft(2, '0');
    final m = months[parsed.month - 1];
    return '$d $m ${parsed.year}';
  }
}
