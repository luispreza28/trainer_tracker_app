// lib/services/nutrition_ocr_service.dart
import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

import 'nutrition_ocr_parser.dart'; // NutritionParseResult + parseNutritionLabel

class NutritionOcrService {
  NutritionOcrService({TextRecognizer? recognizer})
      : _recognizer = recognizer ??
            TextRecognizer(script: TextRecognitionScript.latin);

  final TextRecognizer _recognizer;

  /// Run ML Kit on [imageFile], then parse the recognized text on a background
  /// isolate. Throws on errors (UI can catch and show a message).
  Future<NutritionParseResult> extract(File imageFile) async {
    final input = InputImage.fromFile(imageFile);
    final recognized = await _recognizer.processImage(input);

    // Collect lightweight (text, y) geo lines for layout-aware parsing.
    final geoLines = <Map<String, dynamic>>[];
    for (final block in recognized.blocks) {
      for (final line in block.lines) {
        // y from boundingBox if present, otherwise min(cornerPoints.y)
        final y = line.boundingBox?.top ??
            (line.cornerPoints?.map((pt) => pt.y).reduce((a, b) => a < b ? a : b) ?? 0);
        geoLines.add({'t': line.text, 'y': y.toDouble()});
      }
    }
    // Sort by vertical position, top → bottom (not strictly necessary but nice)
    geoLines.sort((a, b) => (a['y'] as double).compareTo(b['y'] as double));

    // Offload parsing to an isolate (needs a simple map payload).
    final payload = {
      'rawText': recognized.text,
      'geoLines': geoLines,
    };
    final result = await compute(parseNutritionLabelWithGeo, payload);
    return result;
  }
  
  /// Directly parse raw text (useful for unit tests or debugging).
  Future<NutritionParseResult> extractFromText(String raw) async {
    try {
      return await compute(parseNutritionLabel, raw);
    } catch (_) {
      // Fallback if compute() is unavailable (e.g., some test environments)
      return parseNutritionLabel(raw);
    }
  }

  Future<void> dispose() => _recognizer.close();
}
