import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/goals_service.dart';

class GoalsScreen extends StatefulWidget {
  const GoalsScreen({super.key});

  @override
  State<GoalsScreen> createState() => _GoalsScreenState();
}

class _GoalsScreenState extends State<GoalsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _ctrl = <String, TextEditingController>{
    'calories': TextEditingController(),
    'protein': TextEditingController(),
    'carbs': TextEditingController(),
    'fat': TextEditingController(),
    'fiber': TextEditingController(),
    'sugar': TextEditingController(),
    'sodium': TextEditingController(),
  };

  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final c in _ctrl.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    final goals = await GoalsService().getGoals();
    if (!mounted) return;
    setState(() {
      _loading = false;
      _ctrl.forEach((k, c) => c.text = _fmt(goals[k]));
    });
  }

  String _fmt(double? v) {
    if (v == null) return '';
    return NumberFormat('0.##').format(v);
  }

  double? _parse(String s) => s.trim().isEmpty ? null : double.tryParse(s.trim());

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final map = <String, double>{};
    for (final entry in _ctrl.entries) {
      final v = _parse(entry.value.text);
      if (v != null) map[entry.key] = v;
    }
    await GoalsService().setGoals(map);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Goals saved')));
    Navigator.pop(context, true); // show SnackBar before pop (already shown)
  }

  Future<void> _reset() async {
    await GoalsService().clearGoals();
    if (!mounted) return;
    for (final c in _ctrl.values) {
        c.clear();
    }
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Goals cleared')));
  }

  Widget _numField(String key, String label, String unit) {
    return TextFormField(
      controller: _ctrl[key],
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(
        labelText: '$label ($unit)',
        border: const OutlineInputBorder(),
      ),
      onTap: () {
        // Select-all on focus
        final c = _ctrl[key]!;
        c.selection = TextSelection(baseOffset: 0, extentOffset: c.text.length);
      },
      validator: (s) {
        if (s == null || s.trim().isEmpty) return null; // optional
        return double.tryParse(s.trim()) == null ? 'Enter a number' : null;
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Daily Goals')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: ListView(
                  children: [
                    _numField('calories', 'Calories', 'kcal'),
                    const SizedBox(height: 10),
                    _numField('protein', 'Protein', 'g'),
                    const SizedBox(height: 10),
                    _numField('carbs', 'Carbs', 'g'),
                    const SizedBox(height: 10),
                    _numField('fat', 'Fat', 'g'),
                    const SizedBox(height: 10),
                    _numField('fiber', 'Fiber', 'g'),
                    const SizedBox(height: 10),
                    _numField('sugar', 'Sugar', 'g'),
                    const SizedBox(height: 10),
                    _numField('sodium', 'Sodium', 'mg'),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _save,
                            child: const Text('Save'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        TextButton(onPressed: _reset, child: const Text('Reset')),
                      ],
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}