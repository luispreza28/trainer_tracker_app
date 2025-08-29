import 'package:flutter/foundation.dart';

class NutritionParseResult {
  final double? servingSizeValue;
  final String? servingSizeUnit; // normalized: g, ml, cup, tbsp, tsp, oz

  final double? calories;

  final double? fat_g;
  final double? satFat_g;
  final double? transFat_g;

  final double? cholesterol_mg;
  final double? sodium_mg;

  final double? carbs_g;
  final double? fiber_g;
  final double? sugar_g;
  final double? addedSugar_g;

  final double? protein_g;

  const NutritionParseResult({
    this.servingSizeValue,
    this.servingSizeUnit,
    this.calories,
    this.fat_g,
    this.satFat_g,
    this.transFat_g,
    this.cholesterol_mg,
    this.sodium_mg,
    this.carbs_g,
    this.fiber_g,
    this.sugar_g,
    this.addedSugar_g,
    this.protein_g,
  });

  Map<String, dynamic> toMap() => {
        'serving_size_value': servingSizeValue,
        'serving_size_unit': servingSizeUnit,
        'calories': calories,
        'fat_g': fat_g,
        'sat_fat_g': satFat_g,
        'trans_fat_g': transFat_g,
        'cholesterol_mg': cholesterol_mg,
        'sodium_mg': sodium_mg,
        'carbs_g': carbs_g,
        'fiber_g': fiber_g,
        'sugar_g': sugar_g,
        'added_sugar_g': addedSugar_g,
        'protein_g': protein_g,
      };
}

// Top-level function so NutritionOcrService can call:
//   compute(parseNutritionLabel, recognized.text)
NutritionParseResult parseNutritionLabel(String rawText) {
  return NutritionOcrParser.parse(rawText);
}

class NutritionOcrParser {
  // A flat list of all aliases so we can detect “different nutrient rows”.
  static final List<String> _allAliases = [
    'serving size',
    'calories',
    'total fat', 'fat',
    'saturated fat', 'sat fat',
    'trans fat', 'trans',
    'cholesterol',
    'sodium',
    'total carbohydrate', 'total carbs', 'carbohydrate', 'carbs',
    'dietary fiber', 'fiber',
    'total sugars', 'sugars', 'sugar',
    'added sugars', 'incl added sugars', 'includes added sugars', 'incl. added sugars',
    'protein',
  ];

  static NutritionParseResult parse(String rawText) {
    final text = _norm(rawText);
    final lines = text
        .split('\n')
        .map((l) => l.replaceAll(RegExp(r'[ \t]+'), ' ').trim()) // collapse spaces/tabs only
        .where((l) => l.isNotEmpty)
        .toList();

    for (final l in lines) debugPrint('LINES >>> $l');
    // ---- Serving size -------------------------------------------------------
    final ss = _parseServingSize(lines);



    // ---- Macros/micros with units (nearest-to-alias strategy) --------------
    final fatG       = _valueFor(lines, ['total fat', 'fat'],            unit: 'g');
    final satFatG    = _valueFor(lines, ['saturated fat', 'sat fat'],    unit: 'g');
    final transFatG  = _valueFor(lines, ['trans fat', 'trans'],          unit: 'g');

    final cholesterolMg = _valueFor(lines, ['cholesterol'], unit: 'mg');
    final sodiumMg      = _valueFor(lines, ['sodium'],      unit: 'mg');

    final carbsG  = _valueFor(lines, ['total carbohydrate','total carbs','carbohydrate','carbs'], unit: 'g');
    final fiberG  = _valueFor(lines, ['dietary fiber','fiber'],                                   unit: 'g');
    final sugarG  = _valueFor(lines, ['total sugars','sugars','sugar'],                           unit: 'g');
    final addSugG = _extractAddedSugars(lines);


    final proteinG = _valueFor(lines, ['protein'], unit: 'g');

    // ---- Sanity fixes (tame OCR outliers) ----------------------------------
    double? _cap(double? v, double? hi) {
      if (v == null || hi == null) return v;
      return v > hi ? hi : v;
    }

    final fixedSugar = _cap(sugarG, carbsG);     // sugars ≤ carbs
    final fixedSat   = _cap(satFatG, fatG);      // sat fat ≤ fat
    final fixedTrans = _cap(transFatG, fatG);    // trans fat ≤ fat
    final fixedFiber = _cap(fiberG, carbsG);     // fiber ≤ carbs

    // ---- Calories -----------------------------------------------------------
    double? calories = _extractCalories(lines);

    double? _kcalFromMacros(double? fatG, double? carbsG, double? proteinG) {
      if (fatG == null && carbsG == null && proteinG == null) return null;
      final f = (fatG ?? 0).toDouble();
      final c = (carbsG ?? 0).toDouble();
      final p = (proteinG ?? 0).toDouble();
      final val = 9 * f + 4 * c + 4 * p;
      return val; // keep as double (you can round if you want)
    }

    final calc = _kcalFromMacros(fatG, carbsG, proteinG);
    if (calories == null && calc != null) {
      calories = calc; // Fallback only; DO NOT override a found headline value
    }

    return NutritionParseResult(
      servingSizeValue: ss.$1,
      servingSizeUnit:  ss.$2,
      calories: calories,
      fat_g: fatG,
      satFat_g: fixedSat,
      transFat_g: fixedTrans,
      cholesterol_mg: cholesterolMg,
      sodium_mg: sodiumMg,
      carbs_g: carbsG,
      fiber_g: fixedFiber,
      sugar_g: fixedSugar,
      addedSugar_g: addSugG,
      protein_g: proteinG,
    );
  }

