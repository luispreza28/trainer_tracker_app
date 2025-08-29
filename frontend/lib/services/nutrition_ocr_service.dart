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
    try {
      final input = InputImage.fromFile(imageFile);
      final recognized = await _recognizer.processImage(input);

      final raw = recognized.text; // already includes line breaks
      // Offload parsing to keep UI smooth.
      debugPrint('OCR RAW >>> ${recognized.text}');
      return await compute(parseNutritionLabel, raw);
    } catch (e, st) {
      debugPrint('NutritionOcrService.extract error: $e\n$st');
      rethrow;
    }
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
