// lib/screens/label_scan_screen.dart
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../services/nutrition_ocr_service.dart';
import '../services/nutrition_ocr_parser.dart';

class LabelScanScreen extends StatefulWidget {
  const LabelScanScreen({super.key});

  @override
  State<LabelScanScreen> createState() => _LabelScanScreenState();
}

class _LabelScanScreenState extends State<LabelScanScreen> {
  final _formKey = GlobalKey<FormState>();
  final _picker = ImagePicker();
  final _svc = NutritionOcrService();
  

  File? _imageFile;
  bool _busy = false;
  String? _error;

  // Editable fields
  final _servingSizeValue = TextEditingController();
  final _servingSizeUnit = TextEditingController();
  final _cal = TextEditingController();
  final _fat = TextEditingController();
  final _satFat = TextEditingController();
  final _transFat = TextEditingController();
  final _chol = TextEditingController();
  final _sodium = TextEditingController();
  final _carbs = TextEditingController();
  final _fiber = TextEditingController();
  final _sugar = TextEditingController();
  final _addedSugar = TextEditingController();
  final _protein = TextEditingController();

  @override
  void dispose() {
    _svc.dispose();
    _servingSizeValue.dispose();
    _servingSizeUnit.dispose();
    _cal.dispose();
    _fat.dispose();
    _satFat.dispose();
    _transFat.dispose();
    _chol.dispose();
    _sodium.dispose();
    _carbs.dispose();
    _fiber.dispose();
    _sugar.dispose();
    _addedSugar.dispose();
    _protein.dispose();
    super.dispose();
  }

