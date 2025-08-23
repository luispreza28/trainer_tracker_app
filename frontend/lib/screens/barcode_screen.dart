// lib/screens/barcode_screen.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/api_client.dart';
import '../services/auth_service.dart';
import '../models/food.dart';
import 'add_to_meal_screen.dart';
import 'token_settings_screen.dart';
import 'goals_screen.dart';
import '../services/goals_service.dart';
import '../services/tz_service.dart';
import '../services/file_saver.dart';
import '../services/export_service.dart';

class BarcodeScreen extends StatefulWidget {
  static const routeName = '/barcode';
  const BarcodeScreen({super.key});

  @override
  State<BarcodeScreen> createState() => _BarcodeScreenState();
}

class _BarcodeScreenState extends State<BarcodeScreen> {
  final _codeCtrl = TextEditingController();
  final GlobalKey<_TodaysSummaryCardState> _summaryKey = GlobalKey<_TodaysSummaryCardState>(); // ⬅️ key to call refresh()


  String _tz = 'America/Los_Angeles';
  DateTime _selectedDate = (() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  })();

  String _dateStr = DateFormat('yyyy-MM-dd').format(DateTime.now());

  bool _loading = false;
  String? _error;
  Food? _food;

  @override
  void dispose() {
    _codeCtrl.dispose();
    super.dispose();
  }

  // Export (CSV/JSON)
  void _openExportSheet() async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.grid_on),
              title: const Text('Export CSV'),
              onTap: () => Navigator.pop(ctx, 'csv'),
            ),
            ListTile(
              leading: const Icon(Icons.code),
              title: const Text('Export JSON'),
              onTap: () => Navigator.pop(ctx, 'json'),
            ),
          ],
        ),
      ),
    );
    if (!mounted || choice == null) return;
    if (choice == 'csv') {
      await _exportDayCsv();
    } else if (choice == 'json') {
      await _exportDayJson();
    }
  }

  Future<void> _exportDayCsv() async {
    try {
      final client = ApiClient();
      final summary = await client.getSummary(date: _dateStr, tz: _tz);
      final meals = await client.getMealsForDate(_dateStr, tz: _tz);
      final csv = ExportService.csvForDay(
        date: _dateStr,
        tz: _tz,
        summary: summary,
        meals: meals,
      );
      final filename = _safeFilename('trainer_${_dateStr}_$_tz.csv');
      await saveTextFile(filename, csv, mimeType: 'text/csv');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Exported $filename')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Export failed: $e')),
      );
    }
  }

  Future<void> _exportDayJson() async {
    try {
      final client = ApiClient();
      final summary = await client.getSummary(date: _dateStr, tz: _tz);
      final meals = await client.getMealsForDate(_dateStr, tz: _tz);
      final json = ExportService.jsonForDay(
        date: _dateStr,
        tz: _tz,
        summary: summary,
        meals: meals,
      );
      final filename = _safeFilename('trainer_${_dateStr}_$_tz.json');
      await saveTextFile(filename, json, mimeType: 'application/json');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Exported $filename')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Export failed: $e')),
      );
    }
  }

  String _safeFilename(String s) =>
      s.replaceAll('/', '-').replaceAll(RegExp(r'\s'), '_');
  

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _dateStr = DateFormat('yyyy-MM-dd').format(DateTime(now.year, now.month, now.day));
    // Run after first frame so GlobalKey children are mounted
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadTz();
    });
  }

  Future<void> _loadTz() async {
    final saved = await TzService().getTz();
    if (!mounted) return;
    if (saved != null && saved.isNotEmpty && saved != _tz) {
      setState(() => _tz = saved);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _summaryKey.currentState?.refresh(); // re-fetch summary for TZ
      });
    }
  }

  Future<void> _pickTz() async {
    const options = <String>[
      'America/Los_Angeles',
      'America/Denver',
      'America/Chicago',
      'America/New_York',
      'Europe/London',
      'Europe/Berlin',
      'Asia/Tokyo',
      'Australia/Sydney',
    ];
    final selected = await showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Select timezone'),
        children: [
          for (final tz in options)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(ctx, tz),
              child: Text(tz),
            ),
        ],
      ),
    );
    if (!mounted) return;
    if (selected != null && selected != _tz) {
      await TzService().setTz(selected);
      if (!mounted) return;
      setState(() => _tz = selected);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Timezone set to $selected')),
      );
      _summaryKey.currentState?.refresh(); // refresh in new TZ
    }
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

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      helpText: 'Select day',
    );
    if (picked != null) {
      setState(() {
        _selectedDate = DateTime(picked.year, picked.month, picked.day);
        _dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);
      });
    }
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

              // Date picker row
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    OutlinedButton.icon(
                      onPressed: _pickDate,
                      icon: const Icon(Icons.calendar_today, size: 18),
                      label: Text(_dateStr),
                    ),
                    IconButton(
                      icon: const Icon(Icons.flag),
                      tooltip: 'Goals',
                      onPressed: () async {
                        final updated = await Navigator.push<bool>(
                          context,
                          MaterialPageRoute(builder: (_) => const GoalsScreen()),
                        );
                        if (!mounted) return;
                        if (updated == true) {
                          _summaryKey.currentState?.refreshGoals();
                        }
                      },
                    ),
                    IconButton(onPressed: _pickTz, icon: const Icon(Icons.public), tooltip: 'Timezone ($_tz)'),
                    IconButton(onPressed: _openExportSheet, icon: const Icon(Icons.file_download), tooltip: 'Export day (CSV/JSON)'),
                    const SizedBox(width: 8),
                    TextButton(
                      onPressed: () {
                        final now = DateTime.now();
                        setState(() {
                          _selectedDate = DateTime(now.year, now.month, now.day);
                          _dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);
                        });
                      },
                      child: const Text('Today'),
                    ),
                    TextButton(
                      onPressed: () {
                        final y = DateTime.now().subtract(const Duration(days: 1));
                        setState(() {
                          _selectedDate = DateTime(y.year, y.month, y.day);
                          _dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);
                        });
                      },
                      child: const Text('Yesterday'),
                    ),
                    const Spacer(),
                    IconButton(
                      tooltip: 'Refresh cards',
                      onPressed: () => setState(() {}),
                      icon: const Icon(Icons.refresh),
                    ),
                  ],
                ),
              ),

              // Today’s summary (token-aware) right below Import
              const SizedBox(height: 12),
              TodaysSummaryCard(
                key: _summaryKey,
                tz: _tz,
                date: _dateStr,
              ),
              const SizedBox(height: 12),
              TodaysMealsList(
                key: ValueKey('meals-$_dateStr'),
                tz: _tz,
                date: _dateStr,
                onChanged: () => setState(() {}),
              ),

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

