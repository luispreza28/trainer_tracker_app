// dart run tool/ocr_corpus_check.dart [--update]
import 'dart:convert';
import 'dart:io';

import '../lib/services/nutrition_ocr_parser.dart';

void main(List<String> args) async {
  final doUpdate = args.contains('--update');
  final root = Directory.current.path.replaceAll('\\', '/');

  final rawDir = Directory('$root/test/corpus/ocr_raw');
  final expDir = Directory('$root/test/corpus/expected');
  if (!rawDir.existsSync() || !expDir.existsSync()) {
    stderr.writeln('Corpus directories not found.');
    exit(2);
  }

  var failures = 0;
  var created = 0;

  // Process .txt files in a stable order
  final files = rawDir
      .listSync()
      .whereType<File>()
      .where((f) => f.path.endsWith('.txt'))
      .toList()
    ..sort((a, b) => a.path.compareTo(b.path));

  for (final f in files) {
    final name = _baseNameNoExt(f);
    final raw = await f.readAsString();

    // feed exactly what the app sees: the raw OCR lines
    final result = NutritionOcrParser.parse(raw).toMap();

    final expFile = File('${expDir.path}/$name.json');
    if (!expFile.existsSync()) {
      stdout.writeln('[NEW] $name — writing expected.');
      if (doUpdate) {
        await expFile.writeAsString(
          JsonEncoder.withIndent('  ').convert(result),
        );
        created++;
      } else {
        // Missing expected is considered a failure unless --update is used
        failures++;
        continue;
      }
    } else {
      final expected =
          jsonDecode(await expFile.readAsString()) as Map<String, dynamic>;

      // Keys we care to compare
      const keys = <String>{
        'serving_size_value',
        'serving_size_unit',
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
      };

      final diffs = <String, List<dynamic>>{};
      for (final k in keys) {
        final a = expected[k];
        final b = result[k];
        if (!_equalsWithTolerance(a, b)) {
          diffs[k] = [a, b];
        }
      }

      if (diffs.isEmpty) {
        stdout.writeln('[OK ] $name');
      } else {
        failures++;
        stdout.writeln('[DIFF] $name:');
        diffs.forEach((k, v) {
          stdout.writeln('  $k: expected=${v[0]}  got=${v[1]}');
        });
        if (doUpdate) {
          await expFile.writeAsString(
            JsonEncoder.withIndent('  ').convert(result),
          );
          stdout.writeln('  -> updated expected/$name.json');
        }
      }
    }
  }

  if (created > 0) {
    stdout.writeln('Created $created new expected file(s).');
  }

  if (failures > 0 && !doUpdate) {
    stdout.writeln('\nRun with --update to rewrite expected outputs.');
    exit(1); // fail CI
  }

  exit(0); // success
}

bool _equalsWithTolerance(dynamic a, dynamic b) {
  if (a == null && b == null) return true;
  if (a == null || b == null) return false;

  // Same type + exact match
  if (a.runtimeType == b.runtimeType && a == b) return true;

  // Numeric tolerance (±0.5) to allow rounding differences
  if (a is num && b is num) {
    final da = a.toDouble();
    final db = b.toDouble();
    return (da - db).abs() <= 0.5;
  }

  // Fallback to string equality for everything else
  return a.toString() == b.toString();
}

String _baseNameNoExt(File f) {
  final segs = f.uri.pathSegments;
  final base = segs.isNotEmpty ? segs.last : f.path;
  return base.replaceAll(RegExp(r'\.txt$', caseSensitive: false), '');
}
