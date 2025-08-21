// lib/screens/log_meal_screen.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/food.dart';
import '../services/api_client.dart';

class LogMealScreen extends StatefulWidget {
  final Food food;
  const LogMealScreen({super.key, required this.food});

  @override
  State<LogMealScreen> createState() => _LogMealScreenState();
}

class _LogMealScreenState extends State<LogMealScreen> {
  final _qtyCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  DateTime? _when;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _when = DateTime.now();
  }

  @override
  void dispose() {
    _qtyCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDateTime() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _when ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (!mounted) return;
    if (d == null) return;
    
    final t = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_when ?? DateTime.now()),
    );
    if (!mounted) return;
    if (t == null) return;
    setState(() {
      _when = DateTime(d.year, d.month, d.day, t.hour, t.minute);
    });
  }

  Future<void> _submit() async {
    final txt = _qtyCtrl.text.trim();
    final qty = double.tryParse(txt);
    
    if (qty == null || qty <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid quantity in grams')),
      );
      return;
    }
    setState(() => _submitting = true);
    try {
      final api = ApiClient();
      await api.addMeal(
        foodId: widget.food.id!,
        quantity: qty,
        mealTime: _when,
        notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
      );
      if (mounted) {
        Navigator.pop(context, true); // return success
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Meal logged')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final f = widget.food;
    final whenText = _when == null
        ? 'Pick date/time'
        : DateFormat('y-MM-dd HH:mm').format(_when!);

    return Scaffold(
      appBar: AppBar(title: const Text('Log Meal')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(f.name ?? 'Food', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            TextField(
              controller: _qtyCtrl,
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
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _submitting ? null : _submit,
                child: Text(_submitting ? 'Saving…' : 'Save'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
