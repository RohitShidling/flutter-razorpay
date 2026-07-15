import 'package:meal_app/core/models/lookup_models.dart';

/// Meal size recommendation helpers for child / teacher / professional flows.
class MealSizeRecommendations {
  MealSizeRecommendations._();

  /// Parses grade from standard name (e.g. "5th", "Class 10", "XII") or falls back to [standardId].
  static int? parseStandardGrade(String? standardName, int standardId) {
    final text = (standardName ?? '').trim();
    if (text.isNotEmpty) {
      final digitMatch = RegExp(r'(\d{1,2})').firstMatch(text);
      if (digitMatch != null) {
        final n = int.tryParse(digitMatch.group(1)!);
        if (n != null && n >= 1 && n <= 12) return n;
      }
      final roman = text.toUpperCase();
      const romanMap = {
        'XII': 12,
        'XI': 11,
        'VIII': 8,
        'VII': 7,
        'III': 3,
        'IV': 4,
        'IX': 9,
        'X': 10,
        'VI': 6,
        'II': 2,
        'V': 5,
        'I': 1,
      };
      for (final entry in romanMap.entries) {
        if (roman.contains(entry.key)) return entry.value;
      }
    }
    if (standardId >= 1 && standardId <= 12) return standardId;
    return null;
  }

  /// `'small'` | `'medium'` | `'large'` for child grade bands.
  static String recommendedBandForChildGrade(int? grade) {
    if (grade == null) return 'small';
    if (grade >= 1 && grade <= 4) return 'small';
    if (grade >= 5 && grade <= 8) return 'medium';
    return 'large';
  }

  static String recommendedBandForChild(String? standardName, int standardId) {
    return recommendedBandForChildGrade(parseStandardGrade(standardName, standardId));
  }

  static String recommendedBandForTeacherOrProfessional() => 'large';

  static bool _sizeNameMatchesBand(String sizeName, String band) {
    final n = sizeName.toLowerCase();
    switch (band) {
      case 'small':
        return n.contains('small') || n.contains('s ');
      case 'medium':
        return n.contains('medium') || n.contains('med');
      case 'large':
        return n.contains('large') || n.contains('big');
      default:
        return false;
    }
  }

  static bool isRecommendedMealSize(MealSizeModel size, String band) {
    return _sizeNameMatchesBand('${size.name} ${size.displayName}', band);
  }

  static String mealSizeLabel(MealSizeModel size, {required bool showRecommended, String? band}) {
    if (!showRecommended || band == null || !isRecommendedMealSize(size, band)) {
      return size.displayName;
    }
    return '${size.displayName} (Recommended)';
  }

  /// First catalog row matching [band] (small / medium / large).
  static MealSizeModel? pickForBand(List<MealSizeModel> sizes, String band) {
    for (final s in sizes) {
      if (isRecommendedMealSize(s, band)) return s;
    }
    return null;
  }

  static String? recommendedBandForEntity({
    required String entityKind,
    String? standardName,
    int? standardId,
  }) {
    switch (entityKind) {
      case 'child':
        return recommendedBandForChild(standardName, standardId ?? 0);
      case 'teacher':
      case 'professional':
        return recommendedBandForTeacherOrProfessional();
      default:
        return null;
    }
  }
}
