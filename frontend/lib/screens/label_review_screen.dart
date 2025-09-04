import 'dart:io';
import 'package:flutter/material.dart';

import '../services/nutrition_ocr_parser.dart';

/// Result returned to the scanner after user taps Save.
class LabelReviewResult {
  final NutritionParseResult parsed; // per-serving values after edits
  final double servingsEaten;        // multiplier
  final String? foodName;            // optional name typed by user

  const LabelReviewResult({
    required this.parsed,
    required this.servingsEaten,
    this.foodName,
  });
}

class LabelReviewScreen extends StatefulWidget {
  final File imageFile;
  final NutritionParseResult initial; // parsed values
  final int foodId; // kept for parity (not used here, POST happens in scan screen)

  const LabelReviewScreen({
    super.key,
    required this.imageFile,
    required this.initial,
    required this.foodId,
  });

  @override
  State<LabelReviewScreen> createState() => _LabelReviewScreenState();
}

class _LabelReviewScreenState extends State<LabelReviewScreen> {
  bool _saving = false;

  // Serving size + unit + servings eaten
  late final TextEditingController _ssValue = TextEditingController(
    text: _fmt(widget.initial.servingSizeValue),
  );
  late String _ssUnit = widget.initial.servingSizeUnit ?? '';
  late final TextEditingController _servings = TextEditingController(text: '1');

  // Optional food name
  late final TextEditingController _name = TextEditingController();

  // Nutrients (per serving)
  late final TextEditingController _cal   = TextEditingController(text: _fmt(widget.initial.calories));
  late final TextEditingController _fat   = TextEditingController(text: _fmt(widget.initial.fat_g));
  late final TextEditingController _sat   = TextEditingController(text: _fmt(widget.initial.satFat_g));
  late final TextEditingController _trans = TextEditingController(text: _fmt(widget.initial.transFat_g));
  late final TextEditingController _chol  = TextEditingController(text: _fmt(widget.initial.cholesterol_mg));
  late final TextEditingController _sod   = TextEditingController(text: _fmt(widget.initial.sodium_mg));
  late final TextEditingController _carb  = TextEditingController(text: _fmt(widget.initial.carbs_g));
  late final TextEditingController _fiber = TextEditingController(text: _fmt(widget.initial.fiber_g));
  late final TextEditingController _sugar = TextEditingController(text: _fmt(widget.initial.sugar_g));
  late final TextEditingController _added = TextEditingController(text: _fmt(widget.initial.addedSugar_g));
  late final TextEditingController _prot  = TextEditingController(text: _fmt(widget.initial.protein_g));

  // Live total calories (read-only): calories_per_serving × servings_eaten
  late final TextEditingController _totalCaloriesCtrl = TextEditingController();

  String _fmt(double? v) => (v == null)
      ? ''
      : (v % 1 == 0 ? v.toInt().toString() : v.toString());

  double? _num(TextEditingController c) {
    final t = c.text.trim().replaceAll(',', '.');
    if (t.isEmpty) return null;
    return double.tryParse(t);
  }

  double _parseServings() {
    final t = _servings.text.trim().replaceAll(',', '.');
    final v = double.tryParse(t);
    if (v == null || !v.isFinite || v <= 0) return 1.0;
    return v;
  }

  // Constrain obviously-wrong subs to keep UI sane.
  void _applyGuards() {
    final fat = _num(_fat);
    final sat = _num(_sat);
    final trans = _num(_trans);
    final carbs = _num(_carb);
    final fiber = _num(_fiber);
    final sugar = _num(_sugar);

    if (fat != null && sat != null && sat > fat) _sat.text = fat.toString();
    if (fat != null && trans != null && trans > fat) _trans.text = fat.toString();
    if (carbs != null && fiber != null && fiber > carbs) _fiber.text = carbs.toString();
    if (carbs != null && sugar != null && sugar > carbs) _sugar.text = carbs.toString();
  }

  // Keep total calories in sync
  void _syncTotalCalories() {
    final cal = _num(_cal);
    final s = _parseServings();
    final tot = (cal == null) ? null : (cal * s);
    if (tot == null) {
      _totalCaloriesCtrl.text = '';
    } else {
      _totalCaloriesCtrl.text = (tot % 1 == 0)
          ? tot.toInt().toString()
          : tot.toStringAsFixed(1);
    }
  }

  @override
  void initState() {
    super.initState();
    _cal.addListener(_syncTotalCalories);
    _servings.addListener(_syncTotalCalories);
    _syncTotalCalories();
  }