/// "Today's Summary" card (token-aware   refresh)
class TodaysSummaryCard extends StatefulWidget {
  final String tz;
  final String date;
  const TodaysSummaryCard({
    super.key,
    required this.tz,
    required this.date,
  });

  @override
  State<TodaysSummaryCard> createState() => _TodaysSummaryCardState();
}

class _TodaysSummaryCardState extends State<TodaysSummaryCard> {
  Future<Map<String, dynamic>>? _future;
  bool _noToken = false;
  Map<String, double> _goals = {};

  @override
  void initState() {
    super.initState();
    _prepare();
    _BarcodeScreenState()._loadTz();
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
        _goals = {};
      });
    } else {
      final goals = await GoalsService().getGoals();
      if (!mounted) return;
      setState(() {
        _noToken = false;
        _goals = goals;
        final date = widget.date;
        _future = ApiClient().getDailySummary(
          date,
          widget.tz,
        );
      });
    }
  }

  void _refresh() {
    setState(() {
      final date = widget.date;
      _future = ApiClient().getDailySummary(
        date,
        widget.tz,
      );
    });
  }

  Future<void> refreshGoals() async {
    final goals = await GoalsService().getGoals();
    if (!mounted) return;
    setState(() {
      _goals = goals;
      _future = ApiClient().getDailySummary(widget.date, widget.tz);
    });
  }

  @override
  Widget build(BuildContext context) {
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
        final nf2 = NumberFormat('#,##0.00'); // for grams
        final nf0 = NumberFormat('#,##0');    // for kcal / mg
        // helper to render a metric + goal progress
        Widget metricRowVal(String key, String label, String value, String unit) {
          final goal = _goals[key] ?? 0.0;
          final total = (totals[key] as num?)?.toDouble() ?? 0.0;
          final pct = (goal > 0) ? (total / goal).clamp(0.0, 1.0) : 0.0;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  SizedBox(width: 90, child: Text(label)),
                  const SizedBox(width: 8),
                  Text(value),
                  if (unit.isNotEmpty) Text(' $unit'),
                ],
              ),
              const SizedBox(height: 4),
              if (goal > 0) LinearProgressIndicator(value: pct, minHeight: 6),
              if (goal > 0)
                Padding(
                  padding: const EdgeInsets.only(top: 2, bottom: 6),
                  child: Text('Goal: ${NumberFormat('#,##0.##').format(goal)} $unit',
                      style: const TextStyle(fontSize: 12, color: Colors.black54)),
                ),
            ],
          );
        }
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
                        "Today's summary (${data['date']} • ${widget.tz})",
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
                metricRowVal('calories', 'Calories', nf0.format(totals['calories'] ?? 0), (units['calories'] as String?) ?? 'kcal'),
                metricRowVal('protein',  'Protein',  nf2.format(totals['protein']  ?? 0), (units['protein']  as String?) ?? 'g'),
                metricRowVal('carbs',    'Carbs',    nf2.format(totals['carbs']    ?? 0), (units['carbs']    as String?) ?? 'g'),
                metricRowVal('fat',      'Fat',      nf2.format(totals['fat']      ?? 0), (units['fat']      as String?) ?? 'g'),
                metricRowVal('fiber',    'Fiber',    nf2.format(totals['fiber']    ?? 0), (units['fiber']    as String?) ?? 'g'),
                metricRowVal('sugar',    'Sugar',    nf2.format(totals['sugar']    ?? 0), (units['sugar']    as String?) ?? 'g'),
                metricRowVal('sodium',   'Sodium',   nf0.format(totals['sodium']   ?? 0), (units['sodium']   as String?) ?? 'mg'),
              ],
            ),
          ),
        );
      },
    );
  }
}

