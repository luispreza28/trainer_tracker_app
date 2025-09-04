// lib/screens/label_scan_screen.dart
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../services/nutrition_ocr_service.dart';
import '../services/nutrition_ocr_parser.dart';
import '../services/api_client.dart';
import '../models/food.dart'; // NutrientsPer100g model

import 'label_review_screen.dart'; // contains LabelReviewResult

class LabelScanScreen extends StatefulWidget {
  /// Optional: pass when launched from an existing food flow. Not used for save.
  final int? foodId;

  const LabelScanScreen({
    super.key,
    this.foodId,
  });

  @override
  State<LabelScanScreen> createState() => _LabelScanScreenState();
}

class _LabelScanScreenState extends State<LabelScanScreen> {
  final _picker = ImagePicker();
  final _svc = NutritionOcrService();

  File? _imageFile;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _svc.dispose();
    super.dispose();
  }

  Future<void> _pick(ImageSource source) async {
    setState(() => _error = null);

    final x = await _picker.pickImage(
      source: source,
      imageQuality: 85,
      preferredCameraDevice: CameraDevice.rear,
    );
    if (x == null) return;

    final file = File(x.path);
    setState(() {
      _imageFile = file;
      _busy = true;
    });

    try {
      // 1) OCR -> per-serving parse
      final parsed = await _svc.extract(file);

      // 2) Review/edit -> user enters servings eaten & optional name
      final reviewed = await Navigator.of(context).push<LabelReviewResult>(
        MaterialPageRoute(
          builder: (_) => LabelReviewScreen(
            imageFile: file,
            initial: parsed,
            foodId: widget.foodId ?? 0,
          ),
          fullscreenDialog: true,
        ),
      );

      // 3) If user saved: create custom food (per-100g), then log meal with grams eaten
      if (reviewed != null) {
        final gramsPerServing = _servingSizeInGrams(reviewed.parsed);
        if (gramsPerServing == null || gramsPerServing <= 0) {
          setState(() {
            _error = 'Set serving unit to g or oz so we can compute grams.';
          });
          return;
        }
        final gramsEaten = gramsPerServing * reviewed.servingsEaten;

        final per100 = _toPer100g(reviewed.parsed, gramsPerServing);

        setState(() => _busy = true);
        try {
          final api = ApiClient();
          final defaultName = 'Scanned food (${DateTime.now().toIso8601String().substring(0, 19)})';
          final created = await api.createCustomFood(
            name: (reviewed.foodName?.trim().isNotEmpty ?? false)
                ? reviewed.foodName!.trim()
                : defaultName,
            nutrients: per100,
          );

          if (created.id == null) {
            throw ApiException('Server did not return a food id');
          }

          await api.addMeal(
            foodId: created.id!,
            quantity: gramsEaten,
            mealTime: DateTime.now(),
            notes: reviewed.foodName,
          );

          if (!mounted) return;
          Navigator.of(context).pop(true); // single pop AFTER POST succeeds
          return;
        } catch (e) {
          setState(() {
            _error = 'Save failed: $e';
          });
        } finally {
          if (mounted) setState(() => _busy = false);
        }
      }
    } catch (e) {
      setState(() => _error = 'Could not read label: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Convert one serving to grams (supports g/oz)
  double? _servingSizeInGrams(NutritionParseResult p) {
    final double? val = p.servingSizeValue;
    final String? unitRaw = p.servingSizeUnit?.toLowerCase().trim();
    if (val == null || unitRaw == null) return null;

    switch (unitRaw) {
      case 'g':
      case 'gram':
      case 'grams':
        return val;
      case 'oz':
      case 'ounce':
      case 'ounces':
        return val * 28.349523125;
      default:
        return null; // ml/cup/tbsp/tsp need density
    }
  }

  /// Build per-100g nutrients from per-serving values & grams per serving
  NutrientsPer100g _toPer100g(NutritionParseResult p, double gramsPerServing) {
    double? scale(double? perServing) {
      if (perServing == null || gramsPerServing <= 0) return null;
      return perServing / gramsPerServing * 100.0;
    }

    return NutrientsPer100g(
      calories: scale(p.calories),
      protein: scale(p.protein_g),
      carbs:   scale(p.carbs_g),
      fat:     scale(p.fat_g),
      fiber:   scale(p.fiber_g),
      sugar:   scale(p.sugar_g),
      sodium:  scale(p.sodium_mg),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Scan Nutrition Label')),
      body: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
            children: [
              if (_imageFile != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.file(_imageFile!, fit: BoxFit.cover, height: 200),
                ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
                ),
              const SizedBox(height: 12),
              Text(
                "Tap the button below to take a photo or pick from gallery. After review, we'll create a custom food and log your meal.",
                style: theme.textTheme.bodyMedium,
              ),
            ],
          ),
          if (_busy)
            Container(
              color: Colors.black26,
              child: const Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _busy ? null : () => _showPickSheet(context),
        icon: const Icon(Icons.document_scanner),
        label: const Text('Scan label'),
      ),
    );
  }

  void _showPickSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera),
              title: const Text('Take a photo'),
              onTap: () {
                Navigator.pop(ctx);
                _pick(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Choose from gallery'),
              onTap: () {
                Navigator.pop(ctx);
                _pick(ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }
}