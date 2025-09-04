// lib/screens/add_to_meal_screen.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../services/api_client.dart';
import 'label_scan_screen.dart';
import 'label_review_result.dart'; // <-- make sure this import exists

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
    if (!mounted || d == null) return;

    final t = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_when),
    );
    if (!mounted || t == null) return;

    setState(() {
      _when = DateTime(d.year, d.month, d.day, t.hour, t.minute);
    });
  }

  Future<void> _openLabelScan() async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => LabelScanScreen(foodId: widget.foodId),
      ),
    );

    if (!mounted) return;

    if (saved == true) {
      // SnackBar BEFORE pop (project rule)
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Meal logged!')),
      );
      // Tell parent to refresh summary
      Navigator.pop(context, true);
    } else {
      // Optional: hint for the user
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Parsed label. Adjust grams (if needed) and tap Save.')),
      );
    }
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
    // Show SnackBar BEFORE popping (project rule)
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Meal logged!')),
    );
    // Signal caller to refresh its summary
    Navigator.pop(context, true);
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

            // Scan button
            OutlinedButton.icon(
              onPressed: _saving ? null : _openLabelScan,
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
