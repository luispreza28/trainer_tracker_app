// lib/screens/barcode_screen.dart
import 'package:flutter/material.dart';
import '../services/api_client.dart';
import '../models/food.dart';

class BarcodeScreen extends StatefulWidget {
  static const routeName = '/barcode';
  const BarcodeScreen({super.key});

  @override
  State<BarcodeScreen> createState() => _BarcodeScreenState();
}

class _BarcodeScreenState extends State<BarcodeScreen> {
  final _controller = TextEditingController();
  bool _loading = false;
  Food? _food;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _import() async {
    final code = _controller.text.trim();
    if (code.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a barcode')),
      );
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
      // keep existing _food visible until request finishes
    });

    try {
      final api = ApiClient();
      final food = await api.importByBarcode(code);
      setState(() => _food = food);
    } catch (e) {
      setState(() {
        _food = null;
        _error = e.toString();
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_error!)),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _fmt(num? v) => v == null ? '—' : v.toString();

  @override
  Widget build(BuildContext context) {
    final f = _food;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Import by Barcode'),
        actions: [
          IconButton(
            tooltip: 'API Token',
            icon: const Icon(Icons.vpn_key_outlined),
            onPressed: () {
              // Assumes you registered a '/token' route pointing to TokenSettingsScreen
              Navigator.pushNamed(context, '/token');
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _controller,
              keyboardType: TextInputType.number,
              maxLength: 18,
              decoration: const InputDecoration(
                labelText: 'Enter barcode',
                border: OutlineInputBorder(),
                counterText: '',
              ),
              onSubmitted: (_) => _import(),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _loading ? null : _import,
                child: Text(_loading ? 'Importing…' : 'Import'),
              ),
            ),
            const SizedBox(height: 16),

            if (_error != null) ...[
              Text(_error!, style: const TextStyle(color: Colors.red)),
              const SizedBox(height: 8),
            ],

            if (f != null) ...[
              Text(
                f.name ?? 'Food',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              if ((f.brand ?? '').isNotEmpty)
                Text(
                  f.brand!,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              const SizedBox(height: 8),
              Text('Calories: ${_fmt(f.nutrients?.calories)}'),
              Text('Protein:  ${_fmt(f.nutrients?.protein)} g'),
              Text('Carbs:    ${_fmt(f.nutrients?.carbs)} g'),
              Text('Fat:      ${_fmt(f.nutrients?.fat)} g'),
              Text('Sugar:    ${_fmt(f.nutrients?.sugar)} g'),
              Text('Sodium:   ${_fmt(f.nutrients?.sodium)} mg'),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    if (f.id == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Food ID missing')),
                      );
                      return;
                    }
                    final ok = await Navigator.pushNamed(
                      context,
                      '/log-meal',
                      arguments: {
                        'foodId': f.id!,        // pass the Food ID to the log-meal screen
                        'defaultGrams': 100.0,  // or any default you prefer
                      },
                    );
                    if (ok == true && context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Meal logged')),
                      );
                    }
                  },
                  child: const Text('Log Meal'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
