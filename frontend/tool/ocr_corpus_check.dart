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

  for (final f in rawDir.listSync().whereType<File>()) {
    if (!f.path.endsWith('.txt')) continue;
    final name = f.uri.pathSegments.last.replaceAll('.txt', '');
    final raw = await f.readAsString();

    // feed exactly what the app sees: the raw OCR lines
    final result = NutritionOcrParser.parse(raw).toMap();

    final expFile = File('${expDir.path}/$name.json');
    if (!expFile.existsSync()) {
      stdout.writeln('[NEW] $name — writing expected.');
      if (doUpdate) {
        await expFile.writeAsString(JsonEncoder.withIndent('  ').convert(result));
      } else {
        failures++;
        continue;
      }
    } else {
      final expected = jsonDecode(await expFile.readAsString()) as Map<String, dynamic>;

      // Compare shallow equality for known keys
      final keys = {
        'serving_size_value','serving_size_unit','calories','fat_g','sat_fat_g','trans_fat_g',
        'cholesterol_mg','sodium_mg','carbs_g','fiber_g','sugar_g','added_sugar_g','protein_g'
      };

      final diffs = <String, List<dynamic>>{};
      for (final k in keys) {
        final a = expected[k];
        final b = result[k];
        // treat 0 and null as different; you can relax if you like
        if (a != b) diffs[k] = [a, b];
      }

      if (diffs.isEmpty) {
        stdout.writeln('[OK ] $name');
      } else {
        failures++;
        stdout.writeln('[DIFF] $name:');
        diffs.forEach((k, v) => stdout.writeln('  $k: expected=${v[0]}  got=${v[1]}'));
        if (doUpdate) {
          await expFile.writeAsString(JsonEncoder.withIndent('  ').convert(result));
          stdout.writeln('  -> updated expected/$name.json');
        }
      }
    }
  }

  if (!doUpdate && failures > 0) {
    stdout.writeln('\nRun with --update to rewrite expected outputs.');
    exit(1);
  }
}