  /// Parse “Serving size 2 Tbsp (16g)”, “Serving size 1/2 cup”, etc.
  /// Returns (value, unit) where unit is normalized: g, ml, cup, tbsp, tsp, oz.
  static (double?, String?) _parseServingSize(List<String> lines) {
    final ssLineIdx = lines.indexWhere(
      (l) => l.contains(RegExp(r'\bserving\s*size\b', caseSensitive: false)),
    );
    if (ssLineIdx == -1) return (null, null);

    final candidates = <String>[lines[ssLineIdx]];
    if (ssLineIdx + 1 < lines.length) candidates.add(lines[ssLineIdx + 1]);
    final joined = candidates.join(' ');

    // Prefer explicit grams/ml in parens: “… (16g)” or “… (240 ml)”
    final paren = RegExp(
      r'\((\d+(?:[.,]\d+)?)\s*(g|gram|grams|ml|milliliter|milliliters)\b',
      caseSensitive: false,
    ).firstMatch(joined);
    if (paren != null) {
      final v = _toDouble(paren.group(1)!);
      final u = _normUnit(paren.group(2)!);
      return (v, u);
    }

    // Otherwise: “serving size 2 Tbsp”, “1/2 cup”, etc.
    final m = RegExp(
      r'serving\s*size[:\s-]*([0-9]+(?:[./][0-9]+)?)\s*([a-zA-Z]+)',
      caseSensitive: false,
    ).firstMatch(joined);
    if (m != null) {
      final v = _toDouble(m.group(1)!);
      final rawUnit = m.group(2)!;
      return (v, _normUnit(rawUnit));
    }
    return (null, null);
  }

  static String _normUnit(String u) {
    final t = u.toLowerCase();
    if (t.startsWith('g')) return 'g';
    if (t == 'ml' || t.startsWith('milliliter')) return 'ml';
    if (t.startsWith('tbsp') || t.startsWith('tablespoon')) return 'tbsp';
    if (t == 'tsp' || t.startsWith('teaspoon')) return 'tsp';
    if (t.startsWith('cup')) return 'cup';
    if (t == 'oz' || t.startsWith('ounce')) return 'oz';
    return t;
  }

  static double _toDouble(String s) {
    final t = s.replaceAll(',', '.').trim();
    if (t.contains('/')) {
      // fraction like 1/2 or 2/3
      final parts = t.split('/');
      if (parts.length == 2) {
        final a = double.tryParse(parts[0]) ?? 0;
        final b = double.tryParse(parts[1]) ?? 1;
        return a / b;
      }
    }
    return double.tryParse(t) ?? 0;
  }

  static bool _containsAnyAlias(String line) {
    for (final a in _allAliases) {
      if (RegExp(r'\b' + RegExp.escape(a) + r'\b', caseSensitive: false)
          .hasMatch(line)) return true;
    }
    return false;
  }

  static bool _containsAnyOf(String line, List<String> aliases) {
    for (final a in aliases) {
      if (RegExp(r'\b' + RegExp.escape(a) + r'\b', caseSensitive: false)
          .hasMatch(line)) return true;
    }
    return false;
  }

