import '../services/nutrition_ocr_parser.dart';

class LabelReviewResult {
  final NutritionParseResult perServing;
  final double servings;

  LabelReviewResult({required this.perServing, required this.servings});

  NutritionParseResult totals() {
    double? _mul(double? v) => v == null ? null : v * servings;
    return NutritionParseResult(
      servingSizeValue: perServing.servingSizeValue,
      servingSizeUnit:  perServing.servingSizeUnit,
      calories:         _mul(perServing.calories),
      fat_g:            _mul(perServing.fat_g),
      satFat_g:         _mul(perServing.satFat_g),
      transFat_g:       _mul(perServing.transFat_g),
      cholesterol_mg:   _mul(perServing.cholesterol_mg),
      sodium_mg:        _mul(perServing.sodium_mg),
      carbs_g:          _mul(perServing.carbs_g),
      fiber_g:          _mul(perServing.fiber_g),
      sugar_g:          _mul(perServing.sugar_g),
      addedSugar_g:     _mul(perServing.addedSugar_g),
      protein_g:        _mul(perServing.protein_g),
    );
  }
}
    