  Future<void> _pick(ImageSource source) async {
    setState(() {
      _error = null;
    });
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
      final parsed = await _svc.extract(file);
      _fillFromParsed(parsed);
    } catch (e) {
      _error = 'Could not read label: $e';
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _fillFromParsed(NutritionParseResult p) {
    String n(double? v) => v == null ? '' : _trim(v);
    setState(() {
      _servingSizeValue.text = n(p.servingSizeValue);
      _servingSizeUnit.text = p.servingSizeUnit ?? '';
      _cal.text = n(p.calories);
      _fat.text = n(p.fat_g);
      _satFat.text = n(p.satFat_g);
      _transFat.text = n(p.transFat_g);
      _chol.text = n(p.cholesterol_mg);
      _sodium.text = n(p.sodium_mg);
      _carbs.text = n(p.carbs_g);
      _fiber.text = n(p.fiber_g);
      _sugar.text = n(p.sugar_g);
      _addedSugar.text = n(p.addedSugar_g);
      _protein.text = n(p.protein_g);
    });
  }

  String _trim(double v) {
    final s = v.toStringAsFixed(2);
    return s.endsWith('00')
        ? s.substring(0, s.length - 3)
        : (s.endsWith('0') ? s.substring(0, s.length - 1) : s);
  }

  double? _toDouble(String s) {
    final t = s.trim();
    if (t.isEmpty) return null;
    return double.tryParse(t.replaceAll(',', '.'));
  }

  void _save() {
    // Validate numeric fields (your _numField validator allows empty or valid numbers)
    if (!_formKey.currentState!.validate()) return;

    // Build the payload from the form
    final payload = <String, dynamic>{
        'serving_size_value': _toDouble(_servingSizeValue.text),
        'serving_size_unit': _servingSizeUnit.text.trim().isEmpty
            ? null
            : _servingSizeUnit.text.trim(),
        'calories':        _toDouble(_cal.text),
        'fat_g':           _toDouble(_fat.text),
        'sat_fat_g':       _toDouble(_satFat.text),
        'trans_fat_g':     _toDouble(_transFat.text),
        'cholesterol_mg':  _toDouble(_chol.text),
        'sodium_mg':       _toDouble(_sodium.text),
        'carbs_g':         _toDouble(_carbs.text),
        'fiber_g':         _toDouble(_fiber.text),
        'sugar_g':         _toDouble(_sugar.text),
        'added_sugar_g':   _toDouble(_addedSugar.text),
        'protein_g':       _toDouble(_protein.text),
    };

    // Try to also provide serving_size_g when the user's unit makes sense.
    final double? val = payload['serving_size_value'] as double?;
    final String? unitRaw =
        (payload['serving_size_unit'] as String?)?.toLowerCase().trim();

    double? grams;
    if (val != null && unitRaw != null) {
        switch (unitRaw) {
        case 'g':
        case 'gram':
        case 'grams':
            grams = val; // already grams
            break;
        case 'oz':
        case 'ounce':
        case 'ounces':
            grams = val * 28.3495; // convert oz → g
            break;
        // If you ever want to assume 1 ml ≈ 1 g for water-like items, you could:
        // case 'ml':
        //   grams = val;
        //   break;
        default:
            // If the user typed something like "55g" in unit by mistake, try to parse it:
            final m = RegExp(r'(\d+(?:[.,]\d+)?)\s*g').firstMatch(unitRaw);
            if (m != null) {
            grams = double.tryParse(m.group(1)!.replaceAll(',', '.'));
            }
        }
    }
    if (grams != null) {
        // Round sensibly for UI; keep it simple (no decimals for grams here)
        payload['serving_size_g'] = double.parse(grams.toStringAsFixed(0));
    }

    // Drop nulls to keep the payload tidy (optional)
    payload.removeWhere((_, v) => v == null);

    // Return the parsed/edited values to the caller screen
    Navigator.of(context).pop(payload);
}


  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan nutrition label'),
        actions: [
          TextButton(
            onPressed: _save,
            child: const Text('Save'),
          )
        ],
      ),
      body: Column(
        children: [
          if (_imageFile != null)
            AspectRatio(
              aspectRatio: 4 / 3,
              child: Image.file(_imageFile!, fit: BoxFit.cover),
            )
          else
            Container(
              height: 200,
              width: double.infinity,
              color: theme.colorScheme.surfaceContainerHighest,
              alignment: Alignment.center,
              child: const Text('No image selected'),
            ),
          if (_busy) const LinearProgressIndicator(minHeight: 2),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
            ),
          Expanded(
            child: Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(12),
                children: [
                  _row2(
                    _numField(_servingSizeValue, 'Serving size', suffix: ''),
                    _textField(_servingSizeUnit, 'Unit (g, ml, cup...)'),
                  ),
                  const Divider(),
                  _numField(_cal, 'Calories (kcal)'),
                  _row3(
                    _numField(_fat, 'Total fat', suffix: 'g'),
                    _numField(_satFat, 'Sat fat', suffix: 'g'),
                    _numField(_transFat, 'Trans fat', suffix: 'g'),
                  ),
                  _row2(
                    _numField(_chol, 'Cholesterol', suffix: 'mg'),
                    _numField(_sodium, 'Sodium', suffix: 'mg'),
                  ),
                  _row3(
                    _numField(_carbs, 'Carbs', suffix: 'g'),
                    _numField(_fiber, 'Fiber', suffix: 'g'),
                    _numField(_sugar, 'Sugars', suffix: 'g'),
                  ),
                  _numField(_addedSugar, 'Added sugars', suffix: 'g'),
                  _numField(_protein, 'Protein', suffix: 'g'),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: () => _showPickSheet(context),
                    icon: const Icon(Icons.document_scanner),
                    label: const Text('Scan label'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _numField(TextEditingController c, String label, {String? suffix}) {
    return TextFormField(
      controller: c,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(
        labelText: label,
        suffixText: suffix,
      ),
      validator: (v) {
        final t = v?.trim() ?? '';
        if (t.isEmpty) return null;
        final ok = double.tryParse(t.replaceAll(',', '.')) != null;
        return ok ? null : 'Number';
      },
    );
  }

  Widget _textField(TextEditingController c, String label) {
    return TextFormField(
      controller: c,
      decoration: InputDecoration(labelText: label),
    );
  }

  Widget _row2(Widget a, Widget b) {
    return Row(
      children: [
        Expanded(child: a),
        const SizedBox(width: 12),
        Expanded(child: b),
      ],
    );
  }

  Widget _row3(Widget a, Widget b, Widget c) {
    return Row(
      children: [
        Expanded(child: a),
        const SizedBox(width: 12),
        Expanded(child: b),
        const SizedBox(width: 12),
        Expanded(child: c),
      ],
    );
  }

  void _showPickSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera),
              title: const Text('Take photo'),
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