class TodaysMealsList extends StatefulWidget {
  final String tz;
  final String date;
  final VoidCallback? onChanged; // call to refresh summary when meals change
  const TodaysMealsList({
    super.key,
    required this.tz,
    required this.date,
    this.onChanged,
  });
  @override
  State<TodaysMealsList> createState() => _TodaysMealsListState();
}

class _TodaysMealsListState extends State<TodaysMealsList> {
  Future<List<Map<String, dynamic>>>? _future;
  bool _noToken = false;

  @override
  void initState() {
    super.initState();
    _prepare();
    _BarcodeScreenState()._loadTz();
  }

  @override
  void didUpdateWidget(covariant TodaysMealsList oldWidget) {
    super.didUpdateWidget(oldWidget);
    // If parent changes date or tz, refresh this list.
    if (oldWidget.date != widget.date || oldWidget.tz != widget.tz) {
      setState(() {
        _future = ApiClient().getMealsForDate(widget.date, tz: widget.tz);
      });
    }
  }

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
        _future = ApiClient().getMealsForDate(
          widget.date,
          tz: widget.tz,
        );
      });
    }
  }

  void _load() {
    setState(() {
      _future = ApiClient().getMealsForDate(
        widget.date,
        tz: widget.tz,
      );
    });
  }

  Future<void> _delete(int id) async {
    await ApiClient().deleteMeal(id);
    _load();
    widget.onChanged?.call();
  }

  Future<void> _editQuantity(int id, double current) async {
    final ctrl = TextEditingController(text: current.toStringAsFixed(0));
    final grams = await showDialog<double>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit quantity (g)'),
        content: TextField(
          controller: ctrl,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              final v = double.tryParse(ctrl.text.trim());
              Navigator.pop(ctx, v);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (grams != null) {
      await ApiClient().updateMealQuantity(id, grams);
      _load();
      widget.onChanged?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    final df = DateFormat('yyyy-MM-dd');
    final nf0 = NumberFormat('#,##0');
    // final nf2 = NumberFormat('#,##0.##');

    if (_noToken) {
      return Card(
        child: ListTile(
          title: Text("Today's meals (${widget.date} • ${widget.tz})"),
          subtitle: const Text('API token not set. Open Token settings to add your DRF token.'),
          trailing: TextButton(
            onPressed: () {
              Navigator.pushNamed(context, TokenSettingsScreen.routeName)
                  .then((saved) => _prepare());
            },
            child: const Text('Set token'),
          ),
        ),
      );
    }

    if (_future == null) {
      return const Card(
        child: ListTile(title: Text("Today's meals"), subtitle: Text('Loading…')),
      );
    }

    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Card(
            child: ListTile(title: Text("Today's meals"), subtitle: Text('Loading…')),
          );
        }
        if (snap.hasError) {
          return Card(
            child: ListTile(
              title: const Text("Today's meals"),
              subtitle: Text('Error: ${snap.error}'),
              trailing: IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
            ),
          );
        }

        final items = snap.data!;
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text("Today's meals (${df.format(DateFormat('yyyy-MM-dd').parse(widget.date))} • ${widget.tz})",
                          style: Theme.of(context).textTheme.titleMedium),
                    ),
                    IconButton(icon: const Icon(Icons.refresh), tooltip: 'Refresh', onPressed: _load),
                  ],
                ),
                if (items.isEmpty)
                  Text('No meals yet.', style: Theme.of(context).textTheme.bodySmall),
                for (final m in items) ...[
                  const Divider(height: 16),
                  _MealRow(
                    id: m['id'] as int,
                    name: (m['food_name'] ?? 'Food') as String,
                    brand: (m['brand'] ?? '') as String,
                    grams: ((m['quantity'] ?? 0) as num).toDouble(),
                    kcal: (((m['totals']?['calories']) ?? 0) as num).toDouble(),
                    onEdit: _editQuantity,
                    onDelete: _delete,
                    nf0: nf0,
                  ),
                ]
              ],
            ),
          ),
        );
      },
    );
  }
}


class _MealRow extends StatelessWidget {
  final int id;
  final String name;
  final String brand;
  final double grams;
  final double kcal;
  final void Function(int id, double current) onEdit;
  final void Function(int id) onDelete;
  final NumberFormat nf0;

  const _MealRow({
    required this.id,
    required this.name,
    required this.brand,
    required this.grams,
    required this.kcal,
    required this.onEdit,
    required this.onDelete,
    required this.nf0,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(name, style: Theme.of(context).textTheme.bodyMedium),
              if (brand.isNotEmpty)
                Text(brand, style: Theme.of(context).textTheme.bodySmall),
              Text('${nf0.format(grams)} g • ${nf0.format(kcal)} kcal',
                style: Theme.of(context).textTheme.labelSmall),
            ],
          ),
        ),
        IconButton(icon: const Icon(Icons.edit), tooltip: 'Edit', onPressed: () => onEdit(id, grams)),
        IconButton(icon: const Icon(Icons.delete_outline), tooltip: 'Delete', onPressed: () => onDelete(id)),
      ],
    );
  }
}
