class Food {
  final int id;
  final String description;
  final String? brand;
  final String? offBarcode;
  final int? fdcId;
  final NutrientsPer100g? nutrients;

  Food({
    required this.id,
    required this.description,
    this.brand,
    this.offBarcode,
    this.fdcId,
    this.nutrients,
  });

  factory Food.fromJson(Map<String, dynamic> j) {
    return Food(
      id: j['id'] as int,
      description: j['description'] ?? j['name'] ?? '',
      brand: j['brand'],
      offBarcode: j['off_barcode'] ?? j['barcode'],
      fdcId: j['fdc_id'] is int ? j['fdc_id'] : int.tryParse(j['fdc_id']?.toString() ?? ''),
      nutrients: j['nutrients'] != null ? NutrientsPer100g.fromJson(j['nutrients']) : null,
    );
  }
}

class NutrientsPer100g {
  final double? kcal;
  final double? protein;
  final double? carbs;
  final double? fat;

  NutrientsPer100g({this.kcal, this.protein, this.carbs, this.fat});

  factory NutrientsPer100g.fromJson(Map<String, dynamic> j) {
    return NutrientsPer100g(
      kcal: (j['calories'] ?? j['kcal_100g'])?.toDouble(),
      protein: (j['protein'] ?? j['protein_100g'])?.toDouble(),
      carbs: (j['carbs'] ?? j['carbs_100g'] ?? j['carbohydrates_100g'])?.toDouble(),
      fat: (j['fat'] ?? j['fat_100g'])?.toDouble(),
    );
  }
}