  /// Find a value *nearest to the alias* on the same line (to the right),
  /// optionally requiring a unit; ignores percentages. If none, look **left**
  /// of the alias within a small window (handles “includes 2 g added sugars”).
  /// Finally, fall back to the next line **only** if it isn’t clearly another
  /// nutrient row.
  static double? _valueFor(
    List<String> lines,
    List<String> aliases, {
    String? unit,
    int leftWindow = 16, // chars to look left of alias
  }) {
    final aliasRegexes = [
      for (final a in aliases)
        RegExp(r'\b' + RegExp.escape(a) + r'\b', caseSensitive: false),
    ];
    final numWithUnit = unit == null
        ? RegExp(r'(\d+(?:[.,]\d+)?)\s*(g|mg|kcal|cal)?(?!\s*%)\b', caseSensitive: false)
        : RegExp(
            r'(\d+(?:[.,]\d+)?)\s*' + RegExp.escape(unit) + r'(?!\s*%)\b',
            caseSensitive: false,
          );

    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];

      final aliasMatch = aliasRegexes
          .map((re) => re.firstMatch(line))
          .firstWhere((m) => m != null, orElse: () => null);
      if (aliasMatch == null) continue;

      final aliasStart = aliasMatch.start;
      final aliasEnd = aliasMatch.end;

      // 1) Same line — choose number AFTER the alias, nearest to it
      final all = numWithUnit.allMatches(line).toList();
      final after = all.where((m) => m.start >= aliasEnd).toList();
      if (after.isNotEmpty) {
        after.sort((a, b) => (a.start - aliasEnd).compareTo(b.start - aliasEnd));
        final raw = after.first.group(1)!;
        final v = double.tryParse(raw.replaceAll(',', '.'));
        if (v != null) return v;
      }

      // 2) Same line — look LEFT within a small window (e.g., “includes 2 g added sugars”)
      final before = all.where((m) => m.end <= aliasStart).toList();
      if (before.isNotEmpty) {
        // closest to the alias from the left side
        before.sort((a, b) => (aliasStart - a.end).compareTo(aliasStart - b.end));
        final nearest = before.first;
        if (aliasStart - nearest.end <= leftWindow) {
          final raw = nearest.group(1)!;
          final v = double.tryParse(raw.replaceAll(',', '.'));
          if (v != null) return v;
        }
      }

      // 3) Next-line fallback — only if the next line doesn’t look like a different nutrient row
      if (i + 1 < lines.length) {
        final next = lines[i + 1];
        final isDifferentRow = _containsAnyAlias(next) && !_containsAnyOf(next, aliases);
        if (!isDifferentRow) {
          final m2 = numWithUnit.firstMatch(next);
          if (m2 != null) {
            final raw = m2.group(1)!;
            final v = double.tryParse(raw.replaceAll(',', '.'));
            if (v != null) return v;
          }
        }
      }
    }
    return null;
  }


    /// Calories line: grab the integer nearest *after* the word "calories".

   /// Calories line: pick the best integer *after* the word "calories".
/// Scans a window until we hit a section fence (e.g. "% Daily Value").
/// Uses scoring so the big standalone number wins over DV/units rows.
/// Robustly extract kcal near the "Calories" label.
/// Strategy:
///  - After the first line that contains "calories", scan forward.
///  - If we see a **digits-only** line (20..1200) within ~30 lines,
///    return it immediately. This matches the big headline number.
///  - Otherwise, collect candidates and pick the best by a small score.
///  - Only fence by "% Daily Value" so we don't miss a late headline.
static double? _extractCalories(List<String> lines) {
  final reCal   = RegExp(r'\bcalories\b', caseSensitive: false);
  final reDV    = RegExp(r'%\s*daily\s*value', caseSensitive: false);

  // strip common invisibles / bidi / NBSP / soft hyphen etc.
  String _stripWeird(String s) => s
      .replaceAll('\u200E', '')
      .replaceAll('\u200F', '')
      .replaceAll('\u200B', '')
      .replaceAll('\u200C', '')
      .replaceAll('\u200D', '')
      .replaceAll('\u00A0', ' ')
      .replaceAll('\u00AD', '')
      .replaceAll(RegExp(r'[\u202A-\u202E]'), '')
      .replaceAll('|', ' ')
      .trim();

  // detect a pure integer line (no letters, no units, one number)
  bool _isHeadlineNumber(String s) {
    final c = _stripWeird(s);
    // common OCR “6o” => “60”
    final fix = c.replaceAllMapped(RegExp(r'(?<=\b)(\d)[oO](?=\b)'), (m) => '${m[1]}0');
    // if any letters exist, bail (we only want a naked number line)
    if (RegExp(r'[a-z]', caseSensitive: false).hasMatch(fix)) return false;
    // must not contain obvious units or percent
    if (RegExp(r'(?:%|\bg\b|\bmg\b|\bkcal\b|\bcal\b)', caseSensitive: false).hasMatch(fix)) {
      return false;
    }
    // must be exactly one integer token and line must be that token
    final m = RegExp(r'^\s*(\d{1,4})\s*$').firstMatch(fix);
    if (m == null) return false;
    final v = int.tryParse(m.group(1)!);
    return v != null && v >= 20 && v <= 1200;
  }

  for (var i = 0; i < lines.length; i++) {
    if (!reCal.hasMatch(lines[i])) continue;

    // look ahead until "% Daily Value"
    for (int j = i + 1; j < lines.length && j <= i + 80; j++) {
      final s = lines[j];
      if (reDV.hasMatch(s)) break;
      if (_isHeadlineNumber(s)) {
        final v = int.parse(RegExp(r'(\d{1,4})').firstMatch(_stripWeird(s))!.group(1)!);
        debugPrint('Calories candidate (headline) => $v from line: "$s"');        
        return v.toDouble(); // <- should return 60 for your label
      }
    }

    // If we didn’t find a pure headline, don’t guess.
    return null;
  }
  return null;
}



