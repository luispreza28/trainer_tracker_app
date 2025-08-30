// test/nutrition_ocr_parser_corpus_test.dart
import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'package:frontend/services/nutrition_ocr_parser.dart';

/// Where we keep the corpus.
final _root = p.join('test', 'corpus');
final _ocrDir = p.join(_root, 'ocr_raw');
final _expDir = p.join(_root, 'expected');

/// Tolerances per field (absolute).
/// Keep these tight; widen only when you hit unavoidable OCR vagaries.
const _tol = <String, double>{
  'calories': 10.0,        // kcal
  'fat_g': 0.6,
  'sat_fat_g': 0.6,
  'trans_fat_g': 0.6,
  'cholesterol_mg': 15.0,
  'sodium_mg': 20.0,
  'carbs_g': 0.6,
  'fiber_g': 0.6,
  'sugar_g': 0.6,
  'added_sugar_g': 0.6,
  'protein_g': 0.6,
  'serving_size_value': 0.3, // e.g., 1/2 cup → 0.5
};

/// Normalize expected/actual units to the same canonical form.
String? _normUnit(String? u) {
  if (u == null) return null;
  final t = u.trim().toLowerCase();
  if (t.startsWith('tbsp') || t.startsWith('tablespoon')) return 'tbsp';
  if (t == 'tsp' || t.startsWith('teaspoon')) return 'tsp';
  if (t == 'ml' || t.startsWith('milliliter')) return 'ml';
  if (t.startsWith('cup')) return 'cup';
  if (t == 'oz' || t.startsWith('ounce')) return 'oz';
  if (t.startsWith('g')) return 'g';
  return t;
}

/// If ENV var is set, we will auto-create expected JSON for any missing sample.
/// This is handy for bootstrapping a big corpus quickly.
/// Use carefully: UPDATE_EXPECTED=1 flutter test test/nutrition_ocr_parser_corpus_test.dart
final _allowWriteExpected = Platform.environment['UPDATE_EXPECTED'] == '1';

void main() {
  group('Nutrition OCR parser corpus', () {
    final samples = Directory(_ocrDir)
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.txt'))
        .toList()
      ..sort((a, b) => a.path.compareTo(b.path));

    test('Corpus sanity: found at least one .txt OCR sample', () {
      expect(samples.isNotEmpty, true,
          reason:
              'No OCR samples found in $_ocrDir — add files like pbfit.txt');
    });

    for (final txt in samples) {
      final name = p.basenameWithoutExtension(txt.path);
      final expectedJson = File(p.join(_expDir, '$name.json'));

      test('parse "$name"', () async {
        final raw = await txt.readAsString();

        final parsed = NutritionOcrParser.parse(raw);
        final actualMap = parsed.toMap();

        if (!expectedJson.existsSync()) {
          if (_allowWriteExpected) {
            expectedJson.createSync(recursive: true);
            expectedJson.writeAsStringSync(
              const JsonEncoder.withIndent('  ').convert(actualMap),
            );
            // Still pass the test; next run will compare.
            return;
          } else {
            fail(
              'Missing expected file: ${expectedJson.path}\n'
              'Run with UPDATE_EXPECTED=1 to auto-create it from current parser output.',
            );
          }
        }

        final expected =
            jsonDecode(await expectedJson.readAsString()) as Map<String, dynamic>;

        // Compare units (string)
        final expUnit = _normUnit(expected['serving_size_unit'] as String?);
        final actUnit = _normUnit(actualMap['serving_size_unit'] as String?);
        if (expUnit != null) {
          expect(
            actUnit,
            expUnit,
            reason: 'serving_size_unit mismatch for "$name": expected $expUnit, got $actUnit',
          );
        }

        // Compare numbers with tolerance
        final keys = <String>[
          'serving_size_value',
          'calories',
          'fat_g',
          'sat_fat_g',
          'trans_fat_g',
          'cholesterol_mg',
          'sodium_mg',
          'carbs_g',
          'fiber_g',
          'sugar_g',
          'added_sugar_g',
          'protein_g',
        ];

        final failures = <String>[];

        for (final k in keys) {
          if (!expected.containsKey(k)) continue; // not asserted for this sample
          final exp = (expected[k] as num?)?.toDouble();
          final act = (actualMap[k] as num?)?.toDouble();

          if (exp == null && act == null) continue;

          if (exp == null && act != null) {
            failures.add('$k: expected null, got $act');
            continue;
          }
          if (exp != null && act == null) {
            failures.add('$k: expected $exp, got null');
            continue;
          }

          final tol = _tol[k] ?? 0.0001;
          final diff = (act! - exp!).abs();
          if (diff > tol) {
            failures.add('$k: expected $exp, got $act (diff=$diff, tol=$tol)');
          }
        }

        if (failures.isNotEmpty) {
          fail('Sample "$name" had ${failures.length} mismatch(es):\n'
              ' - ${failures.join('\n - ')}\n\n'
              'Actual parsed map:\n${const JsonEncoder.withIndent('  ').convert(actualMap)}');
        }
      });
    }
  });
}
