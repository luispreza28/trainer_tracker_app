import 'package:flutter/material.dart';
import '../services/api_client.dart';
import '../models/food.dart';
import 'add_to_meal_screen.dart';

class BarcodeScreen extends StatefulWidget {
  static const routeName = '/barcode';
  const BarcodeScreen({Key? key}) : super(key: key);

  @override
  State<BarcodeScreen> createState() => _BarcodeScreenState();
}

class _BarcodeScreenState extends State<BarcodeScreen> {
  final _controller = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _import() async {
    final code = _controller.text.trim();
    if (code.isEmpty) return;
    setState(() { _loading = true; _error = null; });
    try {
      final food = await ApiClient().importByBarcode(code);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Imported:  [200m${food.description} [0m')),
      );
      FocusScope.of(context).unfocus();
      await Future.delayed(const Duration(milliseconds: 300));
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => AddToMealScreen(foodId: food.id, defaultGrams: 100),
        ),
      );
    } on NotFoundException {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Product not found')),
      );
    } catch (e) {
      if (!mounted) return;
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
      appBar: AppBar(title: const Text('Barcode')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _controller,
              autofocus: true,
              keyboardType: TextInputType.number,
              maxLength: 18,
              decoration: const InputDecoration(
                labelText: 'Enter barcode',
                border: OutlineInputBorder(),
              ),
              onSubmitted: (_) => _import(),
              textInputAction: TextInputAction.done,
              onEditingComplete: () => FocusScope.of(context).unfocus(),
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _controller.text.trim().isEmpty || _loading
                    ? null
                    : _import,
                child: _loading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Import'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