/// Robustly parse “Includes 2 g Added Sugars”, “Incl. 2g added sugars”, etc.
/// Returns the number of grams if found, else null.
    static double? _extractAddedSugars(List<String> lines) {
        // 1) direct “includes X g added sugars” patterns
        final reIncl = RegExp(
            r'\binc(?:l|ludes)?\b.*?(\d+(?:[.,]\d+)?)\s*g\s*added\s*sugars',
            caseSensitive: false,
        );
        for (final l in lines) {
            final m = reIncl.firstMatch(l);
            if (m != null) {
            return double.tryParse(m.group(1)!.replaceAll(',', '.'));
            }
        }

        // 2) plain “added sugars … X g” patterns
        final reAfter = RegExp(
            r'\badded\s*sugars\b.*?(\d+(?:[.,]\d+)?)\s*g(?!\s*%)',
            caseSensitive: false,
        );
        for (final l in lines) {
            final m = reAfter.firstMatch(l);
            if (m != null) {
            return double.tryParse(m.group(1)!.replaceAll(',', '.'));
            }
        }

        // 3) last resort: let the generic nearest-number logic try (with wider left window)
        return _valueFor(lines,
            ['added sugars', 'incl added sugars', 'includes added sugars', 'incl. added sugars'],
            unit: 'g',
            leftWindow: 48);
    }


    static String _norm(String s) {
        var t = s;

        // Keep real newlines
        t = t.replaceAll('\r\n', '\n').replaceAll('\r', '\n');

        // Lowercase for matching
        t = t.toLowerCase();

        // Common OCR fixes
        t = t.replaceAll('cholester0l', 'cholesterol');
        t = t.replaceAll('proteln', 'protein');
        t = t.replaceAll('sodlum', 'sodium');
        t = t.replaceAll('calorles', 'calories');
        t = t.replaceAll('kcai', 'kcal');
        t = t.replaceAll('satfat', 'sat fat');
        t = t.replaceAll('saturatedfat', 'saturated fat');
        t = t.replaceAll('totalfat', 'total fat');
        t = t.replaceAll('totalcarbohydrate', 'total carbohydrate');
        t = t.replaceAll('dietaryfiber', 'dietary fiber');
        t = t.replaceAll('addedsugars', 'added sugars');

        // Treat pipes as line breaks, not spaces
        t = t.replaceAll(RegExp(r'\s*\|\s*'), '\n');

        // Put key headers on their own lines (both sides)
        t = t.replaceAllMapped(RegExp(r'\bserving\s*size\b', caseSensitive: false),
            (m) => '\n${m[0]}\n');
        t = t.replaceAllMapped(RegExp(r'\bcalories\b', caseSensitive: false),
            (m) => '\n${m[0]}\n');
        t = t.replaceAllMapped(RegExp(r'%\s*daily\s*value\*?', caseSensitive: false),
            (m) => '\n${m[0]}\n');

        // Separate units from numbers
        t = t.replaceAll(RegExp(r'(?<=\d)mg\b'), ' mg');
        t = t.replaceAll(RegExp(r'(?<=\d)g\b'),  ' g');
        t = t.replaceAll(RegExp(r'(?<=\d)kcal\b'), ' kcal');
        t = t.replaceAll(RegExp(r'(?<=\d)cal\b'),  ' cal');

        // Typical zero misreads
        t = t.replaceAll(RegExp(r'\bomg\b'), ' 0 mg');
        t = t.replaceAll(RegExp(r'\bog\b'),  ' 0 g');

        // IMPORTANT: do NOT collapse all whitespace here.
        // We’ll trim per line inside parse().
        return t;
    }  
}
