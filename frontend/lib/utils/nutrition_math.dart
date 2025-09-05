// lib/utils/nutrition_math.dart
// Pure helpers for nutrition math (unit conversions and scaling),
// split out for testability and reuse.

import 'package:frontend/services/nutrition_ocr_parser.dart';
import 'package:frontend/models/food.dart';

/// Convert a serving size (value + unit) to grams (per serving).
/// Returns null for unsupported units (ml/cup/tbsp/tsp) where density is unknown.
double? servingSizeInGrams(double? value, String? unitRaw) {
  if (value == null) return null;
  if (unitRaw == null) return null;
  final unit = unitRaw.toLowerCase().trim();
  switch (unit) {
    case 'g':
    case 'gram':
    case 'grams':
      return value;
    case 'oz':
    case 'ounce':
    case 'ounces':
      return value * 28.349523125;
    default:
      return null; // Cannot convert volume without density
  }
}

/// Convert per-serving parsed values into per-100g nutrients.
/// Sodium stays in mg; others are in kcal or g as per your model.
NutrientsPer100g perServingToPer100g(NutritionParseResult p, double gramsPerServing) {
  double? scale(double? perServing) {
    if (perServing == null) return null;
    if (gramsPerServing <= 0) return null;
    return perServing / gramsPerServing * 100.0;
  }

  return NutrientsPer100g(
    calories: scale(p.calories),
    protein: scale(p.protein_g),
    carbs: scale(p.carbs_g),
    fat: scale(p.fat_g),
    fiber: scale(p.fiber_g),
    sugar: scale(p.sugar_g),
    sodium: scale(p.sodium_mg),
  );
}
