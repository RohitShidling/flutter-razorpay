import 'package:flutter_test/flutter_test.dart';
import 'package:meal_app/core/utils/meal_size_recommendations.dart';

void main() {
  group('MealSizeRecommendations.parseStandardGrade', () {
    test('correctly parses standard digit grades', () {
      expect(MealSizeRecommendations.parseStandardGrade('Class 5', 5), 5);
      expect(MealSizeRecommendations.parseStandardGrade('10th Standard', 10), 10);
    });

    test('correctly parses Roman numeral grades', () {
      expect(MealSizeRecommendations.parseStandardGrade('Class XII', 12), 12);
      expect(MealSizeRecommendations.parseStandardGrade('Standard XI', 11), 11);
      expect(MealSizeRecommendations.parseStandardGrade('Grade X', 10), 10);
      expect(MealSizeRecommendations.parseStandardGrade('Class IX', 9), 9);
      expect(MealSizeRecommendations.parseStandardGrade('VIII C', 8), 8);
      expect(MealSizeRecommendations.parseStandardGrade('VII B', 7), 7);
      expect(MealSizeRecommendations.parseStandardGrade('VI A', 6), 6);
      expect(MealSizeRecommendations.parseStandardGrade('Class V', 5), 5);
      expect(MealSizeRecommendations.parseStandardGrade('IV', 4), 4);
      expect(MealSizeRecommendations.parseStandardGrade('Class III', 3), 3);
      expect(MealSizeRecommendations.parseStandardGrade('Class II', 2), 2);
      expect(MealSizeRecommendations.parseStandardGrade('Class I', 1), 1);
    });

    test('falls back to standard ID when name is invalid or empty', () {
      expect(MealSizeRecommendations.parseStandardGrade('', 6), 6);
      expect(MealSizeRecommendations.parseStandardGrade('ABC', 8), 8);
    });
  });
}
