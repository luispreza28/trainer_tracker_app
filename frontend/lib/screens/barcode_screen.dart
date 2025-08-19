// lib/screens/barcode_screen.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../services/api_client.dart';
import '../services/auth_service.dart';
import '../models/food.dart';
import 'add_to_meal_screen.dart';
import 'token_settings_screen.dart';

class BarcodeScreen extends StatefulWidget {
  static const routeName = '/barcode';
  const BarcodeScreen({super.key});

  @override
  State<BarcodeScreen> createState() => _BarcodeScreenState();
}

class _BarcodeScreenState extends State<BarcodeScreen> {
  final _codeCtrl = TextEditingController();
  final _summaryKey = GlobalKey<_TodaysSummaryCardState>(); // ⬅️ key to call refresh()

  bool _loading = false;
  String? _error;
  Food? _food;

  @override
  void dispose() {
    _codeCtrl.dispose();
    super.dispose();
  }

  Future<void> _doImport() async {
    final code = _codeCtrl.text.trim();
    if (code.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a barcode')),
      );
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final food = await ApiClient().importByBarcode(code);
      if (!mounted) return;
      setState(() => _food = food);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Import failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _fmtNum(num? v, {int dp = 2}) {
    if (v == null) return '—';
    final fmt = NumberFormat('#,##0.${'0' * dp}');
    return fmt.format(v);
  }

  String _fmtInt(num? v) {
    if (v == null) return '—';
    final fmt = NumberFormat('#,##0');
    return fmt.format(v);
  }

  @override
  Widget build(BuildContext context) {
    final f = _food;
    final canLog = f?.id != null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Import by Barcode'),
        actions: [
          IconButton(
            tooltip: 'API Token',
            onPressed: () {
              Navigator.pushNamed(context, TokenSettingsScreen.routeName).then((saved) {
                if (saved == true) {
                  _summaryKey.currentState?.refresh();
                }
              });
            },
            icon: const Icon(Icons.vpn_key_outlined),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _codeCtrl,
                decoration: const InputDecoration(
                  labelText: 'Enter barcode',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                onSubmitted: (_) => _doImport(),
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: _loading ? null : _doImport,
                child: _loading ? const Text('Importing…') : const Text('Import'),
              ),

              // Today’s summary (token-aware) right below Import
              const SizedBox(height: 12),
              TodaysSummaryCard(key: _summaryKey, tz: 'America/Los_Angeles'),

              const SizedBox(height: 12),
              if (_error != null)
                Text(_error!, style: const TextStyle(color: Colors.red)),

              if (f != null) ...[
                Text(
                  f.name ?? 'Food',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                if (f.brand != null && f.brand!.isNotEmpty)
                  Text(
                    f.brand!,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                const SizedBox(height: 12),
                _NutrientRow(label: 'Calories', value: _fmtInt(f.nutrients?.calories), unit: ''),
                _NutrientRow(label: 'Protein',  value: _fmtNum(f.nutrients?.protein),  unit: 'g'),
                _NutrientRow(label: 'Carbs',    value: _fmtNum(f.nutrients?.carbs),    unit: 'g'),
                _NutrientRow(label: 'Fat',      value: _fmtNum(f.nutrients?.fat),      unit: 'g'),
                _NutrientRow(label: 'Fiber',    value: _fmtNum(f.nutrients?.fiber),    unit: 'g'),
                _NutrientRow(label: 'Sugar',    value: _fmtNum(f.nutrients?.sugar),    unit: 'g'),
                _NutrientRow(label: 'Sodium',   value: _fmtInt(f.nutrients?.sodium),   unit: 'mg'),
              ],

              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: canLog
                    ? () async {
                        final id = f!.id!;
                        final saved = await Navigator.push<bool>(
                          context,
                          MaterialPageRoute(
                            builder: (_) => AddToMealScreen(
                              foodId: id,
                              defaultGrams: 100,
                            ),
                          ),
                        );
                        // If AddToMealScreen reported success, refresh the summary
                        if (saved == true) {
                          _summaryKey.currentState?.refresh();
                        }
                      }
                    : null,
                child: const Text('Log Meal'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NutrientRow extends StatelessWidget {
  final String label;
  final String value;
  final String unit;
  const _NutrientRow({required this.label, required this.value, required this.unit});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(width: 80, child: Text('$label:')),
          const SizedBox(width: 8),
          Text(value),
          if (unit.isNotEmpty) Text(' $unit'),
        ],
      ),
    );
  }
}

/// "Today's Summary" card (token-aware + refresh)
class TodaysSummaryCard extends StatefulWidget {
  final String? tz; // e.g., 'America/Los_Angeles'
  const TodaysSummaryCard({super.key, this.tz});

  @override
  State<TodaysSummaryCard> createState() => _TodaysSummaryCardState();
}

class _TodaysSummaryCardState extends State<TodaysSummaryCard> {
  Future<Map<String, dynamic>>? _future;
  bool _noToken = false;

  @override
  void initState() {
    super.initState();
    _prepare();
  }

  /// Public method so parent can trigger a refresh
  void refresh() => _refresh();

  Future<void> _prepare() async {
    final token = await AuthService.getToken();
    if (!mounted) return;
    if (token == null || token.isEmpty) {
      setState(() {
        _noToken = true;
        _future = null;
      });
    } else {
      setState(() {
        _noToken = false;
        _future = ApiClient().getDailySummary(DateTime.now(), tz: widget.tz);
      });
    }
  }

  void _refresh() {
    setState(() {
      _future = ApiClient().getDailySummary(DateTime.now(), tz: widget.tz);
    });
  }

  @override
  Widget build(BuildContext context) {
    final nf0 = NumberFormat('#,##0');    // calories, sodium
    final nf2 = NumberFormat('#,##0.##'); // grams

    Widget row(String label, String value, String unit) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          children: [
            SizedBox(width: 90, child: Text(label)),
            const SizedBox(width: 8),
            Text(value),
            if (unit.isNotEmpty) Text(' $unit'),
          ],
        ),
      );
    }

    if (_noToken) {
      return Card(
        margin: const EdgeInsets.only(bottom: 12),
        child: ListTile(
          title: const Text("Today's summary"),
          subtitle: const Text('API token not set. Open Token settings to add your DRF token.'),
          trailing: TextButton(
            onPressed: () {
              Navigator.pushNamed(context, TokenSettingsScreen.routeName).then((_) => _prepare());
            },
            child: const Text('Set token'),
          ),
        ),
      );
    }

    if (_future == null) {
      return Card(
        margin: const EdgeInsets.only(bottom: 12),
        child: const ListTile(
          title: Text("Today's summary"),
          subtitle: Text('Loading…'),
        ),
      );
    }

    return FutureBuilder<Map<String, dynamic>>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: const ListTile(
              title: Text("Today's summary"),
              subtitle: Text('Loading…'),
            ),
          );
        }
        if (snap.hasError) {
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: ListTile(
              title: const Text("Today's summary"),
              subtitle: Text('Error: ${snap.error}'),
              trailing: IconButton(
                tooltip: 'Retry',
                icon: const Icon(Icons.refresh),
                onPressed: _refresh,
              ),
            ),
          );
        }

        final data = snap.data!;
        final totals = (data['totals'] as Map).cast<String, dynamic>();
        final units = (data['units'] as Map).cast<String, dynamic>();
        final entries = (data['entries'] as num?)?.toInt() ?? 0;

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        "Today's summary (${data['date']})",
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    IconButton(
                      tooltip: 'Refresh',
                      icon: const Icon(Icons.refresh),
                      onPressed: _refresh,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (entries == 0)
                  Text('No meals logged yet.',
                      style: Theme.of(context).textTheme.bodySmall),
                row('Calories', nf0.format(totals['calories'] ?? 0), units['calories'] ?? 'kcal'),
                row('Protein',  nf2.format(totals['protein']  ?? 0), units['protein']  ?? 'g'),
                row('Carbs',    nf2.format(totals['carbs']    ?? 0), units['carbs']    ?? 'g'),
                row('Fat',      nf2.format(totals['fat']      ?? 0), units['fat']      ?? 'g'),
                row('Fiber',    nf2.format(totals['fiber']    ?? 0), units['fiber']    ?? 'g'),
                row('Sugar',    nf2.format(totals['sugar']    ?? 0), units['sugar']    ?? 'g'),
                row('Sodium',   nf0.format(totals['sodium']   ?? 0), units['sodium']   ?? 'mg'),
              ],
            ),
          ),
        );
      },
    );
  }
}
