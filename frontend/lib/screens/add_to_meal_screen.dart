// lib/screens/add_to_meal_screen.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/api_client.dart';
import '../screens/label_scan_screen.dart';


class AddToMealScreen extends StatefulWidget {
  final int foodId;
  final double defaultGrams;
  const AddToMealScreen({
    super.key,
    required this.foodId,
    this.defaultGrams = 100.0,
  });

  @override
  State<AddToMealScreen> createState() => _AddToMealScreenState();
}

class _AddToMealScreenState extends State<AddToMealScreen> {
  Map<String, dynamic>? _scannedNutrition; // holds result from label scanner
  final _gramsCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  DateTime _when = DateTime.now();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _gramsCtrl.text = widget.defaultGrams.toStringAsFixed(
      widget.defaultGrams.truncateToDouble() == widget.defaultGrams ? 0 : 1,
    );
  }

  Future<void> _openLabelScan() async {
    final result = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const LabelScanScreen(),
        fullscreenDialog: true,
      ),
    );

    if (!mounted || result == null) return;

    setState(() {
      _scannedNutrition = result;
      // If your form has only "grams", you can prefill it from the parsed serving size:
      final g = result['serving_size_g'];
      if ((_gramsCtrl.text.isEmpty || _gramsCtrl.text == '0') && g is num) {
        _gramsCtrl.text = g.toStringAsFixed(0);
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Nutrition parsed from label. Review & Save.')),
    );
  }

  Future<void> _onScanLabelPressed() async {
    final res = await Navigator.of(context).push<Map<String, dynamic>>(
      MaterialPageRoute(builder: (_) => const LabelScanScreen()),
    );
    if (!mounted || res == null) return;

    // Debug once to see what the scanner returned
    // (comment out later)
    // ignore: avoid_print
    print('LabelScan result: $res');

    double? _num(String k) {
      final v = res[k];
      if (v == null) return null;
      if (v is num) return v.toDouble();
      if (v is String) return double.tryParse(v);
      return null;
    }

    // Helper: try multiple keys, use the first that exists
    double? _firstNum(Iterable<String> keys) {
      for (final k in keys) {
        final n = _num(k);
        if (n != null) return n;
      }
      return null;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Nutrition fields filled from label scan')),
    );
  }


  @override
  void dispose() {
    _gramsCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDateTime() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _when,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (!mounted) return;
    if (d == null) return;
    final t = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_when),
    );
    if (!mounted) return;
    if (t == null) return;

    if (!mounted) return;
    setState(() {
      _when = DateTime(d.year, d.month, d.day, t.hour, t.minute);
    });
  }

  Future<void> _save() async {
    final grams = double.tryParse(_gramsCtrl.text.trim());
    if (grams == null || grams <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid quantity in grams')),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      final api = ApiClient();
      await api.addMeal(
        foodId: widget.foodId,
        quantity: grams,
        mealTime: _when,
        notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
      );
      if (!mounted) return;
      Navigator.pop(context, true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Meal logged!')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final whenText = DateFormat('y-MM-dd HH:mm').format(_when);

    return Scaffold(
      appBar: AppBar(title: const Text('Log Meal')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _gramsCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Quantity (grams)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _notesCtrl,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Notes (optional)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Text(whenText),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: _pickDateTime,
                  child: const Text('Pick time'),
                ),
              ],
            ),

            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _openLabelScan,
              icon: const Icon(Icons.document_scanner_outlined),
              label: const Text('Scan nutrition label'),
            ),

            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _saving ? null : _save,
                child: Text(_saving ? 'Saving…' : 'Save'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
