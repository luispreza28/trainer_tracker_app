import 'package:flutter/material.dart';
import '../services/api_client.dart';

class BarcodeScreen extends StatefulWidget {
  static const routeName = '/barcode';
  const BarcodeScreen({super.key});

  @override
  State<BarcodeScreen> createState() => _BarcodeScreenState();
}

class _BarcodeScreenState extends State<BarcodeScreen> {
  final _controller = TextEditingController();
  bool _loading = false;

  Future<void> _import() async {
    final code = _controller.text.trim();
    if (code.isEmpty) return;
    setState(() => _loading = true);
    try {
      final api = ApiClient();
      final food = await api.importByBarcode(code);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Imported: ${food.description}')),
      );
      // Placeholder next screen
      Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => AddToMealScreen(foodId: food.id, defaultGrams: 100),
      ));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Barcode')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _controller,
              keyboardType: TextInputType.number,
              maxLength: 18,
              decoration: const InputDecoration(
                labelText: 'Enter barcode',
                counterText: '',
              ),
              onSubmitted: (_) => _import(),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: (_loading || _controller.text.isEmpty) ? null : _import,
              icon: const Icon(Icons.qr_code),
              label: Text(_loading ? 'Importing…' : 'Import'),
            ),
          ],
        ),
      ),
    );
  }
}

// Minimal placeholder so navigation works
class AddToMealScreen extends StatelessWidget {
  final int foodId;
  final double defaultGrams;
  const AddToMealScreen({super.key, required this.foodId, this.defaultGrams = 100});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add to Meal')),
      body: Center(child: Text('Food $foodId • ${defaultGrams.toStringAsFixed(0)} g')),
    );
  }
}
