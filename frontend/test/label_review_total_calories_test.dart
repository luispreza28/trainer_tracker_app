// test/label_review_total_calories_test.dart
// Widget tests for live "Total calories" calculation on LabelReviewScreen.
// These tests verify that the read-only Total Calories field updates when the
// user changes either "Servings eaten" or "Calories (kcal)".

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:frontend/screens/label_review_screen.dart';
import 'package:frontend/services/nutrition_ocr_parser.dart';

void main() {
  group('LabelReviewScreen — Total calories live updates', () {
    late File img;

    setUp(() async {
      img = await _createTinyPng();
    });

    tearDown(() async {
      if (img.existsSync()) {
        try { img.deleteSync(recursive: true); } catch (_) {}
      }
    });

    testWidgets('updates when Servings eaten changes', (tester) async {
      // Arrange: initial calories per serving = 120, default servings = 1
      final initial = NutritionParseResult(
        servingSizeValue: 30,
        servingSizeUnit: 'g',
        calories: 120,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: LabelReviewScreen(
            imageFile: img,
            initial: initial,
            foodId: 0,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Act: change servings to 2
      await tester.enterText(find.bySemanticsLabel('Servings eaten'), '2');
      await tester.pump();

      // Assert: total calories = 120 * 2 = 240
      expect(find.text('240'), findsOneWidget);
      expect(find.bySemanticsLabel('Total calories'), findsOneWidget);
    });

    testWidgets('updates when Calories (kcal) changes', (tester) async {
      final initial = NutritionParseResult(
        servingSizeValue: 40,
        servingSizeUnit: 'g',
        calories: 100,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: LabelReviewScreen(
            imageFile: img,
            initial: initial,
            foodId: 0,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Set servings to 2 first -> total 200
      await tester.enterText(find.bySemanticsLabel('Servings eaten'), '2');
      await tester.pump();
      expect(find.text('200'), findsOneWidget);

      // Act: change calories per serving to 150
      await tester.enterText(find.bySemanticsLabel('Calories (kcal)'), '150');
      await tester.pump();

      // Assert: total calories = 150 * 2 = 300
      expect(find.text('300'), findsOneWidget);
    });

    testWidgets('formats non-integers with one decimal place', (tester) async {
      final initial = NutritionParseResult(
        servingSizeValue: 25,
        servingSizeUnit: 'g',
        calories: 123,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: LabelReviewScreen(
            imageFile: img,
            initial: initial,
            foodId: 0,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // servings 1.2 -> total 147.6
      await tester.enterText(find.bySemanticsLabel('Servings eaten'), '1.2');
      await tester.pump();

      // Assert: shows one decimal (147.6)
      expect(find.text('147.6'), findsOneWidget);
    });
  });
}

/// Creates a tiny valid 1x1 PNG file for Image.file to decode during tests.
Future<File> _createTinyPng() async {
  const b64 =
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO9qjKgAAAAASUVORK5CYII=';
  final bytes = base64Decode(b64);
  final dir = await Directory.systemTemp.createTemp('label_review_test_');
  final f = File('${dir.path}${Platform.pathSeparator}tiny.png');
  await f.writeAsBytes(Uint8List.fromList(bytes), flush: true);
  return f;
}