  @override
  void dispose() {
    for (final c in [
      _ssValue,
      _servings,
      _name,
      _cal,
      _fat,
      _sat,
      _trans,
      _chol,
      _sod,
      _carb,
      _fiber,
      _sugar,
      _added,
      _prot,
      _totalCaloriesCtrl,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final units = const ['g', 'ml', 'cup', 'tbsp', 'tsp', 'oz', '']; // '' = unknown
    return Scaffold(
      appBar: AppBar(
        title: const Text('Review nutrition facts'),
        actions: [
          TextButton(
            onPressed: _saving ? null : _onSave,
            child: const Text('Save', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.file(widget.imageFile, fit: BoxFit.cover, height: 200),
          ),
          const SizedBox(height: 16),

          // Optional name
          TextFormField(
            controller: _name,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'Food name (optional)',
            ),
          ),
          const SizedBox(height: 16),

          _section('Serving'),
          Row(
            children: [
              Expanded(child: _numField('Serving size', _ssValue)),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonFormField<String>(
                  decoration: const InputDecoration(labelText: 'Unit (g, ml, cup...)'),
                  value: _ssUnit.isEmpty ? null : _ssUnit,
                  items: units
                      .map((u) => DropdownMenuItem(
                            value: u.isEmpty ? null : u,
                            child: Text(u.isEmpty ? '—' : u),
                          ))
                      .toList(),
                  onChanged: (v) => setState(() => _ssUnit = v ?? ''),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _numField('Servings eaten', _servings)),
              const SizedBox(width: 12),
              Expanded(child: _numField('Calories (kcal)', _cal)),
            ],
          ),

          // Live total calories (read-only)
          TextFormField(
            controller: _totalCaloriesCtrl,
            readOnly: true,
            decoration: const InputDecoration(
              labelText: 'Total calories',
              suffixText: 'kcal',
            ),
          ),

          const SizedBox(height: 12),
          _section('Fats'),
          Row(
            children: [
              Expanded(child: _numField('Total fat (g)', _fat)),
              const SizedBox(width: 12),
              Expanded(child: _numField('Sat fat (g)', _sat)),
            ],
          ),

          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _numField('Trans fat (g)', _trans)),
              const SizedBox(width: 12),
              Expanded(child: _numField('Cholesterol (mg)', _chol)),
            ],
          ),

          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _numField('Sodium (mg)', _sod)),
              const SizedBox(width: 12),
              Expanded(child: _numField('Carbs (g)', _carb)),
            ],
          ),

          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _numField('Fiber (g)', _fiber)),
              const SizedBox(width: 12),
              Expanded(child: _numField('Sugars (g)', _sugar)),
            ],
          ),

          const SizedBox(height: 12),
          _numField('Added sugars (g)', _added),
          const SizedBox(height: 12),
          _numField('Protein (g)', _prot),
          const SizedBox(height: 24),
        ],
      ),
      bottomSheet: Container(
        color: Theme.of(context).scaffoldBackgroundColor,
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _saving ? null : () => Navigator.of(context).pop(null),
                icon: const Icon(Icons.close),
                label: const Text('Cancel'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton.icon(
                onPressed: _saving ? null : _onSave,
                icon: const Icon(Icons.check),
                label: Text(_saving ? 'Saving…' : 'Save'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _onSave() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      final result = LabelReviewResult(
        parsed: _gatherParsedFromUI(),
        servingsEaten: _parseServings(),
        foodName: _name.text.trim().isEmpty ? null : _name.text.trim(),
      );
      if (!mounted) return;
      Navigator.of(context).pop(result); // single pop
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _numField(String label, TextEditingController c) {
    return TextFormField(
      controller: c,
      decoration: InputDecoration(labelText: label),
      keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: false),
      onChanged: (_) => _applyGuards(),
    );
  }

  Widget _section(String title) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(title, style: Theme.of(context).textTheme.titleMedium),
      );

  NutritionParseResult _gatherParsedFromUI() {
    double? _n(TextEditingController c) => _num(c);

    return NutritionParseResult(
      servingSizeValue: _n(_ssValue),
      servingSizeUnit: _ssUnit.isEmpty ? null : _ssUnit,
      calories: _n(_cal),
      fat_g: _n(_fat),
      satFat_g: _n(_sat),
      transFat_g: _n(_trans),
      cholesterol_mg: _n(_chol),
      sodium_mg: _n(_sod),
      carbs_g: _n(_carb),
      fiber_g: _n(_fiber),
      sugar_g: _n(_sugar),
      addedSugar_g: _n(_added),
      protein_g: _n(_prot),
    );
  }
}