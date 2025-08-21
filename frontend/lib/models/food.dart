// lib/models/food.dart
// Minimal, recursion-free models aligned with the Django API.

class NutrientsPer100g {
  final double? calories;
  final double? protein;
  final double? carbs;
  final double? fat;
  final double? fiber;
  final double? sugar;
  final double? sodium;

  const NutrientsPer100g({
    this.calories,
    this.protein,
    this.carbs,
    this.fat,
    this.fiber,
    this.sugar,
    this.sodium,
  });

  factory NutrientsPer100g.fromJson(Map<String, dynamic> j) {
    double? numVal(dynamic v) {
      if (v == null || (v is String && v.trim().isEmpty)) return null;
      if (v is num) return v.toDouble();
      return double.tryParse(v.toString());
    }

    // Accept both our backend keys and a few OFF-style fallbacks
    double? firstVal(List<String> keys) {
      for (final k in keys) {
        if (j.containsKey(k) && j[k] != null) return numVal(j[k]);
      }
      return null;
    }

    return NutrientsPer100g(
      calories: firstVal([
        'calories',
        'kcal_100g',
        'energy-kcal_100g',
        'energy-kcal_serving',
      ]),
      protein: firstVal(['protein', 'protein_100g', 'proteins_100g']),
      carbs: firstVal(['carbs', 'carbs_100g', 'carbohydrates_100g']),
      fat: firstVal(['fat', 'fat_100g']),
      fiber: firstVal(['fiber', 'fiber_100g']),
      sugar: firstVal(['sugar', 'sugars', 'sugars_100g', 'sugar_100g']),
      sodium: firstVal(['sodium', 'sodium_100g', 'sodium_mg']),
    );
  }

  Map<String, dynamic> toJson() => {
        'calories': calories,
        'protein': protein,
        'carbs': carbs,
        'fat': fat,
        'fiber': fiber,
        'sugar': sugar,
        'sodium': sodium,
      };
}

class Food {
  final int? id;
  final String? name;        // UI reads this
  final String? description; // legacy alias (kept for compatibility)
  final String? brand;
  final String? barcode;     // our API uses "barcode"
  final int? fdcId;          // "fdc_id" (if present)
  final String? dataSource;  // "data_source" (e.g., "OFF")
  final NutrientsPer100g? nutrients;

  const Food({
    this.id,
    this.name,
    this.description,
    this.brand,
    this.barcode,
    this.fdcId,
    this.dataSource,
    this.nutrients,
  });

  // Legacy convenience (if other code still reads offBarcode)
  String? get offBarcode => barcode;

  // If some places still rely on description, ensure it’s never worse than name
  String? get displayName => name ?? description;

  factory Food.fromJson(Map<String, dynamic> j) {
    final n = j['nutrients'];
    return Food(
      id: j['id'] as int?,
      // Prefer "name" from our backend; fall back to "description" if present
      name: j['name'] as String? ?? j['description'] as String?,
      description: j['description'] as String?,
      brand: j['brand'] as String?,
      barcode: j['barcode'] as String? ?? j['offBarcode'] as String?,
      fdcId: j['fdc_id'] as int?,
      dataSource: j['data_source'] as String?,
      nutrients: n is Map<String, dynamic> ? NutrientsPer100g.fromJson(n) : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name ?? description,
        'description': description,
        'brand': brand,
        'barcode': barcode,
        'fdc_id': fdcId,
        'data_source': dataSource,
        'nutrients': nutrients?.toJson(),
      };
}
