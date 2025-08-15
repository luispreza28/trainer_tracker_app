import 'package:flutter/material.dart';
import '../services/api_client.dart';

class AddToMealScreen extends StatefulWidget {
  final int foodId;
  final double defaultGrams;
  const AddToMealScreen({Key? key, required this.foodId, this.defaultGrams = 100}) : super(key: key);

  @override
  State<AddToMealScreen> createState() => _AddToMealScreenState();
}

class _AddToMealScreenState extends State<AddToMealScreen> {
  final _gramsController = TextEditingController();
  String? _mealType;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _gramsController.text = widget.defaultGrams.toStringAsFixed(0);
  }

  @override
  void dispose() {
    _gramsController.dispose();
    super.dispose();
  }

  Future<void> _addMeal() async {
    final grams = double.tryParse(_gramsController.text.trim());
    if (grams == null || grams <= 0) {
      setState(() => _error = 'Enter a valid grams value');
      return;
    }
    setState(() { _loading = true; _error = null; });
    try {
      await ApiClient().addMeal(
        foodId: widget.foodId,
        grams: grams,
        mealType: _mealType,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Added to meal')),
      );
      Navigator.of(context).pop();
    } catch (e) {
      setState(() => _error = e.toString());
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      if (mounted) setState(() { _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add to Meal')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _gramsController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Grams',
                border: OutlineInputBorder(),
              ),
              enabled: !_loading,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _mealType,
              items: [null, 'breakfast', 'lunch', 'dinner', 'snack']
                  .map((type) => DropdownMenuItem<String>(
                        value: type,
                        child: Text(type == null ? 'Meal type (optional)' : type),
                      ))
                  .toList(),
              onChanged: _loading ? null : (v) => setState(() => _mealType = v),
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                const Text('Now', style: TextStyle(fontSize: 12)),
                const Spacer(),
              ],
            ),
            const SizedBox(height: 24),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(_error!, style: const TextStyle(color: Colors.red)),
              ),
            ElevatedButton(
              onPressed: _loading ? null : _addMeal,
              child: _loading
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Add to meal'),
            ),
          ],
        ),
      ),
    );
  }
}
