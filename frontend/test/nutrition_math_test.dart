// test/nutrition_math_test.dart
// Unit tests for serving size → grams conversion and per-100g scaling.

import 'package:flutter_test/flutter_test.dart';

import 'package:frontend/utils/nutrition_math.dart';
import 'package:frontend/services/nutrition_ocr_parser.dart';

void main() {
  group('servingSizeInGrams()', () {
    test('returns grams as-is for g', () {
      expect(servingSizeInGrams(30, 'g'), 30);
      expect(servingSizeInGrams(12.5, 'grams'), 12.5);
    });

    test('converts ounces to grams', () {
      expect(
        servingSizeInGrams(1, 'oz')!,
        closeTo(28.349523125, 1e-9),
      );
      expect(
        servingSizeInGrams(2.5, 'ounces')!,
        closeTo(2.5 * 28.349523125, 1e-9),
      );
    });

    test('returns null for unsupported units', () {
      expect(servingSizeInGrams(30, 'ml'), isNull);
      expect(servingSizeInGrams(1, 'cup'), isNull);
      expect(servingSizeInGrams(1, 'tbsp'), isNull);
      expect(servingSizeInGrams(null, 'g'), isNull);
      expect(servingSizeInGrams(10, null), isNull);
    });
  });

  group('perServingToPer100g()', () {
    test('scales all nutrients to per-100g (sodium mg preserved)', () {
      final p = NutritionParseResult(
        servingSizeValue: 30,
        servingSizeUnit: 'g',
        calories: 120,      // kcal per 30g -> 400 kcal/100g
        protein_g: 10,      // g per 30g -> 33.333 g/100g
        carbs_g: 15,        // -> 50 g/100g
        fat_g: 5,           // -> 16.666 g/100g
        fiber_g: 3,         // -> 10 g/100g
        sugar_g: 2,         // -> 6.666 g/100g
        sodium_mg: 300,     // mg per 30g -> 1000 mg/100g
      );

      final per100 = perServingToPer100g(p, 30);

      expect(per100.calories!, closeTo(400, 1e-9));
      expect(per100.protein!, closeTo(33.3333333, 1e-6));
      expect(per100.carbs!, closeTo(50, 1e-9));
      expect(per100.fat!, closeTo(16.6666667, 1e-6));
      expect(per100.fiber!, closeTo(10, 1e-9));
      expect(per100.sugar!, closeTo(6.6666667, 1e-6));
      expect(per100.sodium!, closeTo(1000, 1e-9));
    });

    test('handles null inputs and non-positive gramsPerServing', () {
      final p = NutritionParseResult(
        servingSizeValue: 0,
        servingSizeUnit: 'g',
        calories: null,
        protein_g: null,
        carbs_g: null,
        fat_g: null,
        fiber_g: null,
        sugar_g: null,
        sodium_mg: null,
      );

      final per100a = perServingToPer100g(p, 0);
      expect(per100a.calories, isNull);
      expect(per100a.protein, isNull);
      expect(per100a.carbs, isNull);
      expect(per100a.fat, isNull);
      expect(per100a.fiber, isNull);
      expect(per100a.sugar, isNull);
      expect(per100a.sodium, isNull);

      final p2 = NutritionParseResult(
        servingSizeValue: 30,
        servingSizeUnit: 'g',
        calories: 120,
      );
      final per100b = perServingToPer100g(p2, -10);
      expect(per100b.calories, isNull);
    });
  });
}